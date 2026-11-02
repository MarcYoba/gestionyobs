import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:gestionyobs/modules/achat.dart';

import 'rapport.dart';

import 'package:gestionyobs/modules/stock.dart';
import 'package:gestionyobs/modules/vente.dart';

/// Fabrique le rapport en PDF, format A4.
class RapportPdf {
  static Future<Uint8List> generer(
    RapportDonnees r,
    InfosEntreprise infos,
  ) async {
    final tableaux = construireTableaux(r);

    final document = pw.Document(title: r.periode.titre, author: r.genererPar);

    pw.Widget cellule(
      TableauRapport t,
      String texte,
      int colonne, {
      bool gras = false,
      PdfColor? couleur,
    }) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2.5),
        child: pw.Text(
          texte,
          textAlign: t.droite.contains(colonne)
              ? pw.TextAlign.right
              : pw.TextAlign.left,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: gras ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: couleur,
          ),
        ),
      );
    }

    pw.Widget tableauPdf(TableauRapport t) {
      final rangees = <pw.TableRow>[
        // L'en-tête, répété en haut de chaque page
        pw.TableRow(
          repeat: true,
          decoration: const pw.BoxDecoration(color: PdfColors.green800),
          children: [
            for (var i = 0; i < t.entetes.length; i++)
              cellule(t, t.entetes[i], i, gras: true, couleur: PdfColors.white),
          ],
        ),
        for (var k = 0; k < t.lignes.length; k++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: k.isOdd ? PdfColors.grey100 : PdfColors.white,
            ),
            children: [
              for (var i = 0; i < t.lignes[k].length; i++)
                cellule(t, t.lignes[k][i], i),
            ],
          ),
        if (t.total != null)
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.green100),
            children: [
              for (var i = 0; i < t.total!.length; i++)
                cellule(t, t.total![i], i, gras: true),
            ],
          ),
      ];

      return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.4),
        columnWidths: {
          for (var i = 0; i < t.flex.length; i++)
            i: pw.FlexColumnWidth(t.flex[i].toDouble()),
        },
        children: rangees,
      );
    }

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 36),
        footer: (contexte) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              r.periode.titre,
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
            ),
            pw.Text(
              'Page ${contexte.pageNumber} / ${contexte.pagesCount}',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
            ),
          ],
        ),
        build: (contexte) => [
          if (infos.nom.isNotEmpty)
            pw.Text(
              infos.nom.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green800,
              ),
            ),
          pw.SizedBox(height: 2),
          pw.Text(
            r.periode.titre,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'Période : du ${formaterDate(r.periode.debut)} au '
            '${formaterDate(r.periode.fin)}   |   ${r.portee}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.Text(
            'Généré le ${formaterDateHeure(r.genereLe)} par ${r.genererPar}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.Divider(thickness: 0.8),

          for (var i = 0; i < tableaux.length; i++) ...[
            pw.SizedBox(height: 14),
            pw.Text(
              '${i + 1}. ${tableaux[i].titre}',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            if (tableaux[i].lignes.isEmpty)
              pw.Text(
                'Aucune opération sur cette période.',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            tableauPdf(tableaux[i]),
            if (tableaux[i].note != null)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 3),
                child: pw.Text(
                  tableaux[i].note!,
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
          ],
        ],
      ),
    );

    return document.save();
  }
}
