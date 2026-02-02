import 'package:deploy_gui/models/client_config.dart';
import 'package:deploy_gui/providers/app_provider.dart';
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
      );

      if (widget.client == null) {
        context.read<AppProvider>().addClient(config);
      } else {
        context.read<AppProvider>().updateClient(config);
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.client == null ? 'Add New Client' : 'Edit Client'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildSectionHeader('General Information', Icons.info_outline),
                _buildCardLayout([
                  _buildTextField(_nameController, 'Client Name', 'My Website'),
                  _buildTextField(
                    _serverAliasController,
                    'SSH Destination',
                    'root@1.2.3.4',
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
                  _buildTextField(_branchController, 'Branch', 'main'),
                  _buildTextField(
                    _domainController,
                    'Domain',
                    'api.example.com',
                  ),
                  _buildTextField(_portController, 'App Port', '5001'),
                  _buildTextField(
                    _appNameController,
                    'App Name (PM2)',
                    'backend',
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

                _buildSectionHeader('Commands', Icons.terminal_outlined),
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

                _buildSectionHeader('Credentials', Icons.key_outlined),
                _buildCardLayout([
                  _buildTextField(
                    _passwordController,
                    'SSH Password',
                    'Leave blank to use keys',
                    isPassword: true,
                  ),
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
                const SizedBox(height: 48),
              ],
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
          Icon(icon, size: 20, color: Colors.white.withAlpha(200)),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white.withAlpha(200),
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
        value: _deploymentType,
        decoration: InputDecoration(
          labelText: 'Deployment Type',
          filled: true,
          fillColor: Colors.black.withAlpha(20),
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          alignLabelWithHint: true,
          filled: true,
          fillColor: Colors.black.withAlpha(20),
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
          if (isPassword) return null;
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
          }
          return null;
        },
      ),
    );
  }
}
