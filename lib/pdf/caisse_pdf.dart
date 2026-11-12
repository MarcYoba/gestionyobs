import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:gestionyobs/modules/achat.dart';
import 'package:gestionyobs/modules/article.dart';
import 'package:gestionyobs/modules/caisse.dart';
import 'package:gestionyobs/rapport/rapport.dart';
import 'package:gestionyobs/modules/stock.dart';
import 'package:gestionyobs/modules/vente.dart';

String _libelleCoupure(int valeur) =>
    valeur == 1 ? 'Autre (montant)' : formaterPrix(valeur);

/// Les tableaux du rapport de caisse. `fond` est le fond d'ouverture utilisé.
List<TableauRapport> construireTableauxCaisse(JourCaisse j, int fond) {
  String p(int v) => formaterPrix(v);
  final c = j.cloture;
  final tableaux = <TableauRapport>[];

  // 1. Les mouvements par mode de paiement
  final modes = j.modes
      .where((m) => m.physique || m.entrees != 0 || m.sorties != 0)
      .toList();
  final totE = j.modes.fold(0, (s, m) => s + m.entrees);
  final totS = j.modes.fold(0, (s, m) => s + m.sorties);
  tableaux.add(
    TableauRapport(
      titre: 'Mouvements par mode de paiement',
      entetes: ['Mode de paiement', 'Entrées', 'Sorties', 'Net'],
      lignes: [
        for (final m in modes)
          [
            m.physique ? '${m.libelle} (caisse)' : m.libelle,
            p(m.entrees),
            p(m.sorties),
            p(m.net),
          ],
      ],
      total: ['TOTAL', p(totE), p(totS), p(totE - totS)],
      flex: [4, 2, 2, 2],
      droite: {1, 2, 3},
    ),
  );

  // 2. La caisse en espèces
  final theorique = c?.theorique ?? (fond + j.netPhysique);
  tableaux.add(
    TableauRapport(
      titre: 'Caisse en espèces',
      entetes: ['Rubrique', 'Montant'],
      lignes: [
        ["Fond de caisse à l'ouverture", p(c?.fondOuverture ?? fond)],
        ['+ Entrées en espèces', p(c?.entrees ?? j.entreesPhysiques)],
        ['- Sorties en espèces', p(c?.sorties ?? j.sortiesPhysiques)],
        ['= Montant théorique en caisse', p(theorique)],
        if (c != null) ...[
          ['Montant compté', p(c.compte)],
          ['Écart (compté - théorique)', p(c.ecart)],
          ['Laissé en caisse pour demain', p(c.laisse)],
          ['Retiré de la caisse (versement)', p(c.verse)],
        ],
      ],
      flex: [5, 2],
      droite: {1},
      note: c?.note == null ? null : "Note d'écart : ${c!.note}",
    ),
  );

  // 3. Le comptage
  if (c != null && c.coupures.isNotEmpty) {
    final valeurs = coupuresCaisse
        .where((v) => (c.coupures[v] ?? 0) > 0)
        .toList();
    tableaux.add(
      TableauRapport(
        titre: 'Comptage',
        entetes: ['Valeur', 'Quantité', 'Montant'],
        lignes: [
          for (final v in valeurs)
            [_libelleCoupure(v), '${c.coupures[v]}', p(v * c.coupures[v]!)],
        ],
        total: ['TOTAL COMPTÉ', '', p(c.compte)],
        flex: [3, 2, 3],
        droite: {1, 2},
      ),
    );
  }

  // 4. Le journal du jour
  final entrees = j.mouvements
      .where((m) => m.flux > 0)
      .fold(0, (s, m) => s + m.flux);
  final sorties = j.mouvements
      .where((m) => m.flux < 0)
      .fold(0, (s, m) => s - m.flux);
  tableaux.add(
    TableauRapport(
      titre: 'Journal du jour',
      entetes: [
        'Heure',
        'Nature',
        'Document',
        'Libellé',
        'Mode',
        'Entrée',
        'Sortie',
      ],
      lignes: [
        for (final m in j.mouvements)
          [
            '${m.heure.hour.toString().padLeft(2, '0')}:${m.heure.minute.toString().padLeft(2, '0')}',
            m.nature,
            m.document,
            m.libelle,
            m.mode,
            m.flux > 0 ? p(m.flux) : '',
            m.flux < 0 ? p(-m.flux) : '',
          ],
      ],
      total: ['TOTAL', '', '', '', '', p(entrees), p(sorties)],
      flex: [1, 3, 3, 4, 2, 2, 2],
      droite: {5, 6},
    ),
  );

  return tableaux;
}

class CaissePdf {
  static Future<Uint8List> generer(
    JourCaisse j,
    InfosEntreprise infos,
    int fond,
  ) async {
    final tableaux = construireTableauxCaisse(j, fond);
    final c = j.cloture;
    final document = pw.Document(title: 'Caisse du ${formaterDate(j.date)}');

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
        ],
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
              'Caisse du ${formaterDate(j.date)} - ${j.agence}',
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
            'Journal de caisse du ${formaterDate(j.date)}',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 3),
          pw.Text(j.agence, style: const pw.TextStyle(fontSize: 9)),
          pw.Text(
            c == null
                ? "JOURNÉE NON CLÔTURÉE : chiffres provisoires"
                : 'Journée clôturée le ${formaterDateHeure(c.creeLe)} par ${c.par} (${c.code})',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: c == null ? PdfColors.red800 : PdfColors.green800,
            ),
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
                'Aucun mouvement.',
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
