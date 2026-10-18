import 'package:flutter/material.dart';

import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/security/login_page.dart';

class PremierAdminPage extends StatefulWidget {
  const PremierAdminPage({super.key});

  @override
  State<PremierAdminPage> createState() => _PremierAdminPageState();
}

class _PremierAdminPageState extends State<PremierAdminPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _identifiantController = TextEditingController();
  final _motDePasseController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _masquer = true;
  bool _chargement = false;

  @override
  void dispose() {
    _nomController.dispose();
    _identifiantController.dispose();
    _motDePasseController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _creer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _chargement = true);
    // Petite pause pour laisser le cercle de chargement s'afficher
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      await DatabaseService.creerUtilisateur(
        nomComplet: _nomController.text.trim(),
        identifiant: _identifiantController.text.trim(),
        motDePasse: _motDePasseController.text,
        role: 'admin',
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _chargement = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 460,
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
                        'Créer le compte administrateur',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ce premier compte permettra de gérer le logiciel '
                        'et de créer les autres utilisateurs.',
                      ),
                      const SizedBox(height: 24),

                      TextFormField(
                        controller: _nomController,
                        decoration: const InputDecoration(
                          labelText: 'Nom complet',
                          prefixIcon: Icon(Icons.badge),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Veuillez saisir le nom complet'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _identifiantController,
                        decoration: const InputDecoration(
                          labelText: 'Identifiant',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Veuillez saisir un identifiant';
                          }
                          if (v.trim().length < 3) {
                            return 'Minimum 3 caractères';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _motDePasseController,
                        obscureText: _masquer,
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          prefixIcon: const Icon(Icons.lock),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _masquer
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () =>
                                setState(() => _masquer = !_masquer),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Veuillez saisir un mot de passe';
                          }
                          if (v.length < 8) {
                            return 'Minimum 8 caractères';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _confirmationController,
                        obscureText: _masquer,
                        decoration: const InputDecoration(
                          labelText: 'Confirmer le mot de passe',
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v != _motDePasseController.text
                            ? 'Les mots de passe ne correspondent pas'
                            : null,
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: _chargement ? null : _creer,
                          child: _chargement
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text("Créer l'administrateur"),
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
