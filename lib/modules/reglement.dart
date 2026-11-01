/// Un tiers qui doit de l'argent (client) ou à qui on en doit (fournisseur).
class SoldeTiers {
  final int tiersId;
  final String code;
  final String nom;
  final String? telephone;
  final int nbDocuments;
  final int du;

  const SoldeTiers({
    required this.tiersId,
    required this.code,
    required this.nom,
    required this.telephone,
    required this.nbDocuments,
    required this.du,
  });

  factory SoldeTiers.fromMap(Map<String, Object?> m) => SoldeTiers(
    tiersId: m['id'] as int,
    code: m['code'] as String,
    nom: m['nom'] as String,
    telephone: m['telephone'] as String?,
    nbDocuments: m['nb'] as int,
    du: (m['du'] as num).toInt(),
  );
}

/// Une facture (vente ou achat) qui n'est pas entièrement payée.
class DocumentDu {
  final int id;
  final String code;
  final DateTime date;
  final int total;
  final int paye;

  const DocumentDu({
    required this.id,
    required this.code,
    required this.date,
    required this.total,
    required this.paye,
  });

  int get reste => total - paye;

  factory DocumentDu.fromMap(Map<String, Object?> m) => DocumentDu(
    id: m['id'] as int,
    code: m['code'] as String,
    date: DateTime.parse(m['date'] as String),
    total: m['total'] as int,
    paye: (m['paye'] as num).toInt(),
  );
}

/// Un montant réparti sur une facture, saisi dans le formulaire.
class AllocationSaisie {
  final int documentId;
  final int montant;

  const AllocationSaisie({required this.documentId, required this.montant});
}

class ReglementEnregistre {
  final int id;
  final String code;

  const ReglementEnregistre({required this.id, required this.code});
}

/// Une ligne de l'historique des règlements.
class ReglementResume {
  final int id;
  final String code;
  final DateTime date;
  final int montant;
  final String tiers;
  final String utilisateur;

  const ReglementResume({
    required this.id,
    required this.code,
    required this.date,
    required this.montant,
    required this.tiers,
    required this.utilisateur,
  });

  factory ReglementResume.fromMap(Map<String, Object?> m) => ReglementResume(
    id: m['id'] as int,
    code: m['code'] as String,
    date: DateTime.parse(m['date_reglement'] as String),
    montant: m['montant'] as int,
    tiers: m['tiers'] as String,
    utilisateur: m['utilisateur'] as String,
  );
}

/// Une facture soldée (en tout ou en partie) par un règlement.
class LigneReglement {
  final String documentCode;
  final int montant;

  const LigneReglement({required this.documentCode, required this.montant});
}

/// Un paiement d'un règlement, par mode.
class PaiementReglement {
  final String mode;
  final int montant;
  final String? reference;

  const PaiementReglement({
    required this.mode,
    required this.montant,
    required this.reference,
  });
}

/// Un règlement : le reçu.
class ReglementDetail {
  final String code;
  final String type; // 'client' ou 'fournisseur'
  final DateTime date;
  final String tiers;
  final String utilisateur;
  final String agence;
  final String? agenceVille;
  final String? agenceTelephone;
  final int montant;
  final String? note;
  final int nbImpressions;
  final int soldeRestant; // ce que le tiers doit encore dans cette agence
  final List<LigneReglement> lignes;
  final List<PaiementReglement> modes;

  const ReglementDetail({
    required this.code,
    required this.type,
    required this.date,
    required this.tiers,
    required this.utilisateur,
    required this.agence,
    required this.agenceVille,
    required this.agenceTelephone,
    required this.montant,
    required this.note,
    required this.nbImpressions,
    required this.soldeRestant,
    required this.lignes,
    required this.modes,
  });
}
