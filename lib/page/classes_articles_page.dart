import 'package:flutter/material.dart';

import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/association/association.dart';
import 'package:gestionyobs/modules/classe_article.dart';
import 'package:gestionyobs/modules/compte_comptable.dart';
import 'package:gestionyobs/dialog/compte_selecteur_dialog.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/security/utilisateur.dart';

class ClassesArticlesPage extends StatefulWidget {
  const ClassesArticlesPage({super.key});

  @override
  State<ClassesArticlesPage> createState() => _ClassesArticlesPageState();
}

class _ClassesArticlesPageState extends State<ClassesArticlesPage> {
  List<ClasseArticle> _classes = [];
  List<Association> _associations = [];
  bool _chargement = true;
  String? _erreur;

  bool get _peutGererClasses => Session.peut('articles.gerer');
  bool get _peutGererCompta => Session.peut('comptabilite.gerer');
  bool get _peutVoirCompta =>
      Session.peut('comptabilite.voir') || _peutGererCompta;
  bool get _autorise =>
      Session.peut('articles.voir') || _peutGererClasses || _peutVoirCompta;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  String _nettoyer(Object e) => e.toString().replaceFirst('Exception: ', '');

  void _message(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  // Le compte de cette classe pour un poste (null = celui du poste général)
  Association? _compte(int classeId, String poste) {
    for (final a in _associations) {
      if (a.poste == poste && a.portee == 'classe' && a.porteeId == classeId) {
        return a;
      }
    }
    return null;
  }

  String _texteCompte(String libelle, Association? a) => a == null
      ? '$libelle : compte du poste général'
      : '$libelle : ${a.numero}  ${a.intitule}';

  Future<void> _charger() async {
    try {
      final classes = await DatabaseService.listerClasses(
        inclureInactives: true,
      );
      final associations = _peutVoirCompta
          ? await DatabaseService.listerAssociations()
          : <Association>[];
      if (!mounted) return;
      setState(() {
        _classes = classes;
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

  Future<void> _ajouterOuModifier([ClasseArticle? classe]) async {
    final r = await showDialog<Map<String, Object>>(
      context: context,
      builder: (_) => _ClasseDialog(classe: classe),
    );
    if (r == null) return;

    try {
      if (classe == null) {
        await DatabaseService.creerClasse(r['nom'] as String);
      } else {
        await DatabaseService.modifierClasse(
          id: classe.id,
          nom: r['nom'] as String,
          actif: r['actif'] as bool,
        );
      }
      await _charger();
    } catch (e) {
      if (!mounted) return;
      _message(_nettoyer(e));
    }
  }

  Future<void> _choisirCompte(ClasseArticle classe, String poste) async {
    try {
      final comptes = await DatabaseService.listerComptes();
      if (!mounted) return;

      final choix = await showDialog<CompteComptable>(
        context: context,
        builder: (_) => CompteSelecteurDialog(
          titre:
              '${poste == 'vente.produit' ? 'Ventes' : 'Achats'} - ${classe.nom}',
          comptes: comptes,
        ),
      );
      if (choix == null) return;

      await DatabaseService.definirAssociation(
        poste: poste,
        compteId: choix.id,
        portee: 'classe',
        porteeId: classe.id,
      );
      await _charger();
    } catch (e) {
      if (!mounted) return;
      _message(_nettoyer(e));
    }
  }

  Future<void> _retirerCompte(ClasseArticle classe, String poste) async {
    try {
      await DatabaseService.supprimerAssociation(
        poste: poste,
        portee: 'classe',
        porteeId: classe.id,
      );
      await _charger();
    } catch (e) {
      if (!mounted) return;
      _message(_nettoyer(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_autorise) {
      return Scaffold(
        appBar: AppBar(title: const Text("Classes d'articles")),
        body: const AccesRefuse(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Classes d'articles")),
      floatingActionButton: _peutGererClasses
          ? FloatingActionButton.extended(
              onPressed: () => _ajouterOuModifier(),
              icon: const Icon(Icons.add),
              label: const Text('Nouvelle classe'),
            )
          : null,
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _erreur != null
          ? Center(
              child: Text(_erreur!, style: const TextStyle(color: Colors.red)),
            )
          : _classes.isEmpty
          ? const Center(child: Text("Aucune classe d'articles"))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  itemCount: _classes.length,
                  itemBuilder: (context, index) {
                    final c = _classes[index];
                    final vente = _compte(c.id, 'vente.produit');
                    final achat = _compte(c.id, 'achat.charge');

                    return Card(
                      child: ListTile(
                        isThreeLine: _peutVoirCompta,
                        leading: const Icon(
                          Icons.category,
                          color: Colors.green,
                        ),
                        title: Text(
                          c.nom,
                          style: TextStyle(
                            decoration: c.actif
                                ? null
                                : TextDecoration.lineThrough,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${c.nbArticles} article(s)'
                              '${c.actif ? '' : ' · Désactivée'}',
                            ),
                            if (_peutVoirCompta) ...[
                              Text(
                                _texteCompte('Ventes', vente),
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                _texteCompte('Achats', achat),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_peutGererClasses)
                              IconButton(
                                icon: const Icon(Icons.edit),
                                tooltip: 'Renommer ou désactiver',
                                onPressed: () => _ajouterOuModifier(c),
                              ),
                            if (_peutGererCompta)
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.account_balance),
                                tooltip: 'Comptes de cette classe',
                                onSelected: (choix) {
                                  switch (choix) {
                                    case 'vente':
                                      _choisirCompte(c, 'vente.produit');
                                    case 'achat':
                                      _choisirCompte(c, 'achat.charge');
                                    case 'retirer_vente':
                                      _retirerCompte(c, 'vente.produit');
                                    case 'retirer_achat':
                                      _retirerCompte(c, 'achat.charge');
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'vente',
                                    child: Text('Choisir le compte de vente'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'achat',
                                    child: Text("Choisir le compte d'achat"),
                                  ),
                                  if (vente != null)
                                    const PopupMenuItem(
                                      value: 'retirer_vente',
                                      child: Text(
                                        'Revenir au compte de vente général',
                                      ),
                                    ),
                                  if (achat != null)
                                    const PopupMenuItem(
                                      value: 'retirer_achat',
                                      child: Text(
                                        "Revenir au compte d'achat général",
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }
}

/// Boîte de dialogue : nouvelle classe, ou renommer / désactiver.
class _ClasseDialog extends StatefulWidget {
  final ClasseArticle? classe; // null = nouvelle classe

  const _ClasseDialog({this.classe});

  @override
  State<_ClasseDialog> createState() => _ClasseDialogState();
}

class _ClasseDialogState extends State<_ClasseDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomController;
  late bool _actif;

  bool get _edition => widget.classe != null;

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController(text: widget.classe?.nom ?? '');
    _actif = widget.classe?.actif ?? true;
  }

  @override
  void dispose() {
    _nomController.dispose();
    super.dispose();
  }

  void _valider() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, <String, Object>{
      'nom': _nomController.text.trim(),
      'actif': _actif,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _edition ? 'Modifier la classe' : "Nouvelle classe d'articles",
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nomController,
                autofocus: true,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'Nom (ex. Outillage)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Veuillez saisir un nom'
                    : null,
                onFieldSubmitted: (_) => _valider(),
              ),
              if (_edition)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Classe active'),
                  subtitle: const Text(
                    'Désactivée : non proposée pour de nouveaux articles',
                  ),
                  value: _actif,
                  onChanged: (v) => setState(() => _actif = v),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _valider, child: const Text('Enregistrer')),
      ],
    );
  }
}
