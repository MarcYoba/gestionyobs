import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/modules/article.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/security/utilisateur.dart';
import 'package:gestionyobs/modules/classe_article.dart';

class ArticleFormPage extends StatefulWidget {
  final Article? article; // null = nouvel article

  const ArticleFormPage({super.key, this.article});

  @override
  State<ArticleFormPage> createState() => _ArticleFormPageState();
}

class _ArticleFormPageState extends State<ArticleFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _designationController;
  // late final TextEditingController _categorieController;
  late final TextEditingController _prixVenteController;
  late final TextEditingController _prixAchatController;
  late final TextEditingController _seuilController;
  int? _classeId;
  List<ClasseArticle> _classes = [];
  bool _classesChargees = false;
  late String _unite;
  late bool _actif;

  // List<String> _categories = [];
  bool _chargement = false;
  String? _erreur;

  bool get _edition => widget.article != null;
  bool get _peutVoirPrixAchat => Session.peut('achats.prix_achat_voir');

  @override
  void initState() {
    super.initState();
    final a = widget.article;
    _codeController = TextEditingController(text: a?.code ?? '');
    _designationController = TextEditingController(text: a?.designation ?? '');
    // _categorieController = TextEditingController(text: a?.categorie ?? '');
    _classeId = a?.classeId;
    _prixVenteController = TextEditingController(
      text: a == null ? '' : a.prixVente.toString(),
    );
    _prixAchatController = TextEditingController(
      text: a?.prixAchat?.toString() ?? '',
    );
    _seuilController = TextEditingController(
      text: a == null ? '0' : formaterQuantite(a.seuilAlerte),
    );
    _unite = a?.unite ?? unitesDisponibles.first;
    _actif = a?.actif ?? true;
    // _chargerCategories();
    _chargerClasses();
    if (a == null) _chargerApercu();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _designationController.dispose();
    //_categorieController.dispose();
    _prixVenteController.dispose();
    _prixAchatController.dispose();
    _seuilController.dispose();
    super.dispose();
  }

  // Future<void> _chargerCategories() async {
  //   final categories = await DatabaseService.categoriesArticles();
  //   if (!mounted) return;
  //   setState(() => _categories = categories);
  // }
  Future<void> _chargerClasses() async {
    final classes = await DatabaseService.listerClasses(inclureInactives: true);
    if (!mounted) return;
    setState(() {
      _classes = classes;
      _classesChargees = true;
    });
  }

  // Montre le prochain matricule (attribué définitivement à l'enregistrement)
  Future<void> _chargerApercu() async {
    final apercu = await DatabaseService.apercuProchainMatriculeArticle();
    if (!mounted) return;
    _codeController.text = apercu;
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _chargement = true;
      _erreur = null;
    });

    try {
      final designation = _designationController.text.trim();
      // final categorie = _categorieController.text.trim();
      final prixVente = int.parse(_prixVenteController.text.trim());
      final prixAchatTexte = _prixAchatController.text.trim();
      final prixAchat = prixAchatTexte.isEmpty
          ? null
          : int.parse(prixAchatTexte);
      final seuilTexte = _seuilController.text.trim().replaceAll(',', '.');
      final seuil = seuilTexte.isEmpty ? 0.0 : double.parse(seuilTexte);

      if (_edition) {
        await DatabaseService.modifierArticle(
          id: widget.article!.id,
          designation: designation,
          //categorie: categorie,
          classeId: _classeId,
          unite: _unite,
          prixAchat: prixAchat,
          prixVente: prixVente,
          seuilAlerte: seuil,
          actif: _actif,
        );
      } else {
        final codeCree = await DatabaseService.creerArticle(
          designation: designation,
          // categorie: categorie,
          classeId: _classeId,
          unite: _unite,
          prixAchat: prixAchat,
          prixVente: prixVente,
          seuilAlerte: seuil,
        );
        if (!mounted) return;
        // Le message reste affiché sur la page suivante
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Article créé - matricule $codeCree')),
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Session.peut('articles.gerer')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Article')),
        body: const AccesRefuse(),
      );
    }

    // On s'assure que l'unité actuelle fait partie de la liste
    final unites = unitesDisponibles.contains(_unite)
        ? unitesDisponibles
        : [...unitesDisponibles, _unite];

    return Scaffold(
      appBar: AppBar(
        title: Text(_edition ? "Modifier l'article" : 'Nouvel article'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 520,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _codeController,
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: _edition
                              ? 'Matricule'
                              : 'Matricule (automatique)',
                          helperText: _edition
                              ? null
                              : "Attribué définitivement à l'enregistrement",
                          prefixIcon: const Icon(Icons.tag),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _designationController,
                        decoration: const InputDecoration(
                          labelText: 'Désignation',
                          prefixIcon: Icon(Icons.inventory_2),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Veuillez saisir la désignation'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        // controller: _categorieController,
                        decoration: const InputDecoration(
                          labelText: 'Catégorie (facultatif)',
                          prefixIcon: Icon(Icons.category),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      // if (_categories.isNotEmpty) ...[
                      //   const SizedBox(height: 8),
                      //   Wrap(
                      //     spacing: 6,
                      //     runSpacing: 6,
                      //     children: _categories
                      //         .map(
                      //           (c) => ActionChip(
                      //             label: Text(c),
                      //             visualDensity: VisualDensity.compact,
                      //             onPressed: () => setState(
                      //               () => _categorieController.text = c,
                      //             ),
                      //           ),
                      //         )
                      //         .toList(),
                      //   ),
                      // ],
                      if (!_classesChargees)
                        const LinearProgressIndicator()
                      else
                        DropdownButtonFormField<int?>(
                          initialValue: _classeId,
                          decoration: const InputDecoration(
                            labelText: "Classe d'articles (facultatif)",
                            prefixIcon: Icon(Icons.category),
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Aucune classe'),
                            ),
                            for (final c in _classes)
                              if (c.actif || c.id == _classeId)
                                DropdownMenuItem<int?>(
                                  value: c.id,
                                  child: Text(
                                    c.actif ? c.nom : '${c.nom} (désactivée)',
                                  ),
                                ),
                          ],
                          onChanged: (v) => setState(() => _classeId = v),
                        ),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        initialValue: _unite,
                        decoration: const InputDecoration(
                          labelText: 'Unité',
                          prefixIcon: Icon(Icons.straighten),
                          border: OutlineInputBorder(),
                        ),
                        items: unites
                            .map(
                              (u) => DropdownMenuItem(value: u, child: Text(u)),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _unite = v);
                        },
                      ),
                      const SizedBox(height: 16),

                      if (_peutVoirPrixAchat) ...[
                        TextFormField(
                          controller: _prixAchatController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: "Prix d'achat (facultatif)",
                            prefixIcon: Icon(Icons.shopping_cart),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      TextFormField(
                        controller: _prixVenteController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Prix de vente',
                          prefixIcon: Icon(Icons.sell),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Veuillez saisir le prix de vente';
                          }
                          if (int.tryParse(v.trim()) == null) {
                            return 'Nombre invalide';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _seuilController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        decoration: const InputDecoration(
                          labelText: "Seuil d'alerte de stock",
                          helperText: 'Une alerte sera affichée quand le stock descend à ce niveau',
                          prefixIcon: Icon(Icons.warning_amber),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final texte = (v ?? '').trim().replaceAll(',', '.');
                          if (texte.isEmpty) return null;
                          if (double.tryParse(texte) == null) {
                            return 'Nombre invalide';
                          }
                          return null;
                        },
                      ),

                      if (_edition) ...[
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Article actif'),
                          subtitle: Text(
                            _actif ? 'Proposé à la vente' : "Désactivé : conservé dans l'historique, mais non proposé",
                          ),
                          value: _actif,
                          onChanged: (v) => setState(() => _actif = v),
                        ),
                      ],

                      if (_erreur != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _erreur!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: _chargement ? null : _enregistrer,
                          child: _chargement
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _edition ? 'Enregistrer' : "Créer l'article",
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
