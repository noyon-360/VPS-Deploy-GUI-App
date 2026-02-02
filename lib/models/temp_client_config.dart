import 'package:deploy_gui/models/client_config.dart';
import 'package:deploy_gui/models/repository_config.dart';

/// Temporary config wrapper that combines client + repository for backward compatibility
/// This allows existing code to work while we gradually migrate to the new structure
class TempClientConfig extends ClientConfig {
  final RepositoryConfig? _currentRepo;

  TempClientConfig({
    required super.id,
    required super.name,
    required super.serverAlias,
    super.password,
    super.repositories,
    super.createdAt,
    super.lastConnected,
    RepositoryConfig? currentRepo,
  }) : _currentRepo = currentRepo;

  // Factory to create from existing client and repository
  factory TempClientConfig.from(ClientConfig client, [RepositoryConfig? repo]) {
    return TempClientConfig(
      id: client.id,
      name: client.name,
      serverAlias: client.serverAlias,
      password: client.password,
      repositories: client.repositories,
      createdAt: client.createdAt,
      lastConnected: client.lastConnected,
      currentRepo:
          repo ??
          (client.repositories.isNotEmpty ? client.repositories.first : null),
    );
  }

  // Repository-level properties (backward compatibility)
  String get repo => _currentRepo?.repoUrl ?? '';
  String get branch => _currentRepo?.branch ?? 'main';
  String get pathOnServer => _currentRepo?.pathOnServer ?? '/var/www/app';
  String get appName => _currentRepo?.appName ?? 'app';
  String get port => _currentRepo?.port ?? '3000';
  String get domain => _currentRepo?.domain ?? '';
  String get installCommand => _currentRepo?.installCommand ?? 'npm install';
  String get startCommand =>
      _currentRepo?.startCommand ?? 'pm2 start server.js';
  String get nginxConf => _currentRepo?.nginxConf ?? '';
  String? get gitUsername => _currentRepo?.gitUsername;
  String? get gitToken => _currentRepo?.gitToken;
  bool get enableSSL => _currentRepo?.enableSSL ?? false;
  String? get sslEmail => _currentRepo?.sslEmail;

  // Get current repository
  RepositoryConfig? get currentRepository => _currentRepo;

  // Update current repository and return new TempClientConfig
  TempClientConfig withUpdatedRepo(RepositoryConfig updatedRepo) {
    final updatedClient = updateRepository(_currentRepo!.repoUrl, updatedRepo);
    return TempClientConfig.from(updatedClient, updatedRepo);
  }

  // Convert to regular ClientConfig
  ClientConfig toClientConfig() {
    return ClientConfig(
      id: id,
      name: name,
      serverAlias: serverAlias,
      password: password,
      repositories: repositories,
      createdAt: createdAt,
      lastConnected: lastConnected,
    );
  }
}
