import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/layout.dart';
import 'package:adguard_home_manager/widgets/miuix_theme_scope.dart';

import 'package:adguard_home_manager/providers/logs_provider.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/dns_provider.dart';
import 'package:adguard_home_manager/providers/filtering_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/constants/colors.dart';
import 'package:adguard_home_manager/config/globals.dart';
import 'package:adguard_home_manager/config/theme.dart';
import 'package:adguard_home_manager/services/module_config_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final sharedPreferences = await SharedPreferences.getInstance();

  final AppConfigProvider appConfigProvider =
      AppConfigProvider(sharedPreferencesInstance: sharedPreferences);
  final ServersProvider serversProvider = ServersProvider();
  final StatusProvider statusProvider = StatusProvider();
  final FilteringProvider filtersProvider = FilteringProvider();
  final DnsProvider dnsProvider = DnsProvider();
  final LogsProvider logsProvider = LogsProvider();
  final ModuleConfigService moduleConfigService = ModuleConfigService();

  appConfigProvider.saveFromSharedPreferences();
  unawaited(appConfigProvider.syncLanguageWithSystem());

  if (Platform.isAndroid) {
    final cachedAddr = appConfigProvider.moduleHttpAddress;
    if (cachedAddr.isNotEmpty) {
      await serversProvider.autoConnectModule(cachedAddr);
      unawaited(
        moduleConfigService.readHttpAddress().then((yamlAddress) async {
          if (yamlAddress != null &&
              yamlAddress.isNotEmpty &&
              yamlAddress != cachedAddr) {
            appConfigProvider.setModuleHttpAddress(yamlAddress);
            await serversProvider.autoConnectModule(yamlAddress);
            await statusProvider.getServerStatus(withLoadingIndicator: false);
          }
        }),
      );
    } else {
      final yamlAddress = await moduleConfigService.readHttpAddress();
      if (yamlAddress != null && yamlAddress.isNotEmpty) {
        appConfigProvider.setModuleHttpAddress(yamlAddress);
        await serversProvider.autoConnectModule(yamlAddress);
      } else {
        await serversProvider.autoConnectModule('127.0.0.1:3000');
      }
    }
  }

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: ((context) => serversProvider)),
      ChangeNotifierProvider(create: ((context) => appConfigProvider)),
      ChangeNotifierProxyProvider<ServersProvider, StatusProvider>(
        create: (context) => statusProvider,
        update: (context, servers, status) => status!..update(servers),
      ),
      ChangeNotifierProxyProvider2<ServersProvider, StatusProvider,
          FilteringProvider>(
        create: (context) => filtersProvider,
        update: (context, servers, status, filtering) =>
            filtering!..update(servers, status),
      ),
      ChangeNotifierProxyProvider<ServersProvider, LogsProvider>(
        create: (context) => logsProvider,
        update: (context, servers, logs) => logs!..update(servers),
      ),
      ChangeNotifierProxyProvider<ServersProvider, DnsProvider>(
        create: (context) => dnsProvider,
        update: (context, servers, dns) => dns!..update(servers),
      ),
    ],
    child: const Main(),
  ));
}

class Main extends StatelessWidget {
  const Main({super.key});

  @override
  Widget build(BuildContext context) {
    final appConfigProvider = Provider.of<AppConfigProvider>(context);
    final themeMode = appConfigProvider.selectedTheme;
    final brightness = switch (themeMode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => MediaQuery.platformBrightnessOf(context),
    };
    final seedColor = colors[0];

    return MiuixThemeScope(
      lightSeed: seedColor,
      darkSeed: seedColor,
      brightness: brightness,
      builder: (context, lightColors, darkColors) => MaterialApp(
        title: 'AdGuard Home Manager',
        theme: miuixThemeData(lightColors, Brightness.light),
        darkTheme: miuixThemeData(darkColors, Brightness.dark),
        themeMode: themeMode,
        locale: appConfigProvider.selectedLocale,
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en', ''),
          Locale('zh', ''),
        ],
        scaffoldMessengerKey: scaffoldMessengerKey,
        navigatorKey: globalNavigatorKey,
        home: const Layout(),
      ),
    );
  }
}
