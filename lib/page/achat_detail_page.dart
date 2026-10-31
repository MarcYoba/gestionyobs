import 'package:flutter/material.dart';
import 'package:gestionyobs/modules/achat.dart';
import 'package:gestionyobs/modules/article.dart';
import 'package:gestionyobs/database/database_service.dart';

class AchatDetailPage extends StatefulWidget {
  final int id;

  const AchatDetailPage({super.key, required this.id});

  @override
  State<AchatDetailPage> createState() => _AchatDetailPageState();
}

class _AchatDetailPageState extends State<AchatDetailPage> {
  AchatDetail? _achat;
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final detail = await DatabaseService.detailAchat(widget.id);
      if (!mounted) return;
      setState(() {
        _achat = detail;
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

  @override
  Widget build(BuildContext context) {
    final a = _achat;

    return Scaffold(
      appBar: AppBar(title: Text(a == null ? 'Achat' : 'Achat ${a.code}')),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _erreur != null
          ? Center(
              child: Text(_erreur!, style: const TextStyle(color: Colors.red)),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      a!.fournisseur,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      [
                        formaterDate(a.date),
                        if (a.referenceFournisseur != null)
                          'Facture ${a.referenceFournisseur}',
                        'Agence ${a.agence}',
                      ].join(' · '),
                    ),
                    Text('Enregistré par ${a.utilisateur}'),
                    if (a.note != null) Text('Note : ${a.note}'),

                    _titre('Articles'),
                    for (final l in a.lignes)
                      Card(
                        child: ListTile(
                          dense: true,
                          title: Text(l.designation),
                          subtitle: Text(
                            '${l.code} · ${formaterQuantite(l.quantite)} × '
                            '${formaterPrix(l.prixUnitaire)}',
                          ),
                          trailing: Text(
                            formaterPrix(l.totalHt),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                    _titre('Paiements'),
                    if (a.paiements.isEmpty)
                      const Text(
                        'Aucun paiement : achat entièrement à crédit.',
                      ),
                    for (final p in a.paiements)
                      Card(
                        child: ListTile(
                          dense: true,
                          title: Text(p.mode),
                          subtitle: Text(
                            [
                              formaterDate(p.date),
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

                    const Divider(height: 32),
                    Text('Total HT : ${formaterPrix(a.totalHt)}'),
                    if (a.totalTva > 0)
                      Text('TVA : ${formaterPrix(a.totalTva)}'),
                    Text(
                      'Total : ${formaterPrix(a.totalTtc)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('Payé : ${formaterPrix(a.paye)}'),
                    Text(
                      a.reste > 0
                          ? 'Reste à payer : ${formaterPrix(a.reste)}'
                          : 'Achat entièrement payé',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: a.reste > 0
                            ? Colors.orange.shade800
                            : Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
