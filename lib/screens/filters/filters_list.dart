// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/rendering.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/screens/filters/add_button.dart';
import 'package:adguard_home_manager/screens/filters/list_options_menu.dart';
import 'package:adguard_home_manager/widgets/custom_list_tile.dart';
import 'package:adguard_home_manager/widgets/tab_content_list.dart';

import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/models/filtering.dart';

class FiltersList extends StatefulWidget {
  final LoadStatus loadStatus;
  final ScrollController? scrollController;
  final List<Filter> data;
  final String type;
  final void Function(Filter, String) onOpenDetailsScreen;

  const FiltersList({
    super.key,
    required this.loadStatus,
    this.scrollController,
    required this.data,
    required this.type,
    required this.onOpenDetailsScreen,
  });

  @override
  State<FiltersList> createState() => _FiltersListState();
}

class _FiltersListState extends State<FiltersList>
    with AutomaticKeepAliveClientMixin {
  late final ScrollController _internalScrollController;
  final ValueNotifier<bool> _fabVisible = ValueNotifier<bool>(true);

  ScrollController get _effectiveScrollController =>
      widget.scrollController ?? _internalScrollController;

  @override
  bool get wantKeepAlive => true;

  void _onScroll() {
    if (!_effectiveScrollController.hasClients) return;
    final direction = _effectiveScrollController.position.userScrollDirection;
    if (direction == ScrollDirection.reverse) {
      if (_fabVisible.value) {
        _fabVisible.value = false;
      }
    } else if (direction == ScrollDirection.forward) {
      if (!_fabVisible.value) {
        _fabVisible.value = true;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _internalScrollController = ScrollController();
    _effectiveScrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _effectiveScrollController.removeListener(_onScroll);
    if (widget.scrollController == null) {
      _internalScrollController.dispose();
    }
    _fabVisible.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filteringProvider =
        Provider.of<FilteringProvider>(context, listen: false);
    final appConfigProvider =
        Provider.of<AppConfigProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final localeName = Platform.localeName;
    final enabledRulesLabel = l10n.enabledRules;
    final useThemeColor = appConfigProvider.useThemeColorForStatus == true;
    final enabledColor =
        useThemeColor ? theme.colorScheme.primary : Colors.green;
    final disabledColor = useThemeColor ? Colors.grey : Colors.red;

    return CustomTabContentList(
      scrollController: _effectiveScrollController,
      loadingGenerator: () => SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height - 171,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 30),
            Text(
              l10n.loadingFilters,
              style: TextStyle(
                fontSize: 22,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          ],
        ),
      ),
      itemsCount: widget.data.length,
      contentWidget: (index) {
        final item = widget.data[index];
        return KeyedSubtree(
          key: ValueKey<int>(item.id),
          child: ListOptionsMenu(
            list: item,
            listType: widget.type,
            child: CustomListTile(
              title: item.name,
              subtitle:
                  "${item.formattedRulesCount(localeName)} $enabledRulesLabel",
              trailing: Icon(
                item.enabled == true
                    ? Icons.check_circle_rounded
                    : Icons.cancel,
                color: item.enabled == true ? enabledColor : disabledColor,
              ),
              onTap: () => widget.onOpenDetailsScreen(item, widget.type),
            ),
          ),
        );
      },
      noData: Container(
        width: double.maxFinite,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                widget.type == 'blacklist'
                    ? l10n.noBlackLists
                    : l10n.noWhiteLists,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 30),
            TextButton.icon(
              onPressed: () async {
                final result = await filteringProvider.fetchFilters();
                if (result == false && mounted) {
                  showSnackbar(
                    appConfigProvider: appConfigProvider,
                    label: l10n.errorLoadFilters,
                    color: Colors.red,
                  );
                }
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.refresh),
            )
          ],
        ),
      ),
      errorGenerator: () => SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height - 171,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.error,
              color: Colors.red,
              size: 50,
            ),
            const SizedBox(height: 30),
            Text(
              l10n.filtersNotLoaded,
              style: TextStyle(
                fontSize: 22,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          ],
        ),
      ),
      loadStatus: widget.loadStatus,
      onRefresh: () async {
        final result = await filteringProvider.fetchFilters();
        if (result == false && mounted) {
          showSnackbar(
            appConfigProvider: appConfigProvider,
            label: l10n.errorLoadFilters,
            color: Colors.red,
          );
        }
      },
      fab: AddFiltersButton(
        type: widget.type,
        widget: (fn) => FloatingActionButton(
          heroTag: 'filters_add_fab_${widget.type}',
          onPressed: fn,
          child: const Icon(Icons.add),
        ),
      ),
      fabVisibleListenable: _fabVisible,
    );
  }
}
