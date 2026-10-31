import 'package:gestionyobs/files/xlsx_reader.dart';

/// Une ligne du fichier, avec les corrections proposées.
class LigneImport {
  final int ligne; // numéro de ligne dans le fichier Excel
  final String numeroBrut;
  final String intituleBrut;
  String numero;
  String intitule;
  bool ignorer;
  bool aVerifier;
  final List<String> remarques;

  // Remplis par AnalysePlan.valider()
  List<String> problemes = [];
  String etat = 'nouveau'; // 'nouveau', 'modifie' ou 'identique'
  String? intituleActuel;

  LigneImport({
    required this.ligne,
    required this.numeroBrut,
    required this.intituleBrut,
    required this.numero,
    required this.intitule,
    this.ignorer = false,
    this.aVerifier = false,
    List<String>? remarques,
  }) : remarques = remarques ?? [];

  bool get numeroCorrige => numero != numeroBrut;
}

/// Le résultat de l'analyse du fichier.
class AnalysePlan {
  final List<LigneImport> lignes;
  final Map<String, String> existants; // numéro -> intitulé déjà en base

  AnalysePlan(this.lignes, this.existants);

  int get nbAImporter => lignes.where((l) => !l.ignorer).length;
  int get nbIgnorees => lignes.where((l) => l.ignorer).length;
  int get nbAVerifier => lignes.where((l) => !l.ignorer && l.aVerifier).length;
  int get nbProblemes =>
      lignes.where((l) => !l.ignorer && l.problemes.isNotEmpty).length;
  int get nbCorrigees => lignes.where((l) => l.numeroCorrige).length;
  int get nbNouveaux =>
      lignes.where((l) => !l.ignorer && l.etat == 'nouveau').length;
  int get nbModifies =>
      lignes.where((l) => !l.ignorer && l.etat == 'modifie').length;

  bool get peutImporter => nbAImporter > 0 && nbProblemes == 0;

  // Recalcule les problèmes et l'état de chaque ligne (après une correction)
  void valider() {
    final compte = <String, int>{};
    for (final l in lignes.where((l) => !l.ignorer)) {
      compte[l.numero] = (compte[l.numero] ?? 0) + 1;
    }

    for (final l in lignes) {
      l.problemes = [];
      if (l.ignorer) continue;

      if (!RegExp(r'^[1-9]\d{1,9}$').hasMatch(l.numero)) {
        l.problemes.add(
          'Numéro invalide (2 à 10 chiffres, sans zéro au début)',
        );
      }
      if (l.intitule.trim().isEmpty) {
        l.problemes.add("L'intitulé est vide");
      }
      if ((compte[l.numero] ?? 0) > 1) {
        l.problemes.add('Numéro en double dans le fichier');
      }

      final actuel = existants[l.numero];
      l.intituleActuel = actuel;
      l.etat = actuel == null
          ? 'nouveau'
          : (actuel == l.intitule ? 'identique' : 'modifie');
    }
  }
}

