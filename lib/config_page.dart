import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'config_service.dart';

//import 'config_test_page.dart';
import 'package:gestionyobs/security/login_page.dart';

class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  final _formKey = GlobalKey<FormState>();
  final _cheminBaseController = TextEditingController();
  final _sauvegardeController = TextEditingController();
  String _type = 'sqlite';
  bool _enregistrement = false;

  @override
  void initState() {
    super.initState();
    _chargerValeursParDefaut();
  }

  @override
  void dispose() {
    _cheminBaseController.dispose();
    _sauvegardeController.dispose();
    super.dispose();
  }

  // Propose des emplacements par défaut dans le dossier Documents
  Future<void> _chargerValeursParDefaut() async {
    final documents = await getApplicationDocumentsDirectory();
    final sep = Platform.pathSeparator;
    final racine = '${documents.path}${sep}Quincaillerie';
    if (!mounted) return;
    _cheminBaseController.text = '$racine${sep}donnees${sep}quincaillerie.db';
    _sauvegardeController.text = '$racine${sep}Sauvegardes';
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _enregistrement = true);

    await ConfigService.ecrire(
      AppConfig(
        type: _type,
        cheminBase: _cheminBaseController.text.trim(),
        dossierSauvegarde: _sauvegardeController.text.trim(),
      ),
    );

    if (!mounted) return;
    setState(() => _enregistrement = false);

    // // Pour l'instant, on affiche la page de test pour vérifier le fichier
    // Navigator.pushReplacement(
    //   context,
    //   MaterialPageRoute(builder: (_) => const ConfigTestPage()),
    // );

    // La configuration est enregistrée : on passe à la page de connexion
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 520,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Configuration de la base de données',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Cette configuration est demandée une seule fois, '
                        'au premier lancement du logiciel.',
                      ),
                      const SizedBox(height: 24),

                      // Type de base de données
                      DropdownButtonFormField<String>(
                        initialValue: _type,
                        decoration: const InputDecoration(
                          labelText: 'Type de base de données',
                          prefixIcon: Icon(Icons.storage),
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'sqlite',
                            child: Text('SQLite (un seul ordinateur)'),
                          ),
                          DropdownMenuItem(
                            value: 'serveur',
                            enabled: false,
                            child: Text(
                              'Serveur local MySQL / PostgreSQL (bientôt)',
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'api',
                            enabled: false,
                            child: Text('API distante (bientôt)'),
                          ),
                        ],
                        onChanged: (valeur) {
                          if (valeur != null) {
                            setState(() => _type = valeur);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Emplacement du fichier de base
                      TextFormField(
                        controller: _cheminBaseController,
                        decoration: const InputDecoration(
                          labelText: 'Emplacement du fichier de base',
                          prefixIcon: Icon(Icons.folder),
                          border: OutlineInputBorder(),
                        ),
                        validator: (valeur) {
                          if (valeur == null || valeur.trim().isEmpty) {
                            return "Veuillez indiquer l'emplacement de la base";
                          }
                          if (!valeur.trim().toLowerCase().endsWith('.db')) {
                            return 'Le fichier doit se terminer par .db';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Dossier des sauvegardes
                      TextFormField(
                        controller: _sauvegardeController,
                        decoration: const InputDecoration(
                          labelText: 'Dossier des sauvegardes',
                          prefixIcon: Icon(Icons.backup),
                          border: OutlineInputBorder(),
                        ),
                        validator: (valeur) {
                          if (valeur == null || valeur.trim().isEmpty) {
                            return 'Veuillez indiquer le dossier des sauvegardes';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: _enregistrement ? null : _enregistrer,
                          child: _enregistrement
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Enregistrer la configuration'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
