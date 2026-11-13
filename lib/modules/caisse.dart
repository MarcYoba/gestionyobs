/// Les billets et pièces à compter, de la plus grande à la plus petite valeur.
/// La valeur 1 sert de ligne « Autre » : on y saisit un montant en unités.
/// À adapter à ta monnaie.
const List<int> coupuresCaisse = [
  10000,
  5000,
  2000,
  1000,
  500,
  100,
  50,
  25,
  10,
  5,
  1,
];

/// Les mouvements d'un mode de paiement sur une journée.
class LigneModeCaisse {
  final int modeId;
  final String libelle;
  final String type; // 'caisse' (espèces), 'mobile', 'banque'
  final int ventes; // ventes encaissées
  final int reglements; // règlements reçus des clients
  final int rembRecus; // remboursements reçus (fournisseurs, dépenses annulées)
  final int fournisseurs; // paiements aux fournisseurs
  final int depenses; // dépenses payées
  final int rembClients; // remboursements rendus aux clients

  const LigneModeCaisse({
    required this.modeId,
    required this.libelle,
    required this.type,
    required this.ventes,
    required this.reglements,
    required this.rembRecus,
    required this.fournisseurs,
    required this.depenses,
    required this.rembClients,
  });

  // Seule la caisse en espèces se compte avec les mains
  bool get physique => type == 'caisse';
  int get entrees => ventes + reglements + rembRecus;
  int get sorties => fournisseurs + depenses + rembClients;
  int get net => entrees - sorties;
}

/// Une ligne du journal du jour.
class MouvementCaisse {
  final DateTime heure;
  final String typeDocument; // 'vente', 'achat' ou 'depense'
  final bool reglement;
  final int montant; // tel qu'enregistré (négatif : remboursement)
  final String mode;
  final String document;
  final String libelle;
  final String utilisateur;

  const MouvementCaisse({
    required this.heure,
    required this.typeDocument,
    required this.reglement,
    required this.montant,
    required this.mode,
    required this.document,
    required this.libelle,
    required this.utilisateur,
  });

  // Positif : de l'argent entre ; négatif : de l'argent sort
  int get flux => typeDocument == 'vente' ? montant : -montant;

  String get nature {
    if (typeDocument == 'vente') {
      if (montant < 0) return 'Remboursement client';
      return reglement ? 'Règlement client' : 'Vente';
    }
    if (typeDocument == 'achat') {
      if (montant < 0) return 'Remboursement fournisseur';
      return reglement ? 'Règlement fournisseur' : 'Paiement achat';
    }
    return montant < 0 ? 'Dépense annulée' : 'Dépense';
  }
}

/// Une clôture enregistrée.
class ClotureCaisse {
  final int id;
  final String code;
  final DateTime dateCaisse;
  final int fondOuverture;
  final int entrees;
  final int sorties;
  final int theorique;
  final int compte;
  final int ecart;
  final int laisse;
  final int verse;
  final String? note;
  final String par;
  final DateTime creeLe;
  final Map<int, int> coupures; // valeur -> quantité
  final int mouvementsApres; // mouvements enregistrés après la clôture

  const ClotureCaisse({
    required this.id,
    required this.code,
    required this.dateCaisse,
    required this.fondOuverture,
    required this.entrees,
    required this.sorties,
    required this.theorique,
    required this.compte,
    required this.ecart,
    required this.laisse,
    required this.verse,
    required this.note,
    required this.par,
    required this.creeLe,
    required this.coupures,
    required this.mouvementsApres,
  });
}

/// Une ligne de l'historique des clôtures.
class ClotureResume {
  final int id;
  final String code;
  final DateTime dateCaisse;
  final int theorique;
  final int compte;
  final int ecart;
  final String par;

  const ClotureResume({
    required this.id,
    required this.code,
    required this.dateCaisse,
    required this.theorique,
    required this.compte,
    required this.ecart,
    required this.par,
  });
}

/// Tout ce qu'il faut pour afficher la caisse d'un jour.
class JourCaisse {
  final DateTime date;
  final String agence;
  final List<LigneModeCaisse> modes;
  final List<MouvementCaisse> mouvements;
  final int?
  fondPrecedent; // laissé par la dernière clôture (null : première clôture)
  final DateTime? jourARegulariser; // un jour précédent non clôturé
  final ClotureCaisse? cloture;

  const JourCaisse({
    required this.date,
    required this.agence,
    required this.modes,
    required this.mouvements,
    required this.fondPrecedent,
    required this.jourARegulariser,
    required this.cloture,
  });

  int get entreesPhysiques =>
      modes.where((m) => m.physique).fold(0, (s, m) => s + m.entrees);
  int get sortiesPhysiques =>
      modes.where((m) => m.physique).fold(0, (s, m) => s + m.sorties);
  int get netPhysique => entreesPhysiques - sortiesPhysiques;
}
