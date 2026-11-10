import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/constants/enums.dart';

class CustomTabContentList extends StatelessWidget {
  final Widget Function() loadingGenerator;
  final int itemsCount;
  final Widget Function(int index) contentWidget;
  final Widget noData;
  final Widget Function() errorGenerator;
  final LoadStatus loadStatus;
  final Future<void> Function() onRefresh;
  final double? refreshIndicatorOffset;
  final Widget? fab;
  final bool? fabVisible;
  final ValueListenable<bool>? fabVisibleListenable;
  final bool? noSliver;
  final EdgeInsets? listPadding;
  final double? heightFabHidden;
  final ScrollController? scrollController;
  final Widget? headerWidget;
  final double? itemExtent;

  const CustomTabContentList({
    super.key,
    required this.loadingGenerator,
    required this.itemsCount,
    required this.contentWidget,
    required this.noData,
    required this.errorGenerator,
    required this.loadStatus,
    required this.onRefresh,
    this.refreshIndicatorOffset,
    this.fab,
    this.fabVisible,
    this.fabVisibleListenable,
    this.noSliver,
    this.listPadding,
    this.heightFabHidden,
    this.scrollController,
    this.headerWidget,
    this.itemExtent,
  });

  Widget _buildFab({required bool isNestedSliver}) {
    if (fab == null) return const SizedBox.shrink();

    Widget buildPositioned(bool visible, bool showingSnackbar) {
      final double shownBottom = isNestedSliver
          ? (showingSnackbar ? 90 : 20)
          : (showingSnackbar ? 70 : 20);
      final double hiddenBottom =
          isNestedSliver ? (heightFabHidden ?? -90) : (heightFabHidden ?? -70);

      return AnimatedPositioned(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        bottom: visible ? shownBottom : hiddenBottom,
        right: 20,
        child: isNestedSliver ? SafeArea(child: fab!) : fab!,
      );
    }

    return Selector<AppConfigProvider, bool>(
      selector: (_, p) => p.showingSnackbar,
      builder: (context, showingSnackbar, _) {
        if (fabVisibleListenable != null) {
          return ValueListenableBuilder<bool>(
            valueListenable: fabVisibleListenable!,
            builder: (context, visible, _) =>
                buildPositioned(visible, showingSnackbar),
          );
        }
        return buildPositioned(fabVisible == true, showingSnackbar);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (loadStatus) {
      case LoadStatus.loading:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: loadingGenerator(),
        );

      case LoadStatus.loaded:
        if (noSliver == true) {
          if (itemsCount > 0) {
            return SafeArea(
              child: Stack(
                children: [
                  ListView.builder(
                    controller: scrollController,
                    padding: listPadding,
                    itemExtent: itemExtent,
                    itemCount: itemsCount,
                    addAutomaticKeepAlives: false,
                    itemBuilder: (context, index) => contentWidget(index),
                  ),
                  _buildFab(isNestedSliver: false),
                ],
              ),
            );
          } else {
            return SafeArea(
              child: Stack(
                children: [
                  noData,
                  _buildFab(isNestedSliver: false),
                ],
              ),
            );
          }
        } else {
          final delegate = SliverChildBuilderDelegate(
            (context, index) => contentWidget(index),
            childCount: itemsCount,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
          );

          return Stack(
            children: [
              SafeArea(
                top: false,
                bottom: false,
                child: RefreshIndicator(
                  onRefresh: onRefresh,
                  edgeOffset: refreshIndicatorOffset ?? 0,
                  child: CustomScrollView(
                    controller: scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: <Widget>[
                      if (headerWidget != null)
                        SliverToBoxAdapter(
                          child: headerWidget!,
                        ),
                      if (itemsCount > 0)
                        itemExtent != null
                            ? SliverFixedExtentList(
                                itemExtent: itemExtent!,
                                delegate: delegate,
                              )
                            : SliverList(
                                delegate: delegate,
                              ),
                      if (itemsCount == 0)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: noData,
                        ),
                    ],
                  ),
                ),
              ),
              _buildFab(isNestedSliver: true),
            ],
          );
        }

      case LoadStatus.error:
        return Padding(
          padding: const EdgeInsets.only(
            top: 32,
            left: 16,
            right: 16,
          ),
          child: errorGenerator(),
        );
    }
  }
}
