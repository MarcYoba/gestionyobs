import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/modules/compte_comptable.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/import/import_plan.dart';
import 'package:gestionyobs/security/utilisateur.dart';
import 'package:gestionyobs/files/xlsx_reader.dart';

class ImportPlanPage extends StatefulWidget {
  const ImportPlanPage({super.key});

  @override
  State<ImportPlanPage> createState() => _ImportPlanPageState();
}

class _ImportPlanPageState extends State<ImportPlanPage> {
  AnalysePlan? _analyse;
  String? _nomFichier;
  bool _lecture = false;
  bool _import = false;
  bool _verifie = false; // « j'ai vérifié les lignes à vérifier »
  String? _erreur;
  String _filtre = 'toutes';

  Future<void> _choisirFichier() async {
    final fichiers = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (fichiers == null || fichiers.isEmpty) return;

    final fichier = fichiers.first;
    final chemin = fichier.path;

    if (chemin == null) {
      setState(() => _erreur = 'Impossible de lire ce fichier');
      return;
    }

    setState(() {
      _lecture = true;
      _erreur = null;
      _analyse = null;
      _verifie = false;
      _filtre = 'toutes';
    });

    try {
      final lignes = await lireXlsx(chemin);
      final existants = await DatabaseService.comptesExistants();
      final analyse = analyserPlan(lignes, existants);
      if (!mounted) return;
      setState(() {
        _analyse = analyse;
        _nomFichier = fichier.name;
        _lecture = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lecture = false;
        _erreur = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _modifierLigne(LigneImport l) async {
    final r = await showDialog<Map<String, Object>>(
      context: context,
      builder: (_) => _LigneDialog(ligne: l),
    );
    if (r == null) return;

    setState(() {
      l.numero = r['numero'] as String;
      l.intitule = r['intitule'] as String;
      l.ignorer = r['ignorer'] as bool;
      l.aVerifier = false; // la personne a regardé cette ligne
      _analyse!.valider();
    });
  }

  Future<void> _importer() async {
    final analyse = _analyse!;
    setState(() {
      _import = true;
      _erreur = null;
    });

    try {
      final bilan = await DatabaseService.importerComptes(
        analyse.lignes
            .where((l) => !l.ignorer)
            .map((l) => CompteAImporter(l.numero, l.intitule))
            .toList(),
      );
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Import terminé'),
          content: Text(
            '${bilan.ajoutes} compte(s) ajouté(s)\n'
            '${bilan.misAJour} intitulé(s) mis à jour\n'
            '${bilan.inchanges} inchangé(s)',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _import = false;
        _erreur = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<LigneImport> _visibles(AnalysePlan a) {
    return a.lignes.where((l) {
      switch (_filtre) {
        case 'verifier':
          return !l.ignorer && l.aVerifier;
        case 'corrigees':
          return l.numeroCorrige;
        case 'nouveaux':
          return !l.ignorer && l.etat == 'nouveau';
        case 'modifies':
          return !l.ignorer && l.etat == 'modifie';
        case 'problemes':
          return !l.ignorer && l.problemes.isNotEmpty;
        case 'ignorees':
          return l.ignorer;
        default:
          return true;
      }
    }).toList();
  }

  Widget _puce(String code, String libelle, int nombre) {
    return ChoiceChip(
      label: Text('$libelle ($nombre)'),
      selected: _filtre == code,
      onSelected: (_) => setState(() => _filtre = code),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!Session.peut('comptabilite.gerer')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Importer un plan comptable')),
        body: const AccesRefuse(),
      );
    }

    final analyse = _analyse;

    return Scaffold(
      appBar: AppBar(title: const Text('Importer un plan comptable')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    FilledButton.icon(
                      onPressed: (_lecture || _import) ? null : _choisirFichier,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Choisir un fichier Excel (.xlsx)'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _nomFichier ??
                            'Colonnes attendues : Compte et Intitulé '
                                '(la colonne classe est ignorée)',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
              if (_erreur != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    _erreur!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (_lecture)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (analyse == null)
                const Expanded(child: SizedBox.shrink())
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${analyse.lignes.length} lignes lues · '
                      '${analyse.nbAImporter} à importer · '
                      '${analyse.nbIgnorees} ignorée(s) · '
                      '${analyse.nbAVerifier} à vérifier · '
                      '${analyse.nbProblemes} problème(s)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _puce('toutes', 'Toutes', analyse.lignes.length),
                        _puce('verifier', 'À vérifier', analyse.nbAVerifier),
                        _puce('problemes', 'Problèmes', analyse.nbProblemes),
                        _puce(
                          'corrigees',
                          'Numéros corrigés',
                          analyse.nbCorrigees,
                        ),
                        _puce('nouveaux', 'Nouveaux', analyse.nbNouveaux),
                        _puce(
                          'modifies',
                          'Intitulés modifiés',
                          analyse.nbModifies,
                        ),
                        _puce('ignorees', 'Ignorées', analyse.nbIgnorees),
                      ],
                    ),
                  ),
                ),
                Expanded(child: _liste(analyse)),
                _barreImport(analyse),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _liste(AnalysePlan analyse) {
    final visibles = _visibles(analyse);
    if (visibles.isEmpty) {
      return const Center(child: Text('Aucune ligne dans ce filtre'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: visibles.length,
      itemBuilder: (context, index) {
        final l = visibles[index];

        final IconData icone;
        final Color couleur;
        if (l.ignorer) {
          icone = Icons.block;
          couleur = Colors.grey;
        } else if (l.problemes.isNotEmpty) {
          icone = Icons.error;
          couleur = Colors.red;
        } else if (l.aVerifier) {
          icone = Icons.warning_amber;
          couleur = Colors.orange;
        } else {
          icone = Icons.check_circle;
          couleur = Colors.green;
        }

        final etat = switch (l.etat) {
          'nouveau' => 'Nouveau',
          'modifie' => 'Modifié',
          _ => 'Identique',
        };

        return Card(
          child: ListTile(
            dense: true,
            onTap: () => _modifierLigne(l),
            leading: Icon(icone, color: couleur),
            title: Text(
              '${l.numero}   ${l.intitule}',
              style: TextStyle(
                decoration: l.ignorer ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Text(
              [
                'Ligne ${l.ligne}',
                if (l.numeroCorrige) 'Numéro d\'origine : ${l.numeroBrut}',
                ...l.remarques,
                if (!l.ignorer && l.etat == 'modifie')
                  'Intitulé actuel : ${l.intituleActuel}',
                ...l.problemes.map((p) => 'PROBLÈME : $p'),
              ].join('\n'),
              style: TextStyle(
                color: l.problemes.isNotEmpty && !l.ignorer ? Colors.red : null,
              ),
            ),
            isThreeLine: l.remarques.isNotEmpty || l.problemes.isNotEmpty,
            trailing: Chip(
              label: Text(l.ignorer ? 'Ignorée' : etat),
              visualDensity: VisualDensity.compact,
            ),
          ),
        );
      },
    );
  }

  Widget _barreImport(AnalysePlan analyse) {
    final verificationRequise = analyse.nbAVerifier > 0 && !_verifie;
    final peut = analyse.peutImporter && !verificationRequise && !_import;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          if (analyse.nbAVerifier > 0)
            Expanded(
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _verifie,
                onChanged: (v) => setState(() => _verifie = v ?? false),
                title: Text(
                  "J'ai vérifié les ${analyse.nbAVerifier} ligne(s) « À vérifier »",
                ),
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: peut ? _importer : null,
            icon: _import
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_done),
            label: Text('Importer ${analyse.nbAImporter} compte(s)'),
          ),
        ],
      ),
    );
  }
}

/// Boîte de dialogue : corriger ou ignorer une ligne du fichier.
class _LigneDialog extends StatefulWidget {
  final LigneImport ligne;

  const _LigneDialog({required this.ligne});

  @override
  State<_LigneDialog> createState() => _LigneDialogState();
}

class _LigneDialogState extends State<_LigneDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _numeroController;
  late final TextEditingController _intituleController;
  late bool _ignorer;

  @override
  void initState() {
    super.initState();
    _numeroController = TextEditingController(text: widget.ligne.numero);
    _intituleController = TextEditingController(text: widget.ligne.intitule);
    _ignorer = widget.ligne.ignorer;
  }

  @override
  void dispose() {
    _numeroController.dispose();
    _intituleController.dispose();
    super.dispose();
  }

  void _valider() {
    // Une ligne ignorée n'a pas besoin d'être valide
    if (!_ignorer && !_formKey.currentState!.validate()) return;
    Navigator.pop(context, <String, Object>{
      'numero': _numeroController.text.trim(),
      'intitule': _intituleController.text
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim(),
      'ignorer': _ignorer,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Ligne ${widget.ligne.ligne} du fichier'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _numeroController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 10,
                decoration: const InputDecoration(
                  labelText: 'Numéro du compte',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    RegExp(r'^[1-9]\d{1,9}$').hasMatch((v ?? '').trim())
                    ? null
                    : 'De 2 à 10 chiffres, sans zéro au début',
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _intituleController,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Intitulé',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Veuillez saisir un intitulé'
                    : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ignorer cette ligne'),
                subtitle: const Text("Elle ne sera pas importée"),
                value: _ignorer,
                onChanged: (v) => setState(() => _ignorer = v),
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
        FilledButton(onPressed: _valider, child: const Text('Appliquer')),
      ],
    );
  }
}
