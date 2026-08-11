
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/screens/settings/logs_settings/logs_settings.dart';
import 'package:adguard_home_manager/screens/settings/statistics_settings/statistics_settings.dart';
import 'package:adguard_home_manager/screens/settings/customization/customization.dart';
import 'package:adguard_home_manager/screens/settings/dns/dns.dart';
import 'package:adguard_home_manager/screens/settings/dns_rewrites/dns_rewrites.dart';

import 'package:adguard_home_manager/widgets/custom_settings_tile.dart';
import 'package:adguard_home_manager/widgets/section_label.dart';
import 'package:adguard_home_manager/widgets/custom_list_tile.dart';

import 'package:adguard_home_manager/functions/desktop_mode.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/services/module_config_service.dart';

final settingsNavigatorKey = GlobalKey<NavigatorState>();

class Settings extends StatelessWidget {
  const Settings({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return Row(
            children: [
              const Expanded(
                flex: 1,
                child: _SettingsWidget(
                  twoColumns: true,
                )
              ),
              Expanded(
                flex: 2,
                child: Navigator(
                  key: settingsNavigatorKey,
                  onGenerateRoute: (settings) => MaterialPageRoute(builder: (ctx) => const SizedBox()),
                ),
              )
            ],
          );
        }
        else {
          return const _SettingsWidget(
            twoColumns: false,
          );
        }
      },
    );
  }
}

class _SettingsWidget extends StatefulWidget {
  final bool twoColumns;

  const _SettingsWidget({
    required this.twoColumns,
  });

  @override
  State<_SettingsWidget> createState() => _SettingsWidgetState();
}

class _SettingsWidgetState extends State<_SettingsWidget> {
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final _proxyUrlController = TextEditingController();

  bool _proxyUrlLoading = true;
  bool _proxyUrlSaving = false;

  @override
  void initState() {
    Provider.of<AppConfigProvider>(context, listen: false).setSelectedSettingsScreen(screen: null);
    super.initState();
    _loadProxyUrl();
  }

