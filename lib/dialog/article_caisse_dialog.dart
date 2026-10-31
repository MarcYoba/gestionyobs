import 'package:flutter/material.dart';
import 'package:gestionyobs/modules/article.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/modules/vente.dart';

/// Boîte de dialogue : choisir un article à vendre, avec son stock.
class ArticleCaisseDialog extends StatefulWidget {
  const ArticleCaisseDialog({super.key});

  @override
  State<ArticleCaisseDialog> createState() => _ArticleCaisseDialogState();
}

class _ArticleCaisseDialogState extends State<ArticleCaisseDialog> {
  final _controller = TextEditingController();
  List<ArticleCaisse> _resultats = [];
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _chercher();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _chercher() async {
    try {
      final liste = await DatabaseService.rechercherArticlesCaisse(
        _controller.text,
      );
      if (!mounted) return;
      setState(() {
        _resultats = liste;
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter un article'),
      content: SizedBox(
        width: 580,
        height: 460,
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: (_) => _chercher(),
              decoration: const InputDecoration(
                labelText: 'Rechercher (matricule, nom, classe)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
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
                  : _resultats.isEmpty
                  ? const Center(child: Text('Aucun article trouvé'))
                  : ListView.builder(
                      itemCount: _resultats.length,
                      itemBuilder: (context, index) {
                        final a = _resultats[index];
                        final epuise = a.stock <= 0;
                        return ListTile(
                          dense: true,
                          enabled: !epuise,
                          title: Text(a.designation),
                          subtitle: Text(
                            [
                              a.code,
                              if (a.categorie != null) a.categorie!,
                              epuise
                                  ? 'Rupture de stock'
                                  : 'Stock : ${formaterQuantite(a.stock)} ${a.unite}',
                            ].join(' · '),
                          ),
                          trailing: Text(
                            formaterPrix(a.prixVente),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          onTap: epuise
                              ? null
                              : () => Navigator.pop(context, a),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
      ],
    );
  }
}
