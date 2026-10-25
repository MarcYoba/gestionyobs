/// Les rôles disponibles : code enregistré dans la base -> texte affiché.
/// Les rôles disponibles : code -> libellé.
/// Cette liste est remplie depuis la base de données au démarrage
/// et à chaque modification des rôles.
final Map<String, String> rolesDisponibles = {};

/// Le texte à afficher pour un rôle (ou le code lui-même s'il est inconnu).
String libelleRole(String role) => rolesDisponibles[role] ?? role;

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
/// Retient l'utilisateur, son agence et ses droits tant que le logiciel est ouvert.
class Session {
  static Utilisateur? utilisateurCourant;
  static Agence? agenceCourante;
  static Set<String> droits = {};

  // L'utilisateur connecté a-t-il ce droit ?
  static bool peut(String permission) => droits.contains(permission);

  static void deconnecter() {
    utilisateurCourant = null;
    agenceCourante = null;
    droits = {};
  }

  // Interrompt l'opération si l'utilisateur n'a pas le droit
  static void exiger(String permission) {
    if (!peut(permission)) {
      throw Exception('Action non autorisée');
    }
  }
}

/// Une ligne de la liste des utilisateurs (avec les noms de ses agences).
class UtilisateurResume {
  final int id;
  final String nomComplet;
  final String identifiant;
  final String role;
  final bool actif;
  final String agences; // noms séparés par des virgules ('' si aucune)

  const UtilisateurResume({
    required this.id,
    required this.nomComplet,
    required this.identifiant,
    required this.role,
    required this.actif,
    required this.agences,
  });

  bool get estAdmin => role == 'admin';
}
