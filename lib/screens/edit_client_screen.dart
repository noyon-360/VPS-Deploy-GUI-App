import 'package:deploy_gui/models/client_config.dart';
import 'package:deploy_gui/providers/app_provider.dart';
import 'package:deploy_gui/services/verification_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class EditClientScreen extends StatefulWidget {
  final ClientConfig? client;

  const EditClientScreen({super.key, this.client});

  @override
  State<EditClientScreen> createState() => _EditClientScreenState();
}

class _EditClientScreenState extends State<EditClientScreen> {
  final _formKey = GlobalKey<FormState>();
  String _deploymentType = 'backend';
  bool _enableSSL = false;
  late TextEditingController _sslEmailController;
  final VerificationService _verifier = VerificationService();
  bool _isVerified = false;
  bool _isVerifying = false;
  String? _verificationStatus;

  late TextEditingController _nameController;
  late TextEditingController _serverAliasController;
  late TextEditingController _repoController;
  late TextEditingController _branchController;
  late TextEditingController _domainController;
  late TextEditingController _portController;
  late TextEditingController _appNameController;
  late TextEditingController _pathOnServerController;
  late TextEditingController _nginxConfController;
  late TextEditingController _installCommandController;
  late TextEditingController _startCommandController;
  late TextEditingController _passwordController;
  late TextEditingController _gitUsernameController;
  late TextEditingController _gitTokenController;

  // Verification States: 0=Initial, 1=Loading, 2=Available(Green), 3=Exists(Orange/Warning)
  int _appVerificationState = 0;
  int _domainVerificationState = 0;

  List<String> _runningApps = [];
  List<String> _activeSites = [];

