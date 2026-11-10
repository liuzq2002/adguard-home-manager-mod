import 'package:flutter/material.dart';

import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/models/applied_filters.dart';
import 'package:adguard_home_manager/models/logs.dart';

class LogsProvider with ChangeNotifier {
  static const int maxRingBufferEntries = 200;

  ServersProvider? _serversProvider;

  void update(ServersProvider? provider) {
    _serversProvider = provider;
  }

  LoadStatus _loadStatus = LoadStatus.loading;
  LogsData? _logsData;
  String _selectedResultStatus = 'all';
  String? _searchText;

  AppliedFiters _appliedFilters = AppliedFiters(
    selectedResultStatus: 'all',
    searchText: null,
    clients: const [],
  );

  LoadStatus get loadStatus => _loadStatus;
  LogsData? get logsData => _logsData;
  String get selectedResultStatus => _selectedResultStatus;
  String? get searchText => _searchText;
  AppliedFiters get appliedFilters => _appliedFilters;

  void resetFilters() {
    _selectedResultStatus = 'all';
    _searchText = null;
    _appliedFilters = AppliedFiters(
      selectedResultStatus: 'all',
      searchText: null,
      clients: const [],
    );
    notifyListeners();
  }

  void setSelectedResultStatus({required String value, bool? refetch}) {
    _selectedResultStatus = value;
    _appliedFilters = AppliedFiters(
      selectedResultStatus: value,
      searchText: _searchText,
      clients: const [],
    );
    notifyListeners();
    if (refetch == true) {
      filterLogs();
    }
  }

  void setSearchText(String? value) {
    final normalized = (value != null && value.trim().isNotEmpty)
        ? value.trim()
        : null;
    _searchText = normalized;
    _appliedFilters = AppliedFiters(
      selectedResultStatus: _selectedResultStatus,
      searchText: normalized,
      clients: const [],
    );
    notifyListeners();
  }

  void setAppliedFilters(AppliedFiters value) {
    _appliedFilters = value;
    _selectedResultStatus = value.selectedResultStatus;
    _searchText = value.searchText;
    notifyListeners();
  }

  Future<bool> fetchLogs({
    int? inOffset,
    String? responseStatus,
    String? searchText,
    bool showLoading = false,
  }) async {
    if (_serversProvider?.apiClient2 == null) {
      _loadStatus = LoadStatus.error;
      notifyListeners();
      return false;
    }

    if (showLoading || _logsData == null) {
      _loadStatus = LoadStatus.loading;
      notifyListeners();
    }

    final resStatus = responseStatus ?? _selectedResultStatus;
    final search = searchText ?? _searchText;

    final result = await _serversProvider!.apiClient2!.getLogs(
      count: maxRingBufferEntries,
      offset: 0,
      responseStatus: resStatus,
      search: search,
    );

    if (result.successful == true) {
      final data = result.content as LogsData;
      if (data.data.length > maxRingBufferEntries) {
        data.data = data.data.sublist(0, maxRingBufferEntries);
      }
      _logsData = data;
      _loadStatus = LoadStatus.loaded;
      notifyListeners();
      return true;
    } else {
      _loadStatus = LoadStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> filterLogs() {
    return fetchLogs(showLoading: true);
  }

  Future<bool> clearAllLogs() async {
    if (_serversProvider?.apiClient2 == null) return false;
    final result = await _serversProvider!.apiClient2!.clearLogs();
    if (result.successful == true) {
      _logsData = LogsData(data: [], oldest: DateTime.now());
      _loadStatus = LoadStatus.loaded;
      notifyListeners();
      return true;
    }
    return false;
  }
}
