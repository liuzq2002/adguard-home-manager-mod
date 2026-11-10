import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/functions/number_format.dart';

enum CustomRuleType { block, allow, comment }

class CustomRuleEntry {
  final String raw;
  final CustomRuleType type;

  const CustomRuleEntry({
    required this.raw,
    required this.type,
  });

  bool get isComment => type == CustomRuleType.comment;
  bool get isAllow => type == CustomRuleType.allow;
}

class PrecomputedCustomRules {
  final List<CustomRuleEntry> allTopBottom;
  final List<CustomRuleEntry> allBottomTop;
  final List<CustomRuleEntry> activeTopBottom;
  final List<CustomRuleEntry> activeBottomTop;
  final List<CustomRuleEntry> allowTopBottom;
  final List<CustomRuleEntry> allowBottomTop;
  final List<CustomRuleEntry> blockTopBottom;
  final List<CustomRuleEntry> blockBottomTop;

  final int activeCount;
  final int allowCount;
  final int blockCount;
  final int totalCount;

  const PrecomputedCustomRules({
    required this.allTopBottom,
    required this.allBottomTop,
    required this.activeTopBottom,
    required this.activeBottomTop,
    required this.allowTopBottom,
    required this.allowBottomTop,
    required this.blockTopBottom,
    required this.blockBottomTop,
    required this.activeCount,
    required this.allowCount,
    required this.blockCount,
    required this.totalCount,
  });

  static const PrecomputedCustomRules empty = PrecomputedCustomRules(
    allTopBottom: [],
    allBottomTop: [],
    activeTopBottom: [],
    activeBottomTop: [],
    allowTopBottom: [],
    allowBottomTop: [],
    blockTopBottom: [],
    blockBottomTop: [],
    activeCount: 0,
    allowCount: 0,
    blockCount: 0,
    totalCount: 0,
  );

  static CustomRuleType classifyRule(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty ||
        trimmed.startsWith('!') ||
        trimmed.startsWith('#')) {
      return CustomRuleType.comment;
    }
    if (trimmed.startsWith('@@')) {
      return CustomRuleType.allow;
    }
    return CustomRuleType.block;
  }

  factory PrecomputedCustomRules.fromRawRules(List<String> rawRules) {
    if (rawRules.isEmpty) return empty;

    final allTB = <CustomRuleEntry>[];
    final activeTB = <CustomRuleEntry>[];
    final allowTB = <CustomRuleEntry>[];
    final blockTB = <CustomRuleEntry>[];

    for (var i = 0; i < rawRules.length; i++) {
      final raw = rawRules[i];
      final type = classifyRule(raw);
      final entry = CustomRuleEntry(raw: raw, type: type);
      allTB.add(entry);
      if (type != CustomRuleType.comment) {
        activeTB.add(entry);
        if (type == CustomRuleType.allow) {
          allowTB.add(entry);
        } else {
          blockTB.add(entry);
        }
      }
    }

    return PrecomputedCustomRules(
      allTopBottom: allTB,
      allBottomTop: allTB.reversed.toList(growable: false),
      activeTopBottom: activeTB,
      activeBottomTop: activeTB.reversed.toList(growable: false),
      allowTopBottom: allowTB,
      allowBottomTop: allowTB.reversed.toList(growable: false),
      blockTopBottom: blockTB,
      blockBottomTop: blockTB.reversed.toList(growable: false),
      activeCount: activeTB.length,
      allowCount: allowTB.length,
      blockCount: blockTB.length,
      totalCount: allTB.length,
    );
  }

  List<CustomRuleEntry> getEntries({
    required String filter,
    required CustomRulesSorting sorting,
  }) {
    final isBottomTop = sorting == CustomRulesSorting.bottomTop;
    switch (filter) {
      case 'active':
        return isBottomTop ? activeBottomTop : activeTopBottom;
      case 'allow':
        return isBottomTop ? allowBottomTop : allowTopBottom;
      case 'block':
        return isBottomTop ? blockBottomTop : blockTopBottom;
      case 'all':
      default:
        return isBottomTop ? allBottomTop : allTopBottom;
    }
  }
}

