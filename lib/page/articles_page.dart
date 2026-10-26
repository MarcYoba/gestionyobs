import 'package:flutter/material.dart';
import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/modules/article.dart';
import 'package:gestionyobs/form/article_form_page.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/security/utilisateur.dart';

class ArticlesPage extends StatefulWidget {
  const ArticlesPage({super.key});

  @override
  State<ArticlesPage> createState() => _ArticlesPageState();
}

class _ArticlesPageState extends State<ArticlesPage> {
  final _rechercheController = TextEditingController();
  List<Article> _articles = [];
  bool _chargement = true;
  bool _inclureInactifs = false;
  String? _erreur;

  bool get _peutGerer => Session.peut('articles.gerer');
  bool get _peutVoirPrixAchat => Session.peut('achats.prix_achat_voir');

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _rechercheController.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      final liste = await DatabaseService.listerArticles(
        recherche: _rechercheController.text,
        inclureInactifs: _inclureInactifs,
      );
      if (!mounted) return;
      setState(() {
        _articles = liste;
        _chargement = false;
        _erreur = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _ouvrirFormulaire([Article? article]) async {
    final modifie = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ArticleFormPage(article: article)),
    );
    if (modifie == true) _charger();
  }

  @override
  Widget build(BuildContext context) {
    if (!Session.peut('articles.voir') && !_peutGerer) {
      return Scaffold(
        appBar: AppBar(title: const Text('Articles')),
        body: const AccesRefuse(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Articles')),
      floatingActionButton: _peutGerer
          ? FloatingActionButton.extended(
              onPressed: () => _ouvrirFormulaire(),
              icon: const Icon(Icons.add),
              label: const Text('Nouvel article'),
            )
          : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _rechercheController,
                        onChanged: (_) => _charger(),
                        decoration: const InputDecoration(
                          labelText: 'Rechercher (référence, nom, catégorie)',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    if (_peutGerer) ...[
                      const SizedBox(width: 12),
                      FilterChip(
                        label: const Text('Afficher les désactivés'),
                        selected: _inclureInactifs,
                        onSelected: (v) {
                          setState(() => _inclureInactifs = v);
                          _charger();
                        },
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: _chargement
                    ? const Center(child: CircularProgressIndicator())
                    : _erreur != null
                    ? Center(
                        child: Text(
                          _erreur!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    : _articles.isEmpty
                    ? const Center(child: Text('Aucun article'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                        itemCount: _articles.length,
                        itemBuilder: (context, index) {
                          final a = _articles[index];
                          final details = [
                            a.code,
                            if (a.categorie != null) a.categorie!,
                            a.unite,
                            if (!a.actif) 'Désactivé',
                          ].join(' · ');

                          return Card(
                            child: ListTile(
                              onTap: _peutGerer
                                  ? () => _ouvrirFormulaire(a)
                                  : null,
                              title: Text(
                                a.designation,
                                style: TextStyle(
                                  decoration: a.actif
                                      ? null
                                      : TextDecoration.lineThrough,
                                ),
                              ),
                              subtitle: Text(details),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    formaterPrix(a.prixVente),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (_peutVoirPrixAchat && a.prixAchat != null)
                                    Text(
                                      'Achat : ${formaterPrix(a.prixAchat!)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
