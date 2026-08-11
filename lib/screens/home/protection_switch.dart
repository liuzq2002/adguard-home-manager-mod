// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/functions/format_time.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';

class ProtectionSwitch extends StatelessWidget {
  const ProtectionSwitch({super.key});

  Future<void> _updateBlocking(
    BuildContext context, {
    required bool value,
    required String filter,
    int? time,
  }) async {
    final statusProvider = Provider.of<StatusProvider>(context, listen: false);
    final appConfigProvider = Provider.of<AppConfigProvider>(context, listen: false);
    final result = await statusProvider.updateBlocking(
      block: filter,
      newStatus: value,
      time: time,
    );
    if (context.mounted && result == false) {
      showSnackbar(
        appConfigProvider: appConfigProvider,
        label: AppLocalizations.of(context)!.invalidUsernamePassword,
        color: Colors.red,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusProvider = Provider.of<StatusProvider>(context);
    final status = statusProvider.serverStatus;
    if (status == null) return const SizedBox.shrink();

    final managingGeneral = statusProvider.protectionsManagementProcess.contains('general');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.shield_rounded,
                    size: 28,
                    color: status.generalEnabled
                      ? Colors.green
                      : Colors.red,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status.generalEnabled
                            ? '全部保护已开启'
                            : '全部保护已暂停',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (status.timeGeneralDisabled > 0 && statusProvider.currentDeadline != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${AppLocalizations.of(context)!.remainingTime}: ${formatRemainingSeconds(statusProvider.remainingTime)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Switch(
                    value: status.generalEnabled,
                    onChanged: managingGeneral
                      ? null
                      : (value) => _updateBlocking(
                          context,
                          value: value,
                          filter: 'general',
                        ),
                  ),
                ],
              ),
              if (status.generalEnabled) ...[
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ActionChip(
                        label: Text(AppLocalizations.of(context)!.seconds(30)),
                        onPressed: managingGeneral
                          ? null
                          : () => _updateBlocking(
                              context,
                              value: false,
                              filter: 'general',
                              time: 29000,
                            ),
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        label: Text(AppLocalizations.of(context)!.minute(1)),
                        onPressed: managingGeneral
                          ? null
                          : () => _updateBlocking(
                              context,
                              value: false,
                              filter: 'general',
                              time: 59000,
                            ),
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        label: Text(AppLocalizations.of(context)!.minutes(10)),
                        onPressed: managingGeneral
                          ? null
                          : () => _updateBlocking(
                              context,
                              value: false,
                              filter: 'general',
                              time: 599000,
                            ),
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        label: Text(AppLocalizations.of(context)!.hour(1)),
                        onPressed: managingGeneral
                          ? null
                          : () => _updateBlocking(
                              context,
                              value: false,
                              filter: 'general',
                              time: 3599000,
                            ),
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        label: Text(AppLocalizations.of(context)!.hours(24)),
                        onPressed: managingGeneral
                          ? null
                          : () => _updateBlocking(
                              context,
                              value: false,
                              filter: 'general',
                              time: 86399000,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
