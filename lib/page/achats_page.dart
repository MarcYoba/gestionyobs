import 'package:flutter/material.dart';

import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/modules/achat.dart';
import 'package:gestionyobs/page/achat_detail_page.dart';
import 'package:gestionyobs/form/achat_form_page.dart';
import 'package:gestionyobs/modules/article.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/security/utilisateur.dart';

class AchatsPage extends StatefulWidget {
  const AchatsPage({super.key});

  @override
  State<AchatsPage> createState() => _AchatsPageState();
}

class _AchatsPageState extends State<AchatsPage> {
  final _rechercheController = TextEditingController();
  List<AchatResume> _achats = [];
  bool _chargement = true;
  bool _creditSeulement = false;
  String? _erreur;

  bool get _peutCreer => Session.peut('achats.creer');
  bool get _autorise => Session.peut('achats.voir') || _peutCreer;

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
      final liste = await DatabaseService.listerAchats(
        recherche: _rechercheController.text,
        creditSeulement: _creditSeulement,
      );
      if (!mounted) return;
      setState(() {
        _achats = liste;
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

  Future<void> _nouvelAchat() async {
    final fait = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AchatFormPage()),
    );
    if (fait == true) _charger();
  }

  @override
  Widget build(BuildContext context) {
    final agence = Session.agenceCourante;

    if (!_autorise) {
      return Scaffold(
        appBar: AppBar(title: const Text('Achats')),
        body: const AccesRefuse(),
      );
    }

    final dettes = _achats
        .where((a) => a.statut == 'valide')
        .fold(0, (somme, a) => somme + a.reste);

    return Scaffold(
      appBar: AppBar(
        title: Text(agence == null ? 'Achats' : 'Achats - ${agence.nom}'),
      ),
      floatingActionButton: _peutCreer
          ? FloatingActionButton.extended(
              onPressed: _nouvelAchat,
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Nouvel achat'),
            )
          : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 950),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _rechercheController,
                        onChanged: (_) => _charger(),
                        decoration: const InputDecoration(
                          labelText:
                              'Rechercher (matricule, fournisseur, facture)',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilterChip(
                      label: const Text('À crédit seulement'),
                      selected: _creditSeulement,
                      onSelected: (v) {
                        setState(() => _creditSeulement = v);
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
                    '${_achats.length} achat(s) · Dû aux fournisseurs : ${formaterPrix(dettes)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
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
                    : _achats.isEmpty
                    ? const Center(child: Text('Aucun achat'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                        itemCount: _achats.length,
                        itemBuilder: (context, index) {
                          final a = _achats[index];
                          return Card(
                            child: ListTile(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AchatDetailPage(id: a.id),
                                ),
                              ),
                              leading: const Icon(
                                Icons.receipt_long,
                                color: Colors.green,
                              ),
                              title: Text('${a.code} · ${a.fournisseur}'),
                              subtitle: Text(
                                [
                                  formaterDate(a.date),
                                  if (a.referenceFournisseur != null)
                                    'Facture ${a.referenceFournisseur}',
                                ].join(' · '),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    formaterPrix(a.totalTtc),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    a.reste > 0
                                        ? 'Reste : ${formaterPrix(a.reste)}'
                                        : 'Payé',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: a.reste > 0
                                          ? Colors.orange.shade800
                                          : Colors.green.shade800,
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
