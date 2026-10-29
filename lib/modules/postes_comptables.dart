/// Un poste comptable : un endroit du logiciel qui doit être relié à un compte.
class PosteComptable {
  final String code;
  final String libelle;
  final String groupe;
  final String description;
  final List<String> propositions; // numéros de comptes proposés, dans l'ordre
  final bool parAgence; // peut avoir un compte différent selon l'agence
  final bool
  parClasse; // peut avoir un compte différent selon la classe d'articles

  const PosteComptable(
    this.code,
    this.libelle,
    this.groupe,
    this.description,
    this.propositions, {
    this.parAgence = false,
    this.parClasse = false,
  });
}

/// Les postes fixes du logiciel. Pour en ajouter un, on ajoute une ligne ici.
const List<PosteComptable> cataloguePostes = [
  PosteComptable(
    'client.collectif',
    'Compte des clients',
    'Tiers',
    'Créance sur chaque client (vente à crédit)',
    ['4111'],
  ),
  PosteComptable(
    'fournisseur.collectif',
    'Compte des fournisseurs',
    'Tiers',
    'Dette envers chaque fournisseur (achat à crédit)',
    ['4011'],
  ),
  PosteComptable(
    'vente.produit',
    'Ventes de marchandises',
    'Ventes',
    "Chiffre d'affaires des ventes",
    ['7011'],
  ),
  PosteComptable(
    'vente.remise',
    'Remises accordées',
    'Ventes',
    'Remises faites aux clients',
    ['7019', '709'],
  ),
  PosteComptable(
    'vente.tva',
    'TVA facturée sur les ventes',
    'Ventes',
    'TVA collectée auprès des clients',
    ['4431'],
  ),
  PosteComptable(
    'achat.charge',
    'Achats de marchandises',
    'Achats',
    'Coût des marchandises achetées',
    ['6011'],
  ),
  PosteComptable(
    'achat.remise',
    'Remises obtenues',
    'Achats',
    'Remises obtenues des fournisseurs',
    ['6019', '609'],
  ),
  PosteComptable(
    'achat.tva',
    'TVA récupérable sur les achats',
    'Achats',
    'TVA payée aux fournisseurs et récupérable',
    ['4452'],
  ),
  PosteComptable(
    'vente.produit',
    'Ventes de marchandises',
    'Ventes',
    "Chiffre d'affaires des ventes",
    ['7011'],
    parClasse: true,
  ),
];

/// Les comptes proposés pour un mode de paiement, selon son type.
const Map<String, List<String>> propositionsPaiement = {
  'caisse': ['5711'],
  'mobile': ['552', '5521'],
  'banque': ['5211'],
};
