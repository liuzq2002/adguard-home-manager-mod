import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/system_ui_overlay_style.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/config/app_screens.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';

class Layout extends StatelessWidget {
  const Layout({super.key});

  @override
  Widget build(BuildContext context) {
    final serversProvider = Provider.of<ServersProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);
    final l10n = AppLocalizations.of(context)!;

    final screens = serversProvider.selectedServer != null &&
            serversProvider.apiClient2 != null
        ? screensServerConnected
        : screensSelectServer;

    final currentIndex = appConfigProvider.selectedScreen < screens.length
        ? appConfigProvider.selectedScreen
        : 0;

    String translatedName(String key) {
      switch (key) {
        case 'home':
          return l10n.home;
        case 'settings':
          return l10n.settings;
        case 'logs':
          return l10n.logs;
        case 'filters':
          return l10n.filters;
        default:
          return '';
      }
    }

    return OverlayStyle(
      child: Scaffold(
        body: screens[currentIndex].child,
        bottomNavigationBar: MiuixNavigationBar(
          children: screens
              .asMap()
              .entries
              .map((screen) => MiuixNavigationBarItem(
                    selected: currentIndex == screen.key,
                    onPressed: () =>
                        appConfigProvider.setSelectedScreen(screen.key),
                    icon: Icon(screen.value.icon),
                    label: translatedName(screen.value.name),
                  ))
              .toList(growable: false),
        ),
      ),
    );
  }
}
