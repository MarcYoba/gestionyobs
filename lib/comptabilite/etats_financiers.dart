import 'package:gestionyobs/modules/achat.dart';
import 'package:gestionyobs/modules/article.dart';
import 'package:gestionyobs/rapport/rapport.dart';

// ---------- Les lignes de chaque état et leurs formules ----------

/// Une ligne d'un état financier.
class LigneEtat {
  final String ref;
  final String libelle;
  final String note;
  final bool total; // ligne de total ou de sous-total (en gras)
  final String
  formule; // la valeur (passif, résultat) ou la colonne Brut (actif)
  final String? formuleAmort; // la colonne Amort. et dépréc. (actif seulement)

  const LigneEtat(
    this.ref,
    this.libelle,
    this.note,
    this.formule, {
    this.formuleAmort,
    this.total = false,
  });
}

const List<LigneEtat> lignesActif = [
  LigneEtat(
    'AD',
    'IMMOBILISATIONS INCORPORELLES',
    '3',
    '{AE}+{AF}+{AG}+{AH}',
    formuleAmort: '{AE}+{AF}+{AG}+{AH}',
    total: true,
  ),
  LigneEtat(
    'AE',
    'Frais de développement et de prospection',
    '',
    'SD(211)',
    formuleAmort: 'SC(2811,2911)',
  ),
  LigneEtat(
    'AF',
    'Brevets, licences, logiciels et droits similaires',
    '',
    'SD(212)',
    formuleAmort: 'SC(2812,2912)',
  ),
  LigneEtat(
    'AG',
    'Fonds commercial et droit au bail',
    '',
    'SD(215,216)',
    formuleAmort: 'SC(2815,2816,2915,2916)',
  ),
  LigneEtat(
    'AH',
    'Autres immobilisations incorporelles',
    '',
    'SD(218)',
    formuleAmort: 'SC(2818,2917,2918)',
  ),
  LigneEtat(
    'AI',
    'IMMOBILISATIONS CORPORELLES',
    '3',
    '{AJ}+{AK}+{AL}+{AM}+{AN}+{AP}',
    formuleAmort: '{AJ}+{AK}+{AL}+{AM}+{AN}+{AP}',
    total: true,
  ),
  LigneEtat('AJ', 'Terrains', '', 'SD(22)', formuleAmort: 'SC(282,292)'),
  LigneEtat(
    'AK',
    'Bâtiments',
    '',
    'SD(231,232,237,239)',
    formuleAmort: 'SC(2831,2931)',
  ),
  LigneEtat(
    'AL',
    'Aménagements, agencements et installations',
    '',
    'SD(233,234,235,238)',
    formuleAmort: 'SC(2838,2934)',
  ),
  LigneEtat(
    'AM',
    'Matériel, mobilier et actifs biologiques',
    '',
    'SD(241,242,243,244,246,247,248,2498)',
    formuleAmort: 'SC(2841,2842,2843,2844,2846,2847,2848,2941,2942,2943,2944,2946,2947,2948)',
  ),
  LigneEtat(
    'AN',
    'Matériel de transport',
    '',
    'SD(245,2495)',
    formuleAmort: 'SC(2845,2945)',
  ),
  LigneEtat(
    'AP',
    'Avances et acomptes versés sur immobilisations',
    '3',
    'SD(25)',
  ),
  LigneEtat(
    'AQ',
    'IMMOBILISATIONS FINANCIÈRES',
    '4',
    '{AR}+{AS}',
    formuleAmort: '{AR}+{AS}',
    total: true,
  ),
  LigneEtat(
    'AR',
    'Titres de participation',
    '',
    'SD(26)',
    formuleAmort: 'SC(296)',
  ),
  LigneEtat(
    'AS',
    'Autres immobilisations financières',
    '',
    'SD(271,275,276,277,278)',
    formuleAmort: 'SC(297)',
  ),
  LigneEtat(
    'AZ',
    'TOTAL ACTIF IMMOBILISÉ',
    '',
    '{AD}+{AI}+{AQ}',
    formuleAmort: '{AD}+{AI}+{AQ}',
    total: true,
  ),
  LigneEtat(
    'BA',
    'ACTIF CIRCULANT HAO',
    '5',
    'SD(485,488)',
    formuleAmort: 'SC(498)',
    total: true,
  ),
  LigneEtat(
    'BB',
    'STOCKS ET ENCOURS',
    '6',
    'SD(31,32,33,34,35,36,37,38)',
    formuleAmort: 'SC(39)',
    total: true,
  ),
  LigneEtat(
    'BG',
    'CRÉANCES ET EMPLOIS ASSIMILÉS',
    '',
    '{BH}+{BI}+{BJ}',
    formuleAmort: '{BH}+{BI}+{BJ}',
    total: true,
  ),
  LigneEtat(
    'BH',
    'Fournisseurs avances versés',
    '17',
    'SD(4091,4094,4098,401,402,408)',
    formuleAmort: 'SC(490)',
  ),
  LigneEtat('BI', 'Clients', '7', 'SD(411)', formuleAmort: 'SC(491)'),
  LigneEtat(
    'BJ',
    'Autres créances',
    '8',
    'SD(421,43,44,45,4711,4712,4751,476,467,4631,466,461,4621,1851,186,187,1891)',
    formuleAmort: 'SC(492)',
  ),
  LigneEtat(
    'BK',
    'TOTAL ACTIFS CIRCULANTS',
    '',
    '{BA}+{BB}+{BG}',
    formuleAmort: '{BA}+{BB}+{BG}',
    total: true,
  ),
  LigneEtat(
    'BQ',
    'Titres de placement',
    '9',
    'SD(50)',
    formuleAmort: 'SC(590)',
  ),
  LigneEtat(
    'BR',
    'Valeurs à encaisser',
    '10',
    'SD(51)',
    formuleAmort: 'SC(591)',
  ),
  LigneEtat(
    'BS',
    'Banques, chèques postaux, caisse et assimilés',
    '11',
    'SD(52,53,54,55,57)',
    formuleAmort: 'SC(592)',
  ),
  LigneEtat(
    'BT',
    'TOTAL TRÉSORERIE - ACTIF',
    '',
    '{BQ}+{BR}+{BS}',
    formuleAmort: '{BQ}+{BR}+{BS}',
    total: true,
  ),
  LigneEtat('BU', 'Écart de conversion - actif', '12', 'SD(478)'),
  LigneEtat(
    'BZ',
    'TOTAL GÉNÉRAL',
    '',
    '{AZ}+{BK}+{BT}+{BU}',
    formuleAmort: '{AZ}+{BK}+{BT}+{BU}',
    total: true,
  ),
];

