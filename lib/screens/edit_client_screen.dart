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
      text: c?.nginxConf ?? '/etc/nginx/sites-available/dashboard',
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField(
                _nameController,
                'Client Name',
                'e.g. My Website',
              ),
              _buildTextField(
                _serverAliasController,
                'SSH Connection (Alias or User@IP)',
                'e.g. root@76.13.x.x or my-alias',
              ),
              _buildTextField(
                _repoController,
                'GitHub Repo (SSH)',
                'git@github.com:user/repo.git',
              ),
              _buildTextField(_branchController, 'Branch', 'main'),
              _buildTextField(_domainController, 'Domain', 'api.example.com'),
              _buildTextField(_portController, 'Port', '5001'),
              _buildTextField(_appNameController, 'App Name (PM2)', 'backend'),
              _buildTextField(
                _pathOnServerController,
                'Path on Server',
                '/var/www/backend',
              ),
              _buildTextField(
                _nginxConfController,
                'NGINX Config Path',
                '/etc/nginx/sites-available/dashboard',
              ),
              _buildTextField(
                _installCommandController,
                'Install Command',
                'e.g. npm install or yarn install',
              ),
              _buildTextField(
                _startCommandController,
                'Start Command',
                'e.g. pm2 start server.js --name "{APP_NAME}"',
              ),
              _buildTextField(
                _passwordController,
                'SSH Password (Alternative to Keys)',
                'Leave blank to use SSH Keys',
                isPassword: true,
              ),
              const Divider(height: 48),
              Text(
                'Git Credentials (HTTPS only)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _gitUsernameController,
                'Git Username',
                'Your GitHub/GitLab username',
              ),
              _buildTextField(
                _gitTokenController,
                'Git Token / Password',
                'Personal Access Token (Recommended)',
                isPassword: true,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: const Text(
                    'Save Configuration',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint, {
    bool isPassword = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (isPassword) return null; // Password is optional
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
          }
          return null;
        },
      ),
    );
  }
}
