import 'package:flutter/material.dart';

/// Tomera's light-first editorial design system.
///
/// The interface is intentionally monochrome. Workspace and semantic colors
/// remain available where color communicates identity or state.
const displayFontFamily = 'Hanken Grotesk';
const bodyFontFamily = 'Hanken Grotesk';

/// Shared geometry keeps cards and controls consistent across feature modules.
const editorialPagePadding = EdgeInsets.symmetric(horizontal: 20);
const editorialCardRadius = 20.0;
const editorialFeaturedRadius = 24.0;
const editorialControlRadius = 16.0;

/// Tabular figures for money, timers and anything that must align.
const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];

class _Dark {
  static const bg = Color(0xFF101111);
  static const surface = Color(0xFF191B1B);
  static const surfaceLow = Color(0xFF151616);
  static const surfaceHigh = Color(0xFF222424);
  static const surfaceHighest = Color(0xFF2B2E2D);
  static const ink = Color(0xFFF5F5F3);
  static const ink2 = Color(0xFFB3B7B3);
  static const ink3 = Color(0xFF858B87);
  static const primary = Color(0xFFF5F5F3);
  static const onPrimary = Color(0xFF141515);
  static const primaryContainer = Color(0xFF2B2E2D);
  static const onPrimaryContainer = Color(0xFFF5F5F3);
  static const danger = Color(0xFFE2938E);
  static const warning = Color(0xFFC5A56D);
  static const success = Color(0xFF8DB39A);
  static const hairline = Color(0xFF292C2B);
  static const line = Color(0xFF383C3A);
  static const dock = Color(0xFFF1F1EF);
  static const dockForeground = Color(0xFF656A67);
  static const dockSelected = Color(0xFF171918);
  static const onDockSelected = Color(0xFFFFFFFF);
}

class _Light {
  static const bg = Color(0xFFF5F5F3);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceLow = Color(0xFFF1F2EF);
  static const surfaceHigh = Color(0xFFEBEEEA);
  static const surfaceHighest = Color(0xFFE3E6E2);
  static const ink = Color(0xFF141515);
  static const ink2 = Color(0xFF5F6561);
  static const ink3 = Color(0xFF858B87);
  static const primary = Color(0xFF141515);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFE9EBE8);
  static const onPrimaryContainer = Color(0xFF141515);
  static const danger = Color(0xFFA94E49);
  static const warning = Color(0xFF82652F);
  static const success = Color(0xFF47775A);
  static const hairline = Color(0xFFE7E9E6);
  static const line = Color(0xFFDADDD9);
  static const dock = Color(0xFF171918);
  static const dockForeground = Color(0xFFAEB3AF);
  static const dockSelected = Color(0xFFFFFFFF);
  static const onDockSelected = Color(0xFF141515);
}

@immutable
class TomeraTokens extends ThemeExtension<TomeraTokens> {
  const TomeraTokens({
    required this.accentSubtle,
    required this.onAccentSubtle,
    required this.borderSubtle,
    required this.borderStrong,
    required this.danger,
    required this.warning,
    required this.success,
    required this.textSecondary,
    required this.textTertiary,
    required this.featuredSurface,
    required this.dockBackground,
    required this.dockForeground,
    required this.dockSelected,
    required this.onDockSelected,
  });

  final Color accentSubtle;
  final Color onAccentSubtle;
  final Color borderSubtle;
  final Color borderStrong;
  final Color danger;
  final Color warning;
  final Color success;
  final Color textSecondary;
  final Color textTertiary;
  final Color featuredSurface;
  final Color dockBackground;
  final Color dockForeground;
  final Color dockSelected;
  final Color onDockSelected;

  static const dark = TomeraTokens(
    accentSubtle: _Dark.primaryContainer,
    onAccentSubtle: _Dark.onPrimaryContainer,
    borderSubtle: _Dark.hairline,
    borderStrong: _Dark.line,
    danger: _Dark.danger,
    warning: _Dark.warning,
    success: _Dark.success,
    textSecondary: _Dark.ink2,
    textTertiary: _Dark.ink3,
    featuredSurface: _Dark.surfaceHigh,
    dockBackground: _Dark.dock,
    dockForeground: _Dark.dockForeground,
    dockSelected: _Dark.dockSelected,
    onDockSelected: _Dark.onDockSelected,
  );

