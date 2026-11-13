import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:gestionyobs/rapport/rapport.dart';
import 'package:gestionyobs/modules/stock.dart';
import 'package:gestionyobs/modules/vente.dart';

class ComptaPdf {
  static Future<Uint8List> generer({
    required String titre,
    required List<String> infosLignes,
    required List<TableauRapport> tableaux,
    required InfosEntreprise infos,
    required String auteur,
    bool paysage = false,
    bool sautDePage = false,
  }) async {
    final document = pw.Document(title: titre, author: auteur);

    pw.Widget cellule(
      TableauRapport t,
      String texte,
      int colonne, {
      bool gras = false,
      PdfColor? couleur,
    }) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2.2),
        child: pw.Text(
          texte,
          textAlign: t.droite.contains(colonne)
              ? pw.TextAlign.right
              : pw.TextAlign.left,
          style: pw.TextStyle(
            fontSize: 7.5,
            fontWeight: gras ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: couleur,
          ),
        ),
      );
    }

    pw.Widget tableauPdf(TableauRapport t) {
      return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.4),
        columnWidths: {
          for (var i = 0; i < t.flex.length; i++)
            i: pw.FlexColumnWidth(t.flex[i].toDouble()),
        },
        children: [
          pw.TableRow(
            repeat: true,
            decoration: const pw.BoxDecoration(color: PdfColors.green800),
            children: [
              for (var i = 0; i < t.entetes.length; i++)
                cellule(
                  t,
                  t.entetes[i],
                  i,
                  gras: true,
                  couleur: PdfColors.white,
                ),
            ],
          ),
          for (var k = 0; k < t.lignes.length; k++)
            pw.TableRow(
              decoration: pw.BoxDecoration(
                color: t.lignesGras.contains(k)
                    ? PdfColors.green50
                    : (k.isOdd ? PdfColors.grey100 : PdfColors.white),
              ),
              children: [
                for (var i = 0; i < t.lignes[k].length; i++)
                  cellule(t, t.lignes[k][i], i, gras: t.lignesGras.contains(k)),
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
        ],
      );
    }

    document.addPage(
      pw.MultiPage(
        pageFormat: paysage ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 36),
        footer: (contexte) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              titre,
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
            titre,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 3),
          for (final ligne in infosLignes)
            pw.Text(ligne, style: const pw.TextStyle(fontSize: 9)),
          pw.Text(
            'Généré le ${formaterDateHeure(DateTime.now())} par $auteur',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.Divider(thickness: 0.8),
          for (final t in tableaux) ...[
            if (sautDePage && !identical(t, tableaux.first)) pw.NewPage(),
            pw.SizedBox(height: 12),
            if (tableaux.length > 1 || t.titre != titre)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(
                  t.titre,
                  style: pw.TextStyle(
                    fontSize: 10.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            if (t.lignes.isEmpty)
              pw.Text(
                'Aucune opération.',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            tableauPdf(t),
            if (t.note != null && t.note!.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 3),
                child: pw.Text(
                  t.note!,
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
