import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';
import 'package:deploy_gui/models/client_config.dart';

class VerificationService {
  Future<bool> verifyConnection(
    ClientConfig config, {
    Function(String)? onLog,
  }) async {
    try {
      onLog?.call('> Connecting to ${config.serverAlias}...');
      final client = await _connect(config);
      onLog?.call('> Connection established successfully.');
      client.close();
      onLog?.call('> Connection closed.');
      return true;
    } catch (e) {
      onLog?.call('> Connection failed: $e');
      return false;
    }
  }

  Future<bool> checkPm2Exists(
    ClientConfig config,
    String appName, {
    Function(String)? onLog,
  }) async {
    if (appName.isEmpty) return false;
    try {
      onLog?.call('> Checking for PM2 app: "$appName"...');
      final client = await _connect(config);

      final cmd = "pm2 list 2>/dev/null | grep '$appName'";
      onLog?.call('> Executing: $cmd');

      final result = await client.run(cmd);
      final output = utf8.decode(result).trim();

      if (output.isNotEmpty) {
        onLog?.call('> Found existing process:\n$output');
      } else {
        onLog?.call('> No existing process found.');
      }

      client.close();
      return result.isNotEmpty;
    } catch (e) {
      onLog?.call('> Error checking PM2: $e');
      return false;
    }
  }

  Future<bool> checkDomainConfigExists(
    ClientConfig config,
    String domain, {
    Function(String)? onLog,
  }) async {
    if (domain.isEmpty) return false;
    try {
      onLog?.call('> Checking for Nginx config: "$domain"...');
      final client = await _connect(config);

      // sudo nginx -T checks loaded configs. We silence stderr (2>/dev/null) to ignore warnings.
      final cmd = 'sudo nginx -T 2>/dev/null | grep "server_name .*$domain"';
      onLog?.call('> Executing: $cmd');

      final result = await client.run(cmd);
      final output = utf8.decode(result).trim();

      if (output.isNotEmpty) {
        onLog?.call('> Found existing domain config:\n$output');
      } else {
        onLog?.call('> No existing domain config found.');
      }

      client.close();
      return result.isNotEmpty;
    } catch (e) {
      onLog?.call('> Error checking domain: $e');
      return false;
    }
  }

  Future<List<String>> getRunningApps(
    ClientConfig config, {
    Function(String)? onLog,
  }) async {
    try {
      onLog?.call('> Fetching running PM2 apps...');
      final client = await _connect(config);

      // pm2 jlist returns JSON array of processes
      final result = await client.run('pm2 jlist 2>/dev/null');
      final jsonStr = utf8.decode(result).trim();
      client.close();

      if (jsonStr.isEmpty || !jsonStr.startsWith('[')) {
        onLog?.call('> No PM2 output or invalid format.');
        return [];
      }

      final List<dynamic> processes = jsonDecode(jsonStr);
      final names = processes.map((p) => p['name'] as String).toList();
      onLog?.call('> Found apps: ${names.join(", ")}');
      return names;
    } catch (e) {
      onLog?.call('> Failed to fetch PM2 apps: $e');
      return [];
    }
  }

  Future<List<String>> getActiveSites(
    ClientConfig config, {
    Function(String)? onLog,
  }) async {
    try {
      onLog?.call('> Fetching Nginx sites...');
      final client = await _connect(config);

      // List files in sites-enabled
      final result = await client.run(
        'ls /etc/nginx/sites-enabled/ 2>/dev/null',
      );
      final output = utf8.decode(result).trim();
      client.close();

      if (output.isEmpty) {
        onLog?.call('> No active sites found.');
        return [];
      }

      final sites = output
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      onLog?.call('> Found sites: ${sites.join(", ")}');
      return sites;
    } catch (e) {
      onLog?.call('> Failed to fetch active sites: $e');
      return [];
    }
  }

  Future<bool> deletePm2App(
    ClientConfig config,
    String appName, {
    Function(String)? onLog,
  }) async {
    try {
      onLog?.call('> Deleting PM2 app: $appName...');
      final client = await _connect(config);
      final session = await client.execute('pm2 delete "$appName" && pm2 save');
      await session.stdout
          .listen((event) => onLog?.call(utf8.decode(event)))
          .asFuture();
      client.close();
      return true;
    } catch (e) {
      onLog?.call('> Error deleting PM2 app: $e');
      return false;
    }
  }

  Future<bool> deleteNginxSite(
    ClientConfig config,
    String siteName, {
    Function(String)? onLog,
  }) async {
    try {
      onLog?.call('> Deleting Nginx site: $siteName...');
      final client = await _connect(config);
      // Remove from enabled and available
      final cmd =
          'sudo rm "/etc/nginx/sites-enabled/$siteName" "/etc/nginx/sites-available/$siteName" && sudo systemctl reload nginx';
      final session = await client.execute(cmd);
      await session.stdout
          .listen((event) => onLog?.call(utf8.decode(event)))
          .asFuture();
      client.close();
      return true;
    } catch (e) {
      onLog?.call('> Error deleting Nginx site: $e');
      return false;
    }
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
