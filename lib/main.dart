import 'dart:ui'; // <--- Ajoutez cet import pour AppExitResponse

import 'package:flutter/material.dart';
import 'package:gestionyobs/controller/app_scroll_behavior.dart';
import 'package:gestionyobs/service/backup_service.dart';
import 'package:gestionyobs/app/messages_app.dart';

import 'startup_page.dart';

void main() {
  runApp(const MonApp());
}

class MonApp extends StatefulWidget {
  const MonApp({super.key});

  @override
  State<MonApp> createState() => _MonAppState();
}

class _MonAppState extends State<MonApp> {
  late final AppLifecycleListener _ecouteur;

  @override
  void initState() {
    super.initState();
    // Quand on ferme la fenêtre : une sauvegarde si la dernière est ancienne
    _ecouteur = AppLifecycleListener(
      onExitRequested: () async {
        await BackupService.sauvegardeALaFermeture();
        return AppExitResponse.exit; // Désormais reconnu grâce à 'dart:ui'
      },
    );
  }

  @override
  void dispose() {
    _ecouteur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestion YOBS',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: MessagesApp.cle,
      scrollBehavior: const AppScrollBehavior(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
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
