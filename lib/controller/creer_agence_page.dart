import 'package:flutter/material.dart';

import 'apres_connexion_page.dart';

import 'package:gestionyobs/database/database_service.dart';

import 'home_page.dart';

import 'package:gestionyobs/security/login_page.dart';
import 'package:gestionyobs/security/utilisateur.dart';

class CreerAgencePage extends StatefulWidget {
  // true = c'est la toute première agence (obligatoire)
  final bool premiere;

  const CreerAgencePage({super.key, this.premiere = false});

  @override
  State<CreerAgencePage> createState() => _CreerAgencePageState();
}

class _CreerAgencePageState extends State<CreerAgencePage> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _villeController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _chargement = false;
  String? _erreur;

  @override
  void dispose() {
    _nomController.dispose();
    _villeController.dispose();
    _telephoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _creer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _chargement = true;
      _erreur = null;
    });

    try {
      final agence = await DatabaseService.creerAgence(
        nom: _nomController.text.trim(),
        ville: _villeController.text.trim(),
        telephone: _telephoneController.text.trim(),
        description: _descriptionController.text.trim(),
      );

      if (!mounted) return;

      if (widget.premiere) {
        // Première agence : on l'utilise directement
        Session.agenceCourante = agence;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      } else {
        // Nouvelle agence : on revient à la liste, mise à jour
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ApresConnexionPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e.toString().contains('UNIQUE')
            ? 'Une agence porte déjà ce nom'
            : 'Erreur : $e';
      });
    }
  }

  void _deconnecter() {
    Session.deconnecter();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Pour une nouvelle agence, une barre avec une flèche de retour
      appBar: widget.premiere
          ? null
          : AppBar(title: const Text('Nouvelle agence')),
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
                      Text(
                        widget.premiere
                            ? 'Créer la première agence'
                            : 'Nouvelle agence',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.premiere) ...[
                        const SizedBox(height: 8),
                        const Text(
                          "Aucune agence n'existe encore. "
                          'Créez-en une pour commencer.',
                        ),
                      ],
                      const SizedBox(height: 24),

                      TextFormField(
                        controller: _nomController,
                        decoration: const InputDecoration(
                          labelText: "Nom de l'agence",
                          prefixIcon: Icon(Icons.store),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? "Veuillez saisir le nom de l'agence"
                            : null,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _villeController,
                        decoration: const InputDecoration(
                          labelText: 'Ville (facultatif)',
                          prefixIcon: Icon(Icons.location_city),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _telephoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Téléphone (facultatif)',
                          prefixIcon: Icon(Icons.phone),
                          border: OutlineInputBorder(),
                        ),
                      ),

                      if (_erreur != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _erreur!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Zone de texte sur plusieurs lignes (textarea)
                      TextFormField(
                        controller: _descriptionController,
                        keyboardType: TextInputType.multiline,
                        minLines: 3,
                        maxLines: 5,
                        maxLength: 250,
                        decoration: const InputDecoration(
                          labelText: 'Description (facultatif)',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
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
                              : const Text("Créer l'agence"),
                        ),
                      ),

                      if (widget.premiere) ...[
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: _deconnecter,
                            child: const Text('Se déconnecter'),
                          ),
                        ),
                      ],
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
