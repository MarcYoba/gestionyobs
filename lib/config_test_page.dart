import 'package:flutter/material.dart';

import 'config_service.dart';

class ConfigTestPage extends StatefulWidget {
  const ConfigTestPage({super.key});

  @override
  State<ConfigTestPage> createState() => _ConfigTestPageState();
}

class _ConfigTestPageState extends State<ConfigTestPage> {
  String _chemin = '';
  bool _existe = false;
  AppConfig? _config;

  @override
  void initState() {
    super.initState();
    _rafraichir(); // au démarrage de la page, on lit le fichier
  }

  Future<void> _rafraichir() async {
    final chemin = await ConfigService.chemin();
    final existe = await ConfigService.existe();
    final config = await ConfigService.lire();
    if (!mounted) return;
    setState(() {
      _chemin = chemin;
      _existe = existe;
      _config = config;
    });
  }

  Future<void> _enregistrerTest() async {
    await ConfigService.ecrire(
      const AppConfig(
        type: 'sqlite',
        cheminBase: r'C:\Quincaillerie\donnees\quincaillerie.db',
        dossierSauvegarde: r'D:\Sauvegardes',
      ),
    );
    await _rafraichir();
  }

  Future<void> _supprimer() async {
    await ConfigService.supprimer();
    await _rafraichir();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test du fichier de configuration')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Emplacement du fichier :',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SelectableText(_chemin),
            const SizedBox(height: 16),
            Text(
              _existe ? 'Le fichier EXISTE' : "Le fichier n'existe pas",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _existe ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            if (_config != null) ...[
              Text('Type : ${_config!.type}'),
              Text('Base : ${_config!.cheminBase}'),
              Text('Sauvegardes : ${_config!.dossierSauvegarde}'),
            ] else
              const Text('Aucune configuration lue'),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              children: [
                FilledButton(
                  onPressed: _enregistrerTest,
                  child: const Text('Enregistrer une config de test'),
                ),
                OutlinedButton(
                  onPressed: _rafraichir,
                  child: const Text('Relire'),
                ),
                OutlinedButton(
                  onPressed: _supprimer,
                  child: const Text('Supprimer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
