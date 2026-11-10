import 'dart:convert';
import 'dart:isolate';

import 'package:adguard_home_manager/models/dns_info.dart';
import 'package:adguard_home_manager/models/filtering.dart';
import 'package:adguard_home_manager/models/filtering_status.dart';
import 'package:adguard_home_manager/models/logs.dart';
import 'package:adguard_home_manager/models/server.dart';
import 'package:adguard_home_manager/models/server_status.dart';
import 'package:adguard_home_manager/classes/http_client.dart';

class ApiResponse {
  final bool successful;
  final dynamic content;
  final int? statusCode;

  const ApiResponse({
    required this.successful,
    this.content,
    this.statusCode,
  });
}

class ApiClientV2 {
  final Server server;

  ApiClientV2({required this.server});

  Future<ApiResponse> getServerStatus() async {
    final results = await Future.wait([
      HttpRequestClient.get(urlPath: "/stats", server: server),
      HttpRequestClient.get(urlPath: "/status", server: server),
      HttpRequestClient.get(urlPath: "/filtering/status", server: server),
    ]);
    if (results.every((e) => e.successful && e.body != null)) {
      try {
        final statsBody = results[0].body!;
        final statusBody = results[1].body!;
        final filteringBody = results[2].body!;

        final serverStatus = await Isolate.run(() {
          final Map<String, dynamic> mappedData = {
            'stats': jsonDecode(statsBody),
            'status': jsonDecode(statusBody),
            'filtering': jsonDecode(filteringBody),
            'safeBrowsingEnabled': null,
            'parentalControlEnabled': null,
          };
          return ServerStatus.fromJson(mappedData);
        });
        return ApiResponse(successful: true, content: serverStatus);
      } catch (_) {
        return const ApiResponse(successful: false);
      }
    } else {
      return const ApiResponse(successful: false);
    }
  }

  Future<ApiResponse> updateFiltering({required bool enable}) async {
    final result = await HttpRequestClient.post(
      urlPath: "/filtering/config",
      server: server,
      body: {'enabled': enable},
    );
    return ApiResponse(successful: result.successful);
  }

  Future<ApiResponse> updateSafeBrowsing({required bool enable}) async {
    return const ApiResponse(successful: true);
  }

  Future<ApiResponse> updateParentalControl({required bool enable}) async {
    return const ApiResponse(successful: true);
  }

  Future<ApiResponse> updateGeneralProtection({
    required bool enable,
    int? time,
  }) async {
    final result = await HttpRequestClient.post(
      urlPath: "/protection",
      server: server,
      body: {'enabled': enable, 'duration': time},
    );
    return ApiResponse(successful: result.successful);
  }

  Future<ApiResponse> getLogs({
    int? count,
    int? offset,
    DateTime? olderThan,
    String? responseStatus,
    String? search,
  }) async {
    final result = await HttpRequestClient.get(
      urlPath:
          '/querylog?${count != null ? 'limit=$count' : ''}${offset != null ? '&offset=$offset' : ''}${olderThan != null ? '&older_than=${olderThan.toIso8601String()}' : ''}${responseStatus != null ? '&response_status=$responseStatus' : ''}${search != null ? '&search=$search' : ''}',
      server: server,
    );
    if (result.successful == true && result.body != null) {
      try {
        final body = result.body!;
        final logsData =
            await Isolate.run(() => LogsData.fromJson(jsonDecode(body)));
        return ApiResponse(successful: true, content: logsData);
      } catch (_) {
        return const ApiResponse(successful: false);
      }
    } else {
      return const ApiResponse(successful: false);
    }
  }

  Future<ApiResponse> getFilteringRules() async {
    final result = await HttpRequestClient.get(
      urlPath: '/filtering/status',
      server: server,
    );
    if (result.successful == true && result.body != null) {
      try {
        final body = result.body!;
        final status = await Isolate.run(
          () => FilteringStatus.fromJson(jsonDecode(body)),
        );
        return ApiResponse(successful: true, content: status);
      } catch (_) {
        return const ApiResponse(successful: false);
      }
    } else {
      return const ApiResponse(successful: false);
    }
  }

  Future<ApiResponse> postFilteringRules({
    required Map<String, List<String>> data,
  }) async {
    final result = await HttpRequestClient.post(
      urlPath: '/filtering/set_rules',
      server: server,
      body: data,
    );
    return ApiResponse(successful: result.successful);
  }

