import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:gestionyobs/modules/achat.dart';
import 'package:gestionyobs/modules/article.dart';
import 'package:gestionyobs/config_service.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/modules/stock.dart';
import 'package:gestionyobs/modules/vente.dart';

/// Fabrique et imprime les tickets de caisse (58 mm ou 80 mm).
class TicketService {
  // Le format du papier : une bande étroite dont la hauteur s'adapte au contenu
  static PdfPageFormat _format(int largeur) {
    const mm = PdfPageFormat.mm;
    final base = largeur == 58 ? PdfPageFormat.roll57 : PdfPageFormat.roll80;
    return base.copyWith(
      marginLeft: 3 * mm,
      marginRight: 3 * mm,
      marginTop: 3 * mm,
      marginBottom: 10 * mm, // de la marge pour la coupe
    );
  }

  static Future<Uint8List> genererPdf({
    required VenteDetail vente,
    required InfosEntreprise infos,
    required int largeur,
    required int numeroImpression,
  }) async {
    final etroit = largeur == 58;
    final t = etroit ? 7.5 : 9.0; // taille du texte courant
    final petit = t - 1;
    final unite = infos.devise.isEmpty ? '' : ' ${infos.devise}';

    pw.TextStyle style(double taille, {bool gras = false}) => pw.TextStyle(
      fontSize: taille,
      fontWeight: gras ? pw.FontWeight.bold : pw.FontWeight.normal,
    );

    // Un texte à gauche, un montant à droite
    pw.Widget ligne(
      String gauche,
      String droite, {
      bool gras = false,
      double? taille,
    }) {
      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Text(gauche, style: style(taille ?? t, gras: gras)),
          ),
          pw.SizedBox(width: 4),
          pw.Text(droite, style: style(taille ?? t, gras: gras)),
        ],
      );
    }

    pw.Widget centre(String texte, {double? taille, bool gras = false}) {
      return pw.Center(
        child: pw.Text(
          texte,
          textAlign: pw.TextAlign.center,
          style: style(taille ?? t, gras: gras),
        ),
      );
    }

    pw.Widget trait() => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Divider(
        height: 1,
        thickness: 0.5,
        borderStyle: pw.BorderStyle.dashed,
      ),
    );

    final contenu = <pw.Widget>[
      // En-tête
      if (infos.nom.isNotEmpty)
        centre(infos.nom.toUpperCase(), taille: t + 2, gras: true),
      centre(
        'Agence ${vente.agence}'
        '${vente.agenceVille == null ? '' : ' - ${vente.agenceVille}'}',
        taille: petit,
      ),
      if (vente.agenceTelephone != null)
        centre('Tél : ${vente.agenceTelephone}', taille: petit),
      if (infos.infos.isNotEmpty) centre(infos.infos, taille: petit),
      trait(),

      // La facture
      centre('FACTURE N° ${vente.code}', gras: true),
      if (numeroImpression > 1)
        centre('*** DUPLICATA n°$numeroImpression ***', gras: true),
      pw.SizedBox(height: 2),
      pw.Text('Date : ${formaterDateHeure(vente.date)}', style: style(petit)),
      pw.Text('Client : ${vente.client}', style: style(petit)),
      pw.Text('Vendeur : ${vente.vendeur}', style: style(petit)),
      trait(),

      // Les articles : le nom, puis la quantité, le prix et le montant
      for (final l in vente.lignes) ...[
        pw.Text(l.designation, style: style(t, gras: true)),
        ligne(
          '  ${formaterQuantite(l.quantite)} x ${formaterPrix(l.prixUnitaire)}',
          formaterPrix(l.totalBrut),
        ),
        if (l.remise > 0)
          ligne('  Remise', '-${formaterPrix(l.remise)}', taille: petit),
        pw.SizedBox(height: 2),
      ],
      trait(),

      // Les totaux
      ligne('Total', formaterPrix(vente.totalBrut)),
      if (vente.totalRemise > 0)
        ligne('Remise', '-${formaterPrix(vente.totalRemise)}'),
      if (vente.totalTva > 0) ligne('TVA', formaterPrix(vente.totalTva)),
      pw.SizedBox(height: 2),
      ligne(
        'NET A PAYER',
        '${formaterPrix(vente.netAPayer)}$unite',
        gras: true,
        taille: t + 3,
      ),
      trait(),

      // Les paiements
      for (final p in vente.paiements) ...[
        ligne(p.mode, formaterPrix(p.montant)),
        if (p.reference != null)
          pw.Text('  Réf. ${p.reference}', style: style(petit)),
      ],
      ligne('Reçu', formaterPrix(vente.recu)),
      if (vente.monnaieRendue > 0)
        ligne('Monnaie rendue', formaterPrix(vente.monnaieRendue), gras: true),
      if (vente.reste > 0)
        ligne(
          'RESTE A PAYER (credit)',
          '${formaterPrix(vente.reste)}$unite',
          gras: true,
        ),
      trait(),

      // Le pied
      if (infos.message.isNotEmpty) centre(infos.message, taille: petit),
      pw.SizedBox(height: 6),
    ];

    final document = pw.Document(title: 'Facture ${vente.code}');
    document.addPage(
      pw.Page(
        pageFormat: _format(largeur),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: contenu,
        ),
      ),
    );
    return document.save();
  }

  static Future<List<Printer>> listerImprimantes() => Printing.listPrinters();

  // Envoie le ticket à l'imprimante : directement sur celle réglée sur ce poste,
  // ou avec la fenêtre d'impression de Windows (si aucune n'est réglée,
  // ou si avecDialogue est vrai).
  // Envoie le ticket à l'imprimante réglée sur ce poste, ou à l'imprimante
  // par défaut de Windows. La fenêtre de Windows n'apparaît que si avecDialogue
  // est vrai, ou si Windows n'a aucune imprimante par défaut.
  static Future<void> _envoyer(
    Uint8List octets,
    AppConfig config,
    String nom, {
    bool avecDialogue = false,
  }) async {
    final format = _format(config.largeurPapier);

    if (!avecDialogue) {
      final imprimantes = await Printing.listPrinters();
      Printer? cible;

      if (config.imprimante != null) {
        for (final p in imprimantes) {
          if (p.name == config.imprimante) cible = p;
        }
        if (cible == null) {
          throw Exception(
            "L'imprimante « ${config.imprimante} » est introuvable. "
            "Vérifiez qu'elle est branchée, ou changez-la dans « Impression ».",
          );
        }
      } else {
        for (final p in imprimantes) {
          if (p.isDefault) cible = p;
        }
      }

      if (cible != null) {
        final ok = await Printing.directPrintPdf(
          printer: cible,
          onLayout: (_) async => octets,
          name: nom,
          format: format,
          usePrinterSettings: config.reglagesImprimante,
        );
        if (!ok) throw Exception("L'impression a échoué");
        return;
      }
    }

    // La fenêtre d'impression de Windows
    final ok = await Printing.layoutPdf(
      onLayout: (_) async => octets,
      name: nom,
      format: format,
      usePrinterSettings: config.reglagesImprimante,
    );
    if (!ok) throw Exception('Impression annulée');
  }

  // Imprime la facture d'une vente et compte l'impression
  static Future<void> imprimerVente(
    int venteId, {
    bool avecDialogue = false,
  }) async {
    final config = await ConfigService.lire();
    if (config == null) throw Exception('Configuration introuvable');

    final vente = await DatabaseService.detailVente(venteId);
    final infos = await DatabaseService.lireInfosEntreprise();

    final octets = await genererPdf(
      vente: vente,
      infos: infos,
      largeur: config.largeurPapier,
      numeroImpression: vente.nbImpressions + 1,
    );

    await _envoyer(
      octets,
      config,
      'Facture ${vente.code}',
      avecDialogue: avecDialogue,
    );
    await DatabaseService.noterImpression(venteId);
  }

  // Un ticket d'exemple, pour tester l'imprimante et la mise en page
  static Future<void> imprimerTest(
    AppConfig config,
    InfosEntreprise infos,
  ) async {
    final maintenant = DateTime.now();
    final exemple = VenteDetail(
      code: '26102900001',
      date: maintenant,
      agence: 'Agence Centrale',
      agenceVille: 'Ville',
      agenceTelephone: '600 00 00 00',
      client: 'Client comptant',
      vendeur: 'Caissier',
      note: null,
      statut: 'valide',
      totalBrut: 4500,
      totalRemise: 200,
      totalTva: 0,
      netAPayer: 4300,
      monnaieRendue: 700,
      nbImpressions: 0,
      lignes: const [
        LigneVente(
          code: 'A1',
          designation: 'Marteau 500 g',
          unite: 'pièce',
          quantite: 1,
          prixUnitaire: 2500,
          remise: 200,
          totalBrut: 2500,
          totalNet: 2300,
        ),
        LigneVente(
          code: 'A2',
          designation: 'Câble électrique 2,5 mm',
          unite: 'mètre',
          quantite: 2.5,
          prixUnitaire: 800,
          remise: 0,
          totalBrut: 2000,
          totalNet: 2000,
        ),
      ],
      paiements: [
        PaiementAchat(
          mode: 'Espèces',
          montant: 4300,
          reference: null,
          date: maintenant,
          utilisateur: 'Caissier',
        ),
      ],
    );

    final octets = await genererPdf(
      vente: exemple,
      infos: infos,
      largeur: config.largeurPapier,
      numeroImpression: 1,
    );
    await _envoyer(octets, config, 'Ticket de test');
  }
}
