/// Les unités proposées pour un article.
const List<String> unitesDisponibles = [
  'pièce',
  'mètre',
  'kg',
  'litre',
  'sac',
  'carton',
  'boîte',
  'rouleau',
  'paire',
];

/// Un article du catalogue (commun à toutes les agences).
class Article {
  final int id;
  final String code;
  final String designation;
  final String? categorie;
  final String unite;
  final int? prixAchat; // null si inconnu ou si l'utilisateur n'a pas le droit
  final int prixVente;
  final double seuilAlerte;
  final bool actif;

  const Article({
    required this.id,
    required this.code,
    required this.designation,
    required this.categorie,
    required this.unite,
    required this.prixAchat,
    required this.prixVente,
    required this.seuilAlerte,
    required this.actif,
  });

  factory Article.fromMap(
    Map<String, Object?> m, {
    required bool avecPrixAchat,
  }) => Article(
    id: m['id'] as int,
    code: m['code'] as String,
    designation: m['designation'] as String,
    categorie: m['categorie'] as String?,
    unite: m['unite'] as String,
    prixAchat: avecPrixAchat ? (m['prix_achat'] as int?) : null,
    prixVente: m['prix_vente'] as int,
    seuilAlerte: (m['seuil_alerte'] as num).toDouble(),
    actif: (m['actif'] as int) == 1,
  );
}

/// 2500 -> "2 500"
String formaterPrix(int montant) => montant.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (m) => ' ',
);

/// 5.0 -> "5" ; 2.5 -> "2.5"
String formaterQuantite(double q) =>
    q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toString();
