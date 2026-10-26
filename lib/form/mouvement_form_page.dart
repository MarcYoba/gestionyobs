import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/modules/article.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/page/mouvements_page.dart';

import 'package:gestionyobs/modules/stock.dart';
import 'package:gestionyobs/security/utilisateur.dart';

class MouvementFormPage extends StatefulWidget {
  final LigneStock ligne;

  const MouvementFormPage({super.key, required this.ligne});

  @override
  State<MouvementFormPage> createState() => _MouvementFormPageState();
}

class _MouvementFormPageState extends State<MouvementFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _quantiteController = TextEditingController();
  final _commentaireController = TextEditingController();
  late String _type;
  late String _motif;
  bool _chargement = false;
  String? _erreur;

  // Les types de mouvement que cet utilisateur a le droit de faire
  List<String> get _typesPermis => [
    if (Session.peut('stock.modifier')) 'entree',
    if (Session.peut('stock.ajuster')) ...['sortie', 'ajustement'],
  ];

  @override
  void initState() {
    super.initState();
    _type = _typesPermis.isEmpty ? 'entree' : _typesPermis.first;
    _motif = motifsMouvement[_type]!.first;
  }

  @override
  void dispose() {
    _quantiteController.dispose();
    _commentaireController.dispose();
    super.dispose();
  }

  String get _libelleQuantite => switch (_type) {
    'entree' => 'Quantité reçue',
    'sortie' => 'Quantité sortie',
    _ => 'Quantité comptée (stock réel)',
  };

  // Le stock qu'on aura après ce mouvement (null si la saisie est invalide)
  double? get _apres {
    final q = double.tryParse(
      _quantiteController.text.trim().replaceAll(',', '.'),
    );
    if (q == null) return null;
    final avant = widget.ligne.quantite;
    final brut = switch (_type) {
      'entree' => avant + q,
      'sortie' => avant - q,
      _ => q,
    };
    return double.parse(brut.toStringAsFixed(3));
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _chargement = true;
      _erreur = null;
    });

    try {
      final q = double.parse(
        _quantiteController.text.trim().replaceAll(',', '.'),
      );

      final code = await DatabaseService.enregistrerMouvement(
        articleId: widget.ligne.articleId,
        type: _type,
        quantite: q,
        motif: _motif,
        commentaire: _commentaireController.text.trim(),
      );

      if (!mounted) return;
      // Le message reste affiché sur la page suivante
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Mouvement enregistré - $code')));
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
    if (_typesPermis.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mouvement de stock')),
        body: const AccesRefuse(),
      );
    }

    final l = widget.ligne;
    final apres = _apres;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mouvement de stock'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historique de cet article',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MouvementsPage(
                  articleId: l.articleId,
                  titre: l.designation,
                ),
              ),
            ),
          ),
        ],
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
                      Text(
                        l.designation,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Matricule ${l.code}'),
                      const SizedBox(height: 4),
                      Text(
                        'Stock actuel : ${formaterQuantite(l.quantite)} ${l.unite}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 20),

                      SegmentedButton<String>(
                        segments: _typesPermis
                            .map(
                              (t) => ButtonSegment(
                                value: t,
                                label: Text(typesMouvement[t]!),
                              ),
                            )
                            .toList(),
                        selected: {_type},
                        onSelectionChanged: (choix) {
                          setState(() {
                            _type = choix.first;
                            _motif = motifsMouvement[_type]!.first;
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        controller: _quantiteController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: _libelleQuantite,
                          suffixText: l.unite,
                          prefixIcon: const Icon(Icons.numbers),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final q = double.tryParse(
                            (v ?? '').trim().replaceAll(',', '.'),
                          );
                          if (q == null) return 'Veuillez saisir une quantité';
                          if (_type == 'ajustement') {
                            return q < 0
                                ? 'La quantité ne peut pas être négative'
                                : null;
                          }
                          if (q <= 0) {
                            return 'La quantité doit être supérieure à zéro';
                          }
                          if (_type == 'sortie' && q > l.quantite) {
                            return 'Stock insuffisant '
                                '(disponible : ${formaterQuantite(l.quantite)})';
                          }
                          return null;
                        },
                      ),

                      if (apres != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Nouveau stock : ${formaterQuantite(apres)} ${l.unite}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: apres < 0
                                ? Colors.red
                                : Colors.green.shade800,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        // Une clé différente par type : la liste se réinitialise
                        key: ValueKey(_type),
                        initialValue: _motif,
                        decoration: const InputDecoration(
                          labelText: 'Motif',
                          prefixIcon: Icon(Icons.help_outline),
                          border: OutlineInputBorder(),
                        ),
                        items: motifsMouvement[_type]!
                            .map(
                              (m) => DropdownMenuItem(value: m, child: Text(m)),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _motif = v);
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _commentaireController,
                        minLines: 2,
                        maxLines: 4,
                        maxLength: 200,
                        decoration: const InputDecoration(
                          labelText: 'Commentaire (facultatif)',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                      ),

                      if (_erreur != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _erreur!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                      const SizedBox(height: 16),

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
                              : const Text('Enregistrer le mouvement'),
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
