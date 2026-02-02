import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';
import 'package:deploy_gui/models/client_config.dart';
import 'package:deploy_gui/models/remote_file.dart';
import 'package:deploy_gui/models/server_tool_status.dart';
import 'package:deploy_gui/models/discovered_application.dart';

class VerificationService {
  Future<List<ServerToolStatus>> checkInstalledTools(
    ClientConfig config, {
    required Function(String) onLog,
  }) async {
    final tools = ['nginx', 'git', 'node', 'pm2'];
    final List<ServerToolStatus> results = [];

    for (final tool in tools) {
      onLog('>> Checking $tool...');
      try {
        final client = await connect(config); // Use public connect

        String cmd = '';
        if (tool == 'nginx') cmd = 'nginx -v';
        if (tool == 'git') cmd = 'git --version';
        if (tool == 'node') cmd = 'node -v';
        if (tool == 'pm2') cmd = 'pm2 -v';

        final result = await client.run('$cmd 2>&1');
        final output = utf8.decode(result).trim();

        client.close();

        final isInstalled =
            !output.contains('command not found') &&
            !output.contains('no such file') &&
            output.isNotEmpty;

        results.add(
          ServerToolStatus(
            name: tool,
            isInstalled: isInstalled,
            version: isInstalled ? output : null,
          ),
        );

        if (isInstalled) {
          onLog('> $tool found: $output');
        } else {
          onLog('> $tool NOT found.');
        }
      } catch (e) {
        onLog('> $tool check failed: $e');
        results.add(ServerToolStatus(name: tool, isInstalled: false));
      }
    }
    return results;
  }

  // Expose connect publicly
  Future<SSHClient> connect(ClientConfig config) async {
    return _connect(config);
  }

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