const List<LigneEtat> lignesPassif = [
  LigneEtat('CA', 'Capital', '13', 'SC(101)'),
  LigneEtat('CB', 'Apporteurs, capital non appelé (*)', '13', '-SD(109)'),
  LigneEtat('CD', 'Primes liées au capital social', '14', 'SC(105)'),
  LigneEtat('CE', 'Écarts de réévaluation', '3e', 'SC(106)'),
  LigneEtat('CF', 'Réserves indisponibles', '14', 'SC(111,112,113)'),
  LigneEtat('CG', 'Réserves libres', '14', 'SC(118)'),
  LigneEtat(
    'CH',
    'Report à nouveau (+ ou -)',
    '14',
    'SC(12)-SD(12)+RESULTAT_ANT',
  ),
  LigneEtat(
    'CJ',
    "Résultat net de l'exercice (bénéfice + ou perte -)",
    '',
    'RESULTAT',
  ),
  LigneEtat('CL', "Subventions d'investissement", '15', 'SC(14)'),
  LigneEtat('CM', 'Provisions réglementées', '15', 'SC(15)'),
  LigneEtat(
    'CP',
    'TOTAL CAPITAUX PROPRES ET RESSOURCES ASSIMILÉES',
    '',
    '{CA}+{CB}+{CD}+{CE}+{CF}+{CG}+{CH}+{CJ}+{CL}+{CM}',
    total: true,
  ),
  LigneEtat(
    'DA',
    'Emprunts et dettes financières diverses',
    '16',
    'SC(161,162,1662,164,165,166,168,183)+SC(184)-SD(184)',
  ),
  LigneEtat('DB', 'Dettes de location acquisition', '16', 'SC(17)'),
  LigneEtat('DC', 'Provisions pour risques et charges', '16', 'SC(19)'),
  LigneEtat(
    'DD',
    'TOTAL DES DETTES FINANCIÈRES ET RESSOURCES ASSIMILÉES',
    '',
    '{DA}+{DB}+{DC}',
    total: true,
  ),
  LigneEtat('DF', 'TOTAL RESSOURCES STABLES', '', '{CP}+{DD}', total: true),
  LigneEtat('DH', 'Dettes circulantes HAO', '5', 'SC(481,482,484,4998)'),
  LigneEtat('DI', 'Clients, avances reçues', '7', 'SC(4191,4198,411)'),
  LigneEtat(
    'DJ',
    "Fournisseurs d'exploitation",
    '17',
    'SC(4011,4012,4013,4017,402,408)',
  ),
  LigneEtat('DK', 'Dettes fiscales et sociales', '18', 'SC(422,43,44)'),
  LigneEtat(
    'DM',
    'Autres dettes',
    '19',
    'SC(45,4712,477,4752,4622,4632,465,4662,1852,186,187,1882)',
  ),
  LigneEtat('DN', 'Provisions pour risques à court terme', '19', 'SC(4991)'),
  LigneEtat(
    'DP',
    'TOTAL PASSIF CIRCULANT',
    '',
    '{DH}+{DI}+{DJ}+{DK}+{DM}+{DN}',
    total: true,
  ),
  LigneEtat('DQ', "Banques, crédit d'escompte", '20', 'SC(52,564,565)'),
  LigneEtat(
    'DR',
    'Banques, établissements financiers et crédits de trésorerie',
    '20',
    'SC(561,566)',
  ),
  LigneEtat('DT', 'TOTAL TRÉSORERIE - PASSIF', '', '{DQ}+{DR}', total: true),
  LigneEtat('DV', 'Écart de conversion - passif', '12', 'SC(479)'),
  LigneEtat('DZ', 'TOTAL GÉNÉRAL', '', '{DF}+{DP}+{DT}+{DV}', total: true),
];

