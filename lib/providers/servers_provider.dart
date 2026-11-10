import 'package:flutter/material.dart';

import 'package:adguard_home_manager/services/api_client.dart';
import 'package:adguard_home_manager/models/server.dart';
import 'package:adguard_home_manager/functions/base64.dart';

class ServersProvider with ChangeNotifier {
  List<Server> _serversList = [];
  Server? _selectedServer;
  ApiClientV2? _apiClient2;

  ApiClientV2? get apiClient2 => _apiClient2;

  List<Server> get serversList => _serversList;

  Server? get selectedServer => _selectedServer;

  void setSelectedServer(Server? server) {
    _selectedServer = server;
    notifyListeners();
  }

  void setApiClient2(ApiClientV2 client) {
    _apiClient2 = client;
    notifyListeners();
  }

  Future<void> autoConnectModule(String address) async {
    final normalized = address.contains('://') ? address : 'http://$address';
    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.port == 0) return;

    final Server server = Server(
      id: 'adguard_home_module',
      name: 'AdGuard Home 模块',
      connectionMethod: 'http',
      domain: uri.host,
      port: uri.port,
      user: 'root',
      password: 'root',
      defaultServer: true,
      authToken: encodeBase64UserPass('root', 'root'),
      runningOnHa: false,
    );

    _serversList = [server];
    _selectedServer = server;
    _apiClient2 = ApiClientV2(server: server);
    notifyListeners();
  }
}
