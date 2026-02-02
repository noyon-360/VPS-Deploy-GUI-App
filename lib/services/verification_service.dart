import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';
import 'package:deploy_gui/models/client_config.dart';

class VerificationService {
  Future<bool> verifyConnection(
    ClientConfig config, {
    Function(String)? onLog,
  }) async {
    SSHClient? client;
    try {
      onLog?.call('> Connecting to ${config.serverAlias}...');
      client = await _connect(config);
      onLog?.call('> Connection established successfully.');
      return true;
    } catch (e) {
      onLog?.call('> Connection failed: $e');
      return false;
    } finally {
      client?.close();
      if (client != null) onLog?.call('> Connection closed.');
    }
  }

  Future<bool> checkPm2Exists(
    ClientConfig config,
    String appName, {
    Function(String)? onLog,
  }) async {
    if (appName.isEmpty) return false;
    SSHClient? client;
    try {
      onLog?.call('> Checking for PM2 app: "$appName"...');
      client = await _connect(config);

      final cmd = "pm2 list 2>/dev/null | grep '$appName'";
      onLog?.call('>> $cmd');

      final result = await client.run(cmd);
      final output = utf8.decode(result).trim();

      if (output.isNotEmpty) {
        onLog?.call('Found existing process:\n$output');
      } else {
        onLog?.call('No existing process found.');
      }

      return result.isNotEmpty;
    } catch (e) {
      onLog?.call('> Error checking PM2: $e');
      return false;
    } finally {
      client?.close();
    }
  }

  Future<bool> checkDomainConfigExists(
    ClientConfig config,
    String domain, {
    Function(String)? onLog,
  }) async {
    if (domain.isEmpty) return false;
    SSHClient? client;
    try {
      onLog?.call('> Checking for Nginx config: "$domain"...');
      client = await _connect(config);

      // Check 1: Filename existence
      final fileCmd = "ls /etc/nginx/sites-enabled/$domain 2>/dev/null";
      onLog?.call('>> $fileCmd');
      final fileResult = await client.run(fileCmd);
      if (utf8.decode(fileResult).trim().isNotEmpty) {
        onLog?.call('Found config file: /etc/nginx/sites-enabled/$domain');
        return true;
      }

      // Check 2: server_name inside files
      // sudo nginx -T checks loaded configs. We silence stderr (2>/dev/null) to ignore warnings.
      final cmd = 'sudo nginx -T 2>/dev/null | grep "server_name .*$domain"';
      onLog?.call('>> $cmd');

      final result = await client.run(cmd);
      final output = utf8.decode(result).trim();

      if (output.isNotEmpty) {
        onLog?.call('Found existing domain config:\n$output');
        return true;
      } else {
        onLog?.call('No existing domain config found.');
        return false;
      }
    } catch (e) {
      onLog?.call('> Error checking domain: $e');
      return false;
    } finally {
      client?.close();
    }
  }

  Future<List<String>> getRunningApps(
    ClientConfig config, {
    Function(String)? onLog,
  }) async {
    SSHClient? client;
    try {
      onLog?.call('> Fetching running PM2 apps...');
      client = await _connect(config);

      // pm2 jlist returns JSON array of processes
      const cmd = 'pm2 jlist 2>/dev/null';
      onLog?.call('>> $cmd');
      final result = await client.run(cmd);
      final jsonStr = utf8.decode(result).trim();

      if (jsonStr.isEmpty || !jsonStr.startsWith('[')) {
        onLog?.call('> No PM2 output or invalid format.');
        return [];
      }

      final List<dynamic> processes = jsonDecode(jsonStr);
      final List<String> appDetails = [];
      for (final p in processes) {
        final name = p['name'] as String;
        final port = _extractPm2Port(p);

        String detail = name;
        if (port != null) {
          detail += ' (Port: $port)';

          // 1. Find the Nginx file pointing to this port
          final fileCmd =
              "grep -rl 'localhost:$port' /etc/nginx/sites-enabled/ 2>/dev/null | head -n 1";
          final fileResult = await client.run(fileCmd);
          final filePath = utf8.decode(fileResult).trim();

          if (filePath.isNotEmpty) {
            // 2. Extract server_name from that file
            final serverNameCmd =
                "grep -oP 'server_name\\s+\\K[^;]+' $filePath 2>/dev/null | head -n 1";
            final serverNameResult = await client.run(serverNameCmd);
            final serverName = utf8.decode(serverNameResult).trim();

            // 3. Check for SSL
            final sslCmd =
                "grep -q 'ssl_certificate' $filePath 2>/dev/null && echo 'https' || echo 'http'";
            final sslResult = await client.run(sslCmd);
            final protocol = utf8.decode(sslResult).trim();

            if (serverName.isNotEmpty) {
              detail += ' (Domain: $serverName [$protocol])';
            } else {
              detail += ' (File: ${filePath.split('/').last} [$protocol])';
            }
          }
        }
        appDetails.add(detail);
      }

      onLog?.call('Found apps: ${appDetails.join(", ")}');
      return appDetails;
    } catch (e) {
      onLog?.call('> Failed to fetch PM2 apps: $e');
      return [];
    } finally {
      client?.close();
    }
  }

  String? _extractPm2Port(Map<String, dynamic> p) {
    try {
      final env = p['pm2_env'];
      if (env == null) return null;

      // 1. Check direct PORT
      if (env['PORT'] != null) return env['PORT'].toString();

      // 2. Check env variables
      final actualEnv = env['env'];
      if (actualEnv != null && actualEnv is Map && actualEnv['PORT'] != null) {
        return actualEnv['PORT'].toString();
      }

      // 3. Check args for --port XXX
      final args = env['args'];
      if (args != null && args is List) {
        final portIdx = args.indexOf('--port');
        if (portIdx != -1 && portIdx + 1 < args.length) {
          return args[portIdx + 1].toString();
        }
      } else if (args != null && args is String) {
        final match = RegExp(r'--port\s+(\d+)').firstMatch(args);
        if (match != null) return match.group(1);
      }
    } catch (_) {}
    return null;
  }