const List<LigneEtat> lignesResultat = [
  LigneEtat('TA', 'Ventes de marchandises', '21', 'SC(701)-SD(7019)-SD(709)'),
  LigneEtat(
    'RA',
    'Achats de marchandises',
    '22',
    '-SD(6011,6012,6013,6014,6015)+SC(6019)',
  ),
  LigneEtat(
    'RB',
    'Variation de stock de marchandises',
    '6',
    '-SD(6031)+SC(6031)',
  ),
  LigneEtat('XA', 'MARGE COMMERCIALE', '', '{TA}+{RA}+{RB}', total: true),
  LigneEtat('TB', 'Ventes de produits fabriqués', '21', 'SC(702,703,704)'),
  LigneEtat('TC', 'Travaux, services vendus', '21', 'SC(705,706)'),
  LigneEtat('TD', 'Produits accessoires', '21', 'SC(707)'),
  LigneEtat('XB', "CHIFFRE D'AFFAIRES", '', '{TA}+{TB}+{TC}+{TD}', total: true),
  LigneEtat(
    'TE',
    'Production stockée (ou déstockage)',
    '6',
    'SC(734,735,736,737)-SD(734,735,736,737)',
  ),
  LigneEtat('TF', 'Production immobilisée', '21', 'SC(721,722,726)'),
  LigneEtat('TG', "Subventions d'exploitation", '21', 'SC(711,712,713,718)'),
  LigneEtat('TH', 'Autres produits', '21', 'SC(752,754,758)'),
  LigneEtat('TI', "Transferts de charges d'exploitation", '12', 'SC(781)'),
  LigneEtat(
    'RC',
    'Achats de matières premières et fournitures liées',
    '22',
    '-SD(6021,6022,6023,6024,6025)+SC(6029)',
  ),
  LigneEtat(
    'RD',
    'Variation de stocks de matières premières et fournitures liées',
    '6',
    '-SD(6032)+SC(6032)',
  ),
  LigneEtat(
    'RE',
    'Autres achats',
    '22',
    '-SD(6041,6042,6043,6044,6045,6046,6047,6048)+SC(6049)'
        '-SD(6051,6052,6053,6054,6055,6056,6057,6058)+SC(6059)',
  ),
  LigneEtat(
    'RF',
    "Variation de stocks d'autres approvisionnements",
    '6',
    '-SD(6033)+SC(6033)-SD(6083)+SC(6083)',
  ),
  LigneEtat('RG', 'Transports', '23', '-SD(612,613,614,616,618)'),
  LigneEtat(
    'RH',
    'Services extérieurs',
    '24',
    '-SD(621,622,623,624,625,626,627,628,631,632,633,634,635,637,638)',
  ),
  LigneEtat('RI', 'Impôts et taxes', '25', '-SD(641,645,646,647,648)'),
  LigneEtat('RJ', 'Autres charges', '26', '-SD(651,652,653,654,658,659)'),
  LigneEtat(
    'XC',
    'VALEUR AJOUTÉE',
    '',
    '{XB}+{RA}+{RB}+{TE}+{TF}+{TG}+{TH}+{TI}+{RC}+{RD}+{RE}+{RF}+{RG}+{RH}+{RI}+{RJ}',
    total: true,
  ),
  LigneEtat('RK', 'Charges de personnel', '27', '-SD(66)'),
  LigneEtat('XD', "EXCÉDENT BRUT D'EXPLOITATION", '', '{XC}+{RK}', total: true),
  LigneEtat(
    'TJ',
    'Reprises d\'amortissements, provisions et dépréciations',
    '28',
    'SC(791,798,799)',
  ),
  LigneEtat(
    'RL',
    'Dotations aux amortissements, aux provisions et dépréciations',
    '3C&28',
    '-SD(68,6911,6913)',
  ),
  LigneEtat('XE', "RÉSULTAT D'EXPLOITATION", '', '{XD}+{TJ}+{RL}', total: true),
  LigneEtat(
    'TK',
    'Revenus financiers et assimilés',
    '29',
    'SC(771,772,773,774,776,777,778,779)',
  ),
  LigneEtat(
    'TL',
    'Reprises de provisions et dépréciations financières',
    '28',
    'SC(797)',
  ),
  LigneEtat('TM', 'Transferts de charges financières', '12', 'SC(782)'),
  LigneEtat(
    'RM',
    'Frais financiers et charges assimilées',
    '29',
    '-SD(671,672,673,674,675,676,677,678,679)',
  ),
  LigneEtat(
    'RN',
    'Dotations aux provisions et aux dépréciations financières',
    '3C&28',
    '-SD(6971,6972)',
  ),
  LigneEtat(
    'XF',
    'RÉSULTAT FINANCIER',
    '',
    '{TK}+{TL}+{TM}+{RM}+{RN}',
    total: true,
  ),
  LigneEtat(
    'XG',
    'RÉSULTAT DES ACTIVITÉS ORDINAIRES',
    '',
    '{XE}+{XF}',
    total: true,
  ),
  LigneEtat(
    'TN',
    "Produits des cessions d'immobilisations",
    '3D',
    'SC(821,822,826)',
  ),
  LigneEtat(
    'TO',
    'Autres produits HAO',
    '3D',
    'SC(841,845,846,848,8493,8494,8495,861,862,8633,8634,8635,864,865,88)',
  ),
  LigneEtat(
    'RO',
    "Valeurs comptables des cessions d'immobilisations",
    '3D',
    '-SD(81)',
  ),
  LigneEtat(
    'RP',
    'Autres charges HAO',
    '3D',
    '-SD(831,834,835,836,839,851,852,853,854)',
  ),
  LigneEtat(
    'XH',
    'RÉSULTAT HORS ACTIVITÉS ORDINAIRES',
    '',
    '{TN}+{TO}+{RO}+{RP}',
    total: true,
  ),
  LigneEtat('RQ', 'Participation des travailleurs', '30', '-SD(871,874,878)'),
  LigneEtat('RS', "Impôt sur le résultat", '30', '-SD(891,892,895)+SC(899)'),
  LigneEtat('XI', 'RÉSULTAT NET', '', '{XG}+{XH}+{RQ}+{RS}', total: true),
];

