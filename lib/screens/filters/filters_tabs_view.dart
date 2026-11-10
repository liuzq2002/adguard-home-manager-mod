import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/screens/filters/custom_rules_list.dart';
import 'package:adguard_home_manager/screens/filters/filters_list.dart';

import 'package:adguard_home_manager/functions/desktop_mode.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/models/filtering.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';

class FiltersTabsView extends StatefulWidget {
  final AppConfigProvider appConfigProvider;
  final List<Widget> actions;
  final void Function(String) onRemoveCustomRule;
  final void Function(Filter, String) onOpenDetailsModal;

  const FiltersTabsView({
    super.key,
    required this.appConfigProvider,
    required this.actions,
    required this.onOpenDetailsModal,
    required this.onRemoveCustomRule,
  });

  @override
  State<FiltersTabsView> createState() => _FiltersTabsViewState();
}

class _FiltersTabsViewState extends State<FiltersTabsView>
    with SingleTickerProviderStateMixin {
  late final TabController tabController;

  void _onTabChanged() {
    if (!tabController.indexIsChanging) {
      widget.appConfigProvider.setSelectedFiltersTab(
        tabController.index,
        notify: false,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    final initialTab = widget.appConfigProvider.selectedFiltersTab.clamp(0, 2);
    tabController = TabController(
      initialIndex: initialTab,
      length: 3,
      vsync: this,
    );
    tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    tabController.removeListener(_onTabChanged);
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteringProvider = Provider.of<FilteringProvider>(context);
    final width = MediaQuery.of(context).size.width;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.filters),
        centerTitle: false,
        actions: widget.actions,
        surfaceTintColor: isDesktop(width) ? Colors.transparent : null,
        bottom: TabBar(
          controller: tabController,
          isScrollable: true,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.gpp_bad_rounded),
                  const SizedBox(width: 8),
                  Text(l10n.blacklists),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_rounded),
                  const SizedBox(width: 8),
                  Text(l10n.customRules),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_user_rounded),
                  const SizedBox(width: 8),
                  Text(l10n.whitelists),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: [
          FiltersList(
            key: const PageStorageKey<String>('filters_blacklist_tab'),
            loadStatus: filteringProvider.loadStatus,
            type: 'blacklist',
            data: filteringProvider.loadStatus == LoadStatus.loaded
                ? filteringProvider.filtering!.filters
                : const [],
            onOpenDetailsScreen: widget.onOpenDetailsModal,
          ),
          CustomRulesList(
            key: const PageStorageKey<String>('filters_custom_rules_tab'),
            loadStatus: filteringProvider.loadStatus,
            data: filteringProvider.loadStatus == LoadStatus.loaded
                ? filteringProvider.filtering!.userRules
                : const [],
            precomputedRules: filteringProvider.loadStatus == LoadStatus.loaded
                ? filteringProvider.filtering!.precomputedCustomRules
                : PrecomputedCustomRules.empty,
            onRemoveCustomRule: widget.onRemoveCustomRule,
          ),
          FiltersList(
            key: const PageStorageKey<String>('filters_whitelist_tab'),
            loadStatus: filteringProvider.loadStatus,
            type: 'whitelist',
            data: filteringProvider.loadStatus == LoadStatus.loaded
                ? filteringProvider.filtering!.whitelistFilters
                : const [],
            onOpenDetailsScreen: widget.onOpenDetailsModal,
          ),
        ],
      ),
    );
  }
}