  Future<List<String>> getActiveSites(
    ClientConfig config, {
    Function(String)? onLog,
  }) async {
    SSHClient? client;
    try {
      onLog?.call('> Fetching Nginx sites...');
      client = await _connect(config);

      // List files in sites-enabled
      const cmd = 'ls /etc/nginx/sites-enabled/ 2>/dev/null';
      onLog?.call('>> $cmd');
      final result = await client.run(cmd);
      final output = utf8.decode(result).trim();

      if (output.isEmpty) {
        onLog?.call('> No active sites found.');
        return [];
      }

      final sitesList = output
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      // For each site, attempt to find its proxy_pass port and app
      final List<String> siteDetails = [];
      for (final site in sitesList) {
        final portCmd =
            "grep 'proxy_pass' /etc/nginx/sites-enabled/$site 2>/dev/null | grep -oE 'localhost:[0-9]+' | cut -d: -f2";
        final portResult = await client.run(portCmd);
        final port = utf8.decode(portResult).trim();

        String detail = site;
        if (port.isNotEmpty) {
          detail += ' (Port: $port)';

          // Attempt to find PM2 app name for this port
          final appCmd =
              "ss -lptn 'sport = :$port' 2>/dev/null | grep -oP '\"[^\"]+\"' | head -n 1 | tr -d '\"'";
          final appResult = await client.run(appCmd);
          final appName = utf8.decode(appResult).trim();
          if (appName.isNotEmpty) {
            detail += ' (App: $appName)';
          }
        }

        // Extract actual server_name and SSL status
        final configPath = "/etc/nginx/sites-enabled/$site";
        final serverNameCmd =
            "grep -oP 'server_name\\s+\\K[^;]+' $configPath 2>/dev/null | head -n 1";
        final serverNameResult = await client.run(serverNameCmd);
        final serverName = utf8.decode(serverNameResult).trim();

        final sslCmd =
            "grep -q 'ssl_certificate' $configPath 2>/dev/null && echo 'https' || echo 'http'";
        final sslResult = await client.run(sslCmd);
        final protocol = utf8.decode(sslResult).trim();

        if (serverName.isNotEmpty && serverName != site) {
          detail += ' (Domain: $serverName [$protocol])';
        } else {
          detail += ' [$protocol]';
        }
        siteDetails.add(detail);
      }

      onLog?.call('Found sites: ${siteDetails.join(", ")}');
      return siteDetails;
    } catch (e) {
      onLog?.call('> Failed to fetch active sites: $e');
      return [];
    } finally {
      client?.close();
    }
  }

  Future<bool> deletePm2App(
    ClientConfig config,
    String appName, {
    Function(String)? onLog,
  }) async {
    SSHClient? client;
    try {
      onLog?.call('> Deleting PM2 app: $appName...');
      client = await _connect(config);
      final cmd = 'pm2 delete "$appName" && pm2 save';
      onLog?.call('>> $cmd');
      final session = await client.execute(cmd);
      await session.stdout
          .listen((event) => onLog?.call(utf8.decode(event)))
          .asFuture();
      return true;
    } catch (e) {
      onLog?.call('> Error deleting PM2 app: $e');
      return false;
    } finally {
      client?.close();
    }
  }

  Future<bool> deleteNginxSite(
    ClientConfig config,
    String siteName, {
    Function(String)? onLog,
  }) async {
    SSHClient? client;
    try {
      onLog?.call('> Deleting Nginx site: $siteName...');
      client = await _connect(config);
      // Remove from enabled and available
      final cmd =
          'sudo rm "/etc/nginx/sites-enabled/$siteName" "/etc/nginx/sites-available/$siteName" && sudo systemctl reload nginx';
      onLog?.call('>> $cmd');
      final session = await client.execute(cmd);
      await session.stdout
          .listen((event) => onLog?.call(utf8.decode(event)))
          .asFuture();
      return true;
    } catch (e) {
      onLog?.call('> Error deleting Nginx site: $e');
      return false;
    } finally {
      client?.close();
    }
  }

  Future<bool> runInteractiveCommand(
    ClientConfig config,
    String command, {
    required Function(String, bool isError) onOutput,
  }) async {
    SSHClient? client;
    try {
      onOutput('>> $command', false);
      client = await _connect(config);
      final session = await client.execute(command);

      // Handle stdout
      final stdoutFuture = session.stdout.listen((event) {
        onOutput(utf8.decode(event), false);
      }).asFuture();

      // Handle stderr
      final stderrFuture = session.stderr.listen((event) {
        onOutput(utf8.decode(event), true);
      }).asFuture();

      await Future.wait([stdoutFuture, stderrFuture]);
      return true;
    } catch (e) {
      onOutput('Error executing command: $e', true);
      return false;
    } finally {
      client?.close();
    }
  }

  Future<SSHClient> createClient(ClientConfig config) async {
    return await _connect(config);
  }

  Future<SSHClient> _connect(ClientConfig config) async {
    final parts = _parseConnection(config.serverAlias);
    final socket = await SSHSocket.connect(parts['host']!, 22);

    return SSHClient(
      socket,
      username: parts['user']!,
      onPasswordRequest: () => config.password,
    );
  }

  Map<String, String> _parseConnection(String alias) {
    if (alias.contains('@')) {
      final parts = alias.split('@');
      return {'user': parts[0], 'host': parts[1]};
    }
    return {'user': 'root', 'host': alias};
  }
}
