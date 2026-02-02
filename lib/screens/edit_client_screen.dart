import 'package:deploy_gui/models/client_config.dart';
import 'package:deploy_gui/providers/app_provider.dart';
import 'package:deploy_gui/providers/edit_client_provider.dart';
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
  late TextEditingController _sslEmailController;

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

  void _save(EditClientProvider provider) async {
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
        type: provider.deploymentType,
        enableSSL: provider.enableSSL,
        sslEmail: provider.enableSSL && _sslEmailController.text.isNotEmpty
            ? _sslEmailController.text
            : null,
      );

      if (widget.client == null) {
        await context.read<AppProvider>().addClient(config);
      } else {
        await context.read<AppProvider>().updateClient(config);
      }
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  // Methods moved to EditClientProvider

  Future<void> _deleteApp(EditClientProvider provider, String appName) async {
    final confirmed = await _showConfirmDialog(
      'Delete PM2 App',
      'Are you sure you want to delete "$appName" from the server?',
    );
    if (!confirmed) return;
    await provider.deleteApp(_createTempConfig(), appName);
  }

  Future<void> _deleteSite(EditClientProvider provider, String siteName) async {
    final confirmed = await _showConfirmDialog(
      'Delete Nginx Site',
      'Are you sure you want to delete Nginx configuration for "$siteName"?',
    );
    if (!confirmed) return;
    await provider.deleteSite(_createTempConfig(), siteName);
  }

  void _selectApp(EditClientProvider provider, String appNameWithPort) {
    // Extract name if it contains port info: "app (Port: 123)" -> "app"
    final appName = appNameWithPort.split(' (Port:').first.trim();
    _appNameController.text = appName;
    // Also try to guess default path/conf if they seem to follow the name
    if (_pathOnServerController.text.contains('backend') ||
        _pathOnServerController.text.contains('website')) {
      _pathOnServerController.text = '/var/www/$appName';
    }
    provider.checkApp(_createTempConfig(), appName);
  }

  void _selectSite(EditClientProvider provider, String domainWithPort) {
    // Extract domain if it contains port info
    final domain = domainWithPort.split(' (Port:').first.trim();
    _domainController.text = domain;
    provider.checkDomain(_createTempConfig(), domain);
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
      repo: _repoController.text,
      branch: _branchController.text,
      appName: _appNameController.text,
      pathOnServer: _pathOnServerController.text,
      nginxConf: _nginxConfController.text,
      domain: _domainController.text,
      port: _portController.text,
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
      sslEmail: _sslEmailController.text.isEmpty
          ? null
          : _sslEmailController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EditClientProvider()
        ..setDeploymentType(widget.client?.type ?? 'backend')
        ..setEnableSSL(widget.client?.enableSSL ?? false),
      child: Consumer<EditClientProvider>(
        builder: (context, provider, child) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                widget.client == null ? 'Add New Client' : 'Edit Client',
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
            ),
            body: Row(
              children: [
                _buildExplorerSidebar(provider),
                _buildResizeHandle(provider, isLeft: true),
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
                              _buildConnectionSection(provider),

                              if (provider.isVerified) ...[
                                const Divider(
                                  height: 48,
                                  thickness: 1,
                                  color: Colors.white10,
                                ),

                                // Step 1: Prerequisites
                                _buildStepHeader(
                                  1,
                                  'Prerequisites Check',
                                  'Verify server tools (Nginx, Git, Node, PM2)',
                                  provider.serverTools.isNotEmpty &&
                                      provider.serverTools.every(
                                        (t) => t.isInstalled,
                                      ),
                                ),
                                _buildPrerequisitesStep(provider),

                                const SizedBox(height: 32),

                                // Step 2: Project Setup
                                _buildStepHeader(
                                  2,
                                  'Project Setup',
                                  'Clone repository and install dependencies',
                                  false, // We'll need a real status for this later
                                ),
                                _buildProjectSetupStep(provider),

                                const SizedBox(height: 32),

                                // Step 3: Deployment Configuration
                                _buildStepHeader(
                                  3,
                                  'Deployment Configuration',
                                  'Configure ports, domains, and processes',
                                  false,
                                ),
                                _buildDeploymentConfigStep(provider),

                                // Step 4: Domain & SSL
                                _buildStepHeader(
                                  4,
                                  'Domain & SSL',
                                  'Verify access and secure connection',
                                  false,
                                ),
                                _buildDomainSSLStep(provider),
                                _buildStepHeader(
                                  5,
                                  'Master Deployment',
                                  'Run full deployment sequence',
                                  false,
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
                _buildResizeHandle(provider, isLeft: false),
                LogConsolePanel(provider: provider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStepHeader(
    int number,
    String title,
    String subtitle,
    bool isCompleted,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isCompleted ? Colors.green : Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : Text(
                      '$number',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrerequisitesStep(EditClientProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (provider.serverTools.isEmpty && !provider.checkingTools)
              const Text(
                'Check if the server has the necessary tools installed.',
                style: TextStyle(color: Colors.grey),
              ),

            if (provider.serverTools.isNotEmpty)
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: provider.serverTools.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final tool = provider.serverTools[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(
                      tool.isInstalled ? Icons.check_circle : Icons.error,
                      color: tool.isInstalled ? Colors.green : Colors.red,
                    ),
                    title: Text(tool.name.toUpperCase()),
                    subtitle: Text(
                      tool.isInstalled
                          ? 'Version: ${tool.version}'
                          : 'Not installed',
                    ),
                    trailing: tool.isInstalled
                        ? null
                        : ElevatedButton(
                            onPressed: provider.isBusy
                                ? null
                                : () => provider.installMissingTools(
                                    _createTempConfig(),
                                  ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Install'),
                          ),
                  );
                },
              ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: provider.isBusy
                    ? null
                    : () => provider.checkServerPrerequisites(
                        _createTempConfig(),
                      ),
                icon: provider.checkingTools
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(
                  provider.serverTools.isEmpty
                      ? 'Check Prerequisites'
                      : 'Re-check Prerequisites',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectSetupStep(EditClientProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(
              _repoController,
              'Git Repository URL',
              'https://github.com/user/repo.git',
            ),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    _branchController,
                    'Branch Name',
                    'main',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    _pathOnServerController,
                    'Destination Path',
                    '/var/www/my-app',
                  ),
                ),
              ],
            ),
            ExpansionTile(
              title: const Text(
                'Git Credentials (Optional)',
                style: TextStyle(fontSize: 14),
              ),
              tilePadding: EdgeInsets.zero,
              collapsedTextColor: Colors.white70,
              textColor: Colors.white,
              children: [
                _buildTextField(
                  _gitUsernameController,
                  'Git Username',
                  'Username',
                ),
                _buildTextField(
                  _gitTokenController,
                  'Git Token / Password',
                  'ghp_...',
                  isPassword: true,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: provider.isBusy || provider.cloning
                    ? null
                    : () {
                        provider.cloneProject(_createTempConfig());
                      },
                icon: provider.cloning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: Text(
                  provider.cloning
                      ? 'Cloning & Installing...'
                      : 'Clone & Install Dependencies',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.withValues(alpha: 0.2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeploymentConfigStep(EditClientProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(_appNameController, 'App Name (PM2)', 'my-app'),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(_portController, 'Port', '3000'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    _domainController,
                    'Domain',
                    'example.com',
                  ),
                ),
              ],
            ),
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

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: provider.isBusy
                    ? null
                    : () {
                        provider.deployApp(_createTempConfig());
                      },
                icon: provider.isBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.rocket_launch),
                label: Text(
                  provider.isBusy ? 'Deploying...' : 'Deploy Application',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.withValues(alpha: 0.2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDomainSSLStep(EditClientProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This step will configure Nginx as a reverse proxy for your app and optionally secure it with SSL (Let\'s Encrypt).',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            // Re-display key info or allow editing?
            // Better to just rely on the controllers which are already filled.
            // Maybe show a summary: "Configuring ${_domainController.text} -> localhost:${_portController.text}"
            // Domain Input
            _buildTextField(_domainController, 'Domain Name', 'example.com'),
            const SizedBox(height: 8),
            Text(
              'Points to localhost:${_portController.text}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text('Enable SSL (HTTPS)'),
              subtitle: const Text('Generate a free certificate using Certbot'),
              value: provider.enableSSL,
              onChanged: (val) => provider.setEnableSSL(val),
              contentPadding: EdgeInsets.zero,
            ),

            if (provider.enableSSL)
              _buildTextField(
                _sslEmailController,
                'Email for SSL Expiry Notifications',
                'admin@example.com',
              ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: provider.isBusy
                    ? null
                    : () {
                        provider.configureNginxAndSSL(_createTempConfig());
                      },
                icon: provider.isBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.security),
                label: Text(
                  provider.isBusy ? 'Configuring...' : 'Configure Nginx & SSL',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.withValues(alpha: 0.2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionSection(EditClientProvider provider) {
    return Column(
      children: [
        _buildSectionHeader('Credentials & Connection', Icons.key_outlined),
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
        // General Info integrated here
        if (provider.isVerified) ...[
          const SizedBox(height: 24),
          _buildSectionHeader('General Information', Icons.info_outline),
          _buildCardLayout([
            _buildTextField(
              _nameController,
              'Client Name',
              'My Production Server',
            ),
            _buildDeploymentTypeDropdown(provider),
          ]),
        ],

        const SizedBox(height: 16),
        Center(
          child: ElevatedButton.icon(
            onPressed: provider.isVerifying
                ? null
                : () => provider.testConnection(_createTempConfig()),
            icon: provider.isVerifying
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    provider.isVerified ? Icons.check_circle : Icons.wifi,
                    color: provider.isVerified ? Colors.green : Colors.white,
                  ),
            label: Text(
              provider.isVerified ? 'Connected' : 'Test Connection',
              style: TextStyle(
                color: provider.isVerified ? Colors.green : Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ),
        if (provider.verificationStatus != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Center(
              child: Text(
                provider.verificationStatus!,
                style: TextStyle(
                  color: provider.isVerified ? Colors.green : Colors.redAccent,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildResizeHandle(
    EditClientProvider provider, {
    required bool isLeft,
  }) {
    final isVisible = isLeft
        ? provider.isSidebarVisible
        : provider.isTerminalVisible;
    if (!isVisible) return const SizedBox();

    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          final maxWidth = MediaQuery.of(context).size.width;
          if (isLeft) {
            provider.updateExplorerWidth(details.delta.dx, maxWidth);
          } else {
            provider.updateTerminalWidth(details.delta.dx, maxWidth);
          }
        },
        child: Container(
          width: 8,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 1,
              height: double.infinity,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
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

  Widget _buildDeploymentTypeDropdown(EditClientProvider provider) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: DropdownButtonFormField<String>(
        value: provider.deploymentType,
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
            provider.setDeploymentType(value);
            _updateDefaultsForType(value);
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

  Widget _buildExplorerSidebar(EditClientProvider provider) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      width: provider.isSidebarVisible ? provider.explorerWidth : 36,
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
            onTap: () => provider.toggleSidebar(),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              color: Colors.black.withValues(alpha: 0.2),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  width: provider.isSidebarVisible
                      ? (provider.explorerWidth - 16)
                      : 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (provider.isSidebarVisible) ...[
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
                          onPressed: () =>
                              provider.refreshServerState(_createTempConfig()),
                          tooltip: 'Refresh',
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                      Icon(
                        provider.isSidebarVisible
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

          if (provider.isSidebarVisible)
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 200) return const SizedBox();
                  return provider.isVerified
                      ? Column(
                          children: [
                            // Top Section: Apps & Sites
                            Expanded(
                              flex: 5, // Default split
                              child: ListView(
                                padding: const EdgeInsets.all(12),
                                children: [
                                  _buildExplorerSection(
                                    'PM2 APPS',
                                    Icons.dns,
                                    provider.runningApps,
                                    (name) => _selectApp(provider, name),
                                    (name) => _deleteApp(provider, name),
                                    Colors.greenAccent,
                                  ),
                                  const SizedBox(height: 20),
                                  _buildExplorerSection(
                                    'NGINX SITES',
                                    Icons.web,
                                    provider.activeSites,
                                    (name) => _selectSite(provider, name),
                                    (name) => _deleteSite(provider, name),
                                    Colors.blueAccent,
                                  ),
                                ],
                              ),
                            ),
                            // Divider / Resize Handle (Simple for now)
                            Container(
                              height: 1,
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                            // Bottom Section: File Explorer
                            _buildFileExplorer(provider),
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
                onTap: () => provider.toggleSidebar(),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.split(' (').first,
                              style: const TextStyle(
                                color: Color(0xFFCCCCCC),
                                fontSize: 12,
                                fontFamily: 'Consolas',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (item.contains(' ('))
                              Text(
                                item
                                    .substring(item.indexOf(' (') + 1)
                                    .replaceAll(')', ''),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 10,
                                  fontFamily: 'Consolas',
                                ),
                              ),
                          ],
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

  Widget _buildFileExplorer(EditClientProvider provider) {
    return Expanded(
      flex: 5,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
        ),
        child: Column(
          children: [
            // Explorer Header
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_open,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'FILES',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 14),
                    color: Colors.white.withValues(alpha: 0.5),
                    onPressed: () => provider.fetchFiles(
                      _createTempConfig(),
                      provider.currentPath,
                    ),
                    splashRadius: 16,
                  ),
                ],
              ),
            ),
            // Current Path
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => provider.navigateUp(_createTempConfig()),
                    child: Icon(
                      Icons.arrow_upward,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      provider.currentPath,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 10,
                        fontFamily: 'Consolas',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (provider.isLoadingFiles)
              const LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
              )
            else
              const Divider(height: 1, thickness: 1, color: Colors.transparent),

            // File List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: provider.files.length,
                itemBuilder: (context, index) {
                  final file = provider.files[index];
                  return InkWell(
                    onTap: () {
                      if (file.isDirectory) {
                        provider.navigateTo(_createTempConfig(), file.path);
                      } else {
                        provider.catFile(_createTempConfig(), file.path);
                      }
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 4,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            file.isDirectory
                                ? Icons.folder
                                : Icons.insert_drive_file,
                            size: 14,
                            color: file.isDirectory
                                ? Colors.amber.withValues(alpha: 0.8)
                                : Colors.blueGrey.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              file.name,
                              style: const TextStyle(
                                color: Color(0xFFDDDDDD),
                                fontSize: 12,
                                fontFamily: 'Consolas',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            file.size,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.2),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LogConsolePanel extends StatelessWidget {
  final EditClientProvider provider;

  const LogConsolePanel({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      width: provider.isTerminalVisible ? provider.terminalWidth : 36,
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
          // Loading Indicator
          if (provider.isBusy)
            const LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent),
            ),

          // Header
          InkWell(
            onTap: () => provider.toggleTerminal(),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              color: Colors.black.withValues(alpha: 0.2),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  width: provider.isTerminalVisible
                      ? (provider.terminalWidth - 16)
                      : 20,
                  child: Row(
                    children: [
                      Icon(
                        provider.isTerminalVisible
                            ? Icons.chevron_right
                            : Icons.chevron_left,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: 16,
                      ),
                      if (provider.isTerminalVisible) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.terminal,
                          size: 16,
                          color: Colors.greenAccent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Console Logs',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_all, size: 16),
                          color: Colors.white.withValues(alpha: 0.5),
                          onPressed: () => provider.copyLogsToClipboard(),
                          tooltip: 'Copy Logs',
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.clear_all, size: 16),
                          color: Colors.white.withValues(alpha: 0.5),
                          onPressed: () => provider.clearLogs(),
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

          // Log Content
          if (provider.isTerminalVisible)
            Expanded(
              child: Container(
                color: const Color(0xFF1E1E1E),
                child: SelectionArea(
                  child: ListView.builder(
                    controller: provider.logScrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: provider.logs.length,
                    itemBuilder: (context, index) {
                      final log = provider.logs[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '[${log.formattedTimestamp}] ',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                  fontFamily: 'Consolas',
                                ),
                              ),
                              TextSpan(
                                text: log.message,
                                style: TextStyle(
                                  color: log.color,
                                  fontSize: 13,
                                  fontFamily: 'Consolas',
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: InkWell(
                onTap: () => provider.setTerminalVisible(true),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        'LOGS',
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
