import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';
import 'package:deploy_gui/models/temp_client_config.dart';

class DeploymentService {
  Future<Stream<String>> deploy(String mode, TempClientConfig config) async {
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
    TempClientConfig config,
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
    TempClientConfig config,
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

  List<String> _getCommands(String mode, TempClientConfig config) {
    // Robust Bash Script Generation
    // We combine initial/update logic into smart checking scripts where possible.
    // 'set -e' ensures the script stops immediately if any command fails.

    final repoUrl = _resolveRepoUrl(config);
    final startCmd = _resolveStartCommand(config);
    final nginxConfigContent = _getNginxConfigContent(config);

    List<String> cmds = [
      'set -e', // Exit immediately if a command exits with a non-zero status.
      // 1. Install Dependencies (Idempotent: apt install -y skips if already installed)
      'sudo apt update',
      'sudo apt install -y git nginx nodejs npm',
      'sudo npm install -g pm2',

      // 2. Prepare Directory
      'sudo mkdir -p ${config.pathOnServer}',
      'sudo chown \$USER:\$USER ${config.pathOnServer}',
      'cd ${config.pathOnServer}',

      // 3. Git Logic (Check if repo exists)
      '''
if [ -d ".git" ]; then
  echo ">>> Repo exists. Pulling latest changes..."
  git remote set-url origin $repoUrl
  git fetch origin
  git reset --hard origin/${config.branch}
else
  echo ">>> Cloning repository..."
  git clone $repoUrl .
  git checkout ${config.branch}
fi
''',

      // 4. Install Dependencies
      config.installCommand,

      // 5. PM2 Logic (Check if app exists)
      '''
if pm2 describe ${config.appName} > /dev/null; then
  echo ">>> App '${config.appName}' is running. Restarting..."
  pm2 restart ${config.appName}
else
  echo ">>> Starting app '${config.appName}'..."
  $startCmd
  pm2 save
fi
''',

      // 6. Nginx Configuration
      // Write config content to a temp file then move it (avoids sudo piping issues)
      '''
echo "$nginxConfigContent" > /tmp/${config.appName}.nginx
sudo mv /tmp/${config.appName}.nginx ${config.nginxConf}
''',
      // Force Link (ln -sf)
      'sudo ln -sf ${config.nginxConf} /etc/nginx/sites-enabled/',
      'sudo nginx -t',
      'sudo systemctl restart nginx',
    ];

    // 7. SSL Logic (Certbot)
    if (config.enableSSL && config.sslEmail != null) {
      // Certbot is generally interactive or fails if not carefully flags.
      // --reinstall or keep-until-expiring are implicit usually.
      cmds.addAll([
        'sudo apt install -y certbot python3-certbot-nginx',
        'sudo certbot --nginx -d ${config.domain} -m ${config.sslEmail} --agree-tos --non-interactive --redirect',
      ]);
    }

    return cmds;
  }

  String _getNginxConfigContent(TempClientConfig config) {
    // Escaping specific for Bash echo
    return '''
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
''';
  }

  String _resolveRepoUrl(TempClientConfig config) {
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

  String _resolveStartCommand(TempClientConfig config) {
    return config.startCommand
        .replaceAll('{APP_NAME}', config.appName)
        .replaceAll('{PORT}', config.port);
  }
}
