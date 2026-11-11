import 'package:flutter/material.dart';
import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/modules/annulation.dart';
import 'package:gestionyobs/modules/article.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/modules/stock.dart';
import 'package:gestionyobs/modules/transfert.dart';
import 'package:gestionyobs/dialog/transfert_dialogs.dart';
import 'package:gestionyobs/security/utilisateur.dart';

class TransfertDetailPage extends StatefulWidget {
  final int id;

  const TransfertDetailPage({super.key, required this.id});

  @override
  State<TransfertDetailPage> createState() => _TransfertDetailPageState();
}

class _TransfertDetailPageState extends State<TransfertDetailPage> {
  TransfertDetail? _transfert;
  bool _chargement = true;
  bool _occupe = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final t = await DatabaseService.detailTransfert(widget.id);
      if (!mounted) return;
      setState(() {
        _transfert = t;
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

  void _message(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  // Lance une action, affiche le résultat, recharge le transfert
  Future<void> _executer(Future<void> Function() action, String succes) async {
    setState(() => _occupe = true);
    try {
      await action();
      if (!mounted) return;
      _message(succes);
      await _charger();
    } catch (e) {
      if (!mounted) return;
      _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _accepter(TransfertDetail t) async {
    final r = await demanderQuantites(
      context,
      titre: 'Accepter la demande',
      consigne:
          "Indiquez ce que vous acceptez de transférer. "
          "Mettez 0 pour un article que vous n'envoyez pas.",
      lignes: t.lignes,
      plafond: (l) => l.demandee,
      initial: (l) => l.demandee,
    );
    if (r == null) return;
    await _executer(
      () => DatabaseService.repondreTransfert(
        id: t.id,
        accepte: true,
        quantites: r.quantites,
      ),
      'Demande acceptée',
    );
  }

  Future<void> _refuser(TransfertDetail t) async {
    final motif = await demanderTexteObligatoire(
      context,
      titre: 'Refuser la demande ?',
      libelle: 'Motif du refus (obligatoire)',
      bouton: 'Refuser',
    );
    if (motif == null) return;
    await _executer(
      () => DatabaseService.repondreTransfert(
        id: t.id,
        accepte: false,
        motifRefus: motif,
      ),
      'Demande refusée',
    );
  }

  Future<void> _expedier(TransfertDetail t) async {
    final r = await demanderQuantites(
      context,
      titre: 'Expédier la marchandise',
      consigne:
          'Confirmez les quantités réellement envoyées. '
          'Le stock de ${t.source} va baisser.',
      lignes: t.lignes,
      plafond: (l) => l.acceptee ?? 0,
      initial: (l) => l.acceptee ?? 0,
    );
    if (r == null) return;
    await _executer(
      () => DatabaseService.expedierTransfert(id: t.id, quantites: r.quantites),
      'Marchandise expédiée : le transfert est en transit',
    );
  }

  Future<void> _receptionner(TransfertDetail t) async {
    final r = await demanderQuantites(
      context,
      titre: 'Réceptionner la marchandise',
      consigne:
          'Indiquez les quantités réellement reçues. '
          'Le stock de ${t.demandeuse} va augmenter de ces quantités.',
      lignes: t.lignes,
      plafond: (l) => l.expediee ?? 0,
      initial: (l) => l.expediee ?? 0,
      auMoinsUne: false,
      avecNote: true,
    );
    if (r == null) return;
    await _executer(
      () => DatabaseService.receptionnerTransfert(
        id: t.id,
        quantites: r.quantites,
        note: r.note,
      ),
      'Marchandise réceptionnée',
    );
  }

  Future<void> _annuler(TransfertDetail t) async {
    // 1. On prépare les conséquences sous forme de texte unique pour le paramètre 'avertissement'
    final avertissementTexte = [
      '• Aucun mouvement de stock n\'a encore eu lieu : le stock ne change pas.',
      '• Le transfert reste dans la liste, marqué ANNULÉ.',
    ].join('\n');

    // 2. On appelle la boîte de dialogue en respectant les paramètres du widget MotifAnnulationDialog
    final motif = await showDialog<String>(
      context: context,
      builder: (context) => MotifAnnulationDialog(
        titre: 'Annuler le transfert ${t.code} ?',
        avertissement: avertissementTexte,
      ),
    );

    if (motif == null) return;

    await _executer(
      () => DatabaseService.annulerTransfert(t.id, motif),
      'Transfert annulé',
    );
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

  Widget _evenement(
    IconData icone,
    String titre,
    String detail, {
    bool fait = true,
  }) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icone, color: fait ? Colors.green : Colors.grey),
      title: Text(
        titre,
        style: TextStyle(
          fontWeight: fait ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Text(detail),
    );
  }

  Widget _valeur(
    String libelle,
    double? valeur,
    String unite, {
    Color? couleur,
  }) {
    if (valeur == null) return const SizedBox.shrink();
    return Text(
      '$libelle ${formaterQuantite(valeur)} $unite',
      style: TextStyle(
        fontSize: 13,
        color: couleur,
        fontWeight: couleur == null ? null : FontWeight.bold,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _transfert;
    final agence = Session.agenceCourante;

    // Qui est cette agence dans ce transfert ?
    final estSource = t != null && agence != null && t.sourceId == agence.id;
    final estDemandeuse =
        t != null && agence != null && t.demandeuseId == agence.id;

    final peutAnnuler =
        t != null &&
        (t.statut == 'demande' || t.statut == 'accepte') &&
        ((estDemandeuse && Session.peut('transferts.demander')) ||
            (estSource && Session.peut('transferts.valider')));

    return Scaffold(
      appBar: AppBar(
        title: Text(t == null ? 'Transfert' : 'Transfert ${t.code}'),
        actions: [
          if (peutAnnuler)
            IconButton(
              icon: const Icon(Icons.cancel_outlined),
              tooltip: 'Annuler le transfert',
              onPressed: _occupe ? null : () => _annuler(t),
            ),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _erreur != null
          ? Center(
              child: Text(_erreur!, style: const TextStyle(color: Colors.red)),
            )
          : t == null
          ? const AccesRefuse()
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${t.source}  →  ${t.demandeuse}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Chip(
                          label: Text(
                            statutsTransfert[t.statut] ?? t.statut,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: couleurStatutTransfert(t.statut).shade800,
                            ),
                          ),
                          backgroundColor: couleurStatutTransfert(t.statut)
                              .shade50,
                        ),
                      ],
                    ),
                    Text(
                      estSource
                          ? 'Votre agence envoie la marchandise.'
                          : 'Votre agence reçoit la marchandise.',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    if (t.note != null) Text('Note : ${t.note}'),

                    if (t.annulation != null)
                      BandeauAnnulation(
                        info: t.annulation!,
                        titre: 'TRANSFERT ANNULÉ',
                      ),

                    _titre('Déroulement'),
                    _evenement(
                      Icons.edit_note,
                      'Demandé par ${t.demandeuse}',
                      '${formaterDateHeure(t.demandeLe)} · ${t.demandePar}',
                    ),
                    if (t.statut == 'refuse')
                      _evenement(
                        Icons.block,
                        'Refusé par ${t.source}',
                        '${t.decisionLe == null ? '' : formaterDateHeure(t.decisionLe!)}'
                            ' · ${t.decisionPar ?? ''}\nMotif : ${t.motifRefus ?? ''}',
                      )
                    else ...[
                      _evenement(
                        Icons.thumb_up_alt_outlined,
                        'Accepté par ${t.source}',
                        t.decisionLe == null
                            ? 'En attente'
                            : '${formaterDateHeure(t.decisionLe!)} · ${t.decisionPar ?? ''}',
                        fait: t.decisionLe != null,
                      ),
                      _evenement(
                        Icons.local_shipping,
                        'Expédié par ${t.source}',
                        t.expedieLe == null
                            ? 'En attente'
                            : '${formaterDateHeure(t.expedieLe!)} · ${t.expediePar ?? ''}',
                        fait: t.expedieLe != null,
                      ),
                      _evenement(
                        Icons.inventory,
                        'Reçu par ${t.demandeuse}',
                        t.recuLe == null
                            ? 'En attente'
                            : '${formaterDateHeure(t.recuLe!)} · ${t.recuPar ?? ''}',
                        fait: t.recuLe != null,
                      ),
                    ],
                    if (t.noteReception != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Note de réception : ${t.noteReception}',
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    _titre('Articles'),
                    for (final l in t.lignes)
                      Card(
                        child: ListTile(
                          title: Text(l.designation),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              spacing: 16,
                              runSpacing: 2,
                              children: [
                                Text(
                                  l.code,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                _valeur('Demandé', l.demandee, l.unite),
                                _valeur('Accepté', l.acceptee, l.unite),
                                _valeur('Expédié', l.expediee, l.unite),
                                _valeur(
                                  l.ecart ? 'Reçu (écart)' : 'Reçu',
                                  l.recue,
                                  l.unite,
                                  couleur: l.ecart ? Colors.red.shade700 : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Les actions possibles, selon l'agence et l'étape
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        if (estSource &&
                            t.statut == 'demande' &&
                            Session.peut('transferts.valider')) ...[
                          FilledButton.icon(
                            onPressed: _occupe ? null : () => _accepter(t),
                            icon: const Icon(Icons.check),
                            label: const Text('Accepter...'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _occupe ? null : () => _refuser(t),
                            icon: const Icon(Icons.close),
                            label: const Text('Refuser...'),
                          ),
                        ],
                        if (estSource &&
                            t.statut == 'accepte' &&
                            Session.peut('transferts.expedier'))
                          FilledButton.icon(
                            onPressed: _occupe ? null : () => _expedier(t),
                            icon: const Icon(Icons.local_shipping),
                            label: const Text('Expédier...'),
                          ),
                        if (estDemandeuse &&
                            t.statut == 'expedie' &&
                            Session.peut('transferts.recevoir'))
                          FilledButton.icon(
                            onPressed: _occupe ? null : () => _receptionner(t),
                            icon: const Icon(Icons.inventory),
                            label: const Text('Réceptionner...'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