// Minuscules, sans accents : pour reconnaître les titres de colonnes
String _simplifier(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[éèêë]'), 'e')
    .replaceAll(RegExp(r'[àâä]'), 'a')
    .replaceAll(RegExp(r'[îï]'), 'i')
    .replaceAll(RegExp(r'[ôö]'), 'o')
    .replaceAll(RegExp(r'[ùûü]'), 'u')
    .replaceAll('ç', 'c')
    .trim();

// Le numéro lu dans une case, en texte (1011000.0 devient 1011000)
String _texteNumero(String? s) {
  final t = (s ?? '').trim().replaceAll(RegExp(r'\s+'), '');
  if (t.isEmpty) return '';
  if (RegExp(r'^\d+$').hasMatch(t)) return t;
  final d = double.tryParse(t.replaceAll(',', '.'));
  if (d != null && d == d.roundToDouble()) return d.toStringAsFixed(0);
  return t; // sera signalé comme invalide
}

String? _case(List<String?> cases, int index) =>
    (index >= 0 && index < cases.length) ? cases[index] : null;

/// Analyse un plan comptable lu dans un fichier Excel.
AnalysePlan analyserPlan(
  List<LigneXlsx> source,
  Map<String, String> existants,
) {
  if (source.isEmpty) throw Exception('Le fichier est vide');

  // 1. On repère les colonnes grâce à la première ligne
  final entetes = source.first.cases.map((c) => _simplifier(c ?? '')).toList();
  final colIntitule = entetes.indexWhere(
    (h) => h.contains('intitul') || h.contains('libell'),
  );
  final colNumero = entetes.indexWhere(
    (h) =>
        h.isNotEmpty &&
        !h.contains('intitul') &&
        (h == 'compte' ||
            h.startsWith('numero') ||
            h.startsWith('n°') ||
            h.startsWith('compte')),
  );

  if (colNumero < 0 || colIntitule < 0) {
    throw Exception(
      'Colonnes introuvables : il faut une colonne « Compte » (ou « Numéro ») '
      'et une colonne « Intitulé ». Colonnes lues : '
      '${source.first.cases.whereType<String>().join(', ')}',
    );
  }

  // 2. On nettoie chaque ligne
  final lignes = <LigneImport>[];
  for (final l in source.skip(1)) {
    final brutNumero = _case(l.cases, colNumero);
    final brutIntitule = _case(l.cases, colIntitule);
    if ((brutNumero ?? '').trim().isEmpty &&
        (brutIntitule ?? '').trim().isEmpty) {
      continue; // ligne vide
    }

    final remarques = <String>[];
    var numero = _texteNumero(brutNumero);
    final numeroBrut = numero;

    // Les zéros de remplissage : 4111000 -> 4111 (jamais en dessous de 3 chiffres)
    if (RegExp(r'^\d+$').hasMatch(numero) && numero.length >= 4) {
      var n = numero;
      while (n.length > 3 && n.endsWith('0')) {
        n = n.substring(0, n.length - 1);
      }
      if (n != numero) {
        remarques.add('Zéros de remplissage retirés : $numero devient $n');
        numero = n;
      }
    }

    final intitule = (brutIntitule ?? '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    var ignorer = false;
    var aVerifier = false;

    // Une fourchette de comptes (ex. « 901 à 904 ») n'est pas un vrai compte
    if (numero.length == 6 && RegExp(r'\d{3}\s*à\s*\d{3}').hasMatch(intitule)) {
      ignorer = true;
      aVerifier = true;
      remarques.add(
        'Fourchette de comptes (pas un vrai compte) : ignorée, à traiter à la main',
      );
    }

    lignes.add(
      LigneImport(
        ligne: l.numero,
        numeroBrut: numeroBrut,
        intituleBrut: (brutIntitule ?? '').toString(),
        numero: numero,
        intitule: intitule,
        ignorer: ignorer,
        aVerifier: aVerifier,
        remarques: remarques,
      ),
    );
  }

  // 3. Les doublons : on propose 391 -> 3911, 3912, 3913...
  final groupes = <String, List<LigneImport>>{};
  for (final l in lignes.where((l) => !l.ignorer)) {
    groupes.putIfAbsent(l.numero, () => []).add(l);
  }
  final tousLesNumeros = groupes.keys.toSet();

  groupes.forEach((numero, liste) {
    if (liste.length < 2) return;

    final propositions = [
      for (var i = 0; i < liste.length; i++) '$numero${i + 1}',
    ];
    final possible =
        liste.length <= 9 &&
        numero.length >= 3 &&
        propositions.every((p) => !tousLesNumeros.contains(p));

    if (possible) {
      for (var i = 0; i < liste.length; i++) {
        liste[i].numero = propositions[i];
        liste[i].aVerifier = true;
        liste[i].remarques.add(
          'Doublon (${liste.length} lignes avec le numéro $numero) : '
          'numéro ${propositions[i]} proposé, à confirmer',
        );
      }
    }
  });

  return AnalysePlan(lignes, existants)..valider();
}
