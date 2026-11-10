// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/options_menu.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/classes/process_modal.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/functions/copy_clipboard.dart';
import 'package:adguard_home_manager/models/menu_option.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/functions/get_filtered_status.dart';
import 'package:adguard_home_manager/models/logs.dart';
import 'package:adguard_home_manager/functions/format_time.dart';

class LogTile extends StatelessWidget {
  final Log log;

  const LogTile({
    super.key,
    required this.log,
  });

  @override
  Widget build(BuildContext context) {
    final appConfigProvider =
        Provider.of<AppConfigProvider>(context, listen: false);
    final statusProvider = Provider.of<StatusProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    final filter =
        getFilteredStatus(context, appConfigProvider, log.reason, false);
    final domainBlocked = isDomainBlocked(log.reason);
    final isSniLog = log.reason == 'FilteredSNI' ||
        log.reason == 'NotFilteredSNI' ||
        log.question.type.toUpperCase() == 'SNI' ||
        (log.clientProto?.toLowerCase().contains('sni') ?? false);

    final badgeColor = isSniLog ? Colors.purple : Colors.blue;
    final badgeLabel = isSniLog
        ? 'SNI'
        : (log.question.type.isNotEmpty ? log.question.type : 'DNS');
    final ruleHint = log.rules.isNotEmpty ? log.rules.first.text : '';
    String? elapsedText;
    if (log.elapsedMs.isNotEmpty) {
      final parsed = double.tryParse(log.elapsedMs);
      if (parsed != null) {
        elapsedText =
            '${parsed < 10 ? parsed.toStringAsFixed(1) : parsed.toStringAsFixed(0)} ms';
      }
    }

    Future<void> blockUnblock({
      required String domain,
      required String newStatus,
    }) async {
      if (!context.mounted) return;
      final processModal = ProcessModal();
      processModal.open(l10n.savingUserFilters);

      final ok = await statusProvider.blockUnblockDomain(
        domain: domain,
        newStatus: newStatus,
      );

      processModal.close();
      if (!context.mounted) return;
      showSnackbar(
        appConfigProvider: appConfigProvider,
        label: ok
            ? l10n.userFilteringRulesUpdated
            : l10n.userFilteringRulesNotUpdated,
        color: ok ? Colors.green : Colors.red,
      );
    }

    final domain = log.question.name;
    final menuOptions = <MenuOption>[
      if (domain != null)
        MenuOption(
          title: domainBlocked ? l10n.unblockDomain : l10n.blockDomain,
          icon: domainBlocked ? Icons.check_rounded : Icons.block_rounded,
          action: () => blockUnblock(
            domain: domain,
            newStatus: domainBlocked ? 'unblock' : 'block',
          ),
        ),
      if (domain != null)
        MenuOption(
          title: l10n.copyClipboard,
          icon: Icons.copy_rounded,
          action: () => copyToClipboard(
            value: domain,
            successMessage: l10n.copiedClipboard,
          ),
        ),
    ];

    return Material(
      color: Colors.transparent,
      child: OptionsMenu(
        options: (_) => menuOptions,
        onTap: (_) {
          if (domain == null) return;
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(
                domain,
                style: const TextStyle(fontSize: 16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('状态: ${filter['label']}'),
                  if (ruleHint.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '命中规则: $ruleHint',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    copyToClipboard(
                      value: domain,
                      successMessage: l10n.copiedClipboard,
                    );
                  },
                  child: Text(l10n.copyClipboard),
                ),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    blockUnblock(
                      domain: domain,
                      newStatus: domainBlocked ? 'unblock' : 'block',
                    );
                  },
                  icon: Icon(
                    domainBlocked ? Icons.check_rounded : Icons.block_rounded,
                    size: 18,
                  ),
                  label: Text(
                    domainBlocked ? l10n.unblockDomain : l10n.blockDomain,
                  ),
                ),
              ],
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      domain ?? 'N/A',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              badgeLabel,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: badgeColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            convertTimestampLocalTimezone(log.time, 'HH:mm:ss'),
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          if (elapsedText != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '· $elapsedText',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          if (ruleHint.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '· $ruleHint',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 72,
                child: Column(
                  children: [
                    Icon(
                      filter['icon'],
                      color: filter['color'],
                      size: 14,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      filter['label'],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: filter['color'],
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
