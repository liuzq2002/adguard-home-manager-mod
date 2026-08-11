import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/screens/home/appbar.dart';
import 'package:adguard_home_manager/screens/home/chart.dart';
import 'package:adguard_home_manager/screens/home/combined_chart.dart';
import 'package:adguard_home_manager/screens/home/protection_switch.dart';
import 'package:adguard_home_manager/screens/home/top_items/top_items_lists.dart';

import 'package:adguard_home_manager/providers/clients_provider.dart';
import 'package:adguard_home_manager/providers/logs_provider.dart';
import 'package:adguard_home_manager/functions/number_format.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    final serversProvider = Provider.of<ServersProvider>(context, listen: false);
    if (serversProvider.selectedServer == null || serversProvider.apiClient2 == null) {
      return;
    }

    final statusProvider = Provider.of<StatusProvider>(context, listen: false);
    statusProvider.getServerStatus(
      withLoadingIndicator: statusProvider.serverStatus != null ? false : true,
    );

    final clientsProvider = Provider.of<ClientsProvider>(context, listen: false);
    clientsProvider.fetchClients(updateLoading: false);
  }

  @override
  Widget build(BuildContext context) {
    final serversProvider = Provider.of<ServersProvider>(context);
    final statusProvider = Provider.of<StatusProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);
    final logsProvider = Provider.of<LogsProvider>(context);

    final width = MediaQuery.of(context).size.width;

    if (serversProvider.selectedServer == null || serversProvider.apiClient2 == null) {
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        top: false,
        child: NestedScrollView(
          controller: scrollController,
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: HomeAppBar(innerBoxScrolled: innerBoxIsScrolled),
            )
          ],
          body: SafeArea(
            top: false,
            bottom: false,
            child: Builder(
              builder: (context) => RefreshIndicator(
                color: Theme.of(context).colorScheme.primary,
                displacement: 110,
                onRefresh: () async {
                  await statusProvider.getServerStatus();
                },
                child: CustomScrollView(
                  slivers: [
                    SliverOverlapInjector(
                      handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                    ),
                    if (statusProvider.loadStatus == LoadStatus.loading)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 30),
                              Text(
                                AppLocalizations.of(context)!.loadingStatus,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 22,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (statusProvider.loadStatus == LoadStatus.loaded)
                      SliverList.list(
                        children: [
                          const ProtectionSwitch(),
                          if (appConfigProvider.combinedChartHome == false)
                            Wrap(
                              children: [
                                FractionallySizedBox(
                                  widthFactor: width > 700 ? 0.5 : 1,
                                  child: HomeChart(
                                    data: statusProvider.serverStatus!.stats.dnsQueries,
                                    label: AppLocalizations.of(context)!.dnsQueries,
                                    primaryValue: intFormat(
                                      statusProvider.serverStatus!.stats.numDnsQueries,
                                      Localizations.localeOf(context).toString(),
                                    ),
                                    secondaryValue: "${doubleFormat(statusProvider.serverStatus!.stats.avgProcessingTime * 1000, Localizations.localeOf(context).toString())} ms",
                                    color: Colors.blue,
                                    hoursInterval: statusProvider.serverStatus!.stats.timeUnits == "days" ? 24 : 1,
                                    onTapTitle: () {
                                      logsProvider.setSelectedResultStatus(
                                        value: "all",
                                        refetch: true,
                                      );
                                      logsProvider.filterLogs();
                                      appConfigProvider.setSelectedScreen(1);
                                    },
                                    isDesktop: width > 700,
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: width > 700 ? 0.5 : 1,
                                  child: HomeChart(
                                    data: statusProvider.serverStatus!.stats.blockedFiltering,
                                    label: AppLocalizations.of(context)!.blockedFilters,
                                    primaryValue: intFormat(
                                      statusProvider.serverStatus!.stats.numBlockedFiltering,
                                      Localizations.localeOf(context).toString(),
                                    ),
                                    secondaryValue: "${statusProvider.serverStatus!.stats.numDnsQueries > 0 ? doubleFormat((statusProvider.serverStatus!.stats.numBlockedFiltering / statusProvider.serverStatus!.stats.numDnsQueries) * 100, Localizations.localeOf(context).toString()) : 0}%",
                                    color: Colors.red,
                                    hoursInterval: statusProvider.serverStatus!.stats.timeUnits == "days" ? 24 : 1,
                                    onTapTitle: () {
                                      logsProvider.setSelectedResultStatus(
                                        value: "blocked",
                                        refetch: true,
                                      );
                                      appConfigProvider.setSelectedScreen(1);
                                    },
                                    isDesktop: width > 700,
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: width > 700 ? 0.5 : 1,
                                  child: HomeChart(
                                    data: statusProvider.serverStatus!.stats.replacedSafebrowsing,
                                    label: AppLocalizations.of(context)!.malwarePhishingBlocked,
                                    primaryValue: intFormat(
                                      statusProvider.serverStatus!.stats.numReplacedSafebrowsing,
                                      Localizations.localeOf(context).toString(),
                                    ),
                                    secondaryValue: "${statusProvider.serverStatus!.stats.numDnsQueries > 0 ? doubleFormat((statusProvider.serverStatus!.stats.numReplacedSafebrowsing / statusProvider.serverStatus!.stats.numDnsQueries) * 100, Localizations.localeOf(context).toString()) : 0}%",
                                    color: Colors.green,
                                    hoursInterval: statusProvider.serverStatus!.stats.timeUnits == "days" ? 24 : 1,
                                    onTapTitle: () {
                                      logsProvider.setSelectedResultStatus(
                                        value: "blocked_safebrowsing",
                                        refetch: true,
                                      );
                                      appConfigProvider.setSelectedScreen(1);
                                    },
                                    isDesktop: width > 700,
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: width > 700 ? 0.5 : 1,
                                  child: HomeChart(
                                    data: statusProvider.serverStatus!.stats.replacedParental,
                                    label: AppLocalizations.of(context)!.blockedAdultWebsites,
                                    primaryValue: intFormat(
                                      statusProvider.serverStatus!.stats.numReplacedParental,
                                      Localizations.localeOf(context).toString(),
                                    ),
                                    secondaryValue: "${statusProvider.serverStatus!.stats.numDnsQueries > 0 ? doubleFormat((statusProvider.serverStatus!.stats.numReplacedParental / statusProvider.serverStatus!.stats.numDnsQueries) * 100, Localizations.localeOf(context).toString()) : 0}%",
                                    color: Colors.orange,
                                    hoursInterval: statusProvider.serverStatus!.stats.timeUnits == "days" ? 24 : 1,
                                    onTapTitle: () {
                                      logsProvider.setSelectedResultStatus(
                                        value: "blocked_parental",
                                        refetch: true,
                                      );
                                      logsProvider.filterLogs();
                                      appConfigProvider.setSelectedScreen(1);
                                    },
                                    isDesktop: width > 700,
                                  ),
                                ),
                              ],
                            ),
                          if (appConfigProvider.combinedChartHome == true)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: CombinedHomeChart(),
                            ),
                          TopItemsLists(order: appConfigProvider.homeTopItemsOrder),
                          const SizedBox(height: 16),
                        ],
                      ),
                    if (statusProvider.loadStatus == LoadStatus.error)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error,
                                color: Colors.red,
                                size: 50,
                              ),
                              const SizedBox(height: 30),
                              Text(
                                AppLocalizations.of(context)!.errorLoadServerStatus,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 22,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
