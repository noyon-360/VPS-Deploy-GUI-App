import 'package:json_annotation/json_annotation.dart';

part 'client_config.g.dart';

@JsonSerializable()
class ClientConfig {
  final String id;
  final String name;
  final String type; // 'backend' or 'website'
  final String serverAlias;
  final String repo;
  final String branch;
  final String domain;
  final String port;
  final String appName;
  final String pathOnServer;
  final String nginxConf;
  final String installCommand;
  final String startCommand;
  final String? password;
  final String? gitUsername;
  final String? gitToken;
  final bool enableSSL;
  final String? sslEmail;

  ClientConfig({
    required this.id,
    required this.name,
    this.type = 'backend',
    this.serverAlias = '',
    required this.repo,
    this.branch = 'main',
    required this.domain,
    this.port = '3000',
    required this.appName,
    required this.pathOnServer,
    required this.nginxConf,
    this.installCommand = 'npm install',
    this.startCommand = 'pm2 start server.js',
    this.password,
    this.gitUsername,
    this.gitToken,
    this.enableSSL = false,
    this.sslEmail,
  });

  factory ClientConfig.fromJson(Map<String, dynamic> json) =>
      _$ClientConfigFromJson(json);
  Map<String, dynamic> toJson() => _$ClientConfigToJson(this);

  ClientConfig copyWith({
    String? id,
    String? name,
    String? type,
    String? serverAlias,
    String? repo,
    String? branch,
    String? domain,
    String? port,
    String? appName,
    String? pathOnServer,
    String? nginxConf,
    String? installCommand,
    String? startCommand,
    String? password,
    String? gitUsername,
    String? gitToken,
    bool? enableSSL,
    String? sslEmail,
  }) {
    return ClientConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      serverAlias: serverAlias ?? this.serverAlias,
      repo: repo ?? this.repo,
      branch: branch ?? this.branch,
      domain: domain ?? this.domain,
      port: port ?? this.port,
      appName: appName ?? this.appName,
      pathOnServer: pathOnServer ?? this.pathOnServer,
      nginxConf: nginxConf ?? this.nginxConf,
      installCommand: installCommand ?? this.installCommand,
      startCommand: startCommand ?? this.startCommand,
      password: password ?? this.password,
      gitUsername: gitUsername ?? this.gitUsername,
      gitToken: gitToken ?? this.gitToken,
      enableSSL: enableSSL ?? this.enableSSL,
      sslEmail: sslEmail ?? this.sslEmail,
    );
  }
}
