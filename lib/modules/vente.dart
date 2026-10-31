import 'achat.dart';
import 'stock.dart';

/// Une ligne saisie à la caisse.
class LigneVenteSaisie {
  final int articleId;
  final double quantite;
  final int prixUnitaire;
  final int remise; // montant total de la remise sur la ligne

  const LigneVenteSaisie({
    required this.articleId,
    required this.quantite,
    required this.prixUnitaire,
    required this.remise,
  });
}

/// Un article proposé à la caisse, avec son stock dans l'agence.
class ArticleCaisse {
  final int id;
  final String code;
  final String designation;
  final String? categorie;
  final String unite;
  final int prixVente;
  final double stock;

  const ArticleCaisse({
    required this.id,
    required this.code,
    required this.designation,
    required this.categorie,
    required this.unite,
    required this.prixVente,
    required this.stock,
  });

  factory ArticleCaisse.fromMap(Map<String, Object?> m) => ArticleCaisse(
    id: m['id'] as int,
    code: m['code'] as String,
    designation: m['designation'] as String,
    categorie: m['categorie'] as String?,
    unite: m['unite'] as String,
    prixVente: m['prix_vente'] as int,
    stock: (m['stock'] as num).toDouble(),
  );
}

/// Ce qu'un client doit déjà, et ce qu'il peut encore devoir.
class SituationClient {
  final int plafond;
  final int encours;
  final bool systeme;

  const SituationClient({
    required this.plafond,
    required this.encours,
    required this.systeme,
  });

  int get disponible => plafond - encours;
}

/// Le résultat d'une vente enregistrée.
class VenteEnregistree {
  final int id;
  final String code;
  final int monnaie;

  const VenteEnregistree({
    required this.id,
    required this.code,
    required this.monnaie,
  });
}

/// Une ligne de la liste des ventes.
class VenteResume {
  final int id;
  final String code;
  final DateTime date;
  final String client;
  final String vendeur;
  final int netAPayer;
  final int paye;
  final String statut;

  const VenteResume({
    required this.id,
    required this.code,
    required this.date,
    required this.client,
    required this.vendeur,
    required this.netAPayer,
    required this.paye,
    required this.statut,
  });

  // Ce que le client doit encore (son crédit)
  int get reste => netAPayer - paye;

  factory VenteResume.fromMap(Map<String, Object?> m) => VenteResume(
    id: m['id'] as int,
    code: m['code'] as String,
    date: DateTime.parse(m['cree_le'] as String),
    client: m['client'] as String,
    vendeur: m['vendeur'] as String,
    netAPayer: m['net_a_payer'] as int,
    paye: (m['paye'] as num).toInt(),
    statut: m['statut'] as String,
  );
}

class LigneVente {
  final String code;
  final String designation;
  final String unite;
  final double quantite;
  final int prixUnitaire;
  final int remise;
  final int totalBrut;
  final int totalNet;

  const LigneVente({
    required this.code,
    required this.designation,
    required this.unite,
    required this.quantite,
    required this.prixUnitaire,
    required this.remise,
    required this.totalBrut,
    required this.totalNet,
  });

  factory LigneVente.fromMap(Map<String, Object?> m) => LigneVente(
    code: m['code_article'] as String,
    designation: m['designation'] as String,
    unite: m['unite'] as String,
    quantite: (m['quantite'] as num).toDouble(),
    prixUnitaire: m['prix_unitaire'] as int,
    remise: m['remise'] as int,
    totalBrut: m['total_brut'] as int,
    totalNet: m['total_net'] as int,
  );
}

/// Un paiement de vente : même contenu qu'un paiement d'achat.
typedef PaiementVente = PaiementAchat;

/// Une vente avec ses lignes et ses paiements : la facture.
class VenteDetail {
  final String code;
  final DateTime date;
  final String agence;
  final String client;
  final String vendeur;
  final String? note;
  final String statut;
  final int totalBrut;
  final int totalRemise;
  final int totalTva;
  final int netAPayer;
  final int monnaieRendue;
  final List<LigneVente> lignes;
  final List<PaiementVente> paiements;

  const VenteDetail({
    required this.code,
    required this.date,
    required this.agence,
    required this.client,
    required this.vendeur,
    required this.note,
    required this.statut,
    required this.totalBrut,
    required this.totalRemise,
    required this.totalTva,
    required this.netAPayer,
    required this.monnaieRendue,
    required this.lignes,
    required this.paiements,
  });

  int get paye => paiements.fold(0, (somme, p) => somme + p.montant);
  int get reste => netAPayer - paye;
  int get recu => paye + monnaieRendue; // ce que le client a donné
}

/// 29/10/2026 14:05
String dateHeureVente(DateTime d) => formaterDateHeure(d);
