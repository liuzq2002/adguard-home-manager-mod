// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/options_menu.dart';

import 'package:adguard_home_manager/classes/process_modal.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/models/filtering.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/functions/copy_clipboard.dart';
import 'package:adguard_home_manager/models/menu_option.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';

class ListOptionsMenu extends StatelessWidget {
  final Filter list;
  final Widget child;
  final String listType;

  const ListOptionsMenu({
    super.key,
    required this.list,
    required this.child,
    required this.listType,
  });

  @override
  Widget build(BuildContext context) {
    final filteringProvider =
        Provider.of<FilteringProvider>(context, listen: false);
    final appConfigProvider =
        Provider.of<AppConfigProvider>(context, listen: false);

    void enableDisable() async {
      ProcessModal processModal = ProcessModal();
      processModal.open(
        list.enabled == true
          ? AppLocalizations.of(context)!.disablingList
          : AppLocalizations.of(context)!.enablingList
      );

      final result = await filteringProvider.updateList(
        list: list, 
        type: listType, 
        action: list.enabled == true
          ? FilteringListActions.disable
          : FilteringListActions.enable
      );

      processModal.close();
      
      if (!context.mounted) return;
      if (result == true) {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: AppLocalizations.of(context)!.listDataUpdated, 
          color: Colors.green
        );
      }
      else {
        showSnackbar(
          appConfigProvider: appConfigProvider,
          label: AppLocalizations.of(context)!.listDataNotUpdated, 
          color: Colors.red
        );
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        child: OptionsMenu(
          options: (_) => [
            MenuOption(
              title: list.enabled == true
                ? AppLocalizations.of(context)!.disable
                : AppLocalizations.of(context)!.enable,
              icon: list.enabled == true
                ? Icons.gpp_bad_rounded
                : Icons.verified_user_rounded,
              action: () => enableDisable()
            ),
            MenuOption(
              title: AppLocalizations.of(context)!.copyListUrl,
              icon: Icons.copy_rounded,
              action: () => copyToClipboard(
                value: list.url, 
                successMessage: AppLocalizations.of(context)!.listUrlCopied
              )
            ),
          ],
          child: child
        )
      ),
    );
  }
}