import 'package:deploy_gui/models/client_config.dart';
import 'package:deploy_gui/services/storage_service.dart';
import 'package:flutter/material.dart';

class AppProvider with ChangeNotifier {
  final StorageService _storageService = StorageService();
  List<ClientConfig> _clients = [];
  bool _isLoading = true;

  List<ClientConfig> get clients => _clients;
  bool get isLoading => _isLoading;

  AppProvider() {
    _init();
  }

  Future<void> _init() async {
    _clients = await _storageService.loadConfigs();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addClient(ClientConfig client) async {
    _clients.add(client);
    await _storageService.saveConfigs(_clients);
    notifyListeners();
  }

  Future<void> updateClient(ClientConfig updatedClient) async {
    final index = _clients.indexWhere((c) => c.id == updatedClient.id);
    if (index != -1) {
      _clients[index] = updatedClient;
      await _storageService.saveConfigs(_clients);
      notifyListeners();
    }
  }

  Future<void> deleteClient(String id) async {
    _clients.removeWhere((c) => c.id == id);
    await _storageService.saveConfigs(_clients);
    notifyListeners();
  }

  Future<void> deleteAllClients() async {
    _clients.clear();
    await _storageService.saveConfigs(_clients);
    notifyListeners();
  }
}