/// Les noms des trois états.
const Map<String, String> nomsEtats = {
  'actif': 'Bilan : actif',
  'passif': 'Bilan : passif',
  'resultat': 'Compte de résultat',
};

List<LigneEtat> lignesDeEtat(String etat) => switch (etat) {
  'actif' => lignesActif,
  'passif' => lignesPassif,
  _ => lignesResultat,
};

/// La formule d'origine d'une colonne (null si la colonne n'existe pas).
String? formuleParDefaut(String etat, String ref, String colonne) {
  for (final l in lignesDeEtat(etat)) {
    if (l.ref == ref) return colonne == 'amort' ? l.formuleAmort : l.formule;
  }
  return null;
}

// ---------- Le lecteur de formules ----------

class _Terme {
  final int signe;
  final String type; // 'D', 'C', 'ref', 'RESULTAT', 'RESULTAT_ANT'
  final List<String> comptes;
  final String ref;

  const _Terme(this.signe, this.type, {this.comptes = const [], this.ref = ''});
}

List<_Terme> _analyser(String f) {
  final termes = <_Terme>[];
  final n = f.length;
  var i = 0;
  var premier = true;

  void sauter() {
    while (i < n && (f[i] == ' ' || f[i] == '\n' || f[i] == '\t')) {
      i++;
    }
  }

  while (true) {
    sauter();
    if (i >= n) break;

    var signe = 1;
    if (f[i] == '+' || f[i] == '-') {
      signe = f[i] == '-' ? -1 : 1;
      i++;
      sauter();
      if (i >= n) {
        throw const FormatException(
          'La formule ne peut pas se terminer par un signe',
        );
      }
    } else if (!premier) {
      throw FormatException(
        'Un « + » ou un « - » est attendu avant « ${f[i]} » (position ${i + 1})',
      );
    }
    premier = false;

    if (f.startsWith('SD(', i) || f.startsWith('SC(', i)) {
      final debit = f.startsWith('SD(', i);
      final fin = f.indexOf(')', i);
      if (fin < 0)
        throw const FormatException('Une parenthèse fermante est manquante');

      final comptes = f
          .substring(i + 3, fin)
          .split(RegExp(r'[,+;\s]+'))
          .where((c) => c.isNotEmpty)
          .toList();
      if (comptes.isEmpty) {
        throw FormatException(
          'Aucun compte dans « ${f.substring(i, fin + 1)} »',
        );
      }
      for (final c in comptes) {
        if (!RegExp(r'^\d{1,8}$').hasMatch(c)) {
          throw FormatException('« $c » n\'est pas un numéro de compte');
        }
      }
      termes.add(_Terme(signe, debit ? 'D' : 'C', comptes: comptes));
      i = fin + 1;
    } else if (f[i] == '{') {
      final fin = f.indexOf('}', i);
      if (fin < 0)
        throw const FormatException('Une accolade fermante est manquante');
      final ref = f.substring(i + 1, fin).trim();
      if (!RegExp(r'^[A-Z]{2}$').hasMatch(ref)) {
        throw FormatException(
          '« $ref » n\'est pas un repère de ligne (deux lettres, ex. XB)',
        );
      }
      termes.add(_Terme(signe, 'ref', ref: ref));
      i = fin + 1;
    } else if (f.startsWith('RESULTAT_ANT', i)) {
      termes.add(_Terme(signe, 'RESULTAT_ANT'));
      i += 12;
    } else if (f.startsWith('RESULTAT', i)) {
      termes.add(_Terme(signe, 'RESULTAT'));
      i += 8;
    } else {
      throw FormatException(
        'Terme inconnu à la position ${i + 1} : « ${f.substring(i, i + 12 > n ? n : i + 12)} »',
      );
    }
  }

  if (termes.isEmpty) throw const FormatException('La formule est vide');
  return termes;
}

