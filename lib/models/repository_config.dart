import 'package:deploy_gui/models/deployment_action.dart';
import 'package:json_annotation/json_annotation.dart';

part 'repository_config.g.dart';

@JsonSerializable(explicitToJson: true)
class RepositoryConfig {
  final String repoUrl;
  final String branch;
  final String pathOnServer;
  final String appName;
  final String port;
  final String domain;
  final String installCommand;
  final String startCommand;
  final String nginxConf;
  final List<DeploymentAction> deploymentActions;
  final String? gitUsername;
  final String? gitToken;
  final bool enableSSL;
  final String? sslEmail;
  final DateTime createdAt;
  final DateTime? lastDeployedAt;

  RepositoryConfig({
    required this.repoUrl,
    this.branch = 'main',
    required this.pathOnServer,
    required this.appName,
    this.port = '3000',
    this.domain = '',
    this.installCommand = 'npm install',
    this.startCommand = 'pm2 start server.js',
    this.nginxConf = '',
    this.deploymentActions = const [],
    this.gitUsername,
    this.gitToken,
    this.enableSSL = false,
    this.sslEmail,
    DateTime? createdAt,
    this.lastDeployedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory RepositoryConfig.fromJson(Map<String, dynamic> json) =>
      _$RepositoryConfigFromJson(json);
  Map<String, dynamic> toJson() => _$RepositoryConfigToJson(this);

  RepositoryConfig copyWith({
    String? repoUrl,
    String? branch,
    String? pathOnServer,
    String? appName,
    String? port,
    String? domain,
    String? installCommand,
    String? startCommand,
    String? nginxConf,
    List<DeploymentAction>? deploymentActions,
    String? gitUsername,
    String? gitToken,
    bool? enableSSL,
    String? sslEmail,
    DateTime? createdAt,
    DateTime? lastDeployedAt,
  }) {
    return RepositoryConfig(
      repoUrl: repoUrl ?? this.repoUrl,
      branch: branch ?? this.branch,
      pathOnServer: pathOnServer ?? this.pathOnServer,
      appName: appName ?? this.appName,
      port: port ?? this.port,
      domain: domain ?? this.domain,
      installCommand: installCommand ?? this.installCommand,
      startCommand: startCommand ?? this.startCommand,
      nginxConf: nginxConf ?? this.nginxConf,
      deploymentActions: deploymentActions ?? this.deploymentActions,
      gitUsername: gitUsername ?? this.gitUsername,
      gitToken: gitToken ?? this.gitToken,
      enableSSL: enableSSL ?? this.enableSSL,
      sslEmail: sslEmail ?? this.sslEmail,
      createdAt: createdAt ?? this.createdAt,
      lastDeployedAt: lastDeployedAt ?? this.lastDeployedAt,
    );
  }

  // Helper to add a deployment action
  RepositoryConfig addAction(DeploymentAction action) {
    return copyWith(
      deploymentActions: [...deploymentActions, action],
      lastDeployedAt: action.timestamp,
    );
  }

  // Check if a specific action type has been completed successfully
  bool hasCompletedAction(DeploymentActionType type) {
    return deploymentActions.any(
      (action) =>
          action.actionType == type &&
          action.status == DeploymentStatus.success,
    );
  }

  // Get the last action of a specific type
  DeploymentAction? getLastAction(DeploymentActionType type) {
    final actions = deploymentActions
        .where((action) => action.actionType == type)
        .toList();
    if (actions.isEmpty) return null;
    actions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return actions.first;
  }
}
