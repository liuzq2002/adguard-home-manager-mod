import 'package:flutter/material.dart';

import 'package:adguard_home_manager/services/api_client.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/models/dns_info.dart';

class DnsProvider with ChangeNotifier {
  ServersProvider? _serversProvider;

  void update(ServersProvider? provider) {
    _serversProvider = provider;
  }

  LoadStatus _loadStatus = LoadStatus.loading;
  DnsInfo? _dnsInfo;

  LoadStatus get loadStatus {
    return _loadStatus;
  }

  DnsInfo? get dnsInfo {
    return _dnsInfo;
  }

  void setDnsInfoData(DnsInfo data) {
    _dnsInfo = data;
    notifyListeners();
  }

  Future<bool> fetchDnsData({bool? showLoading}) async {
    if (showLoading == true) {
      _loadStatus = LoadStatus.loading;
    }

    final result = await _serversProvider!.apiClient2!.getDnsInfo();

    if (result.successful == true) {
      _dnsInfo = result.content as DnsInfo;
      _loadStatus = LoadStatus.loaded;
      notifyListeners();
      return true;
    } else {
      if (showLoading == false) {
        _loadStatus = LoadStatus.loaded;
        notifyListeners();
      }
      return false;
    }
  }

  Future<ApiResponse> saveUnifiedDnsConfig(Map<String, dynamic> value) async {
    final result =
        await _serversProvider!.apiClient2!.setDnsConfig(data: value);

    if (result.successful == true && dnsInfo != null) {
      final data = dnsInfo!;
      if (value['upstream_dns'] != null) {
        data.upstreamDns = List<String>.from(value['upstream_dns']);
      }
      if (value.containsKey('upstream_mode')) {
        data.upstreamMode = value['upstream_mode'];
      }
      if (value['bootstrap_dns'] != null) {
        data.bootstrapDns = List<String>.from(value['bootstrap_dns']);
      }
      if (value['fallback_dns'] != null) {
        data.fallbackDns = List<String>.from(value['fallback_dns']);
      }
      if (value['blocking_mode'] != null) {
        data.blockingMode = value['blocking_mode'];
      }
      if (value['edns_cs_enabled'] != null) {
        data.ednsCsEnabled = value['edns_cs_enabled'];
      }
      if (value['dnssec_enabled'] != null) {
        data.dnssecEnabled = value['dnssec_enabled'];
      }
      if (value['disable_ipv6'] != null) {
        data.disableIpv6 = value['disable_ipv6'];
      }
      if (value['cache_optimistic'] != null) {
        data.cacheOptimistic = value['cache_optimistic'];
      }
      setDnsInfoData(data);
    }
    return result;
  }
}
