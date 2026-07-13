import 'package:flutter/material.dart';

/// Tomera warm design system.
///
/// Dark: warm charcoal ("slate") surfaces with a single bright clay-orange
/// accent. Light: warm bone/paper surfaces built from the same hues.
/// Typography: Bricolage Grotesque for display/headings, Hanken Grotesk for
/// UI and body text, tabular numerals for money and timers.

const displayFontFamily = 'Bricolage Grotesque';
const bodyFontFamily = 'Hanken Grotesk';

/// Tabular figures for money, timers and anything that must align.
const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];

// ---------------------------------------------------------------------------
// Raw palette (from the redesign mock)
// ---------------------------------------------------------------------------

class _Dark {
  static const bg = Color(0xFF211E19); // slate background
  static const card = Color(0xFF2B2823); // raised surface
  static const ink = Color(0xFFF1EBE1); // primary text
  static const ink2 = Color(0xFFADA394); // secondary text
  // Tertiary text still meets WCAG AA against both the background and card.
  static const ink3 = Color(0xFF9D9283);
  static const clay = Color(0xFFEE7B3C); // accent orange
  static const clayD = Color(0xFFF4A870); // lighter orange (on tint)
  static const clayT = Color(0x29EE7B3C); // orange tint (16%)
  static const onClay = Color(0xFF241F18); // dark chocolate on orange
  static const hero = Color(0xFF16130F); // timer hero near-black
  static const overdue = Color(0xFFEE6A4E);
  static const success = Color(0xFF23A896);
  static const hairline = Color(0x14F1EBE1); // rgba(ink, .08)
  static const line = Color(0x24F1EBE1); // rgba(ink, .14)
}

class _Light {
  static const bg = Color(0xFFF5F0E6); // bone background
  static const card = Color(0xFFFFFDF8); // paper surface
  static const ink = Color(0xFF2B2620);
  static const ink2 = Color(0xFF6F6657);
  // 4.6:1 against the bone background; reserve lighter browns for borders.
  static const ink3 = Color(0xFF756B5C);
  static const clay = Color(0xFFD96A2B); // slightly deeper orange for light
  static const clayD = Color(0xFFB04E14); // darker orange (on tint)
  static const clayT = Color(0x26EE7B3C);
  static const onClay = Color(0xFFFFFDF8);
  static const hero = Color(0xFF221E18); // hero card stays dark in light mode
  static const overdue = Color(0xFFD24F33);
  static const success = Color(0xFF178878);
  static const hairline = Color(0x142B2620);
  static const line = Color(0x242B2620);
}

// ---------------------------------------------------------------------------
// Theme extension: tokens Material's ColorScheme has no slot for
// ---------------------------------------------------------------------------

@immutable
class TomeraTokens extends ThemeExtension<TomeraTokens> {
  const TomeraTokens({
    required this.heroBackground,
    required this.heroInk,
    required this.heroMutedInk,
    required this.tint,
    required this.onTint,
    required this.hairline,
    required this.line,
    required this.overdue,
    required this.success,
    required this.ink2,
    required this.ink3,
  });

  /// Near-black background of the timer hero / timer banner.
  final Color heroBackground;

  /// Primary text on [heroBackground].
  final Color heroInk;

  /// Muted text on [heroBackground].
  final Color heroMutedInk;

  /// Accent tint fill (selected chips, nav indicator).
  final Color tint;

  /// Foreground on [tint].
  final Color onTint;

  /// Faintest divider/border.
  final Color hairline;

  /// Slightly stronger border (pills, chips).
  final Color line;

  /// Overdue / destructive-adjacent red-orange.
  final Color overdue;

  /// Paid / done teal-green.
  final Color success;

  /// Secondary ink.
  final Color ink2;

  /// Tertiary ink.
  final Color ink3;

  static const dark = TomeraTokens(
    heroBackground: _Dark.hero,
    heroInk: _Dark.ink,
    heroMutedInk: Color(0xFFC9BCA6),
    tint: _Dark.clayT,
    onTint: _Dark.clayD,
    hairline: _Dark.hairline,
    line: _Dark.line,
    overdue: _Dark.overdue,
    success: _Dark.success,
    ink2: _Dark.ink2,
    ink3: _Dark.ink3,
  );

  static const light = TomeraTokens(
    heroBackground: _Light.hero,
    heroInk: _Dark.ink,
    heroMutedInk: Color(0xFFC9BCA6),
    tint: _Light.clayT,
    onTint: _Light.clayD,
    hairline: _Light.hairline,
    line: _Light.line,
    overdue: _Light.overdue,
    success: _Light.success,
    ink2: _Light.ink2,
    ink3: _Light.ink3,
  );

