/// Les noms des classes de comptes (1 à 9), selon le plan OHADA.
const Map<int, String> nomsClasses = {
  1: 'Ressources durables',
  2: 'Actif immobilisé',
  3: 'Stocks',
  4: 'Tiers',
  5: 'Trésorerie',
  6: 'Charges des activités ordinaires',
  7: 'Produits des activités ordinaires',
  8: 'Autres charges et autres produits',
  9: 'Engagements hors bilan et analytique',
};

/// Un compte du plan comptable.
class CompteComptable {
  final int id;
  final String numero; // texte : '4111'
  final String intitule;
  final int classe; // 1er chiffre du numéro
  final bool actif;
  final bool
  imputable; // false = compte de regroupement (il a des sous-comptes)

  const CompteComptable({
    required this.id,
    required this.numero,
    required this.intitule,
    required this.classe,
    required this.actif,
    required this.imputable,
  });
}

/// Un compte à enregistrer lors d'un import.
class CompteAImporter {
  final String numero;
  final String intitule;

  const CompteAImporter(this.numero, this.intitule);
}

/// Le bilan d'un import.
class ResultatImport {
  final int ajoutes;
  final int misAJour;
  final int inchanges;

  const ResultatImport({
    required this.ajoutes,
    required this.misAJour,
    required this.inchanges,
  });
}
