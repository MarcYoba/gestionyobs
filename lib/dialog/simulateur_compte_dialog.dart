import 'package:flutter/material.dart';

import 'package:gestionyobs/association/association.dart';
import 'package:gestionyobs/modules/classe_article.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/modules/postes_comptables.dart';
import 'package:gestionyobs/security/utilisateur.dart';

class SimulateurCompteDialog extends StatefulWidget {
  const SimulateurCompteDialog({super.key});

  @override
  State<SimulateurCompteDialog> createState() => _SimulateurCompteDialogState();
}

class _SimulateurCompteDialogState extends State<SimulateurCompteDialog> {
  List<PosteComptable> _postes = [];
  List<Agence> _agences = [];
  List<ClasseArticle> _classes = [];
  bool _charge = false;

  String? _posteCode;
  int? _agenceId;
  int? _classeId;

  ComptePourPoste? _resultat;
  bool _calcule = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final postes = await DatabaseService.listerPostes();
      final agences = await DatabaseService.listerToutesLesAgences();
      final classes = await DatabaseService.listerClasses();
      if (!mounted) return;
      setState(() {
        _postes = postes;
        _agences = agences;
        _classes = classes;
        _posteCode = postes.isEmpty ? null : postes.first.code;
        _charge = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _charge = true;
        _erreur = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  PosteComptable? get _poste {
    for (final p in _postes) {
      if (p.code == _posteCode) return p;
    }
    return null;
  }

  Future<void> _calculer() async {
    final poste = _poste;
    if (poste == null) return;
    try {
      final r = await DatabaseService.resoudreCompte(
        poste: poste.code,
        agenceId: poste.parAgence ? _agenceId : null,
        classeId: poste.parClasse ? _classeId : null,
      );
      if (!mounted) return;
      setState(() {
        _resultat = r;
        _calcule = true;
        _erreur = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _erreur = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  String _origine(ComptePourPoste r) {
    switch (r.origine) {
      case 'classe':
        final nom = _classes.where((c) => c.id == _classeId).map((c) => c.nom);
        return "compte de la classe d'articles ${nom.isEmpty ? '' : nom.first}";
      case 'agence':
        final nom = _agences.where((a) => a.id == _agenceId).map((a) => a.nom);
        return "compte de l'agence ${nom.isEmpty ? '' : nom.first}";
      default:
        return 'compte par défaut du poste';
    }
  }

  @override
  Widget build(BuildContext context) {
    final poste = _poste;

    return AlertDialog(
      title: const Text('Quel compte serait utilisé ?'),
      content: SizedBox(
        width: 500,
        child: !_charge
            ? const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _posteCode,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Poste comptable',
                      border: OutlineInputBorder(),
                    ),
                    items: _postes
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.code,
                            child: Text('${p.groupe} : ${p.libelle}'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      _posteCode = v;
                      _calcule = false;
                    }),
                  ),
                  if (poste != null && poste.parAgence) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int?>(
                      key: ValueKey('agence-${poste.code}'),
                      initialValue: _agenceId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Agence',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Aucune précision'),
                        ),
                        for (final a in _agences)
                          DropdownMenuItem<int?>(
                            value: a.id,
                            child: Text(a.nom),
                          ),
                      ],
                      onChanged: (v) => setState(() {
                        _agenceId = v;
                        _calcule = false;
                      }),
                    ),
                  ],
                  if (poste != null && poste.parClasse) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int?>(
                      key: ValueKey('classe-${poste.code}'),
                      initialValue: _classeId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: "Classe de l'article",
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Aucune classe'),
                        ),
                        for (final c in _classes)
                          DropdownMenuItem<int?>(
                            value: c.id,
                            child: Text(c.nom),
                          ),
                      ],
                      onChanged: (v) => setState(() {
                        _classeId = v;
                        _calcule = false;
                      }),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _calculer,
                    icon: const Icon(Icons.rule),
                    label: const Text('Voir le compte retenu'),
                  ),
                  const SizedBox(height: 12),
                  if (_erreur != null)
                    Text(_erreur!, style: const TextStyle(color: Colors.red))
                  else if (_calcule && _resultat == null)
                    Text(
                      'Aucun compte associé à ce poste.',
                      style: TextStyle(color: Colors.orange.shade800),
                    )
                  else if (_calcule && _resultat != null) ...[
                    Text(
                      '${_resultat!.numero}  ${_resultat!.intitule}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('Origine : ${_origine(_resultat!)}'),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}
