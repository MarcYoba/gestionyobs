import 'package:flutter/material.dart';

import 'config_service.dart';
import 'config_page.dart';

import 'package:gestionyobs/security/login_page.dart';

class StartupPage extends StatefulWidget {
  const StartupPage({super.key});

  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage> {
  @override
  void initState() {
    super.initState();
    _demarrer();
  }

  Future<void> _demarrer() async {
    // 1. Lire la configuration (null si absente ou abîmée)
    final config = await ConfigService.lire();

    if (!mounted) return;

    // 2. Choisir la page de destination
    final Widget destination = config == null
        ? const ConfigPage()
        : const LoginPage();

    // 3. Y aller en remplaçant la page de démarrage
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Démarrage...'),
          ],
        ),
      ),
    );
  }
}
