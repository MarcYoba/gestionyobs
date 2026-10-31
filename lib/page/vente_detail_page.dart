import 'package:flutter/material.dart';
import 'package:gestionyobs/modules/article.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/modules/stock.dart';
import 'package:gestionyobs/modules/vente.dart';

class VenteDetailPage extends StatefulWidget {
  final int id;

  const VenteDetailPage({super.key, required this.id});

  @override
  State<VenteDetailPage> createState() => _VenteDetailPageState();
}

class _VenteDetailPageState extends State<VenteDetailPage> {
  VenteDetail? _vente;
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final detail = await DatabaseService.detailVente(widget.id);
      if (!mounted) return;
      setState(() {
        _vente = detail;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Widget _titre(String texte) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 4),
    child: Text(
      texte,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: Colors.green,
      ),
    ),
  );

  Widget _ligneMontant(
    String libelle,
    int montant, {
    bool gras = false,
    Color? couleur,
  }) {
    final style = TextStyle(
      fontSize: gras ? 20 : 15,
      fontWeight: gras ? FontWeight.bold : FontWeight.normal,
      color: couleur,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(libelle, style: style)),
          Text(formaterPrix(montant), style: style),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = _vente;

    return Scaffold(
      appBar: AppBar(title: Text(v == null ? 'Facture' : 'Facture ${v.code}')),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _erreur != null
          ? Center(
              child: Text(_erreur!, style: const TextStyle(color: Colors.red)),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Facture N° ${v!.code}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('${formaterDateHeure(v.date)} · Agence ${v.agence}'),
                    Text('Client : ${v.client}'),
                    Text('Vendeur : ${v.vendeur}'),
                    if (v.note != null) Text('Note : ${v.note}'),

                    _titre('Articles'),
                    for (final l in v.lignes)
                      Card(
                        child: ListTile(
                          dense: true,
                          title: Text(l.designation),
                          subtitle: Text(
                            '${formaterQuantite(l.quantite)} × '
                            '${formaterPrix(l.prixUnitaire)}'
                            '${l.remise > 0 ? '   Remise : -${formaterPrix(l.remise)}' : ''}',
                          ),
                          trailing: Text(
                            formaterPrix(l.totalNet),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                    const Divider(height: 32),
                    _ligneMontant('Total', v.totalBrut),
                    if (v.totalRemise > 0)
                      _ligneMontant(
                        'Remise',
                        -v.totalRemise,
                        couleur: Colors.orange.shade800,
                      ),
                    if (v.totalTva > 0) _ligneMontant('TVA', v.totalTva),
                    _ligneMontant('Net à payer', v.netAPayer, gras: true),

                    _titre('Paiements'),
                    if (v.paiements.isEmpty)
                      const Text(
                        'Aucun paiement : vente entièrement à crédit.',
                      ),
                    for (final p in v.paiements)
                      Card(
                        child: ListTile(
                          dense: true,
                          title: Text(p.mode),
                          subtitle: Text(
                            [
                              if (p.reference != null) 'Réf. ${p.reference}',
                              p.utilisateur,
                            ].join(' · '),
                          ),
                          trailing: Text(
                            formaterPrix(p.montant),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                    const SizedBox(height: 8),
                    _ligneMontant('Reçu', v.recu),
                    if (v.monnaieRendue > 0)
                      _ligneMontant('Monnaie rendue', v.monnaieRendue),
                    if (v.reste > 0)
                      _ligneMontant(
                        'Reste à payer (crédit)',
                        v.reste,
                        gras: true,
                        couleur: Colors.orange.shade800,
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Facture entièrement payée',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