  static const light = TomeraTokens(
    accentSubtle: _Light.primaryContainer,
    onAccentSubtle: _Light.onPrimaryContainer,
    borderSubtle: _Light.hairline,
    borderStrong: _Light.line,
    danger: _Light.danger,
    warning: _Light.warning,
    success: _Light.success,
    textSecondary: _Light.ink2,
    textTertiary: _Light.ink3,
    featuredSurface: _Light.surface,
    dockBackground: _Light.dock,
    dockForeground: _Light.dockForeground,
    dockSelected: _Light.dockSelected,
    onDockSelected: _Light.onDockSelected,
  );

  @override
  TomeraTokens copyWith({
    Color? accentSubtle,
    Color? onAccentSubtle,
    Color? borderSubtle,
    Color? borderStrong,
    Color? danger,
    Color? warning,
    Color? success,
    Color? textSecondary,
    Color? textTertiary,
    Color? featuredSurface,
    Color? dockBackground,
    Color? dockForeground,
    Color? dockSelected,
    Color? onDockSelected,
  }) => TomeraTokens(
    accentSubtle: accentSubtle ?? this.accentSubtle,
    onAccentSubtle: onAccentSubtle ?? this.onAccentSubtle,
    borderSubtle: borderSubtle ?? this.borderSubtle,
    borderStrong: borderStrong ?? this.borderStrong,
    danger: danger ?? this.danger,
    warning: warning ?? this.warning,
    success: success ?? this.success,
    textSecondary: textSecondary ?? this.textSecondary,
    textTertiary: textTertiary ?? this.textTertiary,
    featuredSurface: featuredSurface ?? this.featuredSurface,
    dockBackground: dockBackground ?? this.dockBackground,
    dockForeground: dockForeground ?? this.dockForeground,
    dockSelected: dockSelected ?? this.dockSelected,
    onDockSelected: onDockSelected ?? this.onDockSelected,
  );

