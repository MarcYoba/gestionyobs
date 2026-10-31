import 'package:flutter/material.dart';
import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/association/association.dart';
import 'package:gestionyobs/modules/compte_comptable.dart';
import 'package:gestionyobs/dialog/compte_selecteur_dialog.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/page/exceptions_page.dart';
import 'package:gestionyobs/page/historique_associations_page.dart';
import 'package:gestionyobs/modules/postes_comptables.dart';
import 'package:gestionyobs/security/utilisateur.dart';
import 'package:gestionyobs/dialog/simulateur_compte_dialog.dart';

class AssociationsPage extends StatefulWidget {
  const AssociationsPage({super.key});

  @override
  State<AssociationsPage> createState() => _AssociationsPageState();
}

class _AssociationsPageState extends State<AssociationsPage> {
  List<PosteComptable> _postes = [];
  List<Association> _associations = [];
  bool _chargement = true;
  String? _erreur;

  bool get _peutGerer => Session.peut('comptabilite.gerer');
  bool get _autorise => Session.peut('comptabilite.voir') || _peutGerer;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  String _nettoyer(Object e) => e.toString().replaceFirst('Exception: ', '');

  void _message(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  // Le compte par défaut d'un poste (null s'il n'y en a pas)
  Association? _defaut(String poste) {
    for (final a in _associations) {
      if (a.poste == poste && a.portee == 'defaut') return a;
    }
    return null;
  }

  int _nbExceptions(String poste, String portee) =>
      _associations.where((a) => a.poste == poste && a.portee == portee).length;

  Future<void> _charger() async {
    try {
      final postes = await DatabaseService.listerPostes();
      final associations = await DatabaseService.listerAssociations();
      if (!mounted) return;
      setState(() {
        _postes = postes;
        _associations = associations;
        _chargement = false;
        _erreur = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = _nettoyer(e);
      });
    }
  }

  Future<void> _choisirCompte(PosteComptable poste) async {
    try {
      final comptes = await DatabaseService.listerComptes();
      if (!mounted) return;

      final choix = await showDialog<CompteComptable>(
        context: context,
        builder: (_) => CompteSelecteurDialog(
          titre: poste.libelle,
          comptes: comptes,
          propositions: poste.propositions,
        ),
      );
      if (choix == null) return;

      await DatabaseService.definirAssociation(
        poste: poste.code,
        compteId: choix.id,
      );
      await _charger();
    } catch (e) {
      if (!mounted) return;
      _message(_nettoyer(e));
    }
  }

  Future<void> _retirer(PosteComptable poste) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Retirer l'association ?"),
        content: Text('Le poste « ${poste.libelle} » n\'aura plus de compte.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    try {
      await DatabaseService.supprimerAssociation(poste: poste.code);
      await _charger();
    } catch (e) {
      if (!mounted) return;
      _message(_nettoyer(e));
    }
  }

  Future<void> _appliquerPropositions() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Appliquer les propositions ?'),
        content: const Text(
          'Les comptes proposés seront associés aux postes qui n\'ont encore '
          'aucun compte. Seuls les comptes qui existent dans le plan et qui ne '
          'sont pas des comptes de regroupement sont utilisés. Vous pourrez '
          'ensuite les modifier un par un.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Appliquer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    try {
      final r = await DatabaseService.appliquerPropositions();
      await _charger();
      if (!mounted) return;
      _message(
        '${r.appliquees} proposition(s) appliquée(s), '
        '${r.ignorees} ignorée(s) (compte absent du plan ou de regroupement)',
      );
    } catch (e) {
      if (!mounted) return;
      _message(_nettoyer(e));
    }
  }

  Future<void> _ouvrirExceptions(PosteComptable poste, String portee) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExceptionsPage(poste: poste, portee: portee),
      ),
    );
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    if (!_autorise) {
      return Scaffold(
        appBar: AppBar(title: const Text('Associations comptables')),
        body: const AccesRefuse(),
      );
    }

    // Les postes rangés par groupe, dans l'ordre
    final groupes = <String, List<PosteComptable>>{};
    for (final p in _postes) {
      groupes.putIfAbsent(p.groupe, () => []).add(p);
    }
    final associes = _postes.where((p) => _defaut(p.code) != null).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Associations comptables'),
        actions: [
          if (_peutGerer)
            IconButton(
              icon: const Icon(Icons.auto_fix_high),
              tooltip: 'Appliquer les propositions',
              onPressed: _appliquerPropositions,
            ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historique des modifications',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const HistoriqueAssociationsPage(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.rule),
            tooltip: 'Quel compte serait utilisé ?',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const SimulateurCompteDialog(),
            ),
          ),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _erreur != null
          ? Center(
              child: Text(_erreur!, style: const TextStyle(color: Colors.red)),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 950),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      '$associes poste(s) sur ${_postes.length} ont un compte. '
                      "Les modifications ne concernent que les opérations à venir.",
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    for (final groupe in groupes.entries) ...[
                      const SizedBox(height: 16),
                      Text(
                        groupe.key,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 4),
                      for (final p in groupe.value) _ligne(p),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _ligne(PosteComptable p) {
    final defaut = _defaut(p.code);
    final nbAgences = _nbExceptions(p.code, 'agence');
    final nbClasses = _nbExceptions(p.code, 'classe');

    return Card(
      child: ListTile(
        isThreeLine: true,
        title: Text(p.libelle),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p.description,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 2),
            Text(
              defaut == null
                  ? 'Aucun compte associé'
                  : 'Compte : ${defaut.numero}  ${defaut.intitule}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: defaut == null
                    ? Colors.orange.shade800
                    : Colors.green.shade800,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (p.parAgence && (_peutGerer || nbAgences > 0))
              IconButton(
                icon: Badge(
                  isLabelVisible: nbAgences > 0,
                  label: Text('$nbAgences'),
                  child: const Icon(Icons.store),
                ),
                tooltip: "Compte différent selon l'agence",
                onPressed: () => _ouvrirExceptions(p, 'agence'),
              ),
            if (p.parClasse && (_peutGerer || nbClasses > 0))
              IconButton(
                icon: Badge(
                  isLabelVisible: nbClasses > 0,
                  label: Text('$nbClasses'),
                  child: const Icon(Icons.category),
                ),
                tooltip: "Compte différent selon la classe d'articles",
                onPressed: () => _ouvrirExceptions(p, 'classe'),
              ),
            if (_peutGerer)
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Choisir le compte',
                onPressed: () => _choisirCompte(p),
              ),
            if (_peutGerer && defaut != null)
              IconButton(
                icon: const Icon(Icons.link_off),
                tooltip: "Retirer l'association",
                onPressed: () => _retirer(p),
              ),
          ],
        ),
      ),
    );
  }
}
