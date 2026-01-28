import 'package:deploy_gui/models/client_config.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'dart:convert';

class StorageService {
  static const String _fileName = 'client_configs.json';

  Future<String> get _localPath async {
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
      final List<dynamic> jsonList = json.decode(contents);
      return jsonList.map((json) => ClientConfig.fromJson(json)).toList();
    } catch (e) {
      print('Error loading configs: $e');
      return [];
    }
  }

  Future<void> saveConfigs(List<ClientConfig> configs) async {
    try {
      final file = await _localFile;
      final jsonList = configs.map((config) => config.toJson()).toList();
      await file.writeAsString(json.encode(jsonList));
    } catch (e) {
      print('Error saving configs: $e');
    }
  }
}
