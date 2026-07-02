import 'package:flutter/material.dart';

/// Clean, minimalist Material 3 defaults with a restrained accent (spec §6.7).
const _seed = Color(0xFF00696B);

ThemeData buildLightTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _seed),
    );

ThemeData buildDarkTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: Brightness.dark,
      ),
    );
