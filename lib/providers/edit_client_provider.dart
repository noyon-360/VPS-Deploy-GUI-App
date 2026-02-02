import 'package:deploy_gui/models/client_config.dart';
import 'package:deploy_gui/models/log_entry.dart';
import 'package:deploy_gui/services/verification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditClientProvider with ChangeNotifier {
  final VerificationService _verifier = VerificationService();
  bool _disposed = false;
  bool _isBusy = false; // Global busy state for command execution

  bool get isBusy => _isBusy;

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

  // Terminal (xterm)
  // Terminal Session Management
  bool _isTerminalConnected = false;

  bool get isTerminalConnected => _isTerminalConnected;

  // Legacy logs for verification operations
  final List<LogEntry> _logs = [];
  List<LogEntry> get logs => List.unmodifiable(_logs);
  final ScrollController logScrollController = ScrollController();

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

  // Terminal Session Management
  // Terminal Session Management is removed in favor of Log Console
  Future<void> connectTerminal(ClientConfig config) async {
    // No-op or removed. Keeping empty method if needed for UI temporary compatibility,
    // but better to remove.
    // However, the screen calls this. I will remove it from the screen too.
    // So I will remove this method entirely.
  }

  void disconnectTerminal() {
    // No-op
    _isTerminalConnected = false;
    notifyListeners();
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

  Future<void> testConnection(ClientConfig tempConfig) async {
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

  Future<void> refreshServerState(ClientConfig tempConfig) async {
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
    notifyListeners();
  }

  Future<void> checkApp(ClientConfig tempConfig, String appName) async {
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

  Future<void> checkDomain(ClientConfig tempConfig, String domain) async {
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

  Future<bool> deleteApp(ClientConfig tempConfig, String appName) async {
    if (_isBusy) return false;
    _isBusy = true;
    _isTerminalVisible = true;
    notifyListeners();

    try {
      addLog('--- Deletion Started: PM2 App $appName ---', type: LogType.info);

      final success = await _verifier.deletePm2App(
        tempConfig,
        appName,
        onLog: _handleServiceLog,
      );

      if (success) {
        addLog('--- Deletion Successful: $appName ---', type: LogType.info);
        await refreshServerState(tempConfig);
      }
      return success;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> deleteSite(ClientConfig tempConfig, String siteName) async {
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
        tempConfig,
        siteName,
        onLog: _handleServiceLog,
      );

      if (success) {
        addLog('--- Deletion Successful: $siteName ---', type: LogType.info);
        await refreshServerState(tempConfig);
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
    logScrollController.dispose();
    super.dispose();
  }
}
