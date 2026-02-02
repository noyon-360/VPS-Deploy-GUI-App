import 'package:deploy_gui/models/temp_client_config.dart';
import 'package:deploy_gui/models/log_entry.dart';
import 'package:deploy_gui/services/verification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:deploy_gui/models/remote_file.dart';
import 'package:deploy_gui/models/server_tool_status.dart';
import 'dart:convert'; // For utf8
import 'package:dartssh2/dartssh2.dart'; // For SSHClient
import 'dart:async';

class EditClientProvider with ChangeNotifier {
  final VerificationService _verifier = VerificationService();
  bool _disposed = false;
  // Global busy state for command execution
  bool _isBusy = false;

  // Cloning state
  bool _cloning = false;

  bool get isBusy => _isBusy;
  bool get cloning => _cloning;

  // Form State
  String _deploymentType = 'backend';
  bool _enableSSL = false;
  bool _hasUnsavedChanges = false;

  String get deploymentType => _deploymentType;
  bool get enableSSL => _enableSSL;
  bool get hasUnsavedChanges => _hasUnsavedChanges;

  // Sidebar visibility and widths
  bool _isSidebarVisible = false;
  bool _isTerminalVisible = false;
  double _explorerWidth = 300;
  double _terminalWidth = 400;

  double _centerTerminalHeight = 250;
  bool _isCenterTerminalVisible = false;

  bool get isSidebarVisible => _isSidebarVisible;
  bool get isTerminalVisible => _isTerminalVisible;
  bool get isCenterTerminalVisible => _isCenterTerminalVisible;
  double get explorerWidth => _explorerWidth;
  double get terminalWidth => _terminalWidth;
  double get centerTerminalHeight => _centerTerminalHeight;

  // Connection & Verification States
  bool _isVerified = false;
  bool _isVerifying = false;
  String? _verificationStatus;
  int _appVerificationState = 0; // 0=Initial, 1=Loading, 2=Available, 3=Exists
  int _domainVerificationState = 0;

  bool get isVerified => _isVerified;
  bool get isVerifying => _isVerifying;
  String? get verificationStatus => _verificationStatus;
  int get appVerificationState => _appVerificationState;
  int get domainVerificationState => _domainVerificationState;

  // Server Data
  List<String> _runningApps = [];
  List<String> _activeSites = [];
  List<RemoteFile> _files = [];
  String _currentPath = '/var/www';
  bool _isLoadingFiles = false;

  List<String> get runningApps => _runningApps;
  List<String> get activeSites => _activeSites;
  List<RemoteFile> get files => _files;
  String get currentPath => _currentPath;
  bool get isLoadingFiles => _isLoadingFiles;

  // Legacy logs for verification operations
  final List<LogEntry> _logs = [];
  List<LogEntry> get logs => List.unmodifiable(_logs);
  final ScrollController logScrollController = ScrollController();

  // Shell Logs for Interactive Console
  final List<LogEntry> _shellLogs = [];
  List<LogEntry> get shellLogs => List.unmodifiable(_shellLogs);
  final ScrollController shellScrollController = ScrollController();
  SSHSession? _shellSession;
  final FocusNode terminalFocusNode = FocusNode();

  // Step 1: Prerequisites
  List<ServerToolStatus> _serverTools = [];
  bool _checkingTools = false;
  List<ServerToolStatus> get serverTools => _serverTools;
  bool get checkingTools => _checkingTools;

