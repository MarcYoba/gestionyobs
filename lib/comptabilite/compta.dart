import 'package:gestionyobs/modules/achat.dart';
import 'package:gestionyobs/modules/article.dart';
import 'package:gestionyobs/modules/compte_comptable.dart';
import 'package:gestionyobs/rapport/rapport.dart';

/// Nombre maximum de lignes d'écriture dans un état.
const int limiteLignesCompta = 6000;

/// Les journaux : code -> libellé.
const Map<String, String> journauxCompta = {
  'VT': 'Ventes',
  'AC': 'Achats',
  'CA': 'Caisse',
  'MO': 'Mobile money',
  'BQ': 'Banque',
  'OD': 'Opérations diverses',
};

// ---------- La comptabilisation ----------

/// Une ligne d'écriture à enregistrer.
class LigneAPoster {
  final String compte;
  final String intitule;
  final int? tiersId;
  final int debit;
  final int credit;

  const LigneAPoster({
    required this.compte,
    required this.intitule,
    this.tiersId,
    this.debit = 0,
    this.credit = 0,
  });
}

/// Une écriture à enregistrer.
class EcritureAPoster {
  final String journal;
  final int agenceId;
  final String date; // AAAA-MM-JJ
  final String libelle;
  final String sourceType;
  final int sourceId;
  final List<LigneAPoster> lignes;

  const EcritureAPoster({
    required this.journal,
    required this.agenceId,
    required this.date,
    required this.libelle,
    required this.sourceType,
    required this.sourceId,
    required this.lignes,
  });

  int get totalDebit => lignes.fold(0, (s, l) => s + l.debit);
  int get totalCredit => lignes.fold(0, (s, l) => s + l.credit);
}

/// Le bilan d'une comptabilisation.
class ResultatComptabilisation {
  final int crees; // écritures enregistrées
  final int bloques; // opérations en attente
  final List<String> manquants; // postes sans compte associé
  final List<String> anomalies;

  const ResultatComptabilisation({
    required this.crees,
    required this.bloques,
    required this.manquants,
    required this.anomalies,
  });
}

class StatistiquesCompta {
  final int nbEcritures;
  final int totalDebit;
  final DateTime? derniere;

  const StatistiquesCompta({
    required this.nbEcritures,
    required this.totalDebit,
    required this.derniere,
  });
}

// ---------- Le journal ----------

class LigneEcriture {
  final String compte;
  final String intitule;
  final String? tiers;
  final int debit;
  final int credit;

  const LigneEcriture({
    required this.compte,
    required this.intitule,
    required this.tiers,
    required this.debit,
    required this.credit,
  });
}

class EcritureJournal {
  final String numero;
  final String journal;
  final DateTime date;
  final String libelle;
  final String agence;
  final List<LigneEcriture> lignes;

  const EcritureJournal({
    required this.numero,
    required this.journal,
    required this.date,
    required this.libelle,
    required this.agence,
    required this.lignes,
  });
}

class JournalDonnees {
  final List<EcritureJournal> ecritures;
  final bool tronque;
  final int nbEcritures;
  final int totalDebit;
  final int totalCredit;

  const JournalDonnees({
    required this.ecritures,
    required this.tronque,
    required this.nbEcritures,
    required this.totalDebit,
    required this.totalCredit,
  });
}

// ---------- Le grand livre ----------

class LigneGrandLivre {
  final DateTime date;
  final String piece;
  final String libelle;
  final int debit;
  final int credit;

  const LigneGrandLivre({
    required this.date,
    required this.piece,
    required this.libelle,
    required this.debit,
    required this.credit,
  });
}

class CompteGrandLivre {
  final String numero;
  final String intitule;
  final int report; // solde avant la période (débit - crédit)
  final List<LigneGrandLivre> lignes = [];
  int totalDebit = 0;
  int totalCredit = 0;

  CompteGrandLivre({
    required this.numero,
    required this.intitule,
    required this.report,
  });
}

class GrandLivreDonnees {
  final List<CompteGrandLivre> comptes;
  final bool tronque;

  const GrandLivreDonnees({required this.comptes, required this.tronque});
}

// ---------- La balance ----------

class LigneBalance {
  final String numero;
  final String intitule;
  final int od; // report : débit
  final int oc; // report : crédit
  final int md; // mouvements : débit
  final int mc; // mouvements : crédit

  const LigneBalance({
    required this.numero,
    required this.intitule,
    required this.od,
    required this.oc,
    required this.md,
    required this.mc,
  });
}

class BalanceDonnees {
  final List<LigneBalance> lignes;

  const BalanceDonnees({required this.lignes});
}

// ---------- Les tableaux, à l'écran et dans le PDF ----------

String _montant(int v) => v == 0 ? '' : formaterPrix(v);

String _solde(int v) =>
    v == 0 ? '0' : (v > 0 ? '${formaterPrix(v)} D' : '${formaterPrix(-v)} C');

