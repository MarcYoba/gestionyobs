import 'package:flutter/material.dart';

import 'creer_utilisateur_page.dart';

import 'package:gestionyobs/database/database_service.dart';

import 'package:gestionyobs/security/utilisateur.dart';

import 'modifier_utilisateur_page.dart';

class UtilisateursPage extends StatefulWidget {
  const UtilisateursPage({super.key});

  @override
  State<UtilisateursPage> createState() => _UtilisateursPageState();
}

class _UtilisateursPageState extends State<UtilisateursPage> {
  List<UtilisateurResume> _utilisateurs = [];
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final liste = await DatabaseService.listerUtilisateurs();
      if (!mounted) return;
      setState(() {
        _utilisateurs = liste;
        _chargement = false;
        _erreur = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = 'Erreur : $e';
      });
    }
  }

  Future<void> _nouvelUtilisateur() async {
    final cree = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreerUtilisateurPage()),
    );
    // Si un utilisateur a été créé, on recharge la liste
    if (cree == true) _charger();
  }

  Future<void> _modifier(UtilisateurResume u) async {
    final modifie = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ModifierUtilisateurPage(utilisateur: u),
      ),
    );
    if (modifie == true) _charger();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Utilisateurs')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nouvelUtilisateur,
        icon: const Icon(Icons.person_add),
        label: const Text('Nouvel utilisateur'),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _erreur != null
          ? Center(
              child: Text(_erreur!, style: const TextStyle(color: Colors.red)),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  itemCount: _utilisateurs.length,
                  itemBuilder: (context, index) {
                    final u = _utilisateurs[index];
                    final sansAgence = !u.estAdmin && u.agences.isEmpty;
                    final texteAgences = u.estAdmin
                        ? 'Toutes les agences'
                        : (sansAgence ? 'Aucune agence' : u.agences);

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            u.nomComplet.isEmpty
                                ? '?'
                                : u.nomComplet[0].toUpperCase(),
                          ),
                        ),
                        onTap: () => _modifier(u),
                        title: Text(u.nomComplet),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u.identifiant),
                            Text(
                              texteAgences,
                              style: TextStyle(
                                color: sansAgence
                                    ? Colors.orange.shade800
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!u.actif)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Chip(
                                  label: const Text('Désactivé'),
                                  backgroundColor: Colors.red.shade100,
                                ),
                              ),
                            Chip(label: Text(libelleRole(u.role))),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }
}
