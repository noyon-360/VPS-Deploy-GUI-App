import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';
import 'package:deploy_gui/models/client_config.dart';

class DeploymentService {
  Future<Stream<String>> deploy(String mode, ClientConfig config) async {
    final List<String> commands = _getCommands(mode, config);
    final String fullCommand = commands.join('\n');

    if (config.password != null && config.password!.isNotEmpty) {
      return _deployWithPassword(fullCommand, config);
    } else {
      return _deployWithSystemSsh(fullCommand, config);
    }
  }

  Future<Stream<String>> _deployWithPassword(
    String fullCommand,
    ClientConfig config,
  ) async {
    final controller = StreamController<String>();

    try {
      final parts = _parseConnection(config.serverAlias);
      final client = SSHClient(
        await SSHSocket.connect(parts['host']!, 22),
        username: parts['user']!,
        onPasswordRequest: () => config.password,
      );

      final session = await client.execute('bash -s');
      session.stdin.add(utf8.encode(fullCommand));
      await session.stdin.close();

      session.stdout
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) => controller.add(line),
            onDone: () {
              client.close();
              controller.close();
            },
          );

      session.stderr
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => controller.add('ERR: $line'));
    } catch (e) {
      controller.addError('SSH Connection Error: $e');
      controller.close();
    }

    return controller.stream;
  }

  Future<Stream<String>> _deployWithSystemSsh(
    String fullCommand,
    ClientConfig config,
  ) async {
    final process = await Process.start('ssh', [
      config.serverAlias,
      'bash -s',
    ], runInShell: true);

    process.stdin.writeln(fullCommand);
    process.stdin.close();

    return process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter());
  }

  Map<String, String> _parseConnection(String alias) {
    if (alias.contains('@')) {
      final parts = alias.split('@');
      return {'user': parts[0], 'host': parts[1]};
    }
    return {'user': 'root', 'host': alias};
  }

  List<String> _getCommands(String mode, ClientConfig config) {
    if (mode == 'initial') {
      return [
        'sudo apt update && sudo apt upgrade -y',
        'sudo apt install -y git nginx nodejs npm',
        'sudo npm install -g pm2',
        'sudo mkdir -p ${config.pathOnServer}',
        'sudo chown \$USER:\$USER ${config.pathOnServer}',
        'cd ${config.pathOnServer}',
        'git clone ${_resolveRepoUrl(config)} .',
        'git checkout ${config.branch}',
        config.installCommand,
        _resolveStartCommand(config),
        'pm2 startup',
        'pm2 save',
        _getNginxConfig(config),
        'sudo ln -s ${config.nginxConf} /etc/nginx/sites-enabled/',
        'sudo nginx -t && sudo systemctl restart nginx',
      ];
    } else {
      return [
        'cd ${config.pathOnServer}',
        'git remote set-url origin ${_resolveRepoUrl(config)}',
        'git pull origin ${config.branch}',
        config.installCommand,
        'pm2 restart ${config.appName}',
        'sudo systemctl restart nginx',
      ];
    }
  }

  String _resolveRepoUrl(ClientConfig config) {
    if (config.gitUsername != null &&
        config.gitToken != null &&
        config.repo.startsWith('http')) {
      final url = config.repo
          .replaceFirst('https://', '')
          .replaceFirst('http://', '');
      return 'https://${config.gitUsername}:${config.gitToken}@$url';
    }
    return config.repo;
  }

  String _resolveStartCommand(ClientConfig config) {
    return config.startCommand
        .replaceAll('{APP_NAME}', config.appName)
        .replaceAll('{PORT}', config.port);
  }

  String _getNginxConfig(ClientConfig config) {
    return '''
sudo tee ${config.nginxConf} > /dev/null <<'NGINX'
server {
    listen 80;
    server_name ${config.domain};
    client_max_body_size 100M;
    
    location / {
        proxy_pass http://localhost:${config.port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \\\$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \\\$host;
        proxy_cache_bypass \\\$http_upgrade;
    }
}
NGINX
''';
  }
}
