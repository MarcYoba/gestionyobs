import 'package:flutter/material.dart';

import 'package:gestionyobs/config_service.dart';
import 'package:gestionyobs/config_page.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/controller/apres_connexion_page.dart';

import 'utilisateur.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifiantController = TextEditingController();
  final _motDePasseController = TextEditingController();
  bool _masquerMotDePasse = true;
  bool _chargement = false;
  String? _erreur;

  @override
  void dispose() {
    _identifiantController.dispose();
    _motDePasseController.dispose();
    super.dispose();
  }

  Future<void> _seConnecter() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _chargement = true;
      _erreur = null;
    });

    // Petite pause pour laisser le cercle de chargement s'afficher
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final utilisateur = await DatabaseService.verifierConnexion(
        _identifiantController.text.trim(),
        _motDePasseController.text,
      );

      if (!mounted) return;

      if (utilisateur == null) {
        setState(() {
          _chargement = false;
          _erreur = 'Identifiant ou mot de passe incorrect';
        });
        return;
      }

      // Connexion réussie : on retient l'utilisateur et on ouvre l'accueil
      Session.utilisateurCourant = utilisateur;
      Session.droits = await DatabaseService.droitsDuRole(utilisateur.role);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ApresConnexionPage()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = 'Erreur : $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 400,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/images/logo.jpg',
                          width: 300,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'YOBS ENTREPRISES',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),

                      TextFormField(
                        controller: _identifiantController,
                        decoration: const InputDecoration(
                          labelText: 'Identifiant',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (valeur) {
                          if (valeur == null || valeur.trim().isEmpty) {
                            return 'Veuillez saisir votre identifiant';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _motDePasseController,
                        obscureText: _masquerMotDePasse,
                        onFieldSubmitted: (_) => _seConnecter(),
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          prefixIcon: const Icon(Icons.lock),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _masquerMotDePasse
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _masquerMotDePasse = !_masquerMotDePasse;
                              });
                            },
                          ),
                        ),
                        validator: (valeur) {
                          if (valeur == null || valeur.isEmpty) {
                            return 'Veuillez saisir votre mot de passe';
                          }
                          return null;
                        },
                      ),

                      if (_erreur != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _erreur!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: _chargement ? null : _seConnecter,
                          child: _chargement
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Connexion'),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Bouton provisoire, à retirer plus tard
                      TextButton(
                        onPressed: () async {
                          await ConfigService.supprimer();
                          if (!context.mounted) return;
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ConfigPage(),
                            ),
                          );
                        },
                        child: const Text('Reconfigurer (test)'),
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