List<TableauRapport> tableauxJournal(
  JournalDonnees d, {
  required bool toutesAgences,
}) {
  final lignes = <List<String>>[];
  for (final e in d.ecritures) {
    for (var i = 0; i < e.lignes.length; i++) {
      final l = e.lignes[i];
      lignes.add([
        i == 0 ? formaterDate(e.date) : '',
        i == 0 ? e.numero : '',
        '${l.compte}  ${l.intitule}',
        i == 0
            ? (toutesAgences ? '${e.libelle} [${e.agence}]' : e.libelle)
            : (l.tiers ?? ''),
        _montant(l.debit),
        _montant(l.credit),
      ]);
    }
  }

  final notes = <String>[
    if (d.tronque)
      'Liste limitée à $limiteLignesCompta lignes. Choisissez une période plus courte '
          'ou un seul journal.',
    d.totalDebit == d.totalCredit
        ? 'Journal équilibré : le total des débits égale le total des crédits.'
        : 'ATTENTION : le total des débits et celui des crédits diffèrent.',
  ];

  return [
    TableauRapport(
      titre: 'Écritures',
      entetes: ['Date', 'N°', 'Compte', 'Libellé', 'Débit', 'Crédit'],
      lignes: lignes,
      total: [
        'TOTAL',
        '${d.nbEcritures} écriture(s)',
        '',
        '',
        formaterPrix(d.totalDebit),
        formaterPrix(d.totalCredit),
      ],
      flex: [2, 3, 6, 7, 2, 2],
      droite: {4, 5},
      note: notes.join(' '),
    ),
  ];
}

List<TableauRapport> tableauxGrandLivre(GrandLivreDonnees d) {
  final tableaux = <TableauRapport>[];

  for (var i = 0; i < d.comptes.length; i++) {
    final c = d.comptes[i];
    var courant = c.report;
    final lignes = <List<String>>[];

    if (c.report != 0) {
      lignes.add(['', '', 'Solde reporté', '', '', _solde(c.report)]);
    }
    for (final l in c.lignes) {
      courant += l.debit - l.credit;
      lignes.add([
        formaterDate(l.date),
        l.piece,
        l.libelle,
        _montant(l.debit),
        _montant(l.credit),
        _solde(courant),
      ]);
    }

    final dernier = c.report + c.totalDebit - c.totalCredit;
    tableaux.add(
      TableauRapport(
        titre: '${c.numero}  ${c.intitule}',
        entetes: ['Date', 'Pièce', 'Libellé', 'Débit', 'Crédit', 'Solde'],
        lignes: lignes,
        total: [
          '',
          '',
          'TOTAL DES MOUVEMENTS',
          formaterPrix(c.totalDebit),
          formaterPrix(c.totalCredit),
          _solde(dernier),
        ],
        flex: [2, 3, 7, 2, 2, 3],
        droite: {3, 4, 5},
        note: (i == d.comptes.length - 1 && d.tronque)
            ? 'Liste limitée à $limiteLignesCompta lignes : les derniers comptes sont incomplets. '
                  'Choisissez une période plus courte ou un compte précis.'
            : null,
      ),
    );
  }
  return tableaux;
}

List<TableauRapport> tableauxBalance(BalanceDonnees d) {
  final lignes = <List<String>>[];
  final gras = <int>{};
  final total = List<int>.filled(6, 0);
  var classe = List<int>.filled(6, 0);
  String? classeCourante;

  // Report D, Report C, Mouvements D, Mouvements C, Solde D, Solde C
  List<int> colonnes(LigneBalance b) {
    final report = b.od - b.oc;
    final solde = b.od + b.md - b.oc - b.mc;
    return [
      report > 0 ? report : 0,
      report < 0 ? -report : 0,
      b.md,
      b.mc,
      solde > 0 ? solde : 0,
      solde < 0 ? -solde : 0,
    ];
  }

  void fermerClasse() {
    if (classeCourante == null) return;
    final n = int.tryParse(classeCourante!) ?? 0;
    gras.add(lignes.length);
    lignes.add([
      '',
      'Total classe $classeCourante : ${nomsClasses[n] ?? ''}',
      ...classe.map(_montant),
    ]);
    classe = List<int>.filled(6, 0);
  }

  for (final b in d.lignes) {
    final c = colonnes(b);
    if (c.every((v) => v == 0)) continue;

    final nouvelle = b.numero.substring(0, 1);
    if (nouvelle != classeCourante) {
      fermerClasse();
      classeCourante = nouvelle;
    }
    lignes.add([b.numero, b.intitule, ...c.map(_montant)]);
    for (var i = 0; i < 6; i++) {
      classe[i] += c[i];
      total[i] += c[i];
    }
  }
  fermerClasse();

  final equilibre =
      total[0] == total[1] && total[2] == total[3] && total[4] == total[5];

  return [
    TableauRapport(
      titre: 'Balance des comptes',
      entetes: [
        'Compte',
        'Intitulé',
        'Report D',
        'Report C',
        'Mouv. D',
        'Mouv. C',
        'Solde D',
        'Solde C',
      ],
      lignes: lignes,
      total: ['TOTAL GÉNÉRAL', '', ...total.map(formaterPrix)],
      flex: [2, 6, 2, 2, 2, 2, 2, 2],
      droite: {2, 3, 4, 5, 6, 7},
      lignesGras: gras,
      note: equilibre
          ? 'Balance équilibrée : débits = crédits pour le report, les mouvements et les soldes.'
          : 'ATTENTION : la balance est déséquilibrée.',
    ),
  ];
}