/// Retourne un message d'erreur, ou null si la formule est correcte.
String? validerFormule(String formule, {bool videAutorise = false}) {
  if (formule.trim().isEmpty)
    return videAutorise ? null : 'La formule est vide';
  try {
    _analyser(formule);
    return null;
  } on FormatException catch (e) {
    return e.message;
  }
}

// ---------- Le calcul ----------

class _Moteur {
  final Map<String, int> soldes; // numéro de compte -> débit - crédit
  final int resultat;
  final int resultatAnt;
  final Set<String>
  utilises; // 'compte|D' ou 'compte|C' : déjà repris dans un état

  _Moteur(this.soldes, this.resultat, this.resultatAnt, this.utilises);

  // La somme des soldes débiteurs (ou créditeurs) des comptes qui commencent
  // par l'un des numéros. Chaque compte est jugé séparément.
  int _somme(List<String> prefixes, {required bool debit}) {
    var s = 0;
    soldes.forEach((numero, solde) {
      if (solde == 0) return;
      if (!prefixes.any((p) => numero.startsWith(p))) return;
      if (debit && solde > 0) {
        s += solde;
        utilises.add('$numero|D');
      } else if (!debit && solde < 0) {
        s -= solde;
        utilises.add('$numero|C');
      }
    });
    return s;
  }