class Filtering {
  List<Filter> filters;
  List<Filter> whitelistFilters;
  List<String> _userRules;
  PrecomputedCustomRules _precomputedCustomRules;
  List<String> blockedServices;
  int interval;
  bool enabled;

  Filtering({
    required this.filters,
    required this.whitelistFilters,
    required List<String> userRules,
    required this.blockedServices,
    required this.interval,
    required this.enabled,
    PrecomputedCustomRules? precomputedCustomRules,
  })  : _userRules = userRules,
        _precomputedCustomRules =
            precomputedCustomRules ?? PrecomputedCustomRules.fromRawRules(userRules);

  List<String> get userRules => _userRules;

  set userRules(List<String> value) {
    _userRules = value;
    _precomputedCustomRules = PrecomputedCustomRules.fromRawRules(value);
  }

  PrecomputedCustomRules get precomputedCustomRules => _precomputedCustomRules;

  factory Filtering.fromJson(Map<String, dynamic> json) {
    final parsedUserRules = json["user_rules"] != null
        ? List<String>.from(json["user_rules"].map((x) => x))
            .where((i) => i != '')
            .toList(growable: false)
        : <String>[];
    return Filtering(
      filters: json["filters"] != null
          ? List<Filter>.from(json["filters"].map((x) => Filter.fromJson(x)))
          : [],
      whitelistFilters: json["whitelist_filters"] != null
          ? List<Filter>.from(
              json["whitelist_filters"].map((x) => Filter.fromJson(x)))
          : [],
      userRules: parsedUserRules,
      precomputedCustomRules:
          PrecomputedCustomRules.fromRawRules(parsedUserRules),
      blockedServices: json["blocked_services"] != null
          ? List<String>.from(json["blocked_services"].map((x) => x))
              .where((i) => i != '')
              .toList()
          : [],
      interval: json["interval"],
      enabled: json["enabled"],
    );
  }

  Map<String, dynamic> toJson() => {
    "filters": List<dynamic>.from(filters.map((x) => x.toJson())),
    "whitelist_filters": List<dynamic>.from(whitelistFilters.map((x) => x.toJson())),
    "user_rules": List<dynamic>.from(_userRules.map((x) => x)),
    "blocked_services": List<dynamic>.from(blockedServices.map((x) => x)),
    "interval": interval,
    "enabled": enabled,
  };
}

class Filter {
  final String url;
  final String name;
  final DateTime? lastUpdated;
  final int id;
  final int rulesCount;
  bool enabled;

  String? _cachedLocale;
  String? _cachedFormattedRulesCount;

  Filter({
    required this.url,
    required this.name,
    required this.lastUpdated,
    required this.id,
    required this.rulesCount,
    required this.enabled,
  });

  String formattedRulesCount(String locale) {
    if (_cachedLocale == locale && _cachedFormattedRulesCount != null) {
      return _cachedFormattedRulesCount!;
    }
    final formatted = intFormat(rulesCount, locale);
    _cachedLocale = locale;
    _cachedFormattedRulesCount = formatted;
    return formatted;
  }

  factory Filter.fromJson(Map<String, dynamic> json) => Filter(
    url: json["url"],
    name: json["name"],
    lastUpdated: json["last_updated"] != null && json["last_updated"] != '' ? DateTime.parse(json["last_updated"]) : null,
    id: json["id"],
    rulesCount: json["rules_count"],
    enabled: json["enabled"],
  );

  Map<String, dynamic> toJson() => {
    "url": url,
    "name": name,
    "last_updated": lastUpdated?.toIso8601String(),
    "id": id,
    "rules_count": rulesCount,
    "enabled": enabled,
  };
}

class ProcessedList {
  final Filter list;
  final bool successful;

  const ProcessedList({
    required this.list,
    required this.successful
  });
}
