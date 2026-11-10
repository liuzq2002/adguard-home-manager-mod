// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/screens/logs/log_tile.dart';
import 'package:adguard_home_manager/widgets/floating_search_bar.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/models/applied_filters.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/logs_provider.dart';

class Logs extends StatefulWidget {
  const Logs({super.key});

  @override
  State<Logs> createState() => _LogsState();
}

class _LogsState extends State<Logs> {
  final GlobalKey _searchButtonKey = GlobalKey();
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<LogsProvider>(context, listen: false).fetchLogs();
    });
  }

  Future<void> _handleClearLogs() async {
    if (_clearing) return;
    setState(() => _clearing = true);
    final logsProvider = Provider.of<LogsProvider>(context, listen: false);
    final appConfigProvider =
        Provider.of<AppConfigProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;

    final ok = await logsProvider.clearAllLogs();
    if (!mounted) return;
    setState(() => _clearing = false);
    showSnackbar(
      appConfigProvider: appConfigProvider,
      label: ok ? l10n.logsCleared : l10n.logsNotCleared,
      color: ok ? Colors.green : Colors.red,
    );
  }

  void _showSearchDialog(LogsProvider logsProvider) {
    showDialog(
      context: context,
      builder: (context) => FloatingSearchBar(
        existingSearchValue: logsProvider.appliedFilters.searchText ?? '',
        searchButtonRenderBox:
            _searchButtonKey.currentContext?.findRenderObject() as RenderBox?,
        onSearchCompleted: (v) {
          final text = v.trim().isNotEmpty ? v.trim() : null;
          logsProvider.setAppliedFilters(AppliedFiters(
            selectedResultStatus:
                logsProvider.appliedFilters.selectedResultStatus,
            searchText: text,
            clients: const [],
          ));
          logsProvider.filterLogs();
        },
        onSearchFieldUpdated: (v) {
          logsProvider.setSearchText(v.trim().isEmpty ? null : v.trim());
        },
        onSearchFieldCleared: () {
          logsProvider.setSearchText(null);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logsProvider = Provider.of<LogsProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final items = logsProvider.logsData?.data ?? const [];

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(l10n.logs),
        actions: [
          IconButton(
            key: _searchButtonKey,
            onPressed: () => _showSearchDialog(logsProvider),
            icon: const Icon(Icons.search_rounded),
            tooltip: l10n.search,
          ),
          IconButton(
            onPressed: () => logsProvider.fetchLogs(showLoading: true),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: l10n.refresh,
          ),
          IconButton(
            onPressed: _clearing ? null : _handleClearLogs,
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: l10n.clearLogs,
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              children: [
                for (final entry in const [
                  MapEntry('all', '全部'),
                  MapEntry('blocked', '已拦截'),
                  MapEntry('processed', '已放行'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        entry.value,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      selected:
                          logsProvider.appliedFilters.selectedResultStatus ==
                              entry.key,
                      visualDensity: VisualDensity.compact,
                      showCheckmark: false,
                      onSelected: (selected) {
                        if (!selected &&
                            logsProvider.appliedFilters.selectedResultStatus ==
                                entry.key) {
                          return;
                        }
                        logsProvider.setSelectedResultStatus(
                          value: entry.key,
                          refetch: true,
                        );
                      },
                    ),
                  ),
                if (logsProvider.appliedFilters.searchText != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.search_rounded, size: 16),
                      label: Text(
                        logsProvider.appliedFilters.searchText!,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      deleteIcon: const Icon(Icons.clear, size: 16),
                      onDeleted: () {
                        logsProvider.setSearchText(null);
                        logsProvider.fetchLogs(showLoading: true);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => logsProvider.fetchLogs(showLoading: false),
        child: switch (logsProvider.loadStatus) {
          LoadStatus.loading => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    l10n.loadingLogs,
                    style: TextStyle(
                      fontSize: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          LoadStatus.loaded => items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.55,
                      child: Center(
                        child: Text(
                          l10n.noLogsDisplay,
                          style: TextStyle(
                            fontSize: 18,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: items.length,
                  addAutomaticKeepAlives: false,
                  itemBuilder: (context, index) {
                    final log = items[index];
                    if (log.question.name == null) {
                      return const SizedBox.shrink();
                    }
                    return LogTile(
                      key: ValueKey('${log.time.microsecondsSinceEpoch}_$index'),
                      log: log,
                    );
                  },
                ),
          LoadStatus.error => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 20),
                  Text(
                    l10n.logsNotLoaded,
                    style: TextStyle(
                      fontSize: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        },
      ),
    );
  }
}
