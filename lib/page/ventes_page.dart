import 'package:flutter/material.dart';
import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/modules/achat.dart';
import 'package:gestionyobs/modules/article.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/modules/stock.dart';
import 'package:gestionyobs/security/utilisateur.dart';
import 'package:gestionyobs/modules/vente.dart';
import 'package:gestionyobs/page/vente_detail_page.dart';
import 'package:gestionyobs/form/vente_form_page.dart';

class VentesPage extends StatefulWidget {
  const VentesPage({super.key});

  @override
  State<VentesPage> createState() => _VentesPageState();
}

class _VentesPageState extends State<VentesPage> {
  final _rechercheController = TextEditingController();
  List<VenteResume> _ventes = [];
  bool _chargement = true;
  bool _creditSeulement = false;
  String? _erreur;

  bool get _peutCreer => Session.peut('ventes.creer');
  bool get _autorise => Session.peut('ventes.voir') || _peutCreer;

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
      final liste = await DatabaseService.listerVentes(
        recherche: _rechercheController.text,
        creditSeulement: _creditSeulement,
      );
      if (!mounted) return;
      setState(() {
        _ventes = liste;
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

  Future<void> _nouvelleVente() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VenteFormPage()),
    );
    _charger(); // la caisse a pu enregistrer plusieurs ventes
  }

  @override
  Widget build(BuildContext context) {
    final agence = Session.agenceCourante;

    if (!_autorise) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ventes')),
        body: const AccesRefuse(),
      );
    }

    final creances = _ventes
        .where((v) => v.statut == 'valide')
        .fold(0, (somme, v) => somme + v.reste);
    final total = _ventes
        .where((v) => v.statut == 'valide')
        .fold(0, (somme, v) => somme + v.netAPayer);

    return Scaffold(
      appBar: AppBar(
        title: Text(agence == null ? 'Ventes' : 'Ventes - ${agence.nom}'),
      ),
      floatingActionButton: _peutCreer
          ? FloatingActionButton.extended(
              onPressed: _nouvelleVente,
              icon: const Icon(Icons.point_of_sale),
              label: const Text('Nouvelle vente'),
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
                          labelText: 'Rechercher (facture, client)',
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
                    '${_ventes.length} vente(s) · Total : ${formaterPrix(total)} · '
                    'Dû par les clients : ${formaterPrix(creances)}',
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
                    : _ventes.isEmpty
                    ? const Center(child: Text('Aucune vente'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                        itemCount: _ventes.length,
                        itemBuilder: (context, index) {
                          final v = _ventes[index];
                          return Card(
                            child: ListTile(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => VenteDetailPage(id: v.id),
                                ),
                              ),
                              leading: const Icon(
                                Icons.receipt,
                                color: Colors.green,
                              ),
                              title: Text('${v.code} · ${v.client}'),
                              subtitle: Text(
                                '${formaterDateHeure(v.date)} · ${v.vendeur}',
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    formaterPrix(v.netAPayer),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    v.reste > 0
                                        ? 'Crédit : ${formaterPrix(v.reste)}'
                                        : 'Payée',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: v.reste > 0
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