  @override
  TomeraTokens copyWith({
    Color? heroBackground,
    Color? heroInk,
    Color? heroMutedInk,
    Color? tint,
    Color? onTint,
    Color? hairline,
    Color? line,
    Color? overdue,
    Color? success,
    Color? ink2,
    Color? ink3,
  }) {
    return TomeraTokens(
      heroBackground: heroBackground ?? this.heroBackground,
      heroInk: heroInk ?? this.heroInk,
      heroMutedInk: heroMutedInk ?? this.heroMutedInk,
      tint: tint ?? this.tint,
      onTint: onTint ?? this.onTint,
      hairline: hairline ?? this.hairline,
      line: line ?? this.line,
      overdue: overdue ?? this.overdue,
      success: success ?? this.success,
      ink2: ink2 ?? this.ink2,
      ink3: ink3 ?? this.ink3,
    );
  }

  @override
  TomeraTokens lerp(TomeraTokens? other, double t) {
    if (other == null) return this;
    return TomeraTokens(
      heroBackground: Color.lerp(heroBackground, other.heroBackground, t)!,
      heroInk: Color.lerp(heroInk, other.heroInk, t)!,
      heroMutedInk: Color.lerp(heroMutedInk, other.heroMutedInk, t)!,
      tint: Color.lerp(tint, other.tint, t)!,
      onTint: Color.lerp(onTint, other.onTint, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      line: Color.lerp(line, other.line, t)!,
      overdue: Color.lerp(overdue, other.overdue, t)!,
      success: Color.lerp(success, other.success, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      ink3: Color.lerp(ink3, other.ink3, t)!,
    );
  }
}

/// Convenience accessor: `context.tokens`.
extension TomeraTokensX on BuildContext {
  TomeraTokens get tokens => Theme.of(this).extension<TomeraTokens>()!;
}

// ---------------------------------------------------------------------------
// Text theme
// ---------------------------------------------------------------------------

TextTheme _textTheme(Color ink, Color ink2) {
  const display = TextStyle(
    fontFamily: displayFontFamily,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );
  return TextTheme(
    displayLarge: display.copyWith(fontSize: 52, height: 1.02, color: ink),
    displayMedium: display.copyWith(fontSize: 40, height: 1.05, color: ink),
    displaySmall: display.copyWith(fontSize: 32, height: 1.1, color: ink),
    headlineLarge: display.copyWith(fontSize: 28, letterSpacing: -0.4, color: ink),
    headlineMedium: display.copyWith(fontSize: 26, letterSpacing: -0.4, color: ink),
    headlineSmall: display.copyWith(fontSize: 22, letterSpacing: -0.3, color: ink),
    titleLarge: display.copyWith(fontSize: 19, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: ink),
    titleMedium: TextStyle(
      fontFamily: bodyFontFamily,
      fontSize: 15.5,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.1,
      color: ink,
    ),
    titleSmall: TextStyle(
      fontFamily: bodyFontFamily,
      fontSize: 13.5,
      fontWeight: FontWeight.w700,
      color: ink,
    ),
    bodyLarge: TextStyle(fontFamily: bodyFontFamily, fontSize: 16, fontWeight: FontWeight.w500, color: ink),
    bodyMedium: TextStyle(fontFamily: bodyFontFamily, fontSize: 14, fontWeight: FontWeight.w500, color: ink),
    bodySmall: TextStyle(fontFamily: bodyFontFamily, fontSize: 12.5, fontWeight: FontWeight.w500, color: ink2),
    labelLarge: TextStyle(fontFamily: bodyFontFamily, fontSize: 14.5, fontWeight: FontWeight.w700, color: ink),
    labelMedium: TextStyle(fontFamily: bodyFontFamily, fontSize: 12, fontWeight: FontWeight.w600, color: ink2),
    labelSmall: TextStyle(
      fontFamily: bodyFontFamily,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
      color: ink2,
    ),
  );
}

// ---------------------------------------------------------------------------
// Theme builders
// ---------------------------------------------------------------------------

ThemeData buildDarkTheme() => _buildTheme(
      brightness: Brightness.dark,
      bg: _Dark.bg,
      card: _Dark.card,
      ink: _Dark.ink,
      ink2: _Dark.ink2,
      ink3: _Dark.ink3,
      clay: _Dark.clay,
      onClay: _Dark.onClay,
      clayT: _Dark.clayT,
      clayD: _Dark.clayD,
      overdue: _Dark.overdue,
      hairline: _Dark.hairline,
      line: _Dark.line,
      tokens: TomeraTokens.dark,
    );

ThemeData buildLightTheme() => _buildTheme(
      brightness: Brightness.light,
      bg: _Light.bg,
      card: _Light.card,
      ink: _Light.ink,
      ink2: _Light.ink2,
      ink3: _Light.ink3,
      clay: _Light.clay,
      onClay: _Light.onClay,
      clayT: _Light.clayT,
      clayD: _Light.clayD,
      overdue: _Light.overdue,
      hairline: _Light.hairline,
      line: _Light.line,
      tokens: TomeraTokens.light,
    );

ThemeData _buildTheme({
  required Brightness brightness,
  required Color bg,
  required Color card,
  required Color ink,
  required Color ink2,
  required Color ink3,
  required Color clay,
  required Color onClay,
  required Color clayT,
  required Color clayD,
  required Color overdue,
  required Color hairline,
  required Color line,
  required TomeraTokens tokens,
}) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: clay,
    onPrimary: onClay,
    primaryContainer: clayT,
    onPrimaryContainer: clayD,
    secondary: ink2,
    onSecondary: bg,
    secondaryContainer: card,
    onSecondaryContainer: ink,
    tertiary: tokens.success,
    onTertiary: isDark ? _Dark.onClay : Colors.white,
    tertiaryContainer: tokens.success.withValues(alpha: 0.16),
    onTertiaryContainer: tokens.success,
    error: overdue,
    onError: isDark ? _Dark.onClay : Colors.white,
    errorContainer: overdue.withValues(alpha: 0.16),
    onErrorContainer: overdue,
    surface: bg,
    onSurface: ink,
    onSurfaceVariant: ink2,
    surfaceContainerLowest: isDark ? _Dark.hero : Colors.white,
    surfaceContainerLow: isDark ? const Color(0xFF262320) : card,
    surfaceContainer: card,
    surfaceContainerHigh: isDark ? const Color(0xFF322E28) : const Color(0xFFF0EADD),
    surfaceContainerHighest: isDark ? const Color(0xFF3A362F) : const Color(0xFFEAE3D4),
    outline: line,
    outlineVariant: hairline,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: isDark ? _Light.bg : _Dark.bg,
    onInverseSurface: isDark ? _Light.ink : _Dark.ink,
    inversePrimary: clay,
    surfaceTint: Colors.transparent,
  );

