import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/functions/desktop_mode.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';

class HomeAppBar extends StatelessWidget {
  final bool innerBoxScrolled;

  const HomeAppBar({
    super.key,
    required this.innerBoxScrolled
  });

  @override
  Widget build(BuildContext context) {
    final statusProvider = Provider.of<StatusProvider>(context);
    final width = MediaQuery.of(context).size.width;

    return SliverAppBar.large(
      pinned: true,
      floating: true,
      centerTitle: false,
      forceElevated: innerBoxScrolled,
      surfaceTintColor: isDesktop(width) ? Colors.transparent : null,
      leading: Stack(
        children: [
          Center(
            child: Icon(
              statusProvider.serverStatus != null
                ? statusProvider.serverStatus!.generalEnabled == true
                  ? Icons.gpp_good_rounded
                  : Icons.gpp_bad_rounded
                : Icons.shield,
              size: 30,
              color: statusProvider.serverStatus != null
                ? statusProvider.serverStatus!.generalEnabled == true
                  ? Colors.green
                  : Colors.red
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.38)
            ),
          ),
          if (statusProvider.remainingTime > 0) Positioned(
            bottom: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: Theme.of(context).colorScheme.surface
              ),
              child: Icon(
                Icons.timer_rounded,
                size: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        ],
      ),
      title: Text(
        AppLocalizations.of(context)!.home,
        style: const TextStyle(fontSize: 20),
      ),
      actions: [
        if (!(Platform.isAndroid || Platform.isIOS)) ...[
          IconButton(
            onPressed: () => statusProvider.getServerStatus(), 
            icon: const Icon(Icons.refresh_rounded),
            tooltip: AppLocalizations.of(context)!.refresh,
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }
}
