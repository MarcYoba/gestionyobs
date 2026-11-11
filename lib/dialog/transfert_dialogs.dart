import 'package:flutter/material.dart';
import 'package:gestionyobs/modules/article.dart';
import 'package:gestionyobs/modules/transfert.dart';

/// Le résultat de la fenêtre de quantités.
class QuantitesResultat {
  final List<QuantiteLigneSaisie> quantites;
  final String? note;

  const QuantitesResultat(this.quantites, this.note);
}

/// Demande une quantité pour chaque ligne d'un transfert.
Future<QuantitesResultat?> demanderQuantites(
  BuildContext context, {
  required String titre,
  required String consigne,
  required List<LigneTransfert> lignes,
  required double Function(LigneTransfert) plafond,
  required double Function(LigneTransfert) initial,
  bool auMoinsUne = true,
  bool avecNote = false,
}) {
  return showDialog<QuantitesResultat>(
    context: context,
    builder: (_) => _QuantitesDialog(
      titre: titre,
      consigne: consigne,
      lignes: lignes,
      plafond: plafond,
      initial: initial,
      auMoinsUne: auMoinsUne,
      avecNote: avecNote,
    ),
  );
}

class _QuantitesDialog extends StatefulWidget {
  final String titre;
  final String consigne;
  final List<LigneTransfert> lignes;
  final double Function(LigneTransfert) plafond;
  final double Function(LigneTransfert) initial;
  final bool auMoinsUne;
  final bool avecNote;

  const _QuantitesDialog({
    required this.titre,
    required this.consigne,
    required this.lignes,
    required this.plafond,
    required this.initial,
    required this.auMoinsUne,
    required this.avecNote,
  });

  @override
  State<_QuantitesDialog> createState() => _QuantitesDialogState();
}

class _QuantitesDialogState extends State<_QuantitesDialog> {
  final Map<int, TextEditingController> _champs = {};
  final _noteController = TextEditingController();
  String? _erreur;

  @override
  void initState() {
    super.initState();
    for (final l in widget.lignes) {
      _champs[l.id] = TextEditingController(
        text: formaterQuantite(widget.initial(l)),
      );
    }
  }

  @override
  void dispose() {
    for (final c in _champs.values) {
      c.dispose();
    }
    _noteController.dispose();
    super.dispose();
  }

  void _valider() {
    final resultat = <QuantiteLigneSaisie>[];
    var total = 0.0;
    var ecart = false;

    for (final l in widget.lignes) {
      final q = double.tryParse(
        _champs[l.id]!.text.trim().replaceAll(',', '.'),
      );
      if (q == null) {
        setState(() => _erreur = 'Quantité invalide pour « ${l.designation} »');
        return;
      }
      final max = widget.plafond(l);
      if (q < 0 || q > max) {
        setState(() {
          _erreur =
              '« ${l.designation} » : indiquez une quantité entre 0 et '
              '${formaterQuantite(max)}';
        });
        return;
      }
      if ((q - widget.initial(l)).abs() > 0.0005) ecart = true;
      total += q;
      resultat.add(QuantiteLigneSaisie(ligneId: l.id, quantite: q));
    }

    if (widget.auMoinsUne && total <= 0) {
      setState(
        () => _erreur = 'Indiquez au moins une quantité supérieure à zéro',
      );
      return;
    }

    final note = _noteController.text.trim();
    if (widget.avecNote && ecart && note.length < 5) {
      setState(() {
        _erreur =
            "Il y a un écart : une note est obligatoire (5 caractères minimum)";
      });
      return;
    }

    Navigator.pop(
      context,
      QuantitesResultat(resultat, note.isEmpty ? null : note),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titre),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.consigne),
              const SizedBox(height: 12),
              for (final l in widget.lignes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.designation,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Maximum : ${formaterQuantite(widget.plafond(l))} ${l.unite}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 110,
                        child: TextField(
                          controller: _champs[l.id],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (widget.avecNote) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _noteController,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText:
                        'Note de réception (obligatoire en cas d\'écart)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              if (_erreur != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _erreur!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Revenir'),
        ),
        FilledButton(onPressed: _valider, child: const Text('Valider')),
      ],
    );
  }
}

/// Demande un texte obligatoire (un motif de refus, par exemple).
Future<String?> demanderTexteObligatoire(
  BuildContext context, {
  required String titre,
  required String libelle,
  String bouton = 'Valider',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) =>
        _TexteDialog(titre: titre, libelle: libelle, bouton: bouton),
  );
}

class _TexteDialog extends StatefulWidget {
  final String titre;
  final String libelle;
  final String bouton;

  const _TexteDialog({
    required this.titre,
    required this.libelle,
    required this.bouton,
  });

  @override
  State<_TexteDialog> createState() => _TexteDialogState();
}

class _TexteDialogState extends State<_TexteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titre),
      content: SizedBox(
        width: 440,
        child: TextField(
          controller: _controller,
          autofocus: true,
          maxLength: 120,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: widget.libelle,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Revenir'),
        ),
        FilledButton(
          onPressed: _controller.text.trim().length >= 5
              ? () => Navigator.pop(context, _controller.text.trim())
              : null,
          child: Text(widget.bouton),
        ),
      ],
    );
  }
}