  int evaluer(String formule, int Function(String ref) valeurRef) {
    var total = 0;
    for (final t in _analyser(formule)) {
      final int v;
      switch (t.type) {
        case 'D':
          v = _somme(t.comptes, debit: true);
        case 'C':
          v = _somme(t.comptes, debit: false);
        case 'ref':
          v = valeurRef(t.ref);
        case 'RESULTAT':
          v = resultat;
        default:
          v = resultatAnt;
      }
      total += t.signe * v;
    }
    return total;
  }
}

// Évalue une colonne d'un état : la valeur de chaque ligne, par repère
Map<String, int> _evaluerColonne(
  List<LigneEtat> lignes,
  String etat,
  String colonne,
  _Moteur moteur,
  Map<String, String> personnalisees,
  List<String> erreurs,
) {
  final definitions = {for (final l in lignes) l.ref: l};
  final valeurs = <String, int>{};
  final enCours = <String>{};

  int valeur(String ref) {
    if (valeurs.containsKey(ref)) return valeurs[ref]!;
    final l = definitions[ref];
    if (l == null) {
      erreurs.add('Repère inconnu : $ref');
      return 0;
    }
    if (!enCours.add(ref)) {
      erreurs.add('Formule circulaire autour de $ref');
      return 0;
    }

    final texte =
        personnalisees['$etat|$ref|$colonne'] ??
        (colonne == 'amort' ? l.formuleAmort : l.formule) ??
        '';
    var v = 0;
    if (texte.trim().isNotEmpty) {
      try {
        v = moteur.evaluer(texte, valeur);
      } on FormatException catch (e) {
        erreurs.add('${l.ref} : ${e.message}');
      }
    }
    enCours.remove(ref);
    valeurs[ref] = v;
    return v;
  }

  for (final l in lignes) {
    valeur(l.ref);
  }
  return valeurs;
}

class CompteNonClasse {
  final String numero;
  final String intitule;
  final int solde; // débit - crédit

  const CompteNonClasse({
    required this.numero,
    required this.intitule,
    required this.solde,
  });
}

/// Les valeurs d'un exercice.
class EtatCalcule {
  final Map<String, int> actifBrut;
  final Map<String, int> actifAmort;
  final Map<String, int> passif;
  final Map<String, int> resultat;
  final List<CompteNonClasse> nonClasses;
  final List<String> erreurs;

  const EtatCalcule({
    required this.actifBrut,
    required this.actifAmort,
    required this.passif,
    required this.resultat,
    required this.nonClasses,
    required this.erreurs,
  });

  int net(String ref) => (actifBrut[ref] ?? 0) - (actifAmort[ref] ?? 0);

  // Total de l'actif - total du passif : 0 si le bilan est équilibré
  int get ecartBilan => net('BZ') - (passif['DZ'] ?? 0);
}

/// Les états financiers de l'exercice et de l'exercice précédent.
class EtatsFinanciers {
  final DateTime debut;
  final DateTime fin;
  final DateTime debutPrec;
  final DateTime finPrec;
  final String portee;
  final EtatCalcule n;
  final EtatCalcule p;

