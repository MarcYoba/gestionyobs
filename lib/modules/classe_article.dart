/// Une classe d'articles (Outillage, Plomberie...).
class ClasseArticle {
  final int id;
  final String nom;
  final bool actif;
  final int nbArticles;

  const ClasseArticle({
    required this.id,
    required this.nom,
    required this.actif,
    required this.nbArticles,
  });
}
