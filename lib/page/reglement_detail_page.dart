import 'package:flutter/material.dart';
import 'package:gestionyobs/modules/achat.dart';
import 'package:gestionyobs/modules/article.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/modules/reglement.dart';
import 'package:gestionyobs/modules/stock.dart';
import 'package:gestionyobs/service/ticket_service.dart';

class ReglementDetailPage extends StatefulWidget {
  final int id;

  const ReglementDetailPage({super.key, required this.id});

  @override
  State<ReglementDetailPage> createState() => _ReglementDetailPageState();
}

class _ReglementDetailPageState extends State<ReglementDetailPage> {
  ReglementDetail? _reglement;
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final detail = await DatabaseService.detailReglement(widget.id);
      if (!mounted) return;
      setState(() {
        _reglement = detail;
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

  Future<void> _imprimer({bool avecDialogue = false}) async {
    try {
      await TicketService.imprimerReglement(
        widget.id,
        avecDialogue: avecDialogue,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Reçu envoyé à l'imprimante")),
      );
      _charger(); // pour mettre à jour le nombre d'impressions
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
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
    final r = _reglement;
    final client = r?.type == 'client';

    return Scaffold(
      appBar: AppBar(
        title: Text(r == null ? 'Reçu' : 'Reçu ${r.code}'),
        actions: [
          if (r != null) ...[
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'Imprimer le reçu',
              onPressed: () => _imprimer(),
            ),
            PopupMenuButton<String>(
              tooltip: 'Autres choix',
              onSelected: (_) => _imprimer(avecDialogue: true),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'choisir',
                  child: Text("Choisir l'imprimante (fenêtre Windows)"),
                ),
              ],
            ),
          ],
        ],
      ),
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
                      client!
                          ? 'Reçu de règlement N° ${r!.code}'
                          : 'Paiement fournisseur N° ${r!.code}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('${formaterDate(r.date)} · Agence ${r.agence}'),
                    Text('${client ? 'Client' : 'Fournisseur'} : ${r.tiers}'),
                    Text('Saisi par ${r.utilisateur}'),
                    if (r.note != null) Text('Note : ${r.note}'),
                    Text(
                      r.nbImpressions == 0
                          ? 'Pas encore imprimé'
                          : 'Imprimé ${r.nbImpressions} fois '
                                '(les suivants portent la mention DUPLICATA)',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),

                    _titre('Factures réglées'),
                    for (final l in r.lignes)
                      Card(
                        child: ListTile(
                          dense: true,
                          title: Text('Facture ${l.documentCode}'),
                          trailing: Text(
                            formaterPrix(l.montant),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                    _titre('Paiements'),
                    for (final p in r.modes)
                      Card(
                        child: ListTile(
                          dense: true,
                          title: Text(p.mode),
                          subtitle: p.reference == null
                              ? null
                              : Text('Réf. ${p.reference}'),
                          trailing: Text(
                            formaterPrix(p.montant),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                    const Divider(height: 32),
                    Text(
                      'Total réglé : ${formaterPrix(r.montant)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Solde actuel encore dû : ${formaterPrix(r.soldeRestant)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: r.soldeRestant > 0
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
