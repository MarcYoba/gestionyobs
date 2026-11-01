import 'package:flutter/material.dart';

import 'config_service.dart';
import 'config_page.dart';

import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/security/login_page.dart';
import 'package:gestionyobs/controller/premier_admin_page.dart';
import 'package:gestionyobs/service/backup_service.dart';
import 'package:gestionyobs/app/messages_app.dart';

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

  void _aller(Widget page) {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _demarrer() async {
    // 1. Lire la configuration
    final config = await ConfigService.lire();
    if (!mounted) return;

    // Pas de configuration : assistant
    if (config == null) {
      _aller(const ConfigPage());
      return;
    }

    try {
      // Copie de sécurité avant une éventuelle mise à jour de la base
      try {
        await BackupService.avantMigration(config);
      } catch (e) {
        MessagesApp.afficher(
          'Copie de sécurité avant mise à jour impossible : '
          '${e.toString().replaceFirst('Exception: ', '')}',
        );
      }
      // 2. Ouvrir la base de données
      await DatabaseService.ouvrir(config);

      // Les sauvegardes automatiques commencent dès que la base est ouverte
      BackupService.demarrerPlanification();

      // 3. Premier utilisateur à créer ?
      final aDesUtilisateurs = await DatabaseService.aDesUtilisateurs();
      if (!mounted) return;

      _aller(aDesUtilisateurs ? const LoginPage() : const PremierAdminPage());
    } catch (e) {
      // La base est introuvable ou illisible : retour à l'assistant
      // La base est introuvable ou illisible : retour à l'assistant
      if (!mounted) return;
      _aller(
        ConfigPage(
          messageErreur:
              "Impossible d'ouvrir la base de données : "
              "${e.toString().replaceFirst('Exception: ', '')}",
        ),
      );
    }
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