  @override
  void dispose() {
    _proxyUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadProxyUrl() async {
    final moduleConfigService = ModuleConfigService();
    final url = await moduleConfigService.readProxyUrl();
    if (!mounted) return;
    setState(() {
      _proxyUrlController.text = url;
      _proxyUrlLoading = false;
    });
  }

  Future<void> _saveProxyUrl() async {
    final appConfigProvider = Provider.of<AppConfigProvider>(context, listen: false);
    final value = _proxyUrlController.text.trim();
    setState(() => _proxyUrlSaving = true);
    final ok = await ModuleConfigService().saveProxyUrl(value);
    if (!mounted) return;
    setState(() => _proxyUrlSaving = false);
    showSnackbar(
      appConfigProvider: appConfigProvider,
      label: ok ? '订阅链接已保存，重启设备后生效' : '保存失败，请检查 Root 权限',
      color: ok ? Colors.green : Colors.red,
    );
  }

  void _showTileHelp() {
    final appConfigProvider = Provider.of<AppConfigProvider>(context, listen: false);
    showSnackbar(
      appConfigProvider: appConfigProvider,
      label: '请下拉通知栏 → 点击编辑（铅笔图标）→ 将“AdGuard 开关”拖入快捷设置',
      color: Colors.blueGrey,
    );
  }

  @override
  Widget build(BuildContext context) {
    final serversProvider = Provider.of<ServersProvider>(context);
    final statusProvider = Provider.of<StatusProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    final width = MediaQuery.of(context).size.width;

    if (!widget.twoColumns && appConfigProvider.selectedSettingsScreen != null) {
      appConfigProvider.setSelectedSettingsScreen(screen: null);
    }

    return ScaffoldMessenger(
      key: widget.twoColumns ? _scaffoldMessengerKey : null,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: SliverAppBar.large(
                pinned: true,
                floating: true,
                centerTitle: false,
                forceElevated: innerBoxIsScrolled,
                surfaceTintColor: isDesktop(width) ? Colors.transparent : null,
                title: Text(AppLocalizations.of(context)!.settings),
              )
            )
          ],
          body: SafeArea(
            top: false,
            bottom: false,
            child: Builder(
              builder: (context) => CustomScrollView(
                slivers: [
                  SliverOverlapInjector(
                    handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                  ),
                  SliverList.list(
                    children: [
                      SectionLabel(label: '模块设置'),
                      CustomListTile(
                        icon: Icons.router_rounded,
                        title: '模块管理地址',
                        subtitle: appConfigProvider.moduleHttpAddress.isNotEmpty
                          ? 'http://${appConfigProvider.moduleHttpAddress}'
                          : '未检测到模块',
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: TextField(
                          controller: _proxyUrlController,
                          enabled: !_proxyUrlSaving,
                          decoration: InputDecoration(
                            labelText: 'PROXY_URL 订阅链接',
                            hintText: 'https://example.com/subscribe',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: _proxyUrlSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.save_rounded),
                              tooltip: '保存',
                              onPressed: _proxyUrlSaving ? null : _saveProxyUrl,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                        child: Text(
                          _proxyUrlLoading
                            ? '正在读取当前配置…'
                            : '保存后需重启设备或模块后生效',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      CustomListTile(
                        icon: Icons.toggle_on_rounded,
                        title: '通知栏快捷开关',
                        subtitle: '在快捷设置中添加 AdGuard Home 开关（点击查看添加方法）',
                        onTap: _showTileHelp,
                        trailing: const Icon(Icons.chevron_right_rounded),
                      ),
                      if (
                        serversProvider.selectedServer != null &&
                        statusProvider.serverStatus != null &&
                        serversProvider.apiClient2 != null
                      ) ...[
                        SectionLabel(label: AppLocalizations.of(context)!.serverSettings),
                        _SettingsTile(
                          icon: Icons.list_alt_rounded,
                          title: AppLocalizations.of(context)!.logsSettings,
                          subtitle: AppLocalizations.of(context)!.logsSettingsDescription,
                          thisItem: 0,
                          screenToNavigate: const LogsSettings(),
                          twoColumns: widget.twoColumns,
                        ),
                        _SettingsTile(
                          icon: Icons.analytics_rounded,
                          title: AppLocalizations.of(context)!.statisticsSettings,
                          subtitle: AppLocalizations.of(context)!.statisticsSettingsDescription,
                          thisItem: 1,
                          screenToNavigate: const StatisticsSettings(),
                          twoColumns: widget.twoColumns,
                        ),
                        _SettingsTile(
                          icon: Icons.dns_rounded,
                          title: AppLocalizations.of(context)!.dnsSettings,
                          subtitle: AppLocalizations.of(context)!.dnsSettingsDescription,
                          thisItem: 2,
                          screenToNavigate: DnsSettings(
                            splitView: widget.twoColumns,
                          ),
                          twoColumns: widget.twoColumns,
                        ),
                        _SettingsTile(
                          icon: Icons.route_rounded,
                          title: AppLocalizations.of(context)!.dnsRewrites,
                          subtitle: AppLocalizations.of(context)!.dnsRewritesDescription,
                          thisItem: 3,
                          screenToNavigate: const DnsRewritesScreen(),
                          twoColumns: widget.twoColumns,
                        ),
                      ],
                      SectionLabel(label: AppLocalizations.of(context)!.appSettings),
                      _SettingsTile(
                        icon: Icons.palette_rounded,
                        title: AppLocalizations.of(context)!.customization,
                        subtitle: AppLocalizations.of(context)!.customizationDescription,
                        thisItem: 4,
                        screenToNavigate: const Customization(),
                        twoColumns: widget.twoColumns,
                      ),
                      SectionLabel(label: AppLocalizations.of(context)!.aboutApp),
                      CustomListTile(
                        title: AppLocalizations.of(context)!.appVersion,
                        subtitle: appConfigProvider.getAppInfo!.version,
                      ),
                      const SizedBox(height: 16)
                    ],
                  )
                ],
              )
            ),
          ),
        )
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget screenToNavigate;
  final int thisItem;
  final bool twoColumns;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.screenToNavigate,
    required this.thisItem,
    required this.twoColumns
  });

  @override
  Widget build(BuildContext context) {
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    if (twoColumns) {
      return CustomSettingsTile(
        title: title,
        subtitle: subtitle,
        icon: icon,
        thisItem: thisItem,
        selectedItem: appConfigProvider.selectedSettingsScreen,
        onTap: () {
          appConfigProvider.setSelectedSettingsScreen(screen: thisItem, notify: true);
          Navigator.of(settingsNavigatorKey.currentContext!).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation1, animation2) => screenToNavigate,
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        },
      );
    }
    else {
      return CustomListTile(
        title: title,
        subtitle: subtitle,
        icon: icon,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => screenToNavigate)
          );
        },
      );
    }
  }
}