  const EtatsFinanciers({
    required this.debut,
    required this.fin,
    required this.debutPrec,
    required this.finPrec,
    required this.portee,
    required this.n,
    required this.p,
  });

  int get nbControles =>
      n.nonClasses.length +
      n.erreurs.length +
      (n.ecartBilan != 0 || p.ecartBilan != 0 ? 1 : 0);
}

/// Calcule les trois états pour un exercice.
/// cumul : soldes (débit - crédit) de tous les comptes à la date de fin
/// flux : mouvements de l'exercice
/// resultatAnterieur : produits - charges des exercices d'avant
EtatCalcule calculerColonneEtats({
  required Map<String, int> cumul,
  required Map<String, int> flux,
  required int resultatAnterieur,
  required Map<String, String> personnalisees,
  required Map<String, String> intitules,
}) {
  final erreurs = <String>[];

  // 1. Le compte de résultat, à partir des mouvements de l'exercice
  final utilisesFlux = <String>{};
  final resultat = _evaluerColonne(
    lignesResultat,
    'resultat',
    'net',
    _Moteur(flux, 0, 0, utilisesFlux),
    personnalisees,
    erreurs,
  );
  final resultatNet = resultat['XI'] ?? 0;

  // 2. Le bilan, à partir des soldes cumulés
  final utilisesBilan = <String>{};
  final moteur = _Moteur(cumul, resultatNet, resultatAnterieur, utilisesBilan);
  final actifBrut = _evaluerColonne(
    lignesActif,
    'actif',
    'brut',
    moteur,
    personnalisees,
    erreurs,
  );
  final actifAmort = _evaluerColonne(
    lignesActif,
    'actif',
    'amort',
    moteur,
    personnalisees,
    erreurs,
  );
  final passif = _evaluerColonne(
    lignesPassif,
    'passif',
    'net',
    moteur,
    personnalisees,
    erreurs,
  );

  // 3. Les comptes avec un solde que personne n'a repris
  final nonClasses = <CompteNonClasse>[];
  void verifier(Map<String, int> soldes, Set<String> utilises, String classes) {
    final numeros = soldes.keys.toList()..sort();
    for (final numero in numeros) {
      final s = soldes[numero]!;
      if (s == 0 || numero.isEmpty || !classes.contains(numero[0])) continue;
      if (!utilises.contains('$numero|${s > 0 ? 'D' : 'C'}')) {
        nonClasses.add(
          CompteNonClasse(
            numero: numero,
            intitule: intitules[numero] ?? '',
            solde: s,
          ),
        );
      }
    }
  }

  verifier(cumul, utilisesBilan, '12345');
  verifier(flux, utilisesFlux, '678');

  return EtatCalcule(
    actifBrut: actifBrut,
    actifAmort: actifAmort,
    passif: passif,
    resultat: resultat,
    nonClasses: nonClasses,
    erreurs: erreurs,
  );
}

// ---------- Les tableaux, à l'écran et dans le PDF ----------

