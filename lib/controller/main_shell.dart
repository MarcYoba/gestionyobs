import 'package:flutter/material.dart';

import 'package:gestionyobs/security/login_page.dart';
import 'package:gestionyobs/security/utilisateur.dart';

import 'apres_connexion_page.dart';
import 'home_page.dart';

import 'package:gestionyobs/app/modules_app.dart';

/// La coque du logiciel : barre de navigation à gauche, pages à droite.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Le Navigator de la zone de contenu (à droite)
  final _navKey = GlobalKey<NavigatorState>();

  static const _titreAccueil = 'Accueil';
  String _actif = _titreAccueil;
  bool _reduit = false;

  // Une page sans animation, pour que le changement de module soit instantané
  Route<void> _route(WidgetBuilder builder) => PageRouteBuilder<void>(
    pageBuilder: (context, _, __) => builder(context),
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );

  // Remplace tout le contenu par la page demandée
  void _aller(String titre, WidgetBuilder builder) {
    setState(() => _actif = titre);
    _navKey.currentState?.pushAndRemoveUntil(_route(builder), (r) => false);
  }

  void _ouvrirModule(ModuleApp m) => _aller(m.titre, m.ouvrir);

  void _accueil() =>
      _aller(_titreAccueil, (_) => HomePage(onOuvrir: _ouvrirModule));

  void _changerAgence() {
    Session.agenceCourante = null;
    Navigator.of(context, rootNavigator: true).pushReplacement(
      MaterialPageRoute(builder: (_) => const ApresConnexionPage()),
    );
  }

  void _deconnecter() {
    Session.deconnecter();
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    final modules = construireModules().where((m) => m.autorise).toList();

    return Scaffold(
      body: Row(
        children: [
          _barre(modules),
          const VerticalDivider(width: 1),
          Expanded(
            child: Navigator(
              key: _navKey,
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => HomePage(onOuvrir: _ouvrirModule),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- La barre latérale ----------

  Widget _barre(List<ModuleApp> modules) {
    final couleurs = Theme.of(context).colorScheme;
    final utilisateur = Session.utilisateurCourant;
    final agence = Session.agenceCourante;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: _reduit ? 72 : 220,
      color: couleurs.surfaceContainerLow,
      child: Column(
        children: [
          // En-tête : bouton réduire/agrandir et identité
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(_reduit ? Icons.menu : Icons.menu_open),
                  tooltip: _reduit ? 'Agrandir le menu' : 'Réduire le menu',
                  onPressed: () => setState(() => _reduit = !_reduit),
                ),
                if (!_reduit)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          utilisateur?.nomComplet ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (agence != null)
                          Text(
                            agence.nom,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Les modules (la liste défile s'il y en a beaucoup)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _entree(
                  icone: Icons.home,
                  titre: _titreAccueil,
                  actif: _actif == _titreAccueil,
                  onTap: _accueil,
                ),
                for (final m in modules)
                  _entree(
                    icone: m.icone,
                    titre: m.titre,
                    actif: _actif == m.titre,
                    onTap: () => _ouvrirModule(m),
                  ),
              ],
            ),
          ),

          // Pied : agence et déconnexion
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                _entree(
                  icone: Icons.swap_horiz,
                  titre: "Changer d'agence",
                  actif: false,
                  onTap: _changerAgence,
                ),
                _entree(
                  icone: Icons.logout,
                  titre: 'Déconnexion',
                  actif: false,
                  onTap: _deconnecter,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _entree({
    required IconData icone,
    required String titre,
    required bool actif,
    required VoidCallback onTap,
  }) {
    final couleurs = Theme.of(context).colorScheme;
    final couleurTexte = actif
        ? couleurs.onPrimaryContainer
        : couleurs.onSurface;

    final entree = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: actif ? couleurs.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(icone, size: 22, color: couleurTexte),
                if (!_reduit) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      titre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: couleurTexte,
                        fontWeight: actif ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    // Barre réduite : seul l'icône est visible, le nom s'affiche au survol
    return _reduit ? Tooltip(message: titre, child: entree) : entree;
  }
}
