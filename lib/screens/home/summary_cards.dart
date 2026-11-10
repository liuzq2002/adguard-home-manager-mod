import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:adguard_home_manager/functions/number_format.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/logs_provider.dart';

class HomeSummaryCards extends StatelessWidget {
  const HomeSummaryCards({super.key});

  @override
  Widget build(BuildContext context) {
    final statusProvider = Provider.of<StatusProvider>(context);
    final appConfigProvider =
        Provider.of<AppConfigProvider>(context, listen: false);
    final logsProvider = Provider.of<LogsProvider>(context, listen: false);
    final locale = Localizations.localeOf(context).toString();

    final serverStatus = statusProvider.serverStatus;
    if (serverStatus == null) {
      return const SizedBox.shrink();
    }

    final stats = serverStatus.stats;
    final totalQueries = stats.numDnsQueries;
    final blockedQueries = stats.numBlockedFiltering;
    final blockRate =
        totalQueries > 0 ? (blockedQueries / totalQueries) * 100 : 0.0;
    final avgLatencyMs = stats.avgProcessingTime * 1000;
    final filters = serverStatus.filteringStatus.filters;
    final totalRules = filters.fold<int>(0, (prev, f) => prev + f.rulesCount);
    final enabledLists = filters.where((f) => f.enabled).length;
    final customRulesCount = serverStatus.filteringStatus.userRules.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  title: 'DNS 查询总数',
                  primaryValue: intFormat(totalQueries, locale),
                  secondaryValue:
                      '平均耗时: ${doubleFormat(avgLatencyMs, locale)} ms',
                  icon: Icons.dns_rounded,
                  iconColor: Colors.blue,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    logsProvider.setSelectedResultStatus(
                      value: 'all',
                      refetch: true,
                    );
                    appConfigProvider.setSelectedScreen(1);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  title: '拦截与去广告',
                  primaryValue: intFormat(blockedQueries, locale),
                  secondaryValue: '拦截率: ${blockRate.toStringAsFixed(1)}%',
                  icon: Icons.block_rounded,
                  iconColor: Colors.red,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    logsProvider.setSelectedResultStatus(
                      value: 'blocked',
                      refetch: true,
                    );
                    appConfigProvider.setSelectedScreen(1);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  title: '已加载规则总数',
                  primaryValue: intFormat(totalRules, locale),
                  secondaryValue: '启用订阅: $enabledLists 组',
                  icon: Icons.rule_rounded,
                  iconColor: Colors.teal,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    appConfigProvider.setSelectedFiltersTab(0, notify: false);
                    appConfigProvider.setSelectedScreen(2);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  title: '自定义规则与白名单',
                  primaryValue: intFormat(customRulesCount, locale),
                  secondaryValue:
                      serverStatus.generalEnabled ? '保护运行中' : '保护已暂停',
                  icon: Icons.playlist_add_check_rounded,
                  iconColor: Colors.purple,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    appConfigProvider.setSelectedFiltersTab(1, notify: false);
                    appConfigProvider.setSelectedScreen(2);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String primaryValue;
  final String secondaryValue;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _SummaryCard({
    required this.title,
    required this.primaryValue,
    required this.secondaryValue,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                primaryValue,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                secondaryValue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
