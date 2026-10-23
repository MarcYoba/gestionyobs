/// Un rôle (ex. vendeur, caissier...).
class Role {
  final String code;
  final String libelle;
  final bool systeme; // true = rôle système (l'administrateur)
  final int nbUtilisateurs;

  const Role({
    required this.code,
    required this.libelle,
    required this.systeme,
    required this.nbUtilisateurs,
  });
}

/// Une fonction du logiciel qu'on peut autoriser ou non.
class Permission {
  final String code;
  final String libelle;
  final String groupe;
  final bool adminSeulement;

  const Permission({
    required this.code,
    required this.libelle,
    required this.groupe,
    required this.adminSeulement,
  });
}