  Future<void> checkServerPrerequisites(TempClientConfig config) async {
    if (_isBusy) return;
    _isBusy = true;
    _checkingTools = true;
    _isTerminalVisible = true;
    notifyListeners();

    try {
      addLog('--- Checking Server Prerequisites ---', type: LogType.info);
      final results = await _verifier.checkInstalledTools(
        config,
        onLog: _handleServiceLog,
      );
      _serverTools = results;

      final allInstalled = results.every((t) => t.isInstalled);
      if (allInstalled) {
        addLog(
          '--- All prerequisites found. Ready for deployment. ---',
          type: LogType.info,
        );
      } else {
        addLog(
          '--- Some tools are missing. Please install them. ---',
          type: LogType.stderr,
        );
      }
    } finally {
      _checkingTools = false;
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> installMissingTools(TempClientConfig config) async {
    if (_isBusy) return;
    _isBusy = true;
    _isTerminalVisible = true;
    notifyListeners();

    try {
      addLog('--- Installing Missing Tools ---', type: LogType.info);
      addLog(
        '>> sudo apt update && sudo apt install -y git nginx nodejs npm && sudo npm install -g pm2',
        type: LogType.command,
      );

      await _verifier.runInteractiveCommand(
        config,
        'sudo apt update && sudo apt install -y git nginx nodejs npm && sudo npm install -g pm2',
        onOutput: (msg, isError) {
          addLog(msg, type: isError ? LogType.stderr : LogType.stdout);
        },
      );

      addLog(
        '--- Installation command completed. Re-checking... ---',
        type: LogType.info,
      );
      _isBusy = false; // Release lock briefly for re-check call
      await checkServerPrerequisites(config);
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> cloneProject(TempClientConfig config) async {
    if (_cloning) return;
    _cloning = true;
    _isTerminalVisible = true;
    notifyListeners();

    try {
      addLog('--- Starting Project Setup ---', type: LogType.info);

      // 1. Validate inputs
      if (config.repo.isEmpty) {
        throw Exception('Git repository URL is required');
      }
      if (config.pathOnServer.isEmpty) {
        throw Exception('Destination path is required');
      }

      final client = await _verifier.connect(config);

      // 2. Check if destination exists
      addLog('> Checking destination: ${config.pathOnServer}');
      var checkDir = await client.run(
        'if [ -d "${config.pathOnServer}" ]; then echo "exists"; fi',
      );
      String checkDirOutput = utf8.decode(checkDir).trim();

      if (checkDirOutput == 'exists') {
        addLog('> Destination directory already exists.', type: LogType.stderr);
        // Optional: Ask user if they want to pull instead? For now, we'll try to pull if it's a git repo
        addLog('> Attempting to pull latest changes...');
        await _runCommand(client, 'cd "${config.pathOnServer}" && git pull');
      } else {
        // 3. Clone repository
        addLog('> Cloning repository...');

        // Handle auth if provided
        String repoUrl = config.repo;
        if (config.gitUsername != null && config.gitToken != null) {
          // Inserting credentials into URL: https://user:token@github.com/StartBlock/repo.git
          if (repoUrl.startsWith('https://')) {
            final cleanUrl = repoUrl.substring(8);
            repoUrl =
                'https://${config.gitUsername}:${config.gitToken}@$cleanUrl';
          }
        }

        final parentDir = config.pathOnServer.substring(
          0,
          config.pathOnServer.lastIndexOf('/'),
        );
        await _runCommand(client, 'mkdir -p "$parentDir"');

        await _runCommand(
          client,
          'git clone -b ${config.branch} "$repoUrl" "${config.pathOnServer}"',
        );
      }

      // 4. Install Dependencies
      addLog('> Installing dependencies...');
      await _runCommand(
        client,
        'cd "${config.pathOnServer}" && ${config.installCommand}',
      );

      addLog(
        '--- Project Setup Completed Successfully ---',
        type: LogType.info,
      );

      client.close();
    } catch (e) {
      addLog('Project Setup Failed: $e', type: LogType.stderr);
    } finally {
      _cloning = false;
      notifyListeners();
    }
  }

  Future<void> deployApp(TempClientConfig config) async {
    if (_isBusy) return;
    _isBusy = true;
    _isTerminalVisible = true;
    notifyListeners();

    try {
      addLog('--- Starting Application Deployment ---', type: LogType.info);

      // Validate inputs
      if (config.appName.isEmpty) {
        throw Exception('App name is required');
      }
      if (config.startCommand.isEmpty) {
        throw Exception('Start command is required');
      }
      if (config.pathOnServer.isEmpty) {
        throw Exception('Project path is required');
      }

      final client = await _verifier.connect(config);

      // 1. Stop/Delete existing if needed (optional, safer to just start/restart usually handling by pm2)
      // But let's check if it exists first?
      // For now, we'll assume the user provided a valid start command which might include specific flags.
      // Often, 'pm2 start ...' works even if running (it might duplicate), so 'pm2 restart' or 'delete' first is better.
      // Let's try to be smart: Check if running, if so restart. If not, start.
      // Actually, relying on the user's "Start Command" is most flexible.

      addLog('> Executing start command in ${config.pathOnServer}...');

      // Inject variables into command if they exist (simple replacement)
      String cmd = config.startCommand
          .replaceAll('{APP_NAME}', config.appName)
          .replaceAll('{PORT}', config.port);

      await _runCommand(client, 'cd "${config.pathOnServer}" && $cmd');

      // 2. Save PM2 list
      addLog('> Saving PM2 list...');
      await _runCommand(client, 'pm2 save');

      addLog('--- Deployment Completed Successfully ---', type: LogType.info);
      client.close();

      // Refresh state to show new app in sidebar
      await refreshServerState(config);
    } catch (e) {
      addLog('Deployment Failed: $e', type: LogType.stderr);
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> configureNginxAndSSL(TempClientConfig config) async {
    if (_isBusy) return;
    _isBusy = true;
    _isTerminalVisible = true;
    notifyListeners();

    try {
      addLog('--- Starting Domain & SSL Configuration ---', type: LogType.info);

      if (config.domain.isEmpty || config.domain == 'example.com') {
        throw Exception('Valid domain name is required');
      }
      if (config.port.isEmpty) throw Exception('Port is required');

      final client = await _verifier.connect(config);

      // 1. Create Nginx Config
      // Basic reverse proxy config
      final nginxConfig =
          '''
server {
    listen 80;
    server_name ${config.domain};

    location / {
        proxy_pass http://localhost:${config.port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
''';

      addLog('> Creating Nginx configuration for ${config.domain}...');

      // Write to temp file then move to sites-available (to avoid permission issues needing sudo for echo)
      // Actually we can use sudo bash -c "echo ... > file"
      // Escaping quotes is tricky. simpler to write to /tmp then move.
      final tmpFile = '/tmp/${config.domain}';
      await client.run("echo '$nginxConfig' > $tmpFile");

      final availablePath = '/etc/nginx/sites-available/${config.domain}';
      final enabledPath = '/etc/nginx/sites-enabled/${config.domain}';

      await _runCommand(client, 'sudo mv $tmpFile $availablePath');
      await _runCommand(client, 'sudo ln -sf $availablePath $enabledPath');

      // Check config syntax
      addLog('> Verifying Nginx configuration...');
      await _runCommand(client, 'sudo nginx -t');

      // Reload Nginx
      addLog('> Reloading Nginx...');
      await _runCommand(client, 'sudo systemctl reload nginx');

      // 2. SSL Setup (Certbot)
      if (config.enableSSL) {
        if (config.sslEmail == null || config.sslEmail!.isEmpty) {
          throw Exception('Email is required for SSL certificate');
        }

        addLog('> Requesting SSL certificate via Certbot...');
        // Install certbot if missing? We assumed it's there or user installed it.
        // Let's assume standard Ubuntu: sudo apt install python3-certbot-nginx
        // We'll try running it.

        // Non-interactive mode
        final certbotCmd =
            'sudo certbot --nginx -d ${config.domain} --non-interactive --agree-tos -m ${config.sslEmail} --redirect';
        await _runCommand(client, certbotCmd);
      }

      addLog(
        '--- Configuration Completed Successfully ---',
        type: LogType.info,
      );
      client.close();

      await refreshServerState(config);
    } catch (e) {
      addLog('Configuration Failed: $e', type: LogType.stderr);
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> _runCommand(SSHClient client, String command) async {
    addLog('>> $command');
    final session = await client.execute(command);

    // Stream stdout and stderr
    session.stdout.listen((data) {
      addLog(utf8.decode(data).trim());
    });

    session.stderr.listen((data) {
      addLog(utf8.decode(data).trim(), type: LogType.stderr);
    });

    await session.done;
    if (session.exitCode != 0) {
      throw Exception('Command failed with exit code ${session.exitCode}');
    }
  }

  void setDeploymentType(String type) {
    _deploymentType = type;
    notifyListeners();
  }

  void setEnableSSL(bool enable) {
    _enableSSL = enable;
    notifyListeners();
  }

  void markAsChanged() {
    if (!_hasUnsavedChanges) {
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }

  void markAsSaved() {
    _hasUnsavedChanges = false;
    notifyListeners();
  }

  void resetChangeTracking() {
    _hasUnsavedChanges = false;
    notifyListeners();
  }

  void toggleSidebar() {
    _isSidebarVisible = !_isSidebarVisible;
    notifyListeners();
  }

  void toggleTerminal() {
    _isTerminalVisible = !_isTerminalVisible;
    notifyListeners();
  }

  void setTerminalVisible(bool visible) {
    _isTerminalVisible = visible;
    notifyListeners();
  }

  void toggleCenterTerminal() {
    _isCenterTerminalVisible = !_isCenterTerminalVisible;
    notifyListeners();
  }

  void updateCenterTerminalHeight(double delta, double maxHeight) {
    if (!_isCenterTerminalVisible) return;
    _centerTerminalHeight -= delta;
    const double minH = 100;
    final double maxPossibleH = maxHeight * 0.8;

    if (_centerTerminalHeight < minH) {
      _centerTerminalHeight = minH;
    }
    if (_centerTerminalHeight > maxPossibleH) {
      _centerTerminalHeight = maxPossibleH;
    }
    notifyListeners();
  }

  Future<void> connectSSHShell(TempClientConfig config) async {
    if (_shellSession != null) {
      _shellSession!.close();
      _shellSession = null;
    }

    try {
      addLog('--- Opening Interactive Shell ---', type: LogType.info);
      _shellLogs.clear();
      _shellLogs.add(
        LogEntry(
          message: 'SSH Session Started. You can type commands below.',
          type: LogType.info,
        ),
      );
      _isCenterTerminalVisible = true;
      notifyListeners();

      final client = await _verifier.connect(config);
      _shellSession = await client.shell(
        pty: const SSHPtyConfig(width: 80, height: 24),
      );

      // Pipe SSH -> Shell Logs
      _shellSession!.stdout.listen((data) {
        _addShellLog(utf8.decode(data, allowMalformed: true));
      });
      _shellSession!.stderr.listen((data) {
        _addShellLog(
          utf8.decode(data, allowMalformed: true),
          type: LogType.stderr,
        );
      });

      _shellSession!.done.then((_) {
        if (_disposed) return;
        addLog('--- Interactive Shell Closed ---', type: LogType.info);
        _shellSession = null;
        notifyListeners();
      });

      terminalFocusNode.requestFocus();
    } catch (e) {
      addLog('Failed to open shell: $e', type: LogType.stderr);
      _shellSession = null;
      notifyListeners();
    }
  }

  void _addShellLog(String message, {LogType type = LogType.stdout}) {
    if (_disposed) return;
    String cleanMessage = _stripAnsi(message);
    if (cleanMessage.isEmpty && message.isNotEmpty) return;

    _shellLogs.add(LogEntry(message: cleanMessage.trimRight(), type: type));
    if (_shellLogs.length > 1000) _shellLogs.removeAt(0);

    notifyListeners();

    // Auto-scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (shellScrollController.hasClients) {
        shellScrollController.animateTo(
          shellScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void sendShellInput(String input) {
    if (_shellSession == null) return;
    _shellSession!.stdin.add(utf8.encode('$input\n'));
    // Optionally add a local echo of the command
    // _addShellLog('$ $input', type: LogType.info);
  }

  void disconnectTerminal() {
    _shellSession?.close();
    _shellSession = null;
    _shellLogs.add(
      LogEntry(message: 'Session disconnected', type: LogType.info),
    );
    notifyListeners();
  }

  void updateExplorerWidth(double delta, double maxWidth) {
    if (!_isSidebarVisible) return;

    // We want the center to be at least 400px
    const double centerMinW = 400;
    const double handleW = 24 * 2; // Two handles
    final double currentTerminalW = _isTerminalVisible ? _terminalWidth : 0;
    final double maxW = maxWidth - currentTerminalW - centerMinW - handleW;

    _explorerWidth += delta;
    const double minW = 180; // Minimum width when visible

    if (_explorerWidth < minW) {
      _explorerWidth = minW;
    }
    if (_explorerWidth > maxW) {
      _explorerWidth = maxW;
    }
    notifyListeners();
  }

  void updateTerminalWidth(double delta, double maxWidth) {
    if (!_isTerminalVisible) return;

    // We want the center to be at least 400px
    const double centerMinW = 400;
    const double handleW = 24 * 2;
    final double currentExplorerW = _isSidebarVisible ? _explorerWidth : 0;
    final double maxW = maxWidth - currentExplorerW - centerMinW - handleW;

    _terminalWidth -= delta;
    const double minW = 200; // Minimum width when visible

    if (_terminalWidth < minW) {
      _terminalWidth = minW;
    }
    if (_terminalWidth > maxW) {
      _terminalWidth = maxW;
    }
    notifyListeners();
  }

  void addLog(String message, {LogType type = LogType.info}) {
    if (_disposed) return;
    _logs.add(LogEntry(message: _stripAnsi(message), type: type));
    notifyListeners();
    _scrollToBottom();
  }

  String _stripAnsi(String input) {
    // Regex to match ANSI escape sequences
    final ansiRegex = RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]');
    return input.replaceAll(ansiRegex, '');
  }

  void addLogEntry(LogEntry entry) {
    _logs.add(entry);
    notifyListeners();
    _scrollToBottom();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  void copyLogsToClipboard() {
    final allLogs = _logs
        .map((e) => '[${e.formattedTimestamp}] ${e.message}')
        .join('\n');
    Clipboard.setData(ClipboardData(text: allLogs));
    addLog('System: All logs copied to clipboard.', type: LogType.info);
  }

  void clearTerminal() {
    // No-op
  }

  void _handleServiceLog(String message) {
    if (message.startsWith('>> ')) {
      addLog(message, type: LogType.command);
    } else if (message.startsWith('> Error') ||
        message.contains('Connection failed') ||
        message.contains('Failed')) {
      addLog(message, type: LogType.stderr);
    } else if (message.startsWith('> ')) {
      addLog(message, type: LogType.info);
    } else {
      addLog(message, type: LogType.stdout);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (logScrollController.hasClients) {
        logScrollController.animateTo(
          logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> testConnection(TempClientConfig tempConfig) async {
    if (_isBusy) return;
    _isBusy = true;
    _isVerifying = true;
    _verificationStatus = 'Connecting...';
    _logs.clear();
    _isTerminalVisible = true;
    notifyListeners();

    try {
      addLog('--- Starting Connection Test ---', type: LogType.info);

      final success = await _verifier.verifyConnection(
        tempConfig,
        onLog: _handleServiceLog,
      );

      _isVerified = success;
      _verificationStatus = success
          ? 'Connection Successful'
          : 'Connection Failed. Check credentials.';

      addLog('--- Test Completed. Success: $success ---', type: LogType.info);

      if (success) {
        await refreshServerState(tempConfig);
      }
    } finally {
      _isBusy = false;
      _isVerifying = false;
      notifyListeners();
    }
  }

  Future<void> refreshServerState(TempClientConfig tempConfig) async {
    if (!_isVerified) return;

    final apps = await _verifier.getRunningApps(
      tempConfig,
      onLog: _handleServiceLog,
    );
    final sites = await _verifier.getActiveSites(
      tempConfig,
      onLog: _handleServiceLog,
    );

    _runningApps = apps;
    _activeSites = sites;

    // Initial file fetch if empty
    if (_files.isEmpty) {
      await fetchFiles(tempConfig, _currentPath);
    }

    notifyListeners();
  }

  // File Explorer Methods
  Future<void> fetchFiles(TempClientConfig config, String path) async {
    _isLoadingFiles = true;
    notifyListeners();

    // Log the cd command for user visibility
    if (path != _currentPath) {
      addLog('>> cd "$path"', type: LogType.command);
    }

    final fileList = await _verifier.listFiles(
      config,
      path,
      onLog: _handleServiceLog,
    );

    _files = fileList;
    _currentPath = path;
    _isLoadingFiles = false;
    notifyListeners();
  }

  Future<void> navigateUp(TempClientConfig config) async {
    if (_currentPath == '/') return;

    // Simple path manipulation for parent
    final parts = _currentPath.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isNotEmpty) {
      parts.removeLast();
    }
    final parentPath = parts.isEmpty ? '/' : '/${parts.join('/')}';

    await fetchFiles(config, parentPath);
  }

  Future<void> navigateTo(TempClientConfig config, String path) async {
    await fetchFiles(config, path);
  }

  Future<void> catFile(TempClientConfig config, String path) async {
    if (_isBusy) return;
    _isBusy = true;
    notifyListeners();

    // Ensure logs are visible to see the content
    _isTerminalVisible = true;
    notifyListeners();

    try {
      addLog('--- Reading file: $path ---', type: LogType.info);
      await _verifier.catFile(config, path, onLog: _handleServiceLog);
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> checkApp(TempClientConfig tempConfig, String appName) async {
    if (!_isVerified || appName.isEmpty || _isBusy) return;

    _isBusy = true;
    _appVerificationState = 1; // Loading
    notifyListeners();

    try {
      addLog('--- Checking App Name: $appName ---', type: LogType.info);

      final exists = await _verifier.checkPm2Exists(
        tempConfig,
        appName,
        onLog: _handleServiceLog,
      );

      _appVerificationState = exists ? 3 : 2;
      addLog(
        '--- App Check Completed. Exists: $exists ---',
        type: LogType.info,
      );
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> checkDomain(TempClientConfig tempConfig, String domain) async {
    if (!_isVerified || domain.isEmpty || _isBusy) return;

    _isBusy = true;
    _domainVerificationState = 1; // Loading
    notifyListeners();

    try {
      addLog('--- Checking Domain: $domain ---', type: LogType.info);

      final exists = await _verifier.checkDomainConfigExists(
        tempConfig,
        domain,
        onLog: _handleServiceLog,
      );

      _domainVerificationState = exists ? 3 : 2;
      addLog(
        '--- Domain Check Completed. Exists: $exists ---',
        type: LogType.info,
      );
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> deleteApp(TempClientConfig config, String appName) async {
    if (_isBusy) return false;
    _isBusy = true;
    _isTerminalVisible = true;
    notifyListeners();

    try {
      addLog('--- Deletion Started: PM2 App $appName ---', type: LogType.info);

      final success = await _verifier.deletePm2App(
        config,
        appName,
        onLog: _handleServiceLog,
      );

      if (success) {
        addLog('--- Deletion Successful: $appName ---', type: LogType.info);
        await refreshServerState(config);
      }
      return success;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> deleteSite(TempClientConfig config, String siteName) async {
    if (_isBusy) return false;
    _isBusy = true;
    _isTerminalVisible = true;
    notifyListeners();

    try {
      addLog(
        '--- Deletion Started: Nginx Site $siteName ---',
        type: LogType.info,
      );

      final success = await _verifier.deleteNginxSite(
        config,
        siteName,
        onLog: _handleServiceLog,
      );

      if (success) {
        addLog('--- Deletion Successful: $siteName ---', type: LogType.info);
        await refreshServerState(config);
      }
      return success;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    disconnectTerminal();
    shellScrollController.dispose();
    terminalFocusNode.dispose();
    logScrollController.dispose();
    super.dispose();
  }
}
