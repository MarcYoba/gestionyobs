import 'package:flutter/material.dart';
import 'package:gestionyobs/controller/app_scroll_behavior.dart';

import 'startup_page.dart';

void main() {
  runApp(const MonApp());
}

class MonApp extends StatelessWidget {
  const MonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestion Provenderie',
      debugShowCheckedModeBanner: false,
      // Barres de défilement visibles dans toutes les pages
      scrollBehavior: const AppScrollBehavior(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        // Une barre plus épaisse, plus facile à saisir à la souris
        scrollbarTheme: ScrollbarThemeData(
          thickness: WidgetStateProperty.all(10),
          radius: const Radius.circular(8),
          thumbColor: WidgetStateProperty.all(Colors.green.shade700),
        ),
      ),
      home: const StartupPage(),
    );
  }
}
