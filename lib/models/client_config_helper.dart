import 'package:deploy_gui/models/client_config.dart';
import 'package:deploy_gui/models/repository_config.dart';

/// Temporary helper class to work with ClientConfig in a repository-aware manner
/// This helps bridge the old flat structure usage with the new hierarchical model
class ClientConfigHelper {
  final ClientConfig client;
  final RepositoryConfig? currentRepo;

  ClientConfigHelper(this.client, [this.currentRepo]);

  // Factory to create from client with first repository as default
  factory ClientConfigHelper.withFirstRepo(ClientConfig client) {
    final repo = client.repositories.isNotEmpty
        ? client.repositories.first
        : null;
    return ClientConfigHelper(client, repo);
  }

  // Factory to create from client with specific repository
  factory ClientConfigHelper.withRepo(ClientConfig client, String repoUrl) {
    final repo = client.findRepository(repoUrl);
    return ClientConfigHelper(client, repo);
  }

  // Client-level properties
  String get id => client.id;
  String get name => client.name;
  String get serverAlias => client.serverAlias;
  String? get password => client.password;
  DateTime get createdAt => client.createdAt;
  DateTime? get lastConnected => client.lastConnected;
  List<RepositoryConfig> get repositories => client.repositories;

  // Repository-level properties (from current repository)
  String get repo => currentRepo?.repoUrl ?? '';
  String get branch => currentRepo?.branch ?? 'main';
  String get pathOnServer => currentRepo?.pathOnServer ?? '/var/www/app';
  String get appName => currentRepo?.appName ?? 'app';
  String get port => currentRepo?.port ?? '3000';
  String get domain => currentRepo?.domain ?? '';
  String get installCommand => currentRepo?.installCommand ?? 'npm install';
  String get startCommand => currentRepo?.startCommand ?? 'pm2 start server.js';
  String get nginxConf => currentRepo?.nginxConf ?? '';
  String? get gitUsername => currentRepo?.gitUsername;
  String? get gitToken => currentRepo?.gitToken;
  bool get enableSSL => currentRepo?.enableSSL ?? false;
  String? get sslEmail => currentRepo?.sslEmail;

  // Helper to create a temporary flat ClientConfig for backward compatibility
  // This is used when old code expects the flat structure
  ClientConfig toFlatConfig() {
    if (currentRepo == null) {
      // Return minimal client config
      return client;
    }

    // This is a conceptual representation - the actual ClientConfig doesn't support this anymore
    // Instead, we'll use the helper methods above to access properties
    return client;
  }

  // Update repository in the client
  ClientConfig updateCurrentRepo(RepositoryConfig updatedRepo) {
    if (currentRepo == null) return client;
    return client.updateRepository(currentRepo!.repoUrl, updatedRepo);
  }

  // Create a new ClientConfigHelper with updated repository
  ClientConfigHelper withUpdatedRepo(RepositoryConfig updatedRepo) {
    final updatedClient = updateCurrentRepo(updatedRepo);
    return ClientConfigHelper(updatedClient, updatedRepo);
  }
}
