import 'package:flutter/material.dart';

import 'stock.dart';

/// Qui a annulé un document, quand et pourquoi.
class InfoAnnulation {
  final DateTime date;
  final String utilisateur;
  final String motif;

  const InfoAnnulation({
    required this.date,
    required this.utilisateur,
    required this.motif,
  });
}

/// Bandeau rouge affiché en haut d'un document annulé.
/// Bandeau rouge affiché en haut d'un document annulé.
class BandeauAnnulation extends StatelessWidget {
  final InfoAnnulation info;
  final String? titre; // <-- 1. Ajouter le champ optionnel

  const BandeauAnnulation({
    super.key,
    required this.info,
    this.titre, // <-- 2. L'ajouter dans le constructeur
  });

  @override
  Widget build(BuildContext context) {
    // 3. Utiliser le titre personnalisé s'il existe, sinon le texte par défaut
    final texteTitre =
        titre ??
        'ANNULÉE le ${formaterDateHeure(info.date)} par ${info.utilisateur}';

    return Card(
      color: Colors.red.shade50,
      child: ListTile(
        leading: const Icon(Icons.cancel, color: Colors.red),
        title: Text(
          texteTitre,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        subtitle: Text('Motif : ${info.motif}'),
      ),
    );
  }
}

/// Demande le motif, puis confirme. Retourne le motif, ou null si on renonce.
class MotifAnnulationDialog extends StatefulWidget {
  final String titre;
  final String avertissement;

  const MotifAnnulationDialog({
    super.key,
    required this.titre,
    required this.avertissement,
  });

  @override
  State<MotifAnnulationDialog> createState() => _MotifAnnulationDialogState();
}

class _MotifAnnulationDialogState extends State<MotifAnnulationDialog> {
  final _controller = TextEditingController();

  bool get _valide => _controller.text.trim().length >= 3;

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
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.avertissement),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: 200,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: "Motif de l'annulation (obligatoire)",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Revenir'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: _valide
              ? () => Navigator.pop(context, _controller.text.trim())
              : null,
          child: const Text('Annuler le document'),
        ),
      ],
    );
  }
}
