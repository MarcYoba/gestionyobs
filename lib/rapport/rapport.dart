import 'package:gestionyobs/modules/achat.dart';
import 'package:gestionyobs/modules/article.dart';

/// Nombre maximum de lignes dans les listes détaillées.
const int limiteLignesRapport = 3000;

const List<String> _mois = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];
const List<String> _jours = [
  'lundi',
  'mardi',
  'mercredi',
  'jeudi',
  'vendredi',
  'samedi',
  'dimanche',
];
const List<String> _joursCourts = [
  'lun.',
  'mar.',
  'mer.',
  'jeu.',
  'ven.',
  'sam.',
  'dim.',
];

String _deux(int n) => n.toString().padLeft(2, '0');
String _jourTexte(DateTime d) => '${d.year}-${_deux(d.month)}-${_deux(d.day)}';
String _majuscule(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

// Numéro de semaine ISO (la semaine commence le lundi)
int _semaineIso(DateTime d) {
  final jeudi = DateTime.utc(d.year, d.month, d.day + 4 - d.weekday);
  final debutAnnee = DateTime.utc(jeudi.year, 1, 1);
  return jeudi.difference(debutAnnee).inDays ~/ 7 + 1;
}

/// Un morceau d'une période (un jour, un mois) : une ligne du tableau d'évolution.
class SousPeriode {
  final String cle; // '2026-10-29' ou '2026-10'
  final String libelle;

  const SousPeriode({required this.cle, required this.libelle});
}

/// Une période de rapport : un jour, une semaine, un mois...
class PeriodeRapport {
  final String type;
  final DateTime debut;
  final DateTime fin;
  final String titre;

  const PeriodeRapport({
    required this.type,
    required this.debut,
    required this.fin,
    required this.titre,
  });

  static const Map<String, String> types = {
    'jour': 'Jour',
    'semaine': 'Semaine',
    'mois': 'Mois',
    'trimestre': 'Trimestre',
    'semestre': 'Semestre',
    'annee': 'Année',
  };

  // Les périodes longues sont détaillées par mois, les autres par jour
  bool get parMois =>
      type == 'trimestre' || type == 'semestre' || type == 'annee';

  String get debutTexte => _jourTexte(debut);
  String get finTexte => _jourTexte(fin);
  String get libelleColonne => parMois ? 'Mois' : 'Jour';

  /// La période qui contient la date de référence.
  factory PeriodeRapport.calculer(String type, DateTime reference) {
    final y = reference.year;
    final m = reference.month;
    final d = reference.day;

    if (type == 'jour') {
      final jour = DateTime(y, m, d);
      return PeriodeRapport(
        type: type,
        debut: jour,
        fin: jour,
        titre:
            'Rapport journalier : ${_jours[jour.weekday - 1]} $d ${_mois[m - 1]} $y',
      );
    }

    if (type == 'semaine') {
      final lundi = DateTime(y, m, d - (reference.weekday - 1));
      final dimanche = DateTime(lundi.year, lundi.month, lundi.day + 6);
      return PeriodeRapport(
        type: type,
        debut: lundi,
        fin: dimanche,
        titre:
            'Rapport hebdomadaire : semaine ${_semaineIso(lundi)} '
            '(du ${formaterDate(lundi)} au ${formaterDate(dimanche)})',
      );
    }

    if (type == 'mois') {
      return PeriodeRapport(
        type: type,
        debut: DateTime(y, m, 1),
        fin: DateTime(y, m + 1, 0),
        titre: 'Rapport mensuel : ${_majuscule(_mois[m - 1])} $y',
      );
    }

    if (type == 'trimestre') {
      final q = (m - 1) ~/ 3 + 1;
      final ordinal = q == 1 ? '1er' : '${q}e';
      return PeriodeRapport(
        type: type,
        debut: DateTime(y, (q - 1) * 3 + 1, 1),
        fin: DateTime(y, (q - 1) * 3 + 4, 0),
        titre: 'Rapport trimestriel : $ordinal trimestre $y',
      );
    }

    if (type == 'semestre') {
      final s = (m - 1) ~/ 6 + 1;
      final ordinal = s == 1 ? '1er' : '${s}e';
      return PeriodeRapport(
        type: type,
        debut: DateTime(y, (s - 1) * 6 + 1, 1),
        fin: DateTime(y, (s - 1) * 6 + 7, 0),
        titre: 'Rapport semestriel : $ordinal semestre $y',
      );
    }

    return PeriodeRapport(
      type: 'annee',
      debut: DateTime(y, 1, 1),
      fin: DateTime(y, 12, 31),
      titre: "Rapport annuel : année $y",
    );
  }

  /// Une date de la période précédente (-1) ou suivante (+1).
  DateTime decaler(int sens) => sens > 0
      ? DateTime(fin.year, fin.month, fin.day + 1)
      : DateTime(debut.year, debut.month, debut.day - 1);

  /// Les lignes du tableau d'évolution (vide pour un rapport journalier).
  List<SousPeriode> sousPeriodes() {
    final liste = <SousPeriode>[];
    if (type == 'jour') return liste;

    if (parMois) {
      for (var mois = debut.month; mois <= fin.month; mois++) {
        liste.add(
          SousPeriode(
            cle: '${debut.year}-${_deux(mois)}',
            libelle: '${_majuscule(_mois[mois - 1])} ${debut.year}',
          ),
        );
      }
      return liste;
    }

    for (
      var j = debut;
      !j.isAfter(fin);
      j = DateTime(j.year, j.month, j.day + 1)
    ) {
      liste.add(
        SousPeriode(
          cle: _jourTexte(j),
          libelle:
              '${_joursCourts[j.weekday - 1]} ${_deux(j.day)}/${_deux(j.month)}',
        ),
      );
    }
    return liste;
  }
}

class LigneEvolution {
  final String libelle;
  final int ventes;
  final int achats;
  final int encaissements;
  final int marge;

  const LigneEvolution({
    required this.libelle,
    required this.ventes,
    required this.achats,
    required this.encaissements,
    required this.marge,
  });
}

class OpVente {
  final String code;
  final DateTime date;
  final String client;
  final String agence;
  final int brut;
  final int remise;
  final int net;

  const OpVente({
    required this.code,
    required this.date,
    required this.client,
    required this.agence,
    required this.brut,
    required this.remise,
    required this.net,
  });
}

class OpAchat {
  final String code;
  final DateTime date;
  final String fournisseur;
  final String agence;
  final int total;

  const OpAchat({
    required this.code,
    required this.date,
    required this.fournisseur,
    required this.agence,
    required this.total,
  });
}

class ModeEncaisse {
  final String mode;
  final int nombre;
  final int montant;

  const ModeEncaisse({
    required this.mode,
    required this.nombre,
    required this.montant,
  });
}

class MargeArticle {
  final String code;
  final String designation;
  final double quantite;
  final int ca; // ventes nettes
  final int cout; // coût d'achat

  const MargeArticle({
    required this.code,
    required this.designation,
    required this.quantite,
    required this.ca,
    required this.cout,
  });

  int get marge => ca - cout;
}

/// Un client (créance) ou un fournisseur (dette) avec ce qu'il reste dû.
class SoldeRapport {
  final String nom;
  final int nombre;
  final int montant;

  const SoldeRapport({
    required this.nom,
    required this.nombre,
    required this.montant,
  });
}

class TotauxRapport {
  final int nbVentes;
  final int ventesBrut;
  final int remises;
  final int ventesNet;
  final int nbAchats;
  final int achats;
  final int nbEncaissements;
  final int encaisse;
  final int marge;
  final int coutVendu;
  final int caAvecCout;
  final int nbLignesSansCout;
  final int caSansCout;
  final int creances;
  final int nbCreances;
  final int dettes;
  final int nbDettes;

  const TotauxRapport({
    this.nbVentes = 0,
    this.ventesBrut = 0,
    this.remises = 0,
    this.ventesNet = 0,
    this.nbAchats = 0,
    this.achats = 0,
    this.nbEncaissements = 0,
    this.encaisse = 0,
    this.marge = 0,
    this.coutVendu = 0,
    this.caAvecCout = 0,
    this.nbLignesSansCout = 0,
    this.caSansCout = 0,
    this.creances = 0,
    this.nbCreances = 0,
    this.dettes = 0,
    this.nbDettes = 0,
  });
}

/// Toutes les données d'un rapport.
class RapportDonnees {
  final PeriodeRapport periode;
  final String portee; // « Agence X » ou « Toutes les agences »
  final bool toutesAgences;
  final bool detail;
  final bool voirVentes;
  final bool voirAchats;
  final bool voirEncaissements;
  final bool voirMarges;
  final bool voirCreances;
  final TotauxRapport totaux;
  final List<LigneEvolution> evolution;
  final List<OpVente> ventes;
  final bool ventesTronquees;
  final List<OpAchat> achats;
  final bool achatsTronques;
  final List<ModeEncaisse> modes;
  final List<MargeArticle> marges;
  final bool margesTronquees;
  final List<SoldeRapport> creances;
  final List<SoldeRapport> dettes;
  final DateTime genereLe;
  final String genererPar;

  const RapportDonnees({
    required this.periode,
    required this.portee,
    required this.toutesAgences,
    required this.detail,
    required this.voirVentes,
    required this.voirAchats,
    required this.voirEncaissements,
    required this.voirMarges,
    required this.voirCreances,
    required this.totaux,
    required this.evolution,
    required this.ventes,
    required this.ventesTronquees,
    required this.achats,
    required this.achatsTronques,
    required this.modes,
    required this.marges,
    required this.margesTronquees,
    required this.creances,
    required this.dettes,
    required this.genereLe,
    required this.genererPar,
  });
}

/// Un tableau à afficher (à l'écran et dans le PDF).
class TableauRapport {
  final String titre;
  final List<String> entetes;
  final List<List<String>> lignes;
  final List<String>? total;
  final List<int> flex; // largeurs relatives des colonnes
  final Set<int> droite; // colonnes alignées à droite (les nombres)
  final String? note;

  const TableauRapport({
    required this.titre,
    required this.entetes,
    required this.lignes,
    this.total,
    required this.flex,
    this.droite = const {},
    this.note,
  });
}

/// Fabrique les tableaux d'un rapport, dans l'ordre d'affichage.
List<TableauRapport> construireTableaux(RapportDonnees r) {
  final t = r.totaux;
  final tableaux = <TableauRapport>[];
  String p(int v) => formaterPrix(v);

  // 1. Synthèse
  final synthese = <List<String>>[];
  if (r.voirVentes) {
    synthese.add(['Ventes (montant brut)', '${t.nbVentes}', p(t.ventesBrut)]);
    synthese.add([
      'Remises accordées',
      '',
      t.remises == 0 ? '0' : '-${p(t.remises)}',
    ]);
    synthese.add(['Ventes nettes (total des ventes)', '', p(t.ventesNet)]);
  }
  if (r.voirAchats) {
    synthese.add(['Achats (total)', '${t.nbAchats}', p(t.achats)]);
  }
  if (r.voirEncaissements) {
    synthese.add([
      'Encaissements (paiements reçus des clients)',
      '${t.nbEncaissements}',
      p(t.encaisse),
    ]);
  }
  if (r.voirMarges) {
    synthese.add([
      "Marge brute (prix de vente - prix d'achat)",
      '',
      p(t.marge),
    ]);
  }
  if (r.voirCreances) {
    synthese.add([
      'Créances clients (fin de période)',
      '${t.nbCreances}',
      p(t.creances),
    ]);
    synthese.add([
      'Dettes fournisseurs (fin de période)',
      '${t.nbDettes}',
      p(t.dettes),
    ]);
    synthese.add([
      'Position nette (créances - dettes)',
      '',
      p(t.creances - t.dettes),
    ]);
  }
  tableaux.add(
    TableauRapport(
      titre: 'Synthèse de la période',
      entetes: ['Rubrique', 'Nombre', 'Montant'],
      lignes: synthese,
      flex: [6, 1, 2],
      droite: {1, 2},
    ),
  );

  // 2. Évolution par jour ou par mois
  if (r.evolution.isNotEmpty) {
    final entetes = [
      r.periode.libelleColonne,
      if (r.voirVentes) 'Ventes nettes',
      if (r.voirAchats) 'Achats',
      if (r.voirEncaissements) 'Encaissements',
      if (r.voirMarges) 'Marge',
    ];

    List<String> ligne(String nom, int v, int a, int e, int m) => [
      nom,
      if (r.voirVentes) p(v),
      if (r.voirAchats) p(a),
      if (r.voirEncaissements) p(e),
      if (r.voirMarges) p(m),
    ];

    tableaux.add(
      TableauRapport(
        titre: 'Évolution ${r.periode.parMois ? 'par mois' : 'par jour'}',
        entetes: entetes,
        lignes: [
          for (final e in r.evolution)
            ligne(e.libelle, e.ventes, e.achats, e.encaissements, e.marge),
        ],
        total: ligne('TOTAL', t.ventesNet, t.achats, t.encaisse, t.marge),
        flex: List.filled(entetes.length, 2),
        droite: {for (var i = 1; i < entetes.length; i++) i},
      ),
    );
  }

  // 3. Les ventes
  if (r.voirVentes && r.detail) {
    tableaux.add(
      TableauRapport(
        titre: 'Ventes',
        entetes: ['N° facture', 'Date', 'Client', 'Brut', 'Remise', 'Net'],
        lignes: [
          for (final v in r.ventes)
            [
              v.code,
              formaterDate(v.date),
              r.toutesAgences ? '${v.client} (${v.agence})' : v.client,
              p(v.brut),
              v.remise == 0 ? '' : '-${p(v.remise)}',
              p(v.net),
            ],
        ],
        total: [
          'TOTAL',
          '${t.nbVentes} vente(s)',
          '',
          p(t.ventesBrut),
          t.remises == 0 ? '' : '-${p(t.remises)}',
          p(t.ventesNet),
        ],
        flex: [3, 2, 4, 2, 2, 2],
        droite: {3, 4, 5},
        note: r.ventesTronquees
            ? 'Liste limitée aux $limiteLignesRapport premières lignes. '
                  'Les totaux portent sur toutes les ventes.'
            : null,
      ),
    );
  }

  // 4. Les achats
  if (r.voirAchats && r.detail) {
    tableaux.add(
      TableauRapport(
        titre: 'Achats',
        entetes: ['N° achat', 'Date', 'Fournisseur', 'Total'],
        lignes: [
          for (final a in r.achats)
            [
              a.code,
              formaterDate(a.date),
              r.toutesAgences
                  ? '${a.fournisseur} (${a.agence})'
                  : a.fournisseur,
              p(a.total),
            ],
        ],
        total: ['TOTAL', '${t.nbAchats} achat(s)', '', p(t.achats)],
        flex: [3, 2, 5, 2],
        droite: {3},
        note: r.achatsTronques
            ? 'Liste limitée aux $limiteLignesRapport premières lignes. '
                  'Les totaux portent sur tous les achats.'
            : null,
      ),
    );
  }

  // 5. Les encaissements, par mode de paiement
  if (r.voirEncaissements) {
    tableaux.add(
      TableauRapport(
        titre: 'Encaissements par mode de paiement',
        entetes: ['Mode de paiement', 'Nombre', 'Montant'],
        lignes: [
          for (final m in r.modes) [m.mode, '${m.nombre}', p(m.montant)],
        ],
        total: [
          'TOTAL DES ENCAISSEMENTS',
          '${t.nbEncaissements}',
          p(t.encaisse),
        ],
        flex: [5, 1, 2],
        droite: {1, 2},
      ),
    );
  }

  // 6. Les marges, par article
  if (r.voirMarges) {
    final notes = <String>[
      if (t.nbLignesSansCout > 0)
        "${t.nbLignesSansCout} ligne(s) de vente sans prix d'achat connu "
            '(ventes de ${p(t.caSansCout)}) ne sont pas comptées dans la marge.',
      if (r.margesTronquees)
        'Liste limitée aux 500 articles les plus rentables.',
    ];

    tableaux.add(
      TableauRapport(
        titre: 'Marges par article',
        entetes: ['Article', 'Qté', 'Ventes nettes', "Coût d'achat", 'Marge'],
        lignes: [
          for (final m in r.marges)
            [
              '${m.designation} (${m.code})',
              formaterQuantite(m.quantite),
              p(m.ca),
              p(m.cout),
              p(m.marge),
            ],
        ],
        total: [
          'TOTAL GÉNÉRAL',
          '',
          p(t.caAvecCout),
          p(t.coutVendu),
          p(t.marge),
        ],
        flex: [6, 1, 2, 2, 2],
        droite: {1, 2, 3, 4},
        note: notes.isEmpty ? null : notes.join(' '),
      ),
    );
  }

  // 7. Les créances et les dettes
  if (r.voirCreances) {
    tableaux.add(
      TableauRapport(
        titre: 'Créances clients (ce que les clients doivent, fin de période)',
        entetes: ['Client', 'Factures', 'Montant dû'],
        lignes: [
          for (final c in r.creances) [c.nom, '${c.nombre}', p(c.montant)],
        ],
        total: ['TOTAL DES CRÉANCES', '${t.nbCreances}', p(t.creances)],
        flex: [5, 1, 2],
        droite: {1, 2},
      ),
    );

    tableaux.add(
      TableauRapport(
        titre: 'Dettes fournisseurs (ce que vous devez, fin de période)',
        entetes: ['Fournisseur', 'Achats', 'Montant dû'],
        lignes: [
          for (final d in r.dettes) [d.nom, '${d.nombre}', p(d.montant)],
        ],
        total: ['TOTAL DES DETTES', '${t.nbDettes}', p(t.dettes)],
        flex: [5, 1, 2],
        droite: {1, 2},
      ),
    );
  }

  return tableaux;
}
