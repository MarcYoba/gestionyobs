import 'package:flutter/material.dart';

import 'package:gestionyobs/modules/module_page.dart';
import 'package:gestionyobs/permissions/roles_droits_page.dart';
import 'package:gestionyobs/security/utilisateur.dart';
import 'package:gestionyobs/page/articles_page.dart';
import 'package:gestionyobs/page/stock_page.dart';
import 'package:gestionyobs/page/tiers_page.dart';
import 'package:gestionyobs/page/modes_paiement_page.dart';
import 'package:gestionyobs/page/plan_comptable_page.dart';
import 'package:gestionyobs/page/associations_page.dart';
import 'package:gestionyobs/page/classes_articles_page.dart';
import 'package:gestionyobs/page/achats_page.dart';
import 'package:gestionyobs/page/ventes_page.dart';
import 'package:gestionyobs/page/impression_page.dart';
import 'package:gestionyobs/page/reglements_page.dart';
import 'package:gestionyobs/page/sauvegardes_page.dart';
import 'package:gestionyobs/page/licence_page.dart';
import 'package:gestionyobs/page/rapports_page.dart';

import 'package:gestionyobs/controller/utilisateurs_page.dart';

/// Un module du logiciel : une entrée de la barre et une carte de l'accueil.
class ModuleApp {
  final String titre;
  final String description;
  final IconData icone;
  final List<String> permissions; // il suffit d'en avoir une
  final WidgetBuilder ouvrir;

  const ModuleApp({
    required this.titre,
    required this.description,
    required this.icone,
    required this.permissions,
    required this.ouvrir,
  });

  bool get autorise => permissions.any(Session.peut);
}

/// Tous les modules, dans l'ordre d'affichage de la barre.
List<ModuleApp> construireModules() {
  ModuleApp bientot(
    String titre,
    String description,
    IconData icone,
    List<String> permissions,
  ) {
    return ModuleApp(
      titre: titre,
      description: description,
      icone: icone,
      permissions: permissions,
      ouvrir: (_) =>
          ModulePage(titre: titre, icone: icone, permissions: permissions),
    );
  }

  return [
    ModuleApp(
      titre: 'Ventes',
      description: 'Caisse, factures et crédits',
      icone: Icons.point_of_sale,
      permissions: ['ventes.creer', 'ventes.voir'],
      ouvrir: (_) => const VentesPage(),
    ),
    ModuleApp(
      titre: 'Achats',
      description: 'Achats, paiements et dettes',
      icone: Icons.shopping_cart,
      permissions: ['achats.voir', 'achats.creer'],
      ouvrir: (_) => const AchatsPage(),
    ),
    ModuleApp(
      titre: 'Règlements',
      description: 'Créances clients et dettes fournisseurs',
      icone: Icons.account_balance_wallet,
      permissions: [
        'reglements.voir',
        'reglements.clients',
        'reglements.fournisseurs',
      ],
      ouvrir: (_) => const ReglementsPage(),
    ),
    ModuleApp(
      titre: 'Stock',
      description: "Stock de l'agence et mouvements",
      icone: Icons.inventory_2,
      permissions: ['stock.voir', 'stock.modifier', 'stock.ajuster'],
      ouvrir: (_) => const StockPage(),
    ),
    ModuleApp(
      titre: 'Articles',
      description: 'Catalogue commun et prix',
      icone: Icons.category,
      permissions: ['articles.voir', 'articles.gerer'],
      ouvrir: (_) => const ArticlesPage(),
    ),
    ModuleApp(
      titre: "Classes d'articles",
      description: 'Familles de produits et comptes',
      icone: Icons.folder_copy,
      permissions: [
        'articles.voir',
        'articles.gerer',
        'comptabilite.voir',
        'comptabilite.gerer',
      ],
      ouvrir: (_) => const ClassesArticlesPage(),
    ),
    ModuleApp(
      titre: 'Clients',
      description: 'Fiches clients et plafond de crédit',
      icone: Icons.groups,
      permissions: ['clients.voir', 'clients.gerer'],
      ouvrir: (_) => const TiersPage(type: 'client'),
    ),
    ModuleApp(
      titre: 'Fournisseurs',
      description: 'Fiches fournisseurs',
      icone: Icons.local_shipping,
      permissions: ['fournisseurs.voir', 'fournisseurs.gerer'],
      ouvrir: (_) => const TiersPage(type: 'fournisseur'),
    ),
    ModuleApp(
      titre: 'Rapports',
      description: 'Par jour, semaine, mois, trimestre, semestre, année',
      icone: Icons.bar_chart,
      permissions: ['rapports.voir'],
      ouvrir: (_) => const RapportsPage(),
    ),
    ModuleApp(
      titre: 'Impression',
      description: 'Imprimante, papier 58 ou 80 mm, en-tête',
      icone: Icons.print,
      permissions: ['ventes.creer', 'ventes.voir', 'parametres.gerer'],
      ouvrir: (_) => const ImpressionPage(),
    ),
    ModuleApp(
      titre: 'Modes de paiement',
      description: 'Espèces, mobile money, banque...',
      icone: Icons.payments,
      permissions: ['paiements.gerer'],
      ouvrir: (_) => const ModesPaiementPage(),
    ),
    ModuleApp(
      titre: 'Plan comptable',
      description: 'Comptes et import du plan',
      icone: Icons.menu_book,
      permissions: ['comptabilite.voir', 'comptabilite.gerer'],
      ouvrir: (_) => const PlanComptablePage(),
    ),
    ModuleApp(
      titre: 'Associations comptables',
      description: 'Quel compte pour chaque poste',
      icone: Icons.account_tree,
      permissions: ['comptabilite.voir', 'comptabilite.gerer'],
      ouvrir: (_) => const AssociationsPage(),
    ),
    ModuleApp(
      titre: 'Utilisateurs',
      description: 'Comptes et affectation aux agences',
      icone: Icons.people,
      permissions: ['utilisateurs.gerer'],
      ouvrir: (_) => const UtilisateursPage(),
    ),
    ModuleApp(
      titre: 'Rôles et droits',
      description: 'Ce que chaque rôle peut faire',
      icone: Icons.admin_panel_settings,
      permissions: ['droits.gerer'],
      ouvrir: (_) => const RolesDroitsPage(),
    ),
    ModuleApp(
      titre: 'Sauvegardes',
      description: 'Copies de la base et restauration',
      icone: Icons.backup,
      permissions: ['sauvegardes.gerer'],
      ouvrir: (_) => const SauvegardesPage(),
    ),
    ModuleApp(
      titre: 'Licence',
      description: 'Activation du logiciel',
      icone: Icons.verified_user,
      permissions: ['licence.gerer'],
      ouvrir: (_) => const LicencePage(),
    ),
  ];
}
