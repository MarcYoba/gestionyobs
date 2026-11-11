import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/modules/article.dart';
import 'package:gestionyobs/dialog/article_transfert_dialog.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/modules/transfert.dart';
import 'package:gestionyobs/security/utilisateur.dart';
import 'package:gestionyobs/modules/vente.dart';

// Une ligne de la demande
class _LigneDemande {
  final ArticleCaisse article; // avec le stock de l'agence source
  final TextEditingController quantite = TextEditingController(text: '1');

  _LigneDemande(this.article);

  double get q =>
      double.tryParse(quantite.text.trim().replaceAll(',', '.')) ?? 0;
}

class TransfertFormPage extends StatefulWidget {
  const TransfertFormPage({super.key});

  @override
  State<TransfertFormPage> createState() => _TransfertFormPageState();
}

class _TransfertFormPageState extends State<TransfertFormPage> {
  final _noteController = TextEditingController();
  final List<_LigneDemande> _lignes = [];
  List<Agence> _agences = [];
  Agence? _source;
  bool _pret = false;
  bool _chargement = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _noteController.dispose();
    for (final l in _lignes) {
      l.quantite.dispose();
    }
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      final agences = await DatabaseService.agencesPourTransfert();
      if (!mounted) return;
      setState(() {
        _agences = agences;
        _pret = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pret = true;
        _erreur = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // Libère les champs après l'image suivante, pour ne pas casser l'écran
  void _libererPlusTard(List<_LigneDemande> lignes) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final l in lignes) {
        l.quantite.dispose();
      }
    });
  }

  void _changerSource(Agence? agence) {
    // Le stock affiché dépend de l'agence : on repart d'une liste vide
    final anciennes = List<_LigneDemande>.of(_lignes);
    setState(() {
      _source = agence;
      _lignes.clear();
      _erreur = null;
    });
    _libererPlusTard(anciennes);
  }

  Future<void> _ajouterArticle() async {
    final source = _source;
    if (source == null) return;

    final article = await showDialog<ArticleCaisse>(
      context: context,
      builder: (_) => ArticleTransfertDialog(
        agenceSourceId: source.id,
        nomSource: source.nom,
      ),
    );
    if (article == null) return;

    for (final l in _lignes) {
      if (l.article.id == article.id) {
        setState(() {
          final q = l.q + 1;
          l.quantite.text = q == q.roundToDouble()
              ? q.toStringAsFixed(0)
              : '$q';
        });
        return;
      }
    }
    setState(() => _lignes.add(_LigneDemande(article)));
  }

  void _retirer(_LigneDemande l) {
    setState(() => _lignes.remove(l));
    _libererPlusTard([l]);
  }

  Future<void> _envoyer() async {
    void echec(String message) => setState(() => _erreur = message);
    setState(() => _erreur = null);

    if (_source == null)
      return echec("Choisissez l'agence à qui vous demandez la marchandise");
    if (_lignes.isEmpty) return echec('Ajoutez au moins un article');
    for (final l in _lignes) {
      if (l.q <= 0)
        return echec('Quantité invalide pour « ${l.article.designation} »');
    }

    setState(() => _chargement = true);
    try {
      final code = await DatabaseService.creerDemandeTransfert(
        agenceSourceId: _source!.id,
        note: _noteController.text,
        lignes: _lignes
            .map(
              (l) =>
                  LigneTransfertSaisie(articleId: l.article.id, quantite: l.q),
            )
            .toList(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Demande envoyée à ${_source!.nom} (N° $code)')),
      );
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
    final agence = Session.agenceCourante;

    if (!Session.peut('transferts.demander')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nouvelle demande')),
        body: const AccesRefuse(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle demande de transfert')),
      body: !_pret
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vers : ${agence?.nom ?? ''} (votre agence)',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<Agence>(
                            initialValue: _source,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Demander à (agence qui enverra)',
                              prefixIcon: Icon(Icons.store),
                              border: OutlineInputBorder(),
                            ),
                            items: _agences
                                .map(
                                  (a) => DropdownMenuItem(
                                    value: a,
                                    child: Text(a.nom),
                                  ),
                                )
                                .toList(),
                            onChanged: _changerSource,
                          ),
                          if (_agences.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text(
                                "Il n'y a pas d'autre agence active.",
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Articles demandés',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: _source == null
                                    ? null
                                    : _ajouterArticle,
                                icon: const Icon(Icons.add),
                                label: const Text('Ajouter un article'),
                              ),
                            ],
                          ),
                          if (_source == null)
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text(
                                "Choisissez d'abord l'agence : le stock affiché est le sien.",
                                style: TextStyle(color: Colors.black54),
                              ),
                            ),
                          const SizedBox(height: 6),
                          for (final l in _lignes)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l.article.designation,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          '${l.article.code} · Stock chez ${_source?.nom ?? ''} : '
                                          '${formaterQuantite(l.article.stock)} ${l.article.unite}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: l.q > l.article.stock
                                                ? Colors.orange.shade800
                                                : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: 110,
                                    child: TextField(
                                      controller: l.quantite,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'[0-9.,]'),
                                        ),
                                      ],
                                      onChanged: (_) => setState(() {}),
                                      decoration: const InputDecoration(
                                        labelText: 'Quantité',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: 'Retirer',
                                    onPressed: () => _retirer(l),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _noteController,
                            maxLength: 200,
                            decoration: const InputDecoration(
                              labelText: 'Note (facultatif)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          if (_erreur != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _erreur!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: FilledButton.icon(
                              onPressed: _chargement ? null : _envoyer,
                              icon: _chargement
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send),
                              label: const Text('Envoyer la demande'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
