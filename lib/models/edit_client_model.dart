import 'package:deploy_gui/models/client_config.dart';
import 'package:deploy_gui/models/repository_config.dart';
import 'package:uuid/uuid.dart';

/// Working model for the Edit Client Screen
/// Combines client-level and repository-level data for editing
class EditClientModel {
  // Client-level data
  String clientId;
  String clientName;
  String serverAlias; // SSH IP
  String? password;

  // Repository-level data
  String repoUrl;
  String branch;
  String pathOnServer;
  String appName;
  String port;
  String domain;
  String installCommand;
  String startCommand;
  String nginxConf;
  String? gitUsername;
  String? gitToken;
  bool enableSSL;
  String? sslEmail;

  EditClientModel({
    String? clientId,
    this.clientName = '',
    this.serverAlias = '',
    this.password,
    this.repoUrl = '',
    this.branch = 'main',
    this.pathOnServer = '/var/www/app',
    this.appName = 'app',
    this.port = '3000',
    this.domain = '',
    this.installCommand = 'npm install',
    this.startCommand =
        'pm2 start server.js --name "{APP_NAME}" -- --port {PORT}',
    this.nginxConf = '',
    this.gitUsername,
    this.gitToken,
    this.enableSSL = false,
    this.sslEmail,
  }) : clientId = clientId ?? const Uuid().v4();

  // Create from existing client and repository
  factory EditClientModel.fromClientAndRepo(
    ClientConfig client,
    RepositoryConfig? repo,
  ) {
    return EditClientModel(
      clientId: client.id,
      clientName: client.name,
      serverAlias: client.serverAlias,
      password: client.password,
      repoUrl: repo?.repoUrl ?? '',
      branch: repo?.branch ?? 'main',
      pathOnServer: repo?.pathOnServer ?? '/var/www/app',
      appName: repo?.appName ?? 'app',
      port: repo?.port ?? '3000',
      domain: repo?.domain ?? '',
      installCommand: repo?.installCommand ?? 'npm install',
      startCommand: repo?.startCommand ?? 'pm2 start server.js',
      nginxConf: repo?.nginxConf ?? '',
      gitUsername: repo?.gitUsername,
      gitToken: repo?.gitToken,
      enableSSL: repo?.enableSSL ?? false,
      sslEmail: repo?.sslEmail,
    );
  }

  // Convert to ClientConfig and RepositoryConfig
  ClientConfig toClientConfig({List<RepositoryConfig>? existingRepos}) {
    final repo = toRepositoryConfig();
    final repos = existingRepos ?? [];

    // Add or update the current repository
    final repoIndex = repos.indexWhere((r) => r.repoUrl == repoUrl);
    if (repoIndex >= 0) {
      repos[repoIndex] = repo;
    } else {
      repos.add(repo);
    }

    return ClientConfig(
      id: clientId,
      name: clientName,
      serverAlias: serverAlias,
      password: password,
      repositories: repos,
    );
  }

  RepositoryConfig toRepositoryConfig() {
    return RepositoryConfig(
      repoUrl: repoUrl,
      branch: branch,
      pathOnServer: pathOnServer,
      appName: appName,
      port: port,
      domain: domain,
      installCommand: installCommand,
      startCommand: startCommand,
      nginxConf: nginxConf,
      gitUsername: gitUsername,
      gitToken: gitToken,
      enableSSL: enableSSL,
      sslEmail: sslEmail,
    );
  }

  EditClientModel copyWith({
    String? clientId,
    String? clientName,
    String? serverAlias,
    String? password,
    String? repoUrl,
    String? branch,
    String? pathOnServer,
    String? appName,
    String? port,
    String? domain,
    String? installCommand,
    String? startCommand,
    String? nginxConf,
    String? gitUsername,
    String? gitToken,
    bool? enableSSL,
    String? sslEmail,
  }) {
    return EditClientModel(
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      serverAlias: serverAlias ?? this.serverAlias,
      password: password ?? this.password,
      repoUrl: repoUrl ?? this.repoUrl,
      branch: branch ?? this.branch,
      pathOnServer: pathOnServer ?? this.pathOnServer,
      appName: appName ?? this.appName,
      port: port ?? this.port,
      domain: domain ?? this.domain,
      installCommand: installCommand ?? this.installCommand,
      startCommand: startCommand ?? this.startCommand,
      nginxConf: nginxConf ?? this.nginxConf,
      gitUsername: gitUsername ?? this.gitUsername,
      gitToken: gitToken ?? this.gitToken,
      enableSSL: enableSSL ?? this.enableSSL,
      sslEmail: sslEmail ?? this.sslEmail,
    );
  }
}
