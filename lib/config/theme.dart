import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

/// 把 MIUIX 的配色映射为 Material 的 [ColorScheme]。
///
/// 这样应用里仍然使用 Material 组件的界面（AppBar、Dialog、Chip 等）也会
/// 跟随 MIUIX / Monet 的配色，而不只是 MIUIX 组件本身。
ColorScheme miuixColorScheme(MiuixColors colors, Brightness brightness) {
  return ColorScheme(
    brightness: brightness,
    primary: colors.primary,
    onPrimary: colors.onPrimary,
    primaryContainer: colors.primaryContainer,
    onPrimaryContainer: colors.onPrimaryContainer,
    secondary: colors.secondary,
    onSecondary: colors.onSecondary,
    secondaryContainer: colors.secondaryContainer,
    onSecondaryContainer: colors.onSecondaryContainer,
    tertiary: colors.tertiaryContainer,
    onTertiary: colors.onTertiaryContainer,
    tertiaryContainer: colors.tertiaryContainer,
    onTertiaryContainer: colors.onTertiaryContainer,
    error: colors.error,
    onError: colors.onError,
    errorContainer: colors.errorContainer,
    onErrorContainer: colors.onErrorContainer,
    surface: colors.surface,
    onSurface: colors.onSurface,
    surfaceContainerLowest: colors.background,
    surfaceContainerLow: colors.surfaceVariant,
    surfaceContainer: colors.surfaceContainer,
    surfaceContainerHigh: colors.surfaceContainerHigh,
    surfaceContainerHighest: colors.surfaceContainerHighest,
    onSurfaceVariant: colors.onSurfaceSecondary,
    outline: colors.outline,
    outlineVariant: colors.dividerLine,
    inverseSurface: colors.surfaceContainerHighest,
    onInverseSurface: colors.onSurfaceContainerHighest,
    inversePrimary: colors.primaryVariant,
    surfaceTint: Colors.transparent,
    shadow: Colors.black,
    scrim: Colors.black,
  );
}

/// 由 MIUIX 配色生成的 Material 主题。
///
/// HyperOS 观感的关键：平面化（无 elevation / surfaceTint）、更大的圆角、
/// 统一的 MIUI 配色，以及接近 MIUI 的开关 / 输入框 / 弹窗样式。
ThemeData miuixThemeData(MiuixColors colors, Brightness brightness) {
  final scheme = miuixColorScheme(colors, brightness);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.background,
    canvasColor: colors.background,
    appBarTheme: AppBarThemeData(
      backgroundColor: colors.background,
      foregroundColor: colors.onBackground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: colors.onBackground),
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: colors.onBackground,
      ),
    ),
    cardTheme: CardThemeData(
      color: colors.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: colors.onSurface,
      ),
      contentTextStyle: TextStyle(
        fontSize: 15,
        height: 1.4,
        color: colors.onSurfaceSecondary,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surfaceContainerHigh,
      modalBackgroundColor: colors.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
      dragHandleColor: colors.dividerLine,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colors.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      textStyle: TextStyle(color: colors.onSurface, fontSize: 15),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: colors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.surface,
      indicatorColor: colors.primaryContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? colors.primary
              : colors.onSurfaceSecondary,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: colors.background,
      indicatorColor: colors.primaryContainer,
      selectedIconTheme: IconThemeData(color: colors.onPrimaryContainer),
      unselectedIconTheme: IconThemeData(color: colors.onSurfaceSecondary),
      selectedLabelTextStyle: TextStyle(
        color: colors.primary,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: colors.onSurfaceSecondary,
        fontSize: 13,
      ),
      useIndicator: true,
    ),
    listTileTheme: ListTileThemeData(
      tileColor: Colors.transparent,
      textColor: colors.onSurface,
      iconColor: colors.onSurfaceSecondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colors.surfaceContainerHigh,
      selectedColor: colors.primaryContainer,
      side: BorderSide.none,
      elevation: 0,
      pressElevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: TextStyle(color: colors.onSurface, fontSize: 14),
      secondaryLabelStyle: TextStyle(
        color: colors.onPrimaryContainer,
        fontSize: 14,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.primary
            : colors.secondaryVariant,
      ),
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.onPrimary
            : colors.onSecondaryVariant,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      trackOutlineWidth: const WidgetStatePropertyAll(0),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.primary
            : colors.surfaceContainerHighest,
      ),
      checkColor: WidgetStatePropertyAll(colors.onPrimary),
      side: BorderSide(color: colors.outline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.primary
            : colors.outline,
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: colors.primary,
      inactiveTrackColor: colors.sliderBackground,
      thumbColor: colors.primary,
      overlayColor: colors.primary.withValues(alpha: 0.12),
      trackHeight: 4,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.primary,
      linearTrackColor: colors.surfaceContainerHighest,
      circularTrackColor: colors.surfaceContainerHighest,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: colors.surfaceContainer,
      hintStyle: TextStyle(color: colors.disabledOnSurface, fontSize: 15),
      labelStyle: TextStyle(color: colors.onSurfaceSecondary, fontSize: 15),
      floatingLabelStyle:
          TextStyle(color: colors.onSurfaceSecondary, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.error, width: 1.6),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colors.surfaceContainerHighest,
      contentTextStyle: TextStyle(color: colors.onSurfaceContainerHighest),
      actionTextColor: colors.primary,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: DividerThemeData(
      color: colors.dividerLine,
      thickness: 0.6,
      space: 0.6,
    ),
  );
}
