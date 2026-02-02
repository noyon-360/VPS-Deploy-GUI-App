import 'package:deploy_gui/models/client_config.dart';
import 'package:deploy_gui/models/log_entry.dart';
import 'package:deploy_gui/services/verification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditClientProvider with ChangeNotifier {
  final VerificationService _verifier = VerificationService();
  bool _disposed = false;

  // Form State
  String _deploymentType = 'backend';
  bool _enableSSL = false;

  String get deploymentType => _deploymentType;
  bool get enableSSL => _enableSSL;

  // Sidebar visibility and widths
  bool _isSidebarVisible = false;
  bool _isTerminalVisible = false;
  double _explorerWidth = 300;
  double _terminalWidth = 400;

  bool get isSidebarVisible => _isSidebarVisible;
  bool get isTerminalVisible => _isTerminalVisible;
  double get explorerWidth => _explorerWidth;
  double get terminalWidth => _terminalWidth;

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
  List<String> get runningApps => _runningApps;
  List<String> get activeSites => _activeSites;

  // Terminal Logs
  final List<LogEntry> _logs = [];
  List<LogEntry> get logs => List.unmodifiable(_logs);
  final ScrollController logScrollController = ScrollController();

  // Command History
  final List<String> _history = [];
  List<String> get history => _history;

  void setDeploymentType(String type) {
    _deploymentType = type;
    notifyListeners();
  }

  void setEnableSSL(bool enable) {
    _enableSSL = enable;
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

  void updateExplorerWidth(double delta, double maxWidth) {
    _explorerWidth += delta;
    if (_explorerWidth < 200) _explorerWidth = 200;
    if (_explorerWidth > maxWidth * 0.4) _explorerWidth = maxWidth * 0.4;
    notifyListeners();
  }

  void updateTerminalWidth(double delta, double maxWidth) {
    _terminalWidth -= delta;
    if (_terminalWidth < 200) _terminalWidth = 200;
    if (_terminalWidth > maxWidth * 0.4) _terminalWidth = maxWidth * 0.4;
    notifyListeners();
  }

  void addLog(String message, {LogType type = LogType.info}) {
    if (_disposed) return;
    _logs.add(LogEntry(message: message, type: type));
    notifyListeners();
    _scrollToBottom();
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

  Future<void> executeCommand(ClientConfig tempConfig, String command) async {
    if (command.trim().isEmpty || _disposed) return;

    _history.add(command);

    addLog('> $command', type: LogType.command);

    final success = await _verifier.runInteractiveCommand(
      tempConfig,
      command,
      onOutput: (output, isError) {
        if (!_disposed) {
          addLog(output, type: isError ? LogType.stderr : LogType.stdout);
        }
      },
    );

    if (!_disposed && !success) {
      addLog('Failed to execute command.', type: LogType.stderr);
    }
    if (!_disposed) {
      notifyListeners();
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

  Future<void> testConnection(ClientConfig tempConfig) async {
    _isVerifying = true;
    _verificationStatus = 'Connecting...';
    _logs.clear();
    _isTerminalVisible = true;
    notifyListeners();

    addLog('--- Starting Connection Test ---', type: LogType.info);

    final success = await _verifier.verifyConnection(
      tempConfig,
      onLog: (msg) => addLog(msg, type: LogType.info),
    );

    _isVerifying = false;
    _isVerified = success;
    _verificationStatus = success
        ? 'Connection Successful'
        : 'Connection Failed. Check credentials.';
    notifyListeners();

    addLog('--- Test Completed. Success: $success ---', type: LogType.info);

    if (success) {
      await refreshServerState(tempConfig);
    }
  }

  Future<void> refreshServerState(ClientConfig tempConfig) async {
    if (!_isVerified) return;

    final apps = await _verifier.getRunningApps(
      tempConfig,
      onLog: (msg) => addLog(msg, type: LogType.info),
    );
    final sites = await _verifier.getActiveSites(
      tempConfig,
      onLog: (msg) => addLog(msg, type: LogType.info),
    );

    _runningApps = apps;
    _activeSites = sites;
    notifyListeners();
  }

  Future<void> checkApp(ClientConfig tempConfig, String appName) async {
    if (!_isVerified || appName.isEmpty) return;

    _appVerificationState = 1; // Loading
    notifyListeners();
    addLog('--- Checking App Name: $appName ---', type: LogType.info);

    final exists = await _verifier.checkPm2Exists(
      tempConfig,
      appName,
      onLog: (msg) => addLog(msg, type: LogType.info),
    );

    _appVerificationState = exists ? 3 : 2;
    notifyListeners();
    addLog('--- App Check Completed. Exists: $exists ---', type: LogType.info);
  }

  Future<void> checkDomain(ClientConfig tempConfig, String domain) async {
    if (!_isVerified || domain.isEmpty) return;

    _domainVerificationState = 1; // Loading
    notifyListeners();
    addLog('--- Checking Domain: $domain ---', type: LogType.info);

    final exists = await _verifier.checkDomainConfigExists(
      tempConfig,
      domain,
      onLog: (msg) => addLog(msg, type: LogType.info),
    );

    _domainVerificationState = exists ? 3 : 2;
    notifyListeners();
    addLog(
      '--- Domain Check Completed. Exists: $exists ---',
      type: LogType.info,
    );
  }

  Future<bool> deleteApp(ClientConfig tempConfig, String appName) async {
    _isTerminalVisible = true;
    notifyListeners();
    addLog('--- Deletion Started: PM2 App $appName ---', type: LogType.info);

    final success = await _verifier.deletePm2App(
      tempConfig,
      appName,
      onLog: (msg) => addLog(msg, type: LogType.info),
    );

    if (success) {
      addLog('--- Deletion Successful: $appName ---', type: LogType.info);
      await refreshServerState(tempConfig);
    }
    return success;
  }

  Future<bool> deleteSite(ClientConfig tempConfig, String siteName) async {
    _isTerminalVisible = true;
    notifyListeners();
    addLog(
      '--- Deletion Started: Nginx Site $siteName ---',
      type: LogType.info,
    );

    final success = await _verifier.deleteNginxSite(
      tempConfig,
      siteName,
      onLog: (msg) => addLog(msg, type: LogType.info),
    );

    if (success) {
      addLog('--- Deletion Successful: $siteName ---', type: LogType.info);
      await refreshServerState(tempConfig);
    }
    return success;
  }

  @override
  void dispose() {
    _disposed = true;
    logScrollController.dispose();
    super.dispose();
  }
}
