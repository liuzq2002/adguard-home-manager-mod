import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/screens/home/summary_cards.dart';
import 'package:adguard_home_manager/screens/home/protection_switch.dart';
import 'package:adguard_home_manager/services/module_config_service.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  void initState() {
    super.initState();

    final serversProvider =
        Provider.of<ServersProvider>(context, listen: false);
    if (serversProvider.selectedServer == null ||
        serversProvider.apiClient2 == null) {
      return;
    }

    final statusProvider = Provider.of<StatusProvider>(context, listen: false);
    statusProvider.getServerStatus(
      withLoadingIndicator: statusProvider.serverStatus == null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final serversProvider = Provider.of<ServersProvider>(context);
    final statusProvider = Provider.of<StatusProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    if (serversProvider.selectedServer == null ||
        serversProvider.apiClient2 == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '未检测到 AdGuard Home 模块\n请确认已安装模块并授予 Root 权限后重启应用',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final status = statusProvider.serverStatus;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        leading: Icon(
          status != null
              ? (status.generalEnabled
                  ? Icons.gpp_good_rounded
                  : Icons.gpp_bad_rounded)
              : Icons.shield_rounded,
          size: 26,
          color: status != null
              ? (status.generalEnabled ? Colors.green : Colors.red)
              : colorScheme.onSurfaceVariant,
        ),
        title: Text(l10n.home),
        actions: [
          IconButton(
            onPressed: () => statusProvider.getServerStatus(
              withLoadingIndicator: false,
            ),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: l10n.refresh,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => statusProvider.getServerStatus(
          withLoadingIndicator: false,
        ),
        child: switch (statusProvider.loadStatus) {
          LoadStatus.loading => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    l10n.loadingStatus,
                    style: TextStyle(
                      fontSize: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          LoadStatus.loaded => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              children: const [
                ProtectionSwitch(),
                HomeSummaryCards(),
              ],
            ),
          LoadStatus.error => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 48),
                    const SizedBox(height: 20),
                    Text(
                      l10n.errorLoadServerStatus,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('重新同步端口并重试'),
                      onPressed: () async {
                        await ModuleConfigService().reloadFirewallRules();
                        await statusProvider.getServerStatus();
                      },
                    ),
                  ],
                ),
              ),
            ),
        },
      ),
    );
  }
}
