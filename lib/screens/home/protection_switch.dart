// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_miuix/miuix.dart';
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: MiuixCard(
        cornerRadius: 20,
        insideMargin: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.shield_rounded,
                  size: 28,
                  color: status.generalEnabled ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.generalEnabled ? '全部保护已开启' : '全部保护已暂停',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (status.timeGeneralDisabled > 0 &&
                          statusProvider.currentDeadline != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${AppLocalizations.of(context)!.remainingTime}: ${formatRemainingSeconds(statusProvider.remainingTime)}',
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
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
            if (status.generalEnabled) ...[
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _PauseButton(
                      label: AppLocalizations.of(context)!.seconds(30),
                      enabled: !managingGeneral,
                      onPressed: () => _updateBlocking(
                        context,
                        value: false,
                        filter: 'general',
                        time: 29000,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _PauseButton(
                      label: AppLocalizations.of(context)!.minute(1),
                      enabled: !managingGeneral,
                      onPressed: () => _updateBlocking(
                        context,
                        value: false,
                        filter: 'general',
                        time: 59000,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _PauseButton(
                      label: AppLocalizations.of(context)!.minutes(10),
                      enabled: !managingGeneral,
                      onPressed: () => _updateBlocking(
                        context,
                        value: false,
                        filter: 'general',
                        time: 599000,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _PauseButton(
                      label: AppLocalizations.of(context)!.hour(1),
                      enabled: !managingGeneral,
                      onPressed: () => _updateBlocking(
                        context,
                        value: false,
                        filter: 'general',
                        time: 3599000,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _PauseButton(
                      label: AppLocalizations.of(context)!.hours(24),
                      enabled: !managingGeneral,
                      onPressed: () => _updateBlocking(
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
    );
  }
}

/// 主开关卡片上的暂停时长按钮，统一样式方便后续调整。
class _PauseButton extends StatelessWidget {
  const _PauseButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return MiuixButton(
      enabled: enabled,
      onPressed: enabled ? onPressed : null,
      minWidth: 0,
      minHeight: 34,
      cornerRadius: 12,
      insideMargin: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Text(label),
    );
  }
}
