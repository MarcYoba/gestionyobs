import 'package:flutter/material.dart';
import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/modules/article.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/form/mouvement_form_page.dart';

import 'mouvements_page.dart';

import 'package:gestionyobs/modules/stock.dart';
import 'package:gestionyobs/security/utilisateur.dart';

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  final _rechercheController = TextEditingController();
  List<LigneStock> _lignes = [];
  bool _chargement = true;
  bool _alertesSeulement = false;
  String? _erreur;

  bool get _peutMouvement =>
      Session.peut('stock.modifier') || Session.peut('stock.ajuster');
  bool get _autorise => Session.peut('stock.voir') || _peutMouvement;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _rechercheController.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      final liste = await DatabaseService.listerStock(
        recherche: _rechercheController.text,
        alertesSeulement: _alertesSeulement,
      );
      if (!mounted) return;
      setState(() {
        _lignes = liste;
        _chargement = false;
        _erreur = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _ouvrirMouvement(LigneStock ligne) async {
    final fait = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => MouvementFormPage(ligne: ligne)),
    );
    if (fait == true) _charger();
  }

  Widget _pastille(LigneStock l) {
    if (l.enRupture) {
      return Chip(
        label: const Text('Rupture'),
        backgroundColor: Colors.red.shade100,
        visualDensity: VisualDensity.compact,
      );
    }
    if (l.enAlerte) {
      return Chip(
        label: const Text('Alerte'),
        backgroundColor: Colors.orange.shade100,
        visualDensity: VisualDensity.compact,
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final agence = Session.agenceCourante;

    if (!_autorise) {
      return Scaffold(
        appBar: AppBar(title: const Text('Stock')),
        body: const AccesRefuse(),
      );
    }

    final nbAlertes = _lignes.where((l) => l.enAlerte).length;
    final nbRuptures = _lignes.where((l) => l.enRupture).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(agence == null ? 'Stock' : 'Stock - ${agence.nom}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historique des mouvements',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MouvementsPage()),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _rechercheController,
                        onChanged: (_) => _charger(),
                        decoration: const InputDecoration(
                          labelText: 'Rechercher (matricule, nom, catégorie)',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilterChip(
                      label: const Text('Alertes seulement'),
                      selected: _alertesSeulement,
                      onSelected: (v) {
                        setState(() => _alertesSeulement = v);
                        _charger();
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_lignes.length} article(s) · $nbAlertes en alerte · '
                    '$nbRuptures en rupture',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              ),
              Expanded(
                child: _chargement
                    ? const Center(child: CircularProgressIndicator())
                    : _erreur != null
                    ? Center(
                        child: Text(
                          _erreur!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    : _lignes.isEmpty
                    ? const Center(child: Text('Aucun article'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: _lignes.length,
                        itemBuilder: (context, index) {
                          final l = _lignes[index];
                          return Card(
                            child: ListTile(
                              onTap: _peutMouvement
                                  ? () => _ouvrirMouvement(l)
                                  : null,
                              title: Text(l.designation),
                              subtitle: Text(
                                [
                                  l.code,
                                  if (l.categorie != null) l.categorie!,
                                ].join(' · '),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _pastille(l),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${formaterQuantite(l.quantite)} ${l.unite}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
