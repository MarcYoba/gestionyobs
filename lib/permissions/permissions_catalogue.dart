/// Une fonction du logiciel qu'on peut autoriser ou interdire.
class PermissionDef {
  final String code;
  final String libelle;
  final String groupe;
  final bool adminSeulement;

  const PermissionDef(
    this.code,
    this.libelle,
    this.groupe, {
    this.adminSeulement = false,
  });
}

/// Le catalogue de toutes les fonctions du logiciel.
const List<PermissionDef> cataloguePermissions = [
  PermissionDef('ventes.voir', 'Voir les ventes', 'Ventes'),
  PermissionDef('ventes.creer', 'Enregistrer une vente (caisse)', 'Ventes'),
  PermissionDef('ventes.annuler', 'Annuler une vente', 'Ventes'),
  PermissionDef('stock.voir', 'Consulter le stock', 'Stock'),
  PermissionDef(
    'stock.modifier',
    'Modifier le stock et enregistrer les réceptions',
    'Stock',
  ),
  PermissionDef(
    'achats.prix_achat_voir',
    "Voir les prix d'achat et les marges",
    'Achats',
  ),
  PermissionDef(
    'rapports.voir',
    'Consulter les rapports et finances',
    'Rapports',
  ),
  PermissionDef(
    'utilisateurs.gerer',
    'Gérer les utilisateurs',
    'Administration',
    adminSeulement: true,
  ),
  PermissionDef(
    'agences.gerer',
    'Gérer les agences',
    'Administration',
    adminSeulement: true,
  ),
  PermissionDef(
    'droits.gerer',
    'Gérer les rôles et les droits',
    'Administration',
    adminSeulement: true,
  ),
];

/// Les droits donnés au départ aux rôles de base (d'après le tableau validé).
const Map<String, List<String>> droitsParDefaut = {
  'vendeur': ['ventes.voir', 'ventes.creer', 'stock.voir'],
  'comptable': ['stock.voir', 'achats.prix_achat_voir', 'rapports.voir'],
  'magasinier': ['stock.voir', 'stock.modifier'],
};
