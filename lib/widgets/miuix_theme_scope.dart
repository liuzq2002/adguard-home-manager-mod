import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

/// 在应用根部提供 MIUIX（HyperOS 风格）主题。
///
/// MIUIX 的配色需要通过 HCT / Monet 算法生成，开销不适合放在每次 build 里，
/// 所以这里只在种子色变化时重新生成，其余重建直接复用缓存。
/// [builder] 会拿到生成好的浅色 / 深色配色，用于同时构建 Material 主题。
class MiuixThemeScope extends StatefulWidget {
  const MiuixThemeScope({
    super.key,
    required this.lightSeed,
    required this.darkSeed,
    required this.brightness,
    required this.builder,
  });

  final Color lightSeed;
  final Color darkSeed;
  final Brightness brightness;
  final Widget Function(
    BuildContext context,
    MiuixColors light,
    MiuixColors dark,
  ) builder;

  @override
  State<MiuixThemeScope> createState() => _MiuixThemeScopeState();
}

class _MiuixThemeScopeState extends State<MiuixThemeScope> {
  late MiuixColors _lightColors;
  late MiuixColors _darkColors;

  static MiuixColors _generateColors(Color seed, {required bool dark}) {
    return miuixColorsFromSeed(seed: seed, dark: dark);
  }

  @override
  void initState() {
    super.initState();
    _lightColors = _generateColors(widget.lightSeed, dark: false);
    _darkColors = _generateColors(widget.darkSeed, dark: true);
  }

  @override
  void didUpdateWidget(MiuixThemeScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lightSeed != widget.lightSeed) {
      _lightColors = _generateColors(widget.lightSeed, dark: false);
    }
    if (oldWidget.darkSeed != widget.darkSeed) {
      _darkColors = _generateColors(widget.darkSeed, dark: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MiuixTheme(
      data: MiuixThemeData.of(
        widget.brightness,
        lightColors: _lightColors,
        darkColors: _darkColors,
        fontWeightAdjustment: MediaQuery.boldTextOf(context) ? 100 : 0,
      ),
      child: Builder(
        builder: (context) =>
            widget.builder(context, _lightColors, _darkColors),
      ),
    );
  }
}
