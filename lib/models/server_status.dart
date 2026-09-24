import 'package:adguard_home_manager/functions/time_server_disabled.dart';
import 'package:adguard_home_manager/models/clients.dart';
import 'package:adguard_home_manager/models/dns_statistics.dart';
import 'package:adguard_home_manager/models/filtering_status.dart';

/// 服务器状态。
///
/// 精简过的 AdGuard Home 核心可能不返回部分可选接口/字段（例如安全浏览、
/// 家长控制），这里统一按默认值处理，避免因为缺少字段导致整体解析失败。
class ServerStatus {
  final DnsStatistics stats;
  final List<Client> clients;
  final FilteringStatus filteringStatus;
  int timeGeneralDisabled;
  DateTime? disabledUntil;
  bool generalEnabled;
  bool filteringEnabled;
  bool safeBrowsingEnabled;
  bool parentalControlEnabled;
  final String serverVersion;
  bool dhcpAvailable;

  ServerStatus({
    required this.stats,
    required this.clients,
    required this.filteringStatus,
    required this.timeGeneralDisabled,
    this.disabledUntil,
    required this.generalEnabled,
    required this.filteringEnabled,
    required this.safeBrowsingEnabled,
    required this.parentalControlEnabled,
    required this.serverVersion,
    required this.dhcpAvailable,
  });

  factory ServerStatus.fromJson(Map<String, dynamic> json) => ServerStatus(
        stats: DnsStatistics.fromJson(json['stats']),
        clients: json["clients"] != null
            ? List<Client>.from(json["clients"].map((x) => Client.fromJson(x)))
            : [],
        generalEnabled: json['status']['protection_enabled'] ?? false,
        timeGeneralDisabled:
            json['status']['protection_disabled_duration'] ?? 0,
        disabledUntil: json['status']['protection_disabled_duration'] != null
            ? json['status']['protection_disabled_duration'] > 0
                ? generateTimeDeadline(
                    json['status']['protection_disabled_duration'])
                : null
            : null,
        filteringStatus: FilteringStatus.fromJson(json['filtering']),
        filteringEnabled: json['filtering']['enabled'] ?? false,
        safeBrowsingEnabled: json['safeBrowsingEnabled'] != null
            ? json['safeBrowsingEnabled']['enabled'] ?? false
            : false,
        parentalControlEnabled: json['parentalControlEnabled'] != null
            ? json['parentalControlEnabled']['enabled'] ?? false
            : false,
        serverVersion: json['status']['version'],
        dhcpAvailable: json['status']['dhcp_available'] ?? false,
      );
}
