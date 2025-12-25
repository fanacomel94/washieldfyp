import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_start_gate.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (_, themeProvider, __) {
        return MaterialApp(
          title: 'WAShield',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const AppStartGate(),
        );
      },
    );
  }
}
