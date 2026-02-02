// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'repository_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RepositoryConfig _$RepositoryConfigFromJson(Map<String, dynamic> json) =>
    RepositoryConfig(
      repoUrl: json['repoUrl'] as String,
      branch: json['branch'] as String? ?? 'main',
      pathOnServer: json['pathOnServer'] as String,
      appName: json['appName'] as String,
      port: json['port'] as String? ?? '3000',
      domain: json['domain'] as String? ?? '',
      installCommand: json['installCommand'] as String? ?? 'npm install',
      startCommand: json['startCommand'] as String? ?? 'pm2 start server.js',
      nginxConf: json['nginxConf'] as String? ?? '',
      deploymentActions:
          (json['deploymentActions'] as List<dynamic>?)
              ?.map((e) => DeploymentAction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      gitUsername: json['gitUsername'] as String?,
      gitToken: json['gitToken'] as String?,
      enableSSL: json['enableSSL'] as bool? ?? false,
      sslEmail: json['sslEmail'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      lastDeployedAt: json['lastDeployedAt'] == null
          ? null
          : DateTime.parse(json['lastDeployedAt'] as String),
    );

Map<String, dynamic> _$RepositoryConfigToJson(RepositoryConfig instance) =>
    <String, dynamic>{
      'repoUrl': instance.repoUrl,
      'branch': instance.branch,
      'pathOnServer': instance.pathOnServer,
      'appName': instance.appName,
      'port': instance.port,
      'domain': instance.domain,
      'installCommand': instance.installCommand,
      'startCommand': instance.startCommand,
      'nginxConf': instance.nginxConf,
      'deploymentActions': instance.deploymentActions
          .map((e) => e.toJson())
          .toList(),
      'gitUsername': instance.gitUsername,
      'gitToken': instance.gitToken,
      'enableSSL': instance.enableSSL,
      'sslEmail': instance.sslEmail,
      'createdAt': instance.createdAt.toIso8601String(),
      'lastDeployedAt': instance.lastDeployedAt?.toIso8601String(),
    };