List<TableauRapport> tableauxEtats(EtatsFinanciers e) {
  String m(int v) => v == 0 ? '-' : formaterPrix(v);
  final colN = 'Exercice au ${formaterDate(e.fin)}';
  final colP = 'Exercice au ${formaterDate(e.finPrec)}';

  // Le bilan : actif
  final actif = <List<String>>[];
  final grasActif = <int>{};
  for (final l in lignesActif) {
    if (l.total) grasActif.add(actif.length);
    final avecAmort = l.formuleAmort != null;
    actif.add([
      l.ref,
      l.libelle,
      l.note,
      m(e.n.actifBrut[l.ref] ?? 0),
      avecAmort ? m(e.n.actifAmort[l.ref] ?? 0) : '',
      m(e.n.net(l.ref)),
      m(e.p.net(l.ref)),
    ]);
  }

  // Le bilan : passif
  final passif = <List<String>>[];
  final grasPassif = <int>{};
  for (final l in lignesPassif) {
    if (l.total) grasPassif.add(passif.length);
    passif.add([
      l.ref,
      l.libelle,
      l.note,
      m(e.n.passif[l.ref] ?? 0),
      m(e.p.passif[l.ref] ?? 0),
    ]);
  }

  // Le compte de résultat
  final resultat = <List<String>>[];
  final grasResultat = <int>{};
  for (final l in lignesResultat) {
    if (l.total) grasResultat.add(resultat.length);
    resultat.add([
      l.ref,
      l.libelle,
      l.note,
      m(e.n.resultat[l.ref] ?? 0),
      m(e.p.resultat[l.ref] ?? 0),
    ]);
  }

  final equilibre = e.n.ecartBilan == 0 && e.p.ecartBilan == 0
      ? "Bilan équilibré : le total de l'actif égale le total du passif."
      : 'ATTENTION : le total de l\'actif et le total du passif diffèrent '
            '(écart ${formaterPrix(e.n.ecartBilan)}). Voir l\'onglet Contrôles.';

  return [
    TableauRapport(
      titre: 'Bilan : actif',
      entetes: [
        'REF',
        'ACTIF',
        'Note',
        'Brut',
        'Amort. et déprec.',
        'Net $colN',
        'Net $colP',
      ],
      lignes: actif,
      flex: [1, 8, 1, 3, 3, 3, 3],
      droite: {3, 4, 5, 6},
      lignesGras: grasActif,
    ),
    TableauRapport(
      titre: 'Bilan : passif',
      entetes: ['REF', 'PASSIF', 'Note', colN, colP],
      lignes: passif,
      flex: [1, 9, 1, 3, 3],
      droite: {3, 4},
      lignesGras: grasPassif,
      note: equilibre,
    ),
    TableauRapport(
      titre: 'Compte de résultat',
      entetes: ['REF', 'LIBELLÉS', 'Note', colN, colP],
      lignes: resultat,
      flex: [1, 9, 1, 3, 3],
      droite: {3, 4},
      lignesGras: grasResultat,
      note: 'Les charges sont présentées en négatif.',
    ),
  ];
}

List<TableauRapport> tableauxControles(EtatsFinanciers e) {
  String p(int v) => formaterPrix(v);

  final tableaux = <TableauRapport>[
    TableauRapport(
      titre: 'Équilibre du bilan',
      entetes: ['Contrôle', 'Exercice N', 'Exercice N-1'],
      lignes: [
        ["Total de l'actif (net)", p(e.n.net('BZ')), p(e.p.net('BZ'))],
        ['Total du passif', p(e.n.passif['DZ'] ?? 0), p(e.p.passif['DZ'] ?? 0)],
        ['Différence', p(e.n.ecartBilan), p(e.p.ecartBilan)],
      ],
      flex: [6, 3, 3],
      droite: {1, 2},
      lignesGras: {2},
      note: e.n.ecartBilan == 0 && e.p.ecartBilan == 0
          ? 'Le bilan est équilibré.'
          : "Une différence vient presque toujours d'un compte qui n'est repris dans "
                "aucune ligne (voir ci-dessous) ou d'une formule à corriger.",
    ),
  ];

  tableaux.add(
    TableauRapport(
      titre: 'Comptes non repris dans les états (exercice N)',
      entetes: ['Compte', 'Intitulé', 'Solde', 'Sens'],
      lignes: [
        for (final c in e.n.nonClasses)
          [
            c.numero,
            c.intitule,
            p(c.solde.abs()),
            c.solde > 0 ? 'Débiteur' : 'Créditeur',
          ],
      ],
      flex: [2, 7, 3, 2],
      droite: {2},
      note: e.n.nonClasses.isEmpty
          ? 'Tous les comptes qui ont un solde sont repris dans les états.'
          : "Ajoutez ces comptes à la bonne ligne dans « Règles de calcul » "
                "(un compte débiteur va souvent à l'actif, un compte créditeur au passif).",
    ),
  );

  if (e.n.erreurs.isNotEmpty) {
    tableaux.add(
      TableauRapport(
        titre: 'Formules à corriger',
        entetes: ['Erreur'],
        lignes: [
          for (final x in e.n.erreurs) [x],
        ],
        flex: [1],
      ),
    );
  }
  return tableaux;
}
