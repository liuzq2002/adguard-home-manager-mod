// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/screens/filters/filters_tabs_view.dart';
import 'package:adguard_home_manager/screens/filters/details/list_details_screen.dart';
import 'package:adguard_home_manager/screens/filters/modals/remove_custom_rule_modal.dart';
import 'package:adguard_home_manager/screens/filters/modals/update_interval_lists_modal.dart';

import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/classes/process_modal.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/models/filtering.dart';
import 'package:adguard_home_manager/constants/enums.dart';

class Filters extends StatefulWidget {
  const Filters({super.key});

  @override
  State<Filters> createState() => _FiltersState();
}

class _FiltersState extends State<Filters> {
  @override
  void initState() {
    super.initState();
    final filteringProvider =
        Provider.of<FilteringProvider>(context, listen: false);
    filteringProvider.fetchFilters(
      showLoading: filteringProvider.filtering == null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteringProvider = Provider.of<FilteringProvider>(context);
    final statusProvider = Provider.of<StatusProvider>(context);
    final appConfigProvider =
        Provider.of<AppConfigProvider>(context, listen: false);

    final width = MediaQuery.of(context).size.width;

    void updateLists() async {
      ProcessModal processModal = ProcessModal();
      processModal.open(AppLocalizations.of(context)!.updatingLists);
      final result = await filteringProvider.updateLists();
      if (!mounted) return;
      processModal.close();
      if (result['success'] == true) {
        showSnackbar(
            appConfigProvider: appConfigProvider,
            label:
                "${result['data']['updated']} ${AppLocalizations.of(context)!.listsUpdated}",
            color: Colors.green);
      } else {
        showSnackbar(
            appConfigProvider: appConfigProvider,
            label: AppLocalizations.of(context)!.listsNotUpdated,
            color: Colors.red);
      }
    }

    void enableDisableFiltering() async {
      ProcessModal processModal = ProcessModal();
      processModal.open(statusProvider.serverStatus!.filteringEnabled == true
          ? AppLocalizations.of(context)!.disableFiltering
          : AppLocalizations.of(context)!.enableFiltering);

      final result = await filteringProvider.enableDisableFiltering();

      processModal.close();

      if (result == true) {
        showSnackbar(
            appConfigProvider: appConfigProvider,
            label: AppLocalizations.of(context)!.filteringStatusUpdated,
            color: Colors.green);
      } else {
        showSnackbar(
            appConfigProvider: appConfigProvider,
            label: AppLocalizations.of(context)!.filteringStatusNotUpdated,
            color: Colors.red);
      }
    }

    void setUpdateFrequency(int value) async {
      ProcessModal processModal = ProcessModal();
      processModal.open(AppLocalizations.of(context)!.changingUpdateFrequency);

      final result = await filteringProvider.changeUpdateFrequency(value);

      processModal.close();

      if (result == true) {
        showSnackbar(
            appConfigProvider: appConfigProvider,
            label: AppLocalizations.of(context)!.updateFrequencyChanged,
            color: Colors.green);
      } else {
        showSnackbar(
            appConfigProvider: appConfigProvider,
            label: AppLocalizations.of(context)!.updateFrequencyNotChanged,
            color: Colors.red);
      }
    }

    void removeCustomRule(String rule) async {
      ProcessModal processModal = ProcessModal();
      processModal.open(AppLocalizations.of(context)!.deletingRule);

      final result = await filteringProvider.removeCustomRule(rule);

      processModal.close();

      if (result == true) {
        showSnackbar(
            appConfigProvider: appConfigProvider,
            label: AppLocalizations.of(context)!.ruleRemovedSuccessfully,
            color: Colors.green);
      } else {
        showSnackbar(
            appConfigProvider: appConfigProvider,
            label: AppLocalizations.of(context)!.ruleNotRemoved,
            color: Colors.red);
      }
    }

    void openRemoveCustomRuleModal(String rule) {
      showDialog(
          context: context,
          builder: (context) => RemoveCustomRule(
                onConfirm: () => removeCustomRule(rule),
              ));
    }

    void openListDetails(Filter filter, String type) {
      if (width > 900) {
        showDialog(
          context: context,
          builder: (context) => ListDetailsScreen(
            listId: filter.id,
            type: type,
            dialog: width > 900 || !(Platform.isAndroid | Platform.isIOS),
          ),
        );
      } else {
        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ListDetailsScreen(
                listId: filter.id,
                type: type,
                dialog: width > 900 || !(Platform.isAndroid | Platform.isIOS),
              ),
            ));
      }
    }

    List<Widget> actions() {
      if (filteringProvider.loadStatus == LoadStatus.loaded) {
        return [
          if (statusProvider.loadStatus == LoadStatus.loaded)
            IconButton(
                onPressed: enableDisableFiltering,
                tooltip: filteringProvider.filtering!.enabled == true
                    ? AppLocalizations.of(context)!.disableFiltering
                    : AppLocalizations.of(context)!.enableFiltering,
                icon: Stack(
                  children: [
                    const Icon(Icons.power_settings_new_rounded),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                color: Colors.white),
                            child: Icon(
                                filteringProvider.filtering!.enabled == true
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel,
                                size: 12,
                                color: filteringProvider.filtering!.enabled ==
                                        true
                                    ? appConfigProvider
                                                .useThemeColorForStatus ==
                                            true
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.green
                                    : appConfigProvider
                                                .useThemeColorForStatus ==
                                            true
                                        ? Colors.grey
                                        : Colors.red),
                          ),
                        ],
                      ),
                    )
                  ],
                )),
          IconButton(
            onPressed: () {
              if (width > 900 || !(Platform.isAndroid || Platform.isIOS)) {
                showDialog(
                  context: context,
                  builder: (context) => UpdateIntervalListsModal(
                    interval: filteringProvider.filtering!.interval,
                    onChange: setUpdateFrequency,
                    dialog: true,
                  ),
                );
              } else {
                showModalBottomSheet(
                    context: context,
                    useRootNavigator: true,
                    builder: (context) => UpdateIntervalListsModal(
                          interval: filteringProvider.filtering!.interval,
                          onChange: setUpdateFrequency,
                          dialog: false,
                        ),
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true);
              }
            },
            icon: const Icon(Icons.update_rounded),
            tooltip: AppLocalizations.of(context)!.updateFrequency,
          ),
          IconButton(
            onPressed: updateLists,
            icon: const Icon(Icons.sync_rounded),
            tooltip: AppLocalizations.of(context)!.updateLists,
          ),
          const SizedBox(width: 5),
        ];
      } else {
        return [];
      }
    }

    return FiltersTabsView(
      appConfigProvider: appConfigProvider,
      actions: actions(),
      onRemoveCustomRule: openRemoveCustomRuleModal,
      onOpenDetailsModal: openListDetails,
    );
  }
}