  @override
  TomeraTokens lerp(TomeraTokens? other, double t) {
    if (other == null) return this;
    return TomeraTokens(
      accentSubtle: Color.lerp(accentSubtle, other.accentSubtle, t)!,
      onAccentSubtle: Color.lerp(onAccentSubtle, other.onAccentSubtle, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      success: Color.lerp(success, other.success, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      featuredSurface: Color.lerp(featuredSurface, other.featuredSurface, t)!,
      dockBackground: Color.lerp(dockBackground, other.dockBackground, t)!,
      dockForeground: Color.lerp(dockForeground, other.dockForeground, t)!,
      dockSelected: Color.lerp(dockSelected, other.dockSelected, t)!,
      onDockSelected: Color.lerp(onDockSelected, other.onDockSelected, t)!,
    );
  }
}

extension TomeraTokensX on BuildContext {
  TomeraTokens get tokens => Theme.of(this).extension<TomeraTokens>()!;
}

/// The restrained shadow used only for featured or floating surfaces.
List<BoxShadow> editorialShadow(BuildContext context, {bool strong = false}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return [
    BoxShadow(
      color: Colors.black.withValues(
        alpha: dark ? (strong ? 0.34 : 0.24) : (strong ? 0.12 : 0.07),
      ),
      blurRadius: strong ? 28 : 20,
      offset: Offset(0, strong ? 12 : 8),
    ),
  ];
}

TextTheme _textTheme(Color ink, Color ink2) {
  const display = TextStyle(
    fontFamily: displayFontFamily,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.55,
  );
  return TextTheme(
    displayLarge: display.copyWith(fontSize: 46, height: 1.02, color: ink),
    displayMedium: display.copyWith(fontSize: 38, height: 1.04, color: ink),
    displaySmall: display.copyWith(fontSize: 30, height: 1.08, color: ink),
    headlineLarge: display.copyWith(fontSize: 28, color: ink),
    headlineMedium: display.copyWith(fontSize: 24, color: ink),
    headlineSmall: display.copyWith(fontSize: 20, color: ink),
    titleLarge: display.copyWith(
      fontSize: 18,
      letterSpacing: -0.25,
      color: ink,
    ),
    titleMedium: TextStyle(
      fontFamily: bodyFontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: ink,
    ),
    titleSmall: TextStyle(
      fontFamily: bodyFontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: ink,
    ),
    bodyLarge: TextStyle(
      fontFamily: bodyFontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: ink,
    ),
    bodyMedium: TextStyle(
      fontFamily: bodyFontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: ink,
    ),
    bodySmall: TextStyle(
      fontFamily: bodyFontFamily,
      fontSize: 12.5,
      fontWeight: FontWeight.w400,
      color: ink2,
    ),
    labelLarge: TextStyle(
      fontFamily: bodyFontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: ink,
    ),
    labelMedium: TextStyle(
      fontFamily: bodyFontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: ink2,
    ),
    labelSmall: TextStyle(
      fontFamily: bodyFontFamily,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      color: ink2,
    ),
  );
}

ThemeData buildDarkTheme() => _buildTheme(
  brightness: Brightness.dark,
  bg: _Dark.bg,
  surface: _Dark.surface,
  surfaceLow: _Dark.surfaceLow,
  surfaceHigh: _Dark.surfaceHigh,
  surfaceHighest: _Dark.surfaceHighest,
  ink: _Dark.ink,
  ink2: _Dark.ink2,
  ink3: _Dark.ink3,
  primary: _Dark.primary,
  onPrimary: _Dark.onPrimary,
  primaryContainer: _Dark.primaryContainer,
  onPrimaryContainer: _Dark.onPrimaryContainer,
  danger: _Dark.danger,
  hairline: _Dark.hairline,
  line: _Dark.line,
  tokens: TomeraTokens.dark,
);

ThemeData buildLightTheme() => _buildTheme(
  brightness: Brightness.light,
  bg: _Light.bg,
  surface: _Light.surface,
  surfaceLow: _Light.surfaceLow,
  surfaceHigh: _Light.surfaceHigh,
  surfaceHighest: _Light.surfaceHighest,
  ink: _Light.ink,
  ink2: _Light.ink2,
  ink3: _Light.ink3,
  primary: _Light.primary,
  onPrimary: _Light.onPrimary,
  primaryContainer: _Light.primaryContainer,
  onPrimaryContainer: _Light.onPrimaryContainer,
  danger: _Light.danger,
  hairline: _Light.hairline,
  line: _Light.line,
  tokens: TomeraTokens.light,
);

ThemeData _buildTheme({
  required Brightness brightness,
  required Color bg,
  required Color surface,
  required Color surfaceLow,
  required Color surfaceHigh,
  required Color surfaceHighest,
  required Color ink,
  required Color ink2,
  required Color ink3,
  required Color primary,
  required Color onPrimary,
  required Color primaryContainer,
  required Color onPrimaryContainer,
  required Color danger,
  required Color hairline,
  required Color line,
  required TomeraTokens tokens,
}) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primaryContainer,
    onPrimaryContainer: onPrimaryContainer,
    secondary: ink2,
    onSecondary: bg,
    secondaryContainer: surfaceHigh,
    onSecondaryContainer: ink,
    tertiary: tokens.success,
    onTertiary: isDark ? _Dark.onPrimary : Colors.white,
    tertiaryContainer: tokens.success.withValues(alpha: 0.14),
    onTertiaryContainer: tokens.success,
    error: danger,
    onError: isDark ? _Dark.onPrimary : Colors.white,
    errorContainer: danger.withValues(alpha: 0.14),
    onErrorContainer: danger,
    surface: bg,
    onSurface: ink,
    onSurfaceVariant: ink2,
    surfaceContainerLowest: bg,
    surfaceContainerLow: surfaceLow,
    surfaceContainer: surface,
    surfaceContainerHigh: surfaceHigh,
    surfaceContainerHighest: surfaceHighest,
    outline: line,
    outlineVariant: hairline,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: isDark ? _Light.primary : _Dark.primary,
    onInverseSurface: isDark ? _Light.onPrimary : _Dark.onPrimary,
    inversePrimary: onPrimary,
    surfaceTint: Colors.transparent,
  );
  final textTheme = _textTheme(ink, ink2);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    fontFamily: bodyFontFamily,
    textTheme: textTheme,
    scaffoldBackgroundColor: bg,
    canvasColor: bg,
    splashFactory: InkSparkle.splashFactory,
    dividerColor: hairline,
    extensions: [tokens],
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 68,
      titleSpacing: 20,
      titleTextStyle: TextStyle(
        fontFamily: displayFontFamily,
        fontWeight: FontWeight.w700,
        fontSize: 28,
        letterSpacing: -0.55,
        color: ink,
      ),
      iconTheme: IconThemeData(color: ink, size: 22),
      actionsIconTheme: IconThemeData(color: ink, size: 22),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: tokens.dockSelected,
      indicatorShape: const CircleBorder(),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 23,
          color: states.contains(WidgetState.selected)
              ? tokens.onDockSelected
              : tokens.dockForeground,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(editorialCardRadius),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: onPrimary,
      elevation: 8,
      focusElevation: 8,
      hoverElevation: 8,
      highlightElevation: 12,
      shape: const CircleBorder(),
      iconSize: 24,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(editorialControlRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(editorialControlRadius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(editorialControlRadius),
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(editorialControlRadius),
        borderSide: BorderSide(color: danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(editorialControlRadius),
        borderSide: BorderSide(color: danger, width: 1.5),
      ),
      labelStyle: TextStyle(
        fontFamily: bodyFontFamily,
        fontWeight: FontWeight.w600,
        color: ink2,
      ),
      hintStyle: TextStyle(
        fontFamily: bodyFontFamily,
        fontWeight: FontWeight.w400,
        color: ink3,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? primary : surfaceHigh,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? onPrimary : ink2,
        ),
        side: const WidgetStatePropertyAll(BorderSide.none),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontFamily: bodyFontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        ),
        visualDensity: VisualDensity.compact,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceHigh,
      selectedColor: primary,
      checkmarkColor: onPrimary,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: ink2,
      ),
      secondaryLabelStyle: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: onPrimary,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        backgroundColor: primary,
        foregroundColor: onPrimary,
        textStyle: const TextStyle(
          fontFamily: bodyFontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        elevation: 0,
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ink,
        textStyle: const TextStyle(
          fontFamily: bodyFontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
        ),
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        minimumSize: const Size(48, 50),
        side: BorderSide(color: line),
        textStyle: const TextStyle(
          fontFamily: bodyFontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        shape: const StadiumBorder(),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? onPrimary
            : (isDark ? ink2 : Colors.white),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? primary : surfaceHighest,
      ),
      trackOutlineColor: WidgetStatePropertyAll(line),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? primary : ink3,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? primary
            : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(onPrimary),
      side: BorderSide(color: ink3, width: 1.8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 16,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.4 : 0.14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(editorialFeaturedRadius),
      ),
      titleTextStyle: textTheme.headlineSmall,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: ink2),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: surface,
      elevation: 16,
      modalElevation: 16,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.4 : 0.14),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(editorialFeaturedRadius),
        ),
      ),
      showDragHandle: true,
      dragHandleColor: ink3,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      textStyle: textTheme.bodyMedium,
    ),
    dividerTheme: DividerThemeData(color: hairline, thickness: 1, space: 1),
    listTileTheme: ListTileThemeData(
      iconColor: ink2,
      textColor: ink,
      titleTextStyle: textTheme.titleMedium,
      subtitleTextStyle: textTheme.bodySmall,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(editorialControlRadius),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark ? _Light.primary : _Dark.surfaceHigh,
      contentTextStyle: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDark ? _Light.onPrimary : _Dark.ink,
      ),
      actionTextColor: isDark ? _Light.onPrimary : _Dark.ink2,
      behavior: SnackBarBehavior.floating,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: textTheme.bodyLarge,
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(8),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 16,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(editorialFeaturedRadius),
      ),
      headerHeadlineStyle: textTheme.headlineSmall,
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: surface,
      elevation: 16,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(editorialFeaturedRadius),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
    iconTheme: IconThemeData(color: ink2),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: isDark ? surfaceHighest : _Dark.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isDark ? ink : _Dark.ink,
      ),
    ),
  );
}
