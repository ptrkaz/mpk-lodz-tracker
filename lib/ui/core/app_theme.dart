import 'package:flutter/material.dart';

ThemeData buildLightTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E86DE)),
      useMaterial3: true,
    );

ThemeData buildDarkTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2E86DE),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );
