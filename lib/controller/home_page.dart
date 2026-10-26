import 'package:flutter/material.dart';

import 'apres_connexion_page.dart';

import 'package:gestionyobs/security/login_page.dart';
import 'package:gestionyobs/modules/module_page.dart';
import 'package:gestionyobs/permissions/roles_droits_page.dart';
import 'package:gestionyobs/security/utilisateur.dart';
import 'package:gestionyobs/page/articles_page.dart';

import 'utilisateurs_page.dart';

/// Un module de l'accueil : une carte qui ouvre une page.
class _Module {
  final String titre;
  final String description;
  final IconData icone;
  final List<String> permissions; // il suffit d'en avoir une
  final WidgetBuilder ouvrir; // construit la page à ouvrir

  _Module({
    required this.titre,
    required this.description,
    required this.icone,
    required this.permissions,
    required this.ouvrir,
  });

  bool get autorise => permissions.any(Session.peut);
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // Un module pas encore construit
  _Module _bientot(
    String titre,
    String description,
    IconData icone,
    List<String> permissions,
  ) {
    return _Module(
      titre: titre,
      description: description,
      icone: icone,
      permissions: permissions,
      ouvrir: (_) =>
          ModulePage(titre: titre, icone: icone, permissions: permissions),
    );
  }

  @override
  Widget build(BuildContext context) {
    final utilisateur = Session.utilisateurCourant!;
    final agence = Session.agenceCourante;

    // La liste complète des modules du logiciel
    final modules = <_Module>[
      _bientot(
        'Ventes',
        'Caisse et historique des ventes',
        Icons.point_of_sale,
        ['ventes.creer', 'ventes.voir'],
      ),
      _Module(
        titre: 'Articles',
        description: 'Catalogue commun et prix',
        icone: Icons.category,
        permissions: ['articles.voir', 'articles.gerer'],
        ouvrir: (_) => const ArticlesPage(),
      ),
      _bientot('Stock', 'Articles, stock et réceptions', Icons.inventory_2, [
        'stock.voir',
        'stock.modifier',
      ]),
      _bientot('Achats', 'Achats et fournisseurs', Icons.shopping_cart, [
        'achats.voir',
      ]),
      _bientot('Rapports', 'Rapports et finances', Icons.bar_chart, [
        'rapports.voir',
      ]),
      _Module(
        titre: 'Utilisateurs',
        description: 'Comptes et affectation aux agences',
        icone: Icons.people,
        permissions: ['utilisateurs.gerer'],
        ouvrir: (_) => const UtilisateursPage(),
      ),
      _Module(
        titre: 'Rôles et droits',
        description: 'Ce que chaque rôle peut faire',
        icone: Icons.admin_panel_settings,
        permissions: ['droits.gerer'],
        ouvrir: (_) => const RolesDroitsPage(),
      ),
    ];

    // On ne garde que ceux que l'utilisateur a le droit d'utiliser
    final visibles = modules.where((m) => m.autorise).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(agence == null ? 'Accueil' : 'Accueil - ${agence.nom}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: "Changer d'agence",
            onPressed: () {
              Session.agenceCourante = null;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ApresConnexionPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: () {
              Session.deconnecter();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bonjour ${utilisateur.nomComplet}',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(label: Text(libelleRole(utilisateur.role))),
                    if (agence != null)
                      Chip(
                        avatar: const Icon(Icons.store, size: 18),
                        label: Text('Agence : ${agence.nom}'),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                if (visibles.isEmpty)
                  const Text(
                    "Aucune fonction n'est disponible pour votre rôle. "
                    "Contactez l'administrateur.",
                  )
                else
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: visibles
                        .map((m) => _CarteModule(module: m))
                        .toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CarteModule extends StatelessWidget {
  final _Module module;

  const _CarteModule({required this.module});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      height: 150,
      child: Card(
        elevation: 3,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: module.ouvrir),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(module.icone, size: 40, color: Colors.green),
                const SizedBox(height: 8),
                Text(
                  module.titre,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  module.description,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