  final textTheme = _textTheme(ink, ink2);

  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(18),
    side: BorderSide(color: hairline),
  );

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
      titleTextStyle: TextStyle(
        fontFamily: displayFontFamily,
        fontWeight: FontWeight.w700,
        fontSize: 24,
        letterSpacing: -0.4,
        color: ink,
      ),
      iconTheme: IconThemeData(color: ink, size: 23),
      actionsIconTheme: IconThemeData(color: ink, size: 23),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 74,
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: clayT,
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 23,
          color: states.contains(WidgetState.selected) ? clay : ink3,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: bodyFontFamily,
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w600,
          color: states.contains(WidgetState.selected) ? ink : ink3,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: cardShape,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: clay,
      foregroundColor: onClay,
      elevation: 4,
      highlightElevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      iconSize: 28,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: clay, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: overdue),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: overdue, width: 1.6),
      ),
      labelStyle: TextStyle(fontFamily: bodyFontFamily, fontWeight: FontWeight.w600, color: ink2),
      hintStyle: TextStyle(fontFamily: bodyFontFamily, fontWeight: FontWeight.w500, color: ink3),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? (isDark ? const Color(0xFF3A362F) : const Color(0xFFEAE3D4))
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? ink : ink2,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: line)),
        textStyle: WidgetStatePropertyAll(TextStyle(
          fontFamily: bodyFontFamily,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        )),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        visualDensity: VisualDensity.compact,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: card,
      selectedColor: clayT,
      checkmarkColor: clayD,
      side: BorderSide(color: line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
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
        color: clayD,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: clay,
        foregroundColor: onClay,
        textStyle: const TextStyle(
          fontFamily: bodyFontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: clay,
        textStyle: const TextStyle(
          fontFamily: bodyFontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        side: BorderSide(color: line),
        textStyle: const TextStyle(
          fontFamily: bodyFontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : (isDark ? ink2 : Colors.white),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? tokens.success
            : (isDark ? const Color(0x33F1EBE1) : const Color(0x33000000)),
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? clay : ink3,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? clay : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(onClay),
      side: BorderSide(color: ink3, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titleTextStyle: textTheme.headlineSmall,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: ink2),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      showDragHandle: true,
      dragHandleColor: ink3,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: hairline),
      ),
      textStyle: textTheme.bodyMedium,
    ),
    dividerTheme: DividerThemeData(color: hairline, thickness: 1, space: 1),
    listTileTheme: ListTileThemeData(
      iconColor: ink2,
      textColor: ink,
      titleTextStyle: textTheme.titleMedium,
      subtitleTextStyle: textTheme.bodySmall,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: tokens.heroBackground,
      contentTextStyle: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: tokens.heroInk,
      ),
      actionTextColor: clayD,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: textTheme.bodyLarge,
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(card),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      headerHeadlineStyle: textTheme.headlineSmall,
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: clay),
    iconTheme: IconThemeData(color: ink2),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: tokens.heroBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      textStyle: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: tokens.heroInk,
      ),
    ),
  );
}
