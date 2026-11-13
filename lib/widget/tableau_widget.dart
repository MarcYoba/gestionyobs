import 'package:flutter/material.dart';
import 'package:gestionyobs/rapport/rapport.dart';

/// Un tableau (journal, grand livre, balance) affiché à l'écran.
class TableauWidget extends StatelessWidget {
  final TableauRapport tableau;
  final int? numero;
  final int maxLignes;
  final double minLargeur;

  const TableauWidget({
    super.key,
    required this.tableau,
    this.numero,
    this.maxLignes = 60,
    this.minLargeur = 0,
  });

  Widget _cellule(
    String texte,
    int colonne, {
    bool gras = false,
    Color? couleur,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        texte,
        textAlign: tableau.droite.contains(colonne)
            ? TextAlign.right
            : TextAlign.left,
        style: TextStyle(
          fontSize: 13,
          fontWeight: gras ? FontWeight.bold : FontWeight.normal,
          color: couleur,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lignes = tableau.lignes.take(maxLignes).toList();
    final coupe = tableau.lignes.length > maxLignes;

    final rangees = <TableRow>[
      TableRow(
        decoration: BoxDecoration(color: Colors.green.shade700),
        children: [
          for (var i = 0; i < tableau.entetes.length; i++)
            _cellule(tableau.entetes[i], i, gras: true, couleur: Colors.white),
        ],
      ),
      for (var k = 0; k < lignes.length; k++)
        TableRow(
          decoration: BoxDecoration(
            color: tableau.lignesGras.contains(k)
                ? Colors.green.shade50
                : (k.isOdd ? Colors.grey.shade100 : Colors.white),
          ),
          children: [
            for (var i = 0; i < lignes[k].length; i++)
              _cellule(lignes[k][i], i, gras: tableau.lignesGras.contains(k)),
          ],
        ),
      if (tableau.total != null)
        TableRow(
          decoration: BoxDecoration(color: Colors.green.shade100),
          children: [
            for (var i = 0; i < tableau.total!.length; i++)
              _cellule(tableau.total![i], i, gras: true),
          ],
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          numero == null ? tableau.titre : '$numero. ${tableau.titre}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        if (tableau.lignes.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Aucune opération sur cette période.',
              style: TextStyle(
                color: Colors.black54,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        LayoutBuilder(
          builder: (context, contraintes) {
            final largeur = contraintes.maxWidth < minLargeur
                ? minLargeur
                : contraintes.maxWidth;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: largeur,
                child: Table(
                  border: TableBorder.all(
                    color: Colors.grey.shade400,
                    width: 0.6,
                  ),
                  columnWidths: {
                    for (var i = 0; i < tableau.flex.length; i++)
                      i: FlexColumnWidth(tableau.flex[i].toDouble()),
                  },
                  children: rangees,
                ),
              ),
            );
          },
        ),
        if (coupe)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${tableau.lignes.length} lignes : les $maxLignes premières sont affichées ici. '
              'La liste complète est dans le PDF.',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        if (tableau.note != null && tableau.note!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              tableau.note!,
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }
}
