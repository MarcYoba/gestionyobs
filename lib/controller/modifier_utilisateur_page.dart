import 'package:flutter/material.dart';

import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/security/utilisateur.dart';

class ModifierUtilisateurPage extends StatefulWidget {
  final UtilisateurResume utilisateur;

  const ModifierUtilisateurPage({super.key, required this.utilisateur});

  @override
  State<ModifierUtilisateurPage> createState() =>
      _ModifierUtilisateurPageState();
}

class _ModifierUtilisateurPageState extends State<ModifierUtilisateurPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomController;
  late String _role;
  late bool _actif;

  bool _chargement = false;
  bool _agencesChargees = false;
  String? _erreur;

  List<Agence> _agences = [];
  final Set<int> _agencesCochees = {};

  // Est-ce l'administrateur qui modifie sa propre fiche ?
  bool get _estSoiMeme =>
      widget.utilisateur.id == Session.utilisateurCourant!.id;

  @override
  void initState() {
    super.initState();
    // On préremplit le formulaire avec les valeurs actuelles
    _nomController = TextEditingController(text: widget.utilisateur.nomComplet);
    _role = widget.utilisateur.role;
    _actif = widget.utilisateur.actif;
    _chargerAgences();
  }

  @override
  void dispose() {
    _nomController.dispose();
    super.dispose();
  }

  Future<void> _chargerAgences() async {
    final agences = await DatabaseService.agencesDisponibles(
      Session.utilisateurCourant!,
    );
    final ids = await DatabaseService.agenceIdsDeUtilisateur(
      widget.utilisateur.id,
    );
    if (!mounted) return;
    setState(() {
      _agences = agences;
      _agencesCochees
        ..clear()
        ..addAll(ids);
      _agencesChargees = true;
    });
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _chargement = true;
      _erreur = null;
    });

    try {
      final nom = _nomController.text.trim();

      await DatabaseService.modifierUtilisateur(
        id: widget.utilisateur.id,
        nomComplet: nom,
        role: _role,
        actif: _actif,
        agenceIds: _agencesCochees.toList(),
      );

      // Si l'administrateur a changé son propre nom, on met la session à jour
      if (_estSoiMeme) {
        final courant = Session.utilisateurCourant!;
        Session.utilisateurCourant = Utilisateur(
          id: courant.id,
          nomComplet: nom,
          identifiant: courant.identifiant,
          role: courant.role,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true); // true = la liste doit se recharger
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _reinitialiserMotDePasse() async {
    final nouveau = await showDialog<String>(
      context: context,
      builder: (_) =>
          _NouveauMotDePasseDialog(nom: widget.utilisateur.nomComplet),
    );
    if (nouveau == null) return; // annulé

    try {
      await DatabaseService.reinitialiserMotDePasse(
        widget.utilisateur.id,
        nouveau,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mot de passe réinitialisé')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Modifier l'utilisateur")),
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
                      // Identifiant : affiché, mais non modifiable
                      TextFormField(
                        initialValue: widget.utilisateur.identifiant,
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: 'Identifiant (non modifiable)',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

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
                        // null = champ grisé (impossible de changer son propre rôle)
                        onChanged: _estSoiMeme
                            ? null
                            : (valeur) {
                                if (valeur != null) {
                                  setState(() => _role = valeur);
                                }
                              },
                      ),
                      const SizedBox(height: 8),

                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Compte actif'),
                        subtitle: Text(
                          _actif
                              ? "L'utilisateur peut se connecter"
                              : 'Connexion impossible (le compte est conservé)',
                        ),
                        value: _actif,
                        onChanged: _estSoiMeme
                            ? null
                            : (valeur) => setState(() => _actif = valeur),
                      ),

                      if (_estSoiMeme)
                        const Text(
                          'Vous ne pouvez pas modifier votre propre rôle '
                          'ni désactiver votre propre compte.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      const SizedBox(height: 16),

                      // Agences : pour tout rôle sauf administrateur
                      if (_role != 'admin') ...[
                        const Text(
                          'Agences où travaille cet utilisateur',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        if (!_agencesChargees)
                          const Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else if (_agences.isEmpty)
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
                          // Désactivé tant que les agences ne sont pas chargées,
                          // pour ne pas effacer les affiliations par erreur
                          onPressed: (_chargement || !_agencesChargees)
                              ? null
                              : _enregistrer,
                          child: _chargement
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Enregistrer les modifications'),
                        ),
                      ),

                      const Divider(height: 40),

                      OutlinedButton.icon(
                        icon: const Icon(Icons.lock_reset),
                        label: const Text('Réinitialiser le mot de passe'),
                        onPressed: _reinitialiserMotDePasse,
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

/// Boîte de dialogue : saisie d'un nouveau mot de passe.
class _NouveauMotDePasseDialog extends StatefulWidget {
  final String nom;

  const _NouveauMotDePasseDialog({required this.nom});

  @override
  State<_NouveauMotDePasseDialog> createState() =>
      _NouveauMotDePasseDialogState();
}

class _NouveauMotDePasseDialogState extends State<_NouveauMotDePasseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _motDePasseController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _masquer = true;

  @override
  void dispose() {
    _motDePasseController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouveau mot de passe'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choisissez un nouveau mot de passe pour ${widget.nom}.'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _motDePasseController,
                obscureText: _masquer,
                decoration: InputDecoration(
                  labelText: 'Nouveau mot de passe',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _masquer ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _masquer = !_masquer),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Veuillez saisir un mot de passe';
                  }
                  if (v.length < 8) return 'Minimum 8 caractères';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmationController,
                obscureText: _masquer,
                decoration: const InputDecoration(
                  labelText: 'Confirmer le mot de passe',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v != _motDePasseController.text
                    ? 'Les mots de passe ne correspondent pas'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _motDePasseController.text);
            }
          },
          child: const Text('Réinitialiser'),
        ),
      ],
    );
  }
}
