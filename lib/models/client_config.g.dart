// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ClientConfig _$ClientConfigFromJson(Map<String, dynamic> json) => ClientConfig(
  id: json['id'] as String,
  name: json['name'] as String,
  type: json['type'] as String? ?? 'backend',
  serverAlias: json['serverAlias'] as String,
  repo: json['repo'] as String,
  branch: json['branch'] as String? ?? 'main',
  domain: json['domain'] as String,
  port: json['port'] as String? ?? '5001',
  appName: json['appName'] as String,
  pathOnServer: json['pathOnServer'] as String,
  nginxConf: json['nginxConf'] as String,
  installCommand: json['installCommand'] as String? ?? 'npm install',
  startCommand:
      json['startCommand'] as String? ??
      'pm2 start server.js --name "{APP_NAME}" -- --port {PORT}',
  password: json['password'] as String?,
  gitUsername: json['gitUsername'] as String?,
  gitToken: json['gitToken'] as String?,
);

Map<String, dynamic> _$ClientConfigToJson(ClientConfig instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': instance.type,
      'serverAlias': instance.serverAlias,
      'repo': instance.repo,
      'branch': instance.branch,
      'domain': instance.domain,
      'port': instance.port,
      'appName': instance.appName,
      'pathOnServer': instance.pathOnServer,
      'nginxConf': instance.nginxConf,
      'installCommand': instance.installCommand,
      'startCommand': instance.startCommand,
      'password': instance.password,
      'gitUsername': instance.gitUsername,
      'gitToken': instance.gitToken,
    };