  Future<ApiResponse> getFiltering() async {
    final results1 = await HttpRequestClient.get(
      urlPath: '/filtering/status',
      server: server,
    );
    if (results1.successful == true && results1.body != null) {
      try {
        final body = results1.body!;
        final filtering = await Isolate.run(() => Filtering.fromJson({
              ...jsonDecode(body),
              "blocked_services": [],
            }));
        return ApiResponse(successful: true, content: filtering);
      } catch (_) {
        return const ApiResponse(successful: false);
      }
    } else {
      return const ApiResponse(successful: false);
    }
  }

  Future<ApiResponse> setCustomRules({
    required List<String> rules,
  }) async {
    final result = await HttpRequestClient.post(
      urlPath: '/filtering/set_rules',
      server: server,
      body: {'rules': rules},
    );
    return ApiResponse(successful: result.successful);
  }

  Future<ApiResponse> addFilteringList({
    required Map<String, dynamic> data,
  }) async {
    final result = await HttpRequestClient.post(
      urlPath: '/filtering/add_url',
      server: server,
      body: data,
    );
    return ApiResponse(
      successful: result.successful,
      content: result.body,
      statusCode: result.statusCode,
    );
  }

  Future<ApiResponse> updateFilterList({
    required Map<String, dynamic> data,
  }) async {
    final result = await HttpRequestClient.post(
      urlPath: '/filtering/set_url',
      server: server,
      body: data,
    );
    return ApiResponse(successful: result.successful);
  }

  Future<ApiResponse> deleteFilterList({
    required Map<String, dynamic> data,
  }) async {
    final result = await HttpRequestClient.post(
      urlPath: '/filtering/remove_url',
      server: server,
      body: data,
    );
    return ApiResponse(successful: result.successful);
  }

  Future<ApiResponse> updateLists() async {
    final results = await Future.wait([
      HttpRequestClient.post(
        urlPath: '/filtering/refresh',
        server: server,
        body: {'whitelist': true},
      ),
      HttpRequestClient.post(
        urlPath: '/filtering/refresh',
        server: server,
        body: {'whitelist': false},
      ),
    ]);
    if (results.every((e) => e.successful && e.body != null)) {
      try {
        return ApiResponse(successful: true, content: {
          'updated': jsonDecode(results[0].body!)['updated'] +
              jsonDecode(results[1].body!)['updated'],
        });
      } catch (_) {
        return const ApiResponse(successful: false);
      }
    } else {
      return const ApiResponse(successful: false);
    }
  }

  Future<ApiResponse> requestChangeUpdateFrequency({
    required Map<String, dynamic> data,
  }) async {
    final result = await HttpRequestClient.post(
      urlPath: '/filtering/config',
      server: server,
      body: data,
    );
    return ApiResponse(successful: result.successful);
  }

  Future<ApiResponse> clearLogs() async {
    final result = await HttpRequestClient.post(
      urlPath: '/querylog_clear',
      server: server,
      body: {},
    );
    return ApiResponse(successful: result.successful);
  }

  Future<ApiResponse> getDnsInfo() async {
    final result =
        await HttpRequestClient.get(urlPath: '/dns_info', server: server);
    if (result.successful) {
      try {
        return ApiResponse(
          successful: true,
          content: DnsInfo.fromJson(jsonDecode(result.body!)),
        );
      } catch (_) {
        return const ApiResponse(successful: false);
      }
    } else {
      return const ApiResponse(successful: false);
    }
  }

  Future<ApiResponse> setDnsConfig({
    required Map<String, dynamic> data,
  }) async {
    final result = await HttpRequestClient.post(
      urlPath: '/dns_config',
      server: server,
      body: data,
    );
    if (result.statusCode == 400) {
      return ApiResponse(
        successful: result.successful,
        content: "data_not_valid",
        statusCode: result.statusCode,
      );
    }
    return ApiResponse(successful: result.successful);
  }

  Future<ApiResponse> resetDnsCache() async {
    final result = await HttpRequestClient.post(
      urlPath: '/cache_clear',
      server: server,
    );
    return ApiResponse(successful: result.successful);
  }

  Future<ApiResponse> checkHostFiltered({required String host}) async {
    final result = await HttpRequestClient.get(
      urlPath: '/filtering/check_host?name=$host',
      server: server,
    );
    if (result.successful) {
      return ApiResponse(successful: true, content: jsonDecode(result.body!));
    } else {
      return const ApiResponse(successful: false);
    }
  }

  Future<ApiResponse> testUpstreamDns({
    required Map<String, dynamic> body,
  }) async {
    final result = await HttpRequestClient.post(
      urlPath: '/test_upstream_dns',
      server: server,
      body: body,
    );
    return ApiResponse(
      successful: result.successful,
      content: result.body != null ? jsonDecode(result.body!) : null,
    );
  }
}
