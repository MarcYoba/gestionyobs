/// Une ligne saisie dans le formulaire d'achat.
class LigneAchatSaisie {
  final int articleId;
  final double quantite;
  final int prixUnitaire;

  const LigneAchatSaisie({
    required this.articleId,
    required this.quantite,
    required this.prixUnitaire,
  });
}

/// Un paiement saisi dans le formulaire.
class PaiementSaisi {
  final int modeId;
  final int montant;
  final String? reference;

  const PaiementSaisi({
    required this.modeId,
    required this.montant,
    this.reference,
  });
}

/// Une ligne de la liste des achats.
class AchatResume {
  final int id;
  final String code;
  final DateTime date;
  final String fournisseur;
  final String? referenceFournisseur;
  final int totalTtc;
  final int paye;
  final String statut;

  const AchatResume({
    required this.id,
    required this.code,
    required this.date,
    required this.fournisseur,
    required this.referenceFournisseur,
    required this.totalTtc,
    required this.paye,
    required this.statut,
  });

  // Ce qui reste dû au fournisseur
  int get reste => totalTtc - paye;

  factory AchatResume.fromMap(Map<String, Object?> m) => AchatResume(
    id: m['id'] as int,
    code: m['code'] as String,
    date: DateTime.parse(m['date_achat'] as String),
    fournisseur: m['fournisseur'] as String,
    referenceFournisseur: m['reference_fournisseur'] as String?,
    totalTtc: m['total_ttc'] as int,
    paye: (m['paye'] as num).toInt(),
    statut: m['statut'] as String,
  );
}

class LigneAchat {
  final String code;
  final String designation;
  final double quantite;
  final int prixUnitaire;
  final int totalHt;

  const LigneAchat({
    required this.code,
    required this.designation,
    required this.quantite,
    required this.prixUnitaire,
    required this.totalHt,
  });

  factory LigneAchat.fromMap(Map<String, Object?> m) => LigneAchat(
    code: m['code_article'] as String,
    designation: m['designation'] as String,
    quantite: (m['quantite'] as num).toDouble(),
    prixUnitaire: m['prix_unitaire'] as int,
    totalHt: m['total_ht'] as int,
  );
}

class PaiementAchat {
  final String mode;
  final int montant;
  final String? reference;
  final DateTime date;
  final String utilisateur;

  const PaiementAchat({
    required this.mode,
    required this.montant,
    required this.reference,
    required this.date,
    required this.utilisateur,
  });

  factory PaiementAchat.fromMap(Map<String, Object?> m) => PaiementAchat(
    mode: m['mode'] as String,
    montant: m['montant'] as int,
    reference: m['reference'] as String?,
    date: DateTime.parse(m['date_paiement'] as String),
    utilisateur: m['utilisateur'] as String,
  );
}

/// Un achat avec ses lignes et ses paiements.
class AchatDetail {
  final String code;
  final DateTime date;
  final String fournisseur;
  final String? referenceFournisseur;
  final String? note;
  final String agence;
  final String utilisateur;
  final String statut;
  final int totalHt;
  final int totalTva;
  final int totalTtc;
  final List<LigneAchat> lignes;
  final List<PaiementAchat> paiements;

  const AchatDetail({
    required this.code,
    required this.date,
    required this.fournisseur,
    required this.referenceFournisseur,
    required this.note,
    required this.agence,
    required this.utilisateur,
    required this.statut,
    required this.totalHt,
    required this.totalTva,
    required this.totalTtc,
    required this.lignes,
    required this.paiements,
  });

  int get paye => paiements.fold(0, (somme, p) => somme + p.montant);
  int get reste => totalTtc - paye;
}

/// 29/10/2026
String formaterDate(DateTime d) {
  String deux(int n) => n.toString().padLeft(2, '0');
  return '${deux(d.day)}/${deux(d.month)}/${d.year}';
}
