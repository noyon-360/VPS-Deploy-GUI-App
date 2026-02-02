import 'package:deploy_gui/models/client_config.dart';
import 'package:deploy_gui/models/repository_config.dart';
import 'package:deploy_gui/models/deployment_action.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'dart:convert';

class StorageService {
  static const String _fileName = 'client_configs.json';
  static const String _storageVersion = '2.0';

  Future<String> get _localPath async {
    if (kIsWeb) {
      return ''; // Path not used for web storage usually
    }
    final directory = await getApplicationDocumentsDirectory();
    final deployDir = Directory(p.join(directory.path, 'DeployGUI'));
    if (!await deployDir.exists()) {
      await deployDir.create(recursive: true);
    }
    return deployDir.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File(p.join(path, _fileName));
  }

  Future<List<ClientConfig>> loadConfigs() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) {
        return [];
      }
      final contents = await file.readAsString();
      final Map<String, dynamic> jsonData = json.decode(contents);

      // Check version and migrate if needed
      if (jsonData['version'] == null ||
          jsonData['version'] != _storageVersion) {
        debugPrint('Migrating old storage format to version $_storageVersion');
        return await _migrateOldFormat(jsonData);
      }

      final List<dynamic> jsonList = jsonData['clients'] ?? [];
      return jsonList.map((json) => ClientConfig.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error loading configs: $e');
      return [];
    }
  }

  Future<void> saveConfigs(List<ClientConfig> configs) async {
    try {
      final file = await _localFile;
      final jsonData = {
        'version': _storageVersion,
        'clients': configs.map((config) => config.toJson()).toList(),
      };
      await file.writeAsString(json.encode(jsonData));
    } catch (e) {
      debugPrint('Error saving configs: $e');
    }
  }

  // Find client by SSH IP (primary unique identifier)
  Future<ClientConfig?> findClientBySSH(String sshIp) async {
    final configs = await loadConfigs();
    try {
      return configs.firstWhere((client) => client.serverAlias == sshIp);
    } catch (e) {
      return null;
    }
  }

  // Find repository within a client
  Future<RepositoryConfig?> findRepository(String sshIp, String repoUrl) async {
    final client = await findClientBySSH(sshIp);
    return client?.findRepository(repoUrl);
  }

  // Add a new repository to an existing client
  Future<bool> addRepository(String clientId, RepositoryConfig repo) async {
    final configs = await loadConfigs();
    final index = configs.indexWhere((c) => c.id == clientId);

    if (index == -1) return false;

    final updatedClient = configs[index].addRepository(repo);
    configs[index] = updatedClient;
    await saveConfigs(configs);
    return true;
  }

  // Update an existing repository
  Future<bool> updateRepository(
    String clientId,
    String repoUrl,
    RepositoryConfig updatedRepo,
  ) async {
    final configs = await loadConfigs();
    final index = configs.indexWhere((c) => c.id == clientId);

    if (index == -1) return false;

    final updatedClient = configs[index].updateRepository(repoUrl, updatedRepo);
    configs[index] = updatedClient;
    await saveConfigs(configs);
    return true;
  }

  // Add deployment action to a repository
  Future<bool> addDeploymentAction(
    String clientId,
    String repoUrl,
    DeploymentAction action,
  ) async {
    final configs = await loadConfigs();
    final clientIndex = configs.indexWhere((c) => c.id == clientId);

    if (clientIndex == -1) return false;

    final client = configs[clientIndex];
    final repo = client.findRepository(repoUrl);

    if (repo == null) return false;

    final updatedRepo = repo.addAction(action);
    final updatedClient = client.updateRepository(repoUrl, updatedRepo);
    configs[clientIndex] = updatedClient;
    await saveConfigs(configs);
    return true;
  }

  // Update client's last connected timestamp
  Future<bool> updateLastConnected(String clientId) async {
    final configs = await loadConfigs();
    final index = configs.indexWhere((c) => c.id == clientId);

    if (index == -1) return false;

    configs[index] = configs[index].updateLastConnected();
    await saveConfigs(configs);
    return true;
  }

  // Migration from old flat structure to hierarchical
  Future<List<ClientConfig>> _migrateOldFormat(
    Map<String, dynamic> jsonData,
  ) async {
    debugPrint('Starting migration from old format...');

    // Old format was just a list of configs
    final List<dynamic> oldConfigs = jsonData is List
        ? jsonData
        : (jsonData['clients'] ?? []);

    // Group by SSH IP
    final Map<String, List<Map<String, dynamic>>> groupedBySSH = {};

    for (var config in oldConfigs) {
      final sshIp = config['serverAlias'] ?? '';
      if (sshIp.isEmpty) continue;

      if (!groupedBySSH.containsKey(sshIp)) {
        groupedBySSH[sshIp] = [];
      }
      groupedBySSH[sshIp]!.add(config);
    }

    // Create new hierarchical structure
    final List<ClientConfig> migratedClients = [];

    for (var entry in groupedBySSH.entries) {
      final sshIp = entry.key;
      final configs = entry.value;

      // Use the first config for client-level data
      final firstConfig = configs.first;

      // Create repositories from all configs for this SSH IP
      final repositories = configs.map((config) {
        return RepositoryConfig(
          repoUrl: config['repo'] ?? '',
          branch: config['branch'] ?? 'main',
          pathOnServer: config['pathOnServer'] ?? '/var/www/app',
          appName: config['appName'] ?? 'app',
          port: config['port'] ?? '3000',
          domain: config['domain'] ?? '',
          installCommand: config['installCommand'] ?? 'npm install',
          startCommand: config['startCommand'] ?? 'pm2 start server.js',
          nginxConf: config['nginxConf'] ?? '',
          gitUsername: config['gitUsername'],
          gitToken: config['gitToken'],
          enableSSL: config['enableSSL'] ?? false,
          sslEmail: config['sslEmail'],
        );
      }).toList();

      final client = ClientConfig(
        id:
            firstConfig['id'] ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: firstConfig['name'] ?? 'Migrated Client',
        serverAlias: sshIp,
        password: firstConfig['password'],
        repositories: repositories,
      );

      migratedClients.add(client);
    }

    // Save migrated data
    await saveConfigs(migratedClients);
    debugPrint(
      'Migration completed. Created ${migratedClients.length} clients.',
    );

    return migratedClients;
  }
}
