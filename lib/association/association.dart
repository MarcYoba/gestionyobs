/// Un compte associé à un poste.
class Association {
  final int id;
  final String poste;
  final String portee; // 'defaut', 'agence' ou 'classe'
  final int
  porteeId; // 0 pour le défaut, sinon le numéro de l'agence ou de la classe
  final int compteId;
  final String numero;
  final String intitule;
  final String? agenceNom;
  final String? classeNom;

  const Association({
    required this.id,
    required this.poste,
    required this.portee,
    required this.porteeId,
    required this.compteId,
    required this.numero,
    required this.intitule,
    required this.agenceNom,
    required this.classeNom,
  });

  factory Association.fromMap(Map<String, Object?> m) => Association(
    id: m['id'] as int,
    poste: m['poste'] as String,
    portee: m['portee'] as String,
    porteeId: m['portee_id'] as int,
    compteId: m['compte_id'] as int,
    numero: m['numero'] as String,
    intitule: m['intitule'] as String,
    agenceNom: m['agence_nom'] as String?,
    classeNom: m['classe_nom'] as String?,
  );
}

/// Une ligne de l'historique des modifications.
class HistoriqueAssociation {
  final String poste;
  final String portee;
  final String? agenceNom;
  final String? classeNom;
  final String? ancienCompte;
  final String? nouveauCompte;
  final String utilisateur;
  final DateTime date;

  const HistoriqueAssociation({
    required this.poste,
    required this.portee,
    required this.agenceNom,
    required this.classeNom,
    required this.ancienCompte,
    required this.nouveauCompte,
    required this.utilisateur,
    required this.date,
  });

  factory HistoriqueAssociation.fromMap(Map<String, Object?> m) =>
      HistoriqueAssociation(
        poste: m['poste'] as String,
        portee: m['portee'] as String,
        agenceNom: m['agence_nom'] as String?,
        classeNom: m['classe_nom'] as String?,
        ancienCompte: m['ancien_compte'] as String?,
        nouveauCompte: m['nouveau_compte'] as String?,
        utilisateur: m['utilisateur'] as String,
        date: DateTime.parse(m['cree_le'] as String),
      );
}

/// Le bilan de l'application des propositions.
class ResultatPropositions {
  final int appliquees;
  final int ignorees;

  const ResultatPropositions({
    required this.appliquees,
    required this.ignorees,
  });
}

/// Le compte retenu pour un poste, avec son origine.
class ComptePourPoste {
  final String numero;
  final String intitule;
  final String origine; // 'classe', 'agence' ou 'defaut'

  const ComptePourPoste({
    required this.numero,
    required this.intitule,
    required this.origine,
  });
}
