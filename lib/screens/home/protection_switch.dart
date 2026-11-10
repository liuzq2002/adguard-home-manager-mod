// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/functions/format_time.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/screens/home/module_quick_card.dart';

class ProtectionSwitch extends StatelessWidget {
  const ProtectionSwitch({super.key});

  Future<void> _updateBlocking(
    BuildContext context, {
    required bool value,
    required String filter,
    int? time,
  }) async {
    final statusProvider = Provider.of<StatusProvider>(context, listen: false);
    final appConfigProvider =
        Provider.of<AppConfigProvider>(context, listen: false);
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

    final managingGeneral =
        statusProvider.protectionsManagementProcess.contains('general');
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: MiuixCard(
        cornerRadius: 20,
        insideMargin: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.shield_rounded,
                  size: 26,
                  color: status.generalEnabled ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.generalEnabled ? '保护已开启' : '保护已暂停',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (status.timeGeneralDisabled > 0 &&
                          statusProvider.currentDeadline != null) ...[
                        const SizedBox(height: 2),
                        ValueListenableBuilder<int>(
                          valueListenable: statusProvider.remainingTimeNotifier,
                          builder: (context, remainingSeconds, _) => Text(
                            '${l10n.remainingTime}: ${formatRemainingSeconds(remainingSeconds)}',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (status.generalEnabled)
                  PopupMenuButton<int>(
                    enabled: !managingGeneral,
                    tooltip: '定时暂停',
                    icon: Icon(
                      Icons.timer_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    onSelected: (time) => _updateBlocking(
                      context,
                      value: false,
                      filter: 'general',
                      time: time,
                    ),
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 29000,
                        child: Text('暂停 ${l10n.seconds(30)}'),
                      ),
                      PopupMenuItem(
                        value: 59000,
                        child: Text('暂停 ${l10n.minute(1)}'),
                      ),
                      PopupMenuItem(
                        value: 599000,
                        child: Text('暂停 ${l10n.minutes(10)}'),
                      ),
                      PopupMenuItem(
                        value: 3599000,
                        child: Text('暂停 ${l10n.hour(1)}'),
                      ),
                      PopupMenuItem(
                        value: 86399000,
                        child: Text('暂停 ${l10n.hours(24)}'),
                      ),
                    ],
                  ),
                MiuixSwitch(
                  value: status.generalEnabled,
                  enabled: !managingGeneral,
                  onChanged: (value) => _updateBlocking(
                    context,
                    value: value,
                    filter: 'general',
                  ),
                ),
              ],
            ),
            const ModuleQuickActions(),
          ],
        ),
      ),
    );
  }
}
