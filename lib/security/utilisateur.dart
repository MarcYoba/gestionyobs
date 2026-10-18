/// Un utilisateur du logiciel.
class Utilisateur {
  final int id;
  final String nomComplet;
  final String identifiant;
  final String role; // 'admin' ou 'vendeur'

  const Utilisateur({
    required this.id,
    required this.nomComplet,
    required this.identifiant,
    required this.role,
  });

  bool get estAdmin => role == 'admin';
}

/// Une agence (un point de vente).
class Agence {
  final int id;
  final String nom;
  final String? ville;
  final String? telephone;
  final String? description;

  const Agence({
    required this.id,
    required this.nom,
    this.ville,
    this.telephone,
    this.description,
  });

  // Construit une Agence à partir d'une ligne de la base de données
  factory Agence.fromMap(Map<String, Object?> m) => Agence(
    id: m['id'] as int,
    nom: m['nom'] as String,
    ville: m['ville'] as String?,
    telephone: m['telephone'] as String?,
    description: m['description'] as String?,
  );
}

/// Retient l'utilisateur et l'agence choisie tant que le logiciel est ouvert.
class Session {
  static Utilisateur? utilisateurCourant;
  static Agence? agenceCourante;

  static void deconnecter() {
    utilisateurCourant = null;
    agenceCourante = null;
  }
}
