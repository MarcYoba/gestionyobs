import 'package:flutter/material.dart';

import 'package:gestionyobs/database/database_service.dart';

import 'package:gestionyobs/security/utilisateur.dart';

class CreerUtilisateurPage extends StatefulWidget {
  const CreerUtilisateurPage({super.key});

  @override
  State<CreerUtilisateurPage> createState() => _CreerUtilisateurPageState();
}

class _CreerUtilisateurPageState extends State<CreerUtilisateurPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _identifiantController = TextEditingController();
  final _motDePasseController = TextEditingController();
  final _confirmationController = TextEditingController();

  String _role = 'vendeur';
  bool _masquer = true;
  bool _chargement = false;
  String? _erreur;

  List<Agence> _agences = [];
  final Set<int> _agencesCochees = {};

  @override
  void initState() {
    super.initState();
    _chargerAgences();
  }

  @override
  void dispose() {
    _nomController.dispose();
    _identifiantController.dispose();
    _motDePasseController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _chargerAgences() async {
    final agences = await DatabaseService.agencesDisponibles(
      Session.utilisateurCourant!,
    );
    if (!mounted) return;
    setState(() => _agences = agences);
  }

  Future<void> _creer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _chargement = true;
      _erreur = null;
    });
    // Petite pause pour laisser le cercle de chargement s'afficher
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      await DatabaseService.creerUtilisateur(
        nomComplet: _nomController.text.trim(),
        identifiant: _identifiantController.text.trim(),
        motDePasse: _motDePasseController.text,
        role: _role,
        // Un administrateur a accès à toutes les agences : pas d'affiliation
        agenceIds: _role == 'admin' ? const [] : _agencesCochees.toList(),
      );
      if (!mounted) return;
      Navigator.pop(context, true); // true = un utilisateur a été créé
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e.toString().contains('UNIQUE')
            ? 'Cet identifiant existe déjà'
            : 'Erreur : $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvel utilisateur')),
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
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        initialValue: _role,
                        decoration: const InputDecoration(
                          labelText: 'Rôle',
                          prefixIcon: Icon(Icons.admin_panel_settings),
                          border: OutlineInputBorder(),
                        ),
                        items: rolesDisponibles.entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            )
                            .toList(),
                        onChanged: (valeur) {
                          if (valeur != null) setState(() => _role = valeur);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Agences : seulement pour un vendeur
                      if (_role != 'admin') ...[
                        const Text(
                          'Agences où travaille cet utilisateur',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        if (_agences.isEmpty)
                          const Text("Aucune agence n'est disponible.")
                        else
                          ..._agences.map(
                            (agence) => CheckboxListTile(
                              value: _agencesCochees.contains(agence.id),
                              title: Text(agence.nom),
                              subtitle: agence.ville == null
                                  ? null
                                  : Text(agence.ville!),
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (coche) {
                                setState(() {
                                  if (coche == true) {
                                    _agencesCochees.add(agence.id);
                                  } else {
                                    _agencesCochees.remove(agence.id);
                                  }
                                });
                              },
                            ),
                          ),
                      ] else
                        const Text(
                          "L'administrateur a accès à toutes les agences.",
                        ),

                      if (_erreur != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _erreur!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
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
                              : const Text("Créer l'utilisateur"),
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