  String? _extractPm2Port(Map<String, dynamic> process) {
    try {
      final pm2Env = process['pm2_env'];
      if (pm2Env == null) return null;

      // 1. Check environment variables (Most common)
      final env = pm2Env['env'];
      if (env != null && env is Map) {
        if (env['PORT'] != null) return env['PORT'].toString();
        if (env['port'] != null) return env['port'].toString();
        // Next.js typical port env
        if (env['NEXT_PUBLIC_PORT'] != null)
          return env['NEXT_PUBLIC_PORT'].toString();
      }

      // 2. Check arguments
      final args = pm2Env['args'];
      if (args != null) {
        List<String> argList = [];
        if (args is List) {
          argList = args.map((e) => e.toString()).toList();
        } else if (args is String) {
          argList = args.split(' ');
        }

        for (int i = 0; i < argList.length; i++) {
          final arg = argList[i];
          if ((arg == '--port' || arg == '-p') && i + 1 < argList.length) {
            return argList[i + 1];
          }
          // Handle --port=3000 format
          if (arg.startsWith('--port=')) {
            return arg.split('=')[1];
          }
        }
      }

      return null;
    } catch (e) {
      return null;
    }
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

  Future<List<RemoteFile>> listFiles(
    ClientConfig config,
    String path, {
    Function(String)? onLog,
  }) async {
    SSHClient? client;
    try {
      onLog?.call('> Listing files in: $path');
      client = await _connect(config);

      // ls -la --time-style=long-iso to get consistent date format if possible,
      // but standard ls -la is safer for general compatibility.
      final cmd = 'ls -la "$path" 2>/dev/null';
      onLog?.call('>> $cmd');
      final result = await client.run(cmd);
      final output = utf8.decode(result).trim();

      if (output.isEmpty) {
        return [];
      }

      final lines = output.split('\n');
      final List<RemoteFile> files = [];

      for (final line in lines) {
        if (line.trim().isEmpty || line.startsWith('total')) continue;
        try {
          // Filter out . and .. to avoid loop/confusion if desired,
          // or keep them for navigation. Let's keep them but maybe UI filters ..
          // Actually .. is useful for "Up", . is useless.
          // Parsing ls -la is fragile, but standard format is:
          // drwxr-xr-x 2 user group size date time name
          final file = RemoteFile.fromLsOutput(line.trim(), path);
          if (file.name != '.') {
            files.add(file);
          }
        } catch (e) {
          // ignore parse errors for weird lines
        }
      }

      // Sort: Directories first, then files
      files.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.compareTo(b.name);
      });

      return files;
    } catch (e) {
      onLog?.call('> Error listing files: $e');
      return [];
    } finally {
      client?.close();
    }
  }

  Future<void> catFile(
    ClientConfig config,
    String path, {
    Function(String)? onLog,
  }) async {
    SSHClient? client;
    try {
      onLog?.call('> Reading content of $path...');
      client = await _connect(config);

      final cmd = 'cat "$path"';
      onLog?.call('>> $cmd');

      final result = await client.run(cmd);
      final output = utf8.decode(
        result,
      ); // Don't trim to preserve whitespace structure if important

      if (output.isNotEmpty) {
        onLog?.call(output);
      } else {
        onLog?.call('(File is empty)');
      }
    } catch (e) {
      onLog?.call('> Error reading file: $e');
    } finally {
      client?.close();
    }
  }

  /// Discover all deployed applications in /var/www
  Future<List<DiscoveredApplication>> discoverApplications(
    ClientConfig config, {
    Function(String)? onLog,
  }) async {
    SSHClient? client;
    try {
      onLog?.call('> Discovering applications in /var/www...');
      client = await _connect(config);

      // List all directories in /var/www
      final cmd = 'ls -d /var/www/*/ 2>/dev/null';
      onLog?.call('>> $cmd');
      final result = await client.run(cmd);
      final output = utf8.decode(result).trim();

      if (output.isEmpty) {
        onLog?.call('> No directories found in /var/www');
        return [];
      }

      final directories = output
          .split('\n')
          .map((s) => s.trim().replaceAll(RegExp(r'/$'), ''))
          .where((s) => s.isNotEmpty)
          .toList();

      onLog?.call('> Found ${directories.length} directories');

      final List<DiscoveredApplication> apps = [];

      // Get PM2 process list once for efficiency
      final pm2Processes = await _getPm2ProcessList(client, onLog);

      for (final dir in directories) {
        onLog?.call('> Analyzing: $dir');
        try {
          final app = await _analyzeDirectory(client, dir, pm2Processes, onLog);
          if (app != null) {
            apps.add(app);
            onLog?.call('  ✓ ${app.displayName} - ${app.statusSummary}');
          }
        } catch (e) {
          onLog?.call('  ✗ Error analyzing $dir: $e');
        }
      }

      onLog?.call('> Discovery complete. Found ${apps.length} applications.');
      return apps;
    } catch (e) {
      onLog?.call('> Error discovering applications: $e');
      return [];
    } finally {
      client?.close();
    }
  }

  /// Get PM2 process list as JSON
  Future<List<Map<String, dynamic>>> _getPm2ProcessList(
    SSHClient client,
    Function(String)? onLog,
  ) async {
    try {
      final result = await client.run('pm2 jlist 2>/dev/null');
      final jsonStr = utf8.decode(result).trim();

      if (jsonStr.isEmpty || !jsonStr.startsWith('[')) {
        return [];
      }

      final List<dynamic> processes = jsonDecode(jsonStr);
      return processes.cast<Map<String, dynamic>>();
    } catch (e) {
      onLog?.call('  Warning: Could not fetch PM2 processes: $e');
      return [];
    }
  }

  /// Analyze a single directory to extract all configuration
  Future<DiscoveredApplication?> _analyzeDirectory(
    SSHClient client,
    String path,
    List<Map<String, dynamic>> pm2Processes,
    Function(String)? onLog,
  ) async {
    // Extract git information
    final gitInfo = await _extractGitInfo(client, path);

    // Find matching PM2 process
    final pm2Info = _findPm2Process(pm2Processes, path);
    if (pm2Info != null && onLog != null) {
      if (pm2Info['port'] == null) {
        onLog(
          '  Warning: PM2 process found but no port detected for ${pm2Info['appName']}',
        );
      } else {
        onLog(
          '  PM2 process detected: ${pm2Info['appName']} on port ${pm2Info['port']}',
        );
      }
    }

    // Extract Nginx configuration if PM2 port is available
    Map<String, dynamic>? nginxInfo;
    if (pm2Info != null && pm2Info['port'] != null) {
      final port = pm2Info['port'];
      if (port != null) {
        nginxInfo = await _extractNginxConfig(client, port);
      }
    }

    // Detect install command
    final installCmd = await _detectInstallCommand(client, path);

    return DiscoveredApplication(
      pathOnServer: path,
      repoUrl: gitInfo['repoUrl'],
      branch: gitInfo['branch'],
      gitUsername: gitInfo['gitUsername'],
      gitToken: gitInfo['gitToken'],
      appName: pm2Info?['appName'],
      port: pm2Info?['port'],
      startCommand: pm2Info?['startCommand'],
      installCommand: installCmd,
      domain: nginxInfo?['domain'],
      hasSSL: nginxInfo?['hasSSL'] ?? false,
      sslEmail: nginxInfo?['sslEmail'],
      nginxConfigPath: nginxInfo?['configPath'],
    );
  }

  /// Extract git repository information
  Future<Map<String, String?>> _extractGitInfo(
    SSHClient client,
    String path,
  ) async {
    try {
      // Check if .git exists
      final gitCheck = await client.run('[ -d "$path/.git" ] && echo "yes"');
      if (utf8.decode(gitCheck).trim() != 'yes') {
        return {'repoUrl': null, 'branch': null};
      }

      // Get remote URL
      final repoResult = await client.run(
        'cd "$path" && git config --get remote.origin.url 2>/dev/null',
      );
      String? repoUrl = utf8.decode(repoResult).trim();
      if (repoUrl.isEmpty) repoUrl = null;

      // Get current branch
      final branchResult = await client.run(
        'cd "$path" && git branch --show-current 2>/dev/null',
      );
      String? branch = utf8.decode(branchResult).trim();
      if (branch.isEmpty) branch = null;

      // Parse git credentials from URL if present
      String? gitUsername;
      String? gitToken;
      if (repoUrl != null && repoUrl.contains('@')) {
        final match = RegExp(r'https://([^:]+):([^@]+)@').firstMatch(repoUrl);
        if (match != null) {
          gitUsername = match.group(1);
          gitToken = match.group(2);
          // Clean URL for display
          repoUrl = repoUrl.replaceFirst(
            RegExp(r'https://[^:]+:[^@]+@'),
            'https://',
          );
        }
      }

      return {
        'repoUrl': repoUrl,
        'branch': branch,
        'gitUsername': gitUsername,
        'gitToken': gitToken,
      };
    } catch (e) {
      return {'repoUrl': null, 'branch': null};
    }
  }

  /// Find PM2 process matching the directory path
  Map<String, String?>? _findPm2Process(
    List<Map<String, dynamic>> processes,
    String path,
  ) {
    try {
      for (final p in processes) {
        final pm2Env = p['pm2_env'];
        if (pm2Env == null) continue;

        final cwd = pm2Env['pm_cwd'] as String?;
        if (cwd == null || cwd != path) continue;

        // Found matching process
        final appName = p['name'] as String?;
        final port = _extractPm2Port(p);

        // Extract start command
        String? startCommand;
        final execPath = pm2Env['pm_exec_path'] as String?;
        final args = pm2Env['args'];
        if (execPath != null) {
          startCommand = 'pm2 start $execPath';
          if (args != null) {
            if (args is List) {
              startCommand += ' -- ${args.join(' ')}';
            } else if (args is String && args.isNotEmpty) {
              startCommand += ' -- $args';
            }
          }
          if (appName != null) {
            startCommand += ' --name "$appName"';
          }
        }

        return {'appName': appName, 'port': port, 'startCommand': startCommand};
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Extract Nginx configuration for a specific port
  Future<Map<String, dynamic>?> _extractNginxConfig(
    SSHClient client,
    String port,
  ) async {
    try {
      // Find nginx config file that proxies to this port
      final fileCmd =
          "grep -rl 'localhost:$port' /etc/nginx/sites-enabled/ 2>/dev/null | head -n 1";
      final fileResult = await client.run(fileCmd);
      final configPath = utf8.decode(fileResult).trim();

      if (configPath.isEmpty) return null;

      // Extract server_name
      final serverNameCmd =
          "grep -oP 'server_name\\s+\\K[^;]+' $configPath 2>/dev/null | head -n 1";
      final serverNameResult = await client.run(serverNameCmd);
      final domain = utf8.decode(serverNameResult).trim();

      // Check for SSL
      final sslCmd =
          "grep -q 'ssl_certificate' $configPath 2>/dev/null && echo 'yes' || echo 'no'";
      final sslResult = await client.run(sslCmd);
      final hasSSL = utf8.decode(sslResult).trim() == 'yes';

      // Extract SSL email from certbot renewal config
      String? sslEmail;
      if (hasSSL && domain.isNotEmpty) {
        final emailCmd =
            "grep -oP 'email = \\K.*' /etc/letsencrypt/renewal/$domain.conf 2>/dev/null";
        final emailResult = await client.run(emailCmd);
        sslEmail = utf8.decode(emailResult).trim();
        if (sslEmail.isEmpty) sslEmail = null;
      }

      return {
        'domain': domain.isEmpty ? null : domain,
        'hasSSL': hasSSL,
        'sslEmail': sslEmail,
        'configPath': configPath,
      };
    } catch (e) {
      return null;
    }
  }

  /// Detect install command based on project type
  Future<String?> _detectInstallCommand(SSHClient client, String path) async {
    try {
      // Check for package.json (Node.js)
      final packageJsonCheck = await client.run(
        '[ -f "$path/package.json" ] && echo "yes"',
      );
      if (utf8.decode(packageJsonCheck).trim() == 'yes') {
        return 'npm install';
      }

      // Check for requirements.txt (Python)
      final requirementsCheck = await client.run(
        '[ -f "$path/requirements.txt" ] && echo "yes"',
      );
      if (utf8.decode(requirementsCheck).trim() == 'yes') {
        return 'pip install -r requirements.txt';
      }

      // Check for composer.json (PHP)
      final composerCheck = await client.run(
        '[ -f "$path/composer.json" ] && echo "yes"',
      );
      if (utf8.decode(composerCheck).trim() == 'yes') {
        return 'composer install';
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}
