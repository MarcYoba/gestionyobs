/// Les types de mouvement : code enregistré -> libellé affiché.
const Map<String, String> typesMouvement = {
  'entree': 'Entrée',
  'sortie': 'Sortie',
  'ajustement': 'Inventaire',
};

/// Les motifs proposés pour chaque type.
const Map<String, List<String>> motifsMouvement = {
  'entree': ['Réception fournisseur', 'Retour client', 'Autre entrée'],
  'sortie': [
    'Casse',
    'Perte ou vol',
    'Usage interne',
    'Retour fournisseur',
    'Autre sortie',
  ],
  'ajustement': ['Inventaire physique', "Correction d'erreur"],
};

/// Une ligne de la page Stock : un article et sa quantité dans l'agence.
class LigneStock {
  final int articleId;
  final String code;
  final String designation;
  final String? categorie;
  final String unite;
  final double seuilAlerte;
  final double quantite;

  const LigneStock({
    required this.articleId,
    required this.code,
    required this.designation,
    required this.categorie,
    required this.unite,
    required this.seuilAlerte,
    required this.quantite,
  });

  bool get enRupture => quantite <= 0;
  bool get enAlerte => !enRupture && seuilAlerte > 0 && quantite <= seuilAlerte;

  factory LigneStock.fromMap(Map<String, Object?> m) => LigneStock(
    articleId: m['id'] as int,
    code: m['code'] as String,
    designation: m['designation'] as String,
    categorie: m['categorie'] as String?,
    unite: m['unite'] as String,
    seuilAlerte: (m['seuil_alerte'] as num).toDouble(),
    quantite: (m['quantite'] as num).toDouble(),
  );
}

/// Un mouvement de stock (une ligne de l'historique).
class Mouvement {
  final String code;
  final String type;
  final double quantite; // signée : +10 pour une entrée, -3 pour une sortie
  final double avant;
  final double apres;
  final String motif;
  final String? commentaire;
  final DateTime date;
  final String designation;
  final String articleCode;
  final String unite;
  final String utilisateur;

  const Mouvement({
    required this.code,
    required this.type,
    required this.quantite,
    required this.avant,
    required this.apres,
    required this.motif,
    required this.commentaire,
    required this.date,
    required this.designation,
    required this.articleCode,
    required this.unite,
    required this.utilisateur,
  });

  factory Mouvement.fromMap(Map<String, Object?> m) => Mouvement(
    code: m['code'] as String,
    type: m['type'] as String,
    quantite: (m['quantite'] as num).toDouble(),
    avant: (m['quantite_avant'] as num).toDouble(),
    apres: (m['quantite_apres'] as num).toDouble(),
    motif: m['motif'] as String,
    commentaire: m['commentaire'] as String?,
    date: DateTime.parse(m['cree_le'] as String),
    designation: m['designation'] as String,
    articleCode: m['article_code'] as String,
    unite: m['unite'] as String,
    utilisateur: m['utilisateur'] as String,
  );
}

/// 26/10/2026 14:05
String formaterDateHeure(DateTime d) {
  String deux(int n) => n.toString().padLeft(2, '0');
  return '${deux(d.day)}/${deux(d.month)}/${d.year} ${deux(d.hour)}:${deux(d.minute)}';
}