  // Terminal Logs
  final List<String> _logs = [];
  bool _isTerminalVisible = false;
  bool _isSidebarVisible = false; // New left sidebar state
  double _explorerWidth = 300;
  double _terminalWidth = 400;
  final ScrollController _logScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final c = widget.client;
    _nameController = TextEditingController(text: c?.name ?? '');
    _serverAliasController = TextEditingController(text: c?.serverAlias ?? '');
    _repoController = TextEditingController(text: c?.repo ?? '');
    _branchController = TextEditingController(text: c?.branch ?? 'main');
    _domainController = TextEditingController(text: c?.domain ?? '');
    _portController = TextEditingController(text: c?.port ?? '5001');
    _appNameController = TextEditingController(text: c?.appName ?? 'backend');
    _pathOnServerController = TextEditingController(
      text: c?.pathOnServer ?? '/var/www/backend',
    );
    _nginxConfController = TextEditingController(
      text: c?.nginxConf ?? '/etc/nginx/sites-available/backend',
    );
    _installCommandController = TextEditingController(
      text: c?.installCommand ?? 'npm install',
    );
    _startCommandController = TextEditingController(
      text:
          c?.startCommand ??
          'pm2 start server.js --name "{APP_NAME}" -- --port {PORT}',
    );
    _passwordController = TextEditingController(text: c?.password ?? '');
    _gitUsernameController = TextEditingController(text: c?.gitUsername ?? '');
    _gitTokenController = TextEditingController(text: c?.gitToken ?? '');
    _deploymentType = c?.type ?? 'backend';
    _enableSSL = c?.enableSSL ?? false;
    _sslEmailController = TextEditingController(text: c?.sslEmail ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _serverAliasController.dispose();
    _repoController.dispose();
    _branchController.dispose();
    _domainController.dispose();
    _portController.dispose();
    _appNameController.dispose();
    _pathOnServerController.dispose();
    _nginxConfController.dispose();
    _installCommandController.dispose();
    _startCommandController.dispose();
    _passwordController.dispose();
    _gitUsernameController.dispose();
    _gitTokenController.dispose();
    _sslEmailController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final config = ClientConfig(
        id: widget.client?.id ?? const Uuid().v4(),
        name: _nameController.text,
        serverAlias: _serverAliasController.text,
        repo: _repoController.text,
        branch: _branchController.text,
        domain: _domainController.text,
        port: _portController.text,
        appName: _appNameController.text,
        pathOnServer: _pathOnServerController.text,
        nginxConf: _nginxConfController.text,
        installCommand: _installCommandController.text,
        startCommand: _startCommandController.text,
        password: _passwordController.text.isEmpty
            ? null
            : _passwordController.text,
        gitUsername: _gitUsernameController.text.isEmpty
            ? null
            : _gitUsernameController.text,
        gitToken: _gitTokenController.text.isEmpty
            ? null
            : _gitTokenController.text,
        type: _deploymentType,
        enableSSL: _enableSSL,
        sslEmail: _enableSSL && _sslEmailController.text.isNotEmpty
            ? _sslEmailController.text
            : null,
      );

      if (widget.client == null) {
        context.read<AppProvider>().addClient(config);
      } else {
        context.read<AppProvider>().updateClient(config);
      }
      Navigator.pop(context);
    }
  }

  void _addLog(String message) {
    if (mounted) {
      setState(() {
        _logs.add(
          '${DateTime.now().toIso8601String().split('T')[1].substring(0, 8)} $message',
        );
        // Auto-show terminal on new significant logs if preferred, or just let user toggle
      });
      // Scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_logScrollController.hasClients) {
          _logScrollController.jumpTo(
            _logScrollController.position.maxScrollExtent,
          );
        }
      });
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isVerifying = true;
      _verificationStatus = 'Connecting...';
      _logs.clear();
      _isTerminalVisible = true; // Auto-open terminal on manual test
    });

    _addLog('--- Starting Connection Test ---');

    final tempConfig = ClientConfig(
      id: 'temp',
      name: 'temp',
      serverAlias: _serverAliasController.text,
      repo: '',
      appName: '',
      pathOnServer: '',
      nginxConf: '',
      domain: '',
      password: _passwordController.text.isEmpty
          ? null
          : _passwordController.text,
    );

    final success = await _verifier.verifyConnection(
      tempConfig,
      onLog: _addLog,
    );

    if (mounted) {
      setState(() {
        _isVerifying = false;
        _isVerified = success;
        _verificationStatus = success
            ? 'Connection Successful'
            : 'Connection Failed. Check credentials.';
      });

      _addLog('--- Test Completed. Success: $success ---');

      if (success) {
        // Fetch Info
        final apps = await _verifier.getRunningApps(tempConfig, onLog: _addLog);
        final sites = await _verifier.getActiveSites(
          tempConfig,
          onLog: _addLog,
        );
        if (mounted) {
          setState(() {
            _runningApps = apps;
            _activeSites = sites;
          });
        }
      }
    }
  }

  Future<void> _checkApp() async {
    if (!_isVerified || _appNameController.text.isEmpty) return;

    setState(() => _appVerificationState = 1); // Loading
    _addLog('--- Checking App Name: ${_appNameController.text} ---');

    final tempConfig = _createTempConfig();
    final exists = await _verifier.checkPm2Exists(
      tempConfig,
      _appNameController.text,
      onLog: _addLog,
    );

    if (mounted) {
      setState(() {
        // If exists -> 3 (Warning), If not -> 2 (Green/Available)
        _appVerificationState = exists ? 3 : 2;
      });
      _addLog('--- App Check Completed. Exists: $exists ---');
    }
  }

  Future<void> _checkDomain() async {
    if (!_isVerified || _domainController.text.isEmpty) return;

    setState(() => _domainVerificationState = 1); // Loading
    _addLog('--- Checking Domain: ${_domainController.text} ---');

    final tempConfig = _createTempConfig();
    final exists = await _verifier.checkDomainConfigExists(
      tempConfig,
      _domainController.text,
      onLog: _addLog,
    );

    if (mounted) {
      setState(() {
        _domainVerificationState = exists ? 3 : 2;
      });
      _addLog('--- Domain Check Completed. Exists: $exists ---');
    }
  }

  Future<void> _deleteApp(String appName) async {
    final confirmed = await _showConfirmDialog(
      'Delete PM2 App',
      'Are you sure you want to delete "$appName" from the server?',
    );
    if (!confirmed) return;

    setState(() => _isTerminalVisible = true);
    _addLog('--- Deletion Started: PM2 App $appName ---');
    final tempConfig = _createTempConfig();
    final success = await _verifier.deletePm2App(
      tempConfig,
      appName,
      onLog: _addLog,
    );

    if (success) {
      _addLog('--- Deletion Successful: $appName ---');
      await _refreshServerState();
    }
  }

  Future<void> _deleteSite(String siteName) async {
    final confirmed = await _showConfirmDialog(
      'Delete Nginx Site',
      'Are you sure you want to delete Nginx configuration for "$siteName"?',
    );
    if (!confirmed) return;

    setState(() => _isTerminalVisible = true);
    _addLog('--- Deletion Started: Nginx Site $siteName ---');
    final tempConfig = _createTempConfig();
    final success = await _verifier.deleteNginxSite(
      tempConfig,
      siteName,
      onLog: _addLog,
    );

    if (success) {
      _addLog('--- Deletion Successful: $siteName ---');
      await _refreshServerState();
    }
  }

  Future<void> _refreshServerState() async {
    if (!_isVerified) return;
    final tempConfig = _createTempConfig();
    final apps = await _verifier.getRunningApps(tempConfig, onLog: _addLog);
    final sites = await _verifier.getActiveSites(tempConfig, onLog: _addLog);
    if (mounted) {
      setState(() {
        _runningApps = apps;
        _activeSites = sites;
      });
    }
  }

  void _selectApp(String appName) {
    setState(() {
      _appNameController.text = appName;
      // Also try to guess default path/conf if they seem to follow the name
      if (_pathOnServerController.text.contains('backend') ||
          _pathOnServerController.text.contains('website')) {
        _pathOnServerController.text = '/var/www/$appName';
      }
    });
    _checkApp(); // Trigger validation UI
  }

  void _selectSite(String domain) {
    setState(() {
      _domainController.text = domain;
    });
    _checkDomain(); // Trigger validation UI
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  ClientConfig _createTempConfig() {
    return ClientConfig(
      id: 'temp',
      name: 'temp',
      serverAlias: _serverAliasController.text,
      repo: '',
      appName: '',
      pathOnServer: '',
      nginxConf: '',
      domain: '',
      password: _passwordController.text.isEmpty
          ? null
          : _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.client == null ? 'Add New Client' : 'Edit Client'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Row(
        children: [
          _buildExplorerSidebar(),
          _buildResizeHandle(isLeft: true),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40.0,
                    vertical: 24.0,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildSectionHeader(
                          'Credentials & Connection',
                          Icons.key_outlined,
                        ),
                        _buildCardLayout([
                          _buildTextField(
                            _serverAliasController,
                            'SSH Destination',
                            'root@1.2.3.4',
                          ),
                          _buildTextField(
                            _passwordController,
                            'SSH Password',
                            'Leave blank to use keys',
                            isPassword: true,
                          ),
                        ]),
                        const SizedBox(height: 16),
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _isVerifying ? null : _testConnection,
                            icon: _isVerifying
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    _isVerified
                                        ? Icons.check_circle
                                        : Icons.wifi,
                                    color: _isVerified
                                        ? Colors.green
                                        : Colors.white,
                                  ),
                            label: Text(
                              _isVerified ? 'Connected' : 'Test Connection',
                              style: TextStyle(
                                color: _isVerified
                                    ? Colors.green
                                    : Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.08,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ),
                        if (_verificationStatus != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Center(
                              child: Text(
                                _verificationStatus!,
                                style: TextStyle(
                                  color: _isVerified
                                      ? Colors.green
                                      : Colors.redAccent,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),

                        if (_isVerified &&
                            (_runningApps.isNotEmpty ||
                                _activeSites.isNotEmpty))
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_runningApps.isNotEmpty) ...[
                                  Text(
                                    'Running PM2 Apps:',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: _runningApps
                                        .map(
                                          (app) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.green.withValues(
                                                  alpha: 0.3,
                                                ),
                                              ),
                                            ),
                                            child: Text(
                                              app,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.greenAccent,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (_activeSites.isNotEmpty) ...[
                                  Text(
                                    'Active Nginx Sites:',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: _activeSites
                                        .map(
                                          (site) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.blue.withValues(
                                                  alpha: 0.3,
                                                ),
                                              ),
                                            ),
                                            child: Text(
                                              site,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.lightBlueAccent,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),

                        if (_isVerified) ...[
                          _buildSectionHeader(
                            'General Information',
                            Icons.info_outline,
                          ),
                          _buildCardLayout([
                            _buildTextField(
                              _nameController,
                              'Client Name',
                              'My Website',
                            ),
                            _buildDeploymentTypeDropdown(),
                          ]),

                          _buildSectionHeader(
                            'Deployment Settings',
                            Icons.settings_outlined,
                          ),
                          _buildCardLayout([
                            _buildTextField(
                              _repoController,
                              'Git Repository',
                              'git@github.com:user/repo.git',
                            ),
                            _buildTextField(
                              _branchController,
                              'Branch',
                              'main',
                            ),
                            Focus(
                              onFocusChange: (hasNext) {
                                if (!hasNext) _checkDomain();
                              },
                              child: _buildTextField(
                                _domainController,
                                'Domain',
                                'api.example.com',
                                verificationState: _domainVerificationState,
                                verificationMessage:
                                    _domainVerificationState == 3
                                    ? 'Domain config exists'
                                    : (_domainVerificationState == 2
                                          ? 'Domain available'
                                          : null),
                              ),
                            ),
                            _buildTextField(
                              _portController,
                              'App Port',
                              '5001',
                            ),
                            Focus(
                              onFocusChange: (hasNext) {
                                if (!hasNext) _checkApp();
                              },
                              child: _buildTextField(
                                _appNameController,
                                'App Name (PM2)',
                                'backend',
                                verificationState: _appVerificationState,
                                verificationMessage: _appVerificationState == 3
                                    ? 'App already running (Update)'
                                    : (_appVerificationState == 2
                                          ? 'App name available'
                                          : null),
                              ),
                            ),
                            _buildTextField(
                              _pathOnServerController,
                              'Server Path',
                              '/var/www/backend',
                            ),
                            _buildTextField(
                              _nginxConfController,
                              'NGINX Config Path',
                              '/etc/nginx/sites-enabled/default',
                            ),
                          ]),

                          _buildSectionHeader(
                            'Git Credentials (Optional)',
                            Icons.lock_outline,
                          ),
                          _buildCardLayout([
                            _buildTextField(
                              _gitUsernameController,
                              'Git Username',
                              'Username',
                            ),
                            _buildTextField(
                              _gitTokenController,
                              'Git Token',
                              'Token',
                              isPassword: true,
                            ),
                          ]),

                          _buildSectionHeader(
                            'Commands',
                            Icons.terminal_outlined,
                          ),
                          _buildCardLayout([
                            _buildTextField(
                              _installCommandController,
                              'Install Command',
                              'npm install',
                            ),
                            _buildTextField(
                              _startCommandController,
                              'Start Command',
                              'pm2 start...',
                            ),
                          ]),

                          _buildSectionHeader(
                            'SSL Configuration',
                            Icons.security,
                          ),
                          _buildCardLayout([
                            _buildSwitch('Enable SSL (Certbot)', _enableSSL, (
                              val,
                            ) {
                              setState(() {
                                _enableSSL = val;
                              });
                            }),
                            if (_enableSSL)
                              _buildTextField(
                                _sslEmailController,
                                'SSL Email',
                                'email@example.com',
                              ),
                          ]),

                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                textStyle: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              child: const Text('Save Configuration'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          _buildResizeHandle(isLeft: false),
          _buildTerminalView(),
        ],
      ),
    );
  }

  Widget _buildResizeHandle({required bool isLeft}) {
    final isVisible = isLeft ? _isSidebarVisible : _isTerminalVisible;
    if (!isVisible) return const SizedBox();

    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          setState(() {
            if (isLeft) {
              _explorerWidth += details.delta.dx;
              if (_explorerWidth < 200) _explorerWidth = 200;
              if (_explorerWidth > MediaQuery.of(context).size.width * 0.4) {
                _explorerWidth = MediaQuery.of(context).size.width * 0.4;
              }
            } else {
              _terminalWidth -= details.delta.dx;
              if (_terminalWidth < 200) _terminalWidth = 200;
              if (_terminalWidth > MediaQuery.of(context).size.width * 0.4) {
                _terminalWidth = MediaQuery.of(context).size.width * 0.4;
              }
            }
          });
        },
        child: Container(
          width: 4,
          color: Colors.transparent,
          height: double.infinity,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 24, left: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.78)),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardLayout(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWide = constraints.maxWidth > 600;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Wrap(
              spacing: 24,
              runSpacing: 0,
              children: children
                  .map(
                    (child) => SizedBox(
                      width: isWide
                          ? (constraints.maxWidth - 72) / 2
                          : double.infinity,
                      child: child,
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeploymentTypeDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: DropdownButtonFormField<String>(
        initialValue: _deploymentType,
        decoration: InputDecoration(
          labelText: 'Deployment Type',
          filled: true,
          fillColor: Colors.black.withValues(alpha: 0.08),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        dropdownColor: Colors.grey[900],
        style: const TextStyle(fontSize: 14, color: Colors.white),
        items: const [
          DropdownMenuItem(value: 'backend', child: Text('Backend (Node.js)')),
          DropdownMenuItem(value: 'website', child: Text('Website (Next.js)')),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _deploymentType = value;
              _updateDefaultsForType(value);
            });
          }
        },
      ),
    );
  }

  void _updateDefaultsForType(String type) {
    if (type == 'backend') {
      _installCommandController.text = 'npm install';
      _startCommandController.text =
          'pm2 start server.js --name "{APP_NAME}" -- --port {PORT}';
      _portController.text = '5001';
      _appNameController.text = 'backend';
      _pathOnServerController.text = '/var/www/backend';
      _nginxConfController.text = '/etc/nginx/sites-available/backend';
    } else if (type == 'website') {
      _installCommandController.text = 'npm install && npm run build';
      _startCommandController.text =
          'pm2 start npm --name "{APP_NAME}" -- start -- --port {PORT}';
      _portController.text = '3000';
      _appNameController.text = 'website';
      _pathOnServerController.text = '/var/www/website';
      _nginxConfController.text = '/etc/nginx/sites-available/website';
    }
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint, {
    bool isPassword = false,
    int verificationState = 0, // 0: None, 1: Loading, 2: Good, 3: Warning
    String? verificationMessage,
  }) {
    Widget? suffix;
    if (verificationState == 1) {
      suffix = const Padding(
        padding: EdgeInsets.all(12.0),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else if (verificationState == 2) {
      suffix = const Icon(Icons.check_circle, color: Colors.green);
    } else if (verificationState == 3) {
      suffix = const Icon(Icons.warning_amber_rounded, color: Colors.orange);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: controller,
            obscureText: isPassword,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              alignLabelWithHint: true,
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.08),
              suffixIcon: suffix,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            validator: (value) {
              // Password/Tokens optional depending on use
              if (isPassword) return null;
              if (value == null || value.isEmpty) {
                return 'Please enter $label';
              }
              return null;
            },
          ),
          if (verificationMessage != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 4),
              child: Text(
                verificationMessage,
                style: TextStyle(
                  fontSize: 12,
                  color: verificationState == 2 ? Colors.green : Colors.orange,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExplorerSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      width: _isSidebarVisible ? _explorerWidth : 36,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        children: [
          // Header Toggle
          InkWell(
            onTap: () => setState(() => _isSidebarVisible = !_isSidebarVisible),
            child: Container(
              height: 48,
              // expended width
              // width: _isSidebarVisible ? 280 : 36,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              color: Colors.black.withValues(alpha: 0.2),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  // width will be expeneded acoordingly
                  width: _isSidebarVisible ? 280 : 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_isSidebarVisible) ...[
                        const Icon(
                          Icons.explore,
                          size: 16,
                          color: Colors.blueAccent,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'VPS EXPLORER',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 16),
                          onPressed: _refreshServerState,
                          tooltip: 'Refresh',
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                      Icon(
                        _isSidebarVisible
                            ? Icons.chevron_left
                            : Icons.chevron_right,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (_isSidebarVisible)
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 200) return const SizedBox();
                  return _isVerified
                      ? ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            _buildExplorerSection(
                              'PM2 APPS',
                              Icons.dns,
                              _runningApps,
                              _selectApp,
                              _deleteApp,
                              Colors.greenAccent,
                            ),
                            const SizedBox(height: 20),
                            _buildExplorerSection(
                              'NGINX SITES',
                              Icons.web,
                              _activeSites,
                              _selectSite,
                              _deleteSite,
                              Colors.blueAccent,
                            ),
                          ],
                        )
                      : Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Text(
                              'Connect to VPS to explore services',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.3),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                },
              ),
            )
          else
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _isSidebarVisible = true),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        'EXPLORER',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 10,
                          letterSpacing: 2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExplorerSection(
    String title,
    IconData icon,
    List<String> items,
    Function(String) onSelect,
    Function(String) onDelete,
    Color accentColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.5)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${items.length}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 22, top: 4),
            child: Text(
              'None found',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.2),
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: InkWell(
                onTap: () => onSelect(item),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(
                            color: Color(0xFFCCCCCC),
                            fontSize: 12,
                            fontFamily: 'Consolas',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 14),
                        color: Colors.white.withValues(alpha: 0.3),
                        hoverColor: Colors.redAccent.withValues(alpha: 0.2),
                        onPressed: () => onDelete(item),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSwitch(String label, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 14)),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }

  Widget _buildTerminalView() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      width: _isTerminalVisible
          ? _terminalWidth
          : 36, // Collapsed width for toggle bar
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border(
          left: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header / Toggle Bar
          InkWell(
            onTap: () {
              setState(() {
                _isTerminalVisible = !_isTerminalVisible;
              });
            },
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              color: Colors.black.withValues(alpha: 0.2),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  width: _isTerminalVisible ? 380 : 20,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isTerminalVisible
                            ? Icons.chevron_right
                            : Icons.chevron_left,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: 16,
                      ),
                      if (_isTerminalVisible) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.terminal,
                          size: 16,
                          color: Colors.greenAccent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Terminal Output',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.clear_all, size: 16),
                          color: Colors.white.withValues(alpha: 0.5),
                          onPressed: () => setState(() => _logs.clear()),
                          tooltip: 'Clear Logs',
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Terminal Body
          if (_isTerminalVisible)
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 200) return const SizedBox();
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: const Color(0xFF1E1E1E),
                    child: ListView.builder(
                      controller: _logScrollController,
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: SelectableText(
                            // Make text copyable
                            _logs[index],
                            style: const TextStyle(
                              fontFamily: 'Consolas',
                              fontSize: 12,
                              color: Color(0xFFCCCCCC),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            )
          else
            // Vertical Toggle Strip when collapsed
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _isTerminalVisible = true),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        'TERMINAL',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 10,
                          letterSpacing: 2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
