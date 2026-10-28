import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/modules/compte_comptable.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/page/import_plan_page.dart';
import 'package:gestionyobs/security/utilisateur.dart';

class PlanComptablePage extends StatefulWidget {
  const PlanComptablePage({super.key});

  @override
  State<PlanComptablePage> createState() => _PlanComptablePageState();
}

class _PlanComptablePageState extends State<PlanComptablePage> {
  final _rechercheController = TextEditingController();
  List<CompteComptable> _comptes = [];
  bool _chargement = true;
  String? _erreur;
  int? _classe; // null = toutes les classes
  bool _inactifs = false;
  bool _imputablesSeulement = false;

  bool get _peutGerer => Session.peut('comptabilite.gerer');
  bool get _autorise => Session.peut('comptabilite.voir') || _peutGerer;

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
      final liste = await DatabaseService.listerComptes();
      if (!mounted) return;
      setState(() {
        _comptes = liste;
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

  // Les comptes qui correspondent à la recherche et aux filtres
  List<CompteComptable> get _visibles {
    final texte = _rechercheController.text.trim().toLowerCase();
    return _comptes.where((c) {
      if (!_inactifs && !c.actif) return false;
      if (_classe != null && c.classe != _classe) return false;
      if (_imputablesSeulement && !c.imputable) return false;
      if (texte.isEmpty) return true;
      return c.numero.startsWith(texte) ||
          c.intitule.toLowerCase().contains(texte);
    }).toList();
  }

  Future<void> _ajouterOuModifier([CompteComptable? compte]) async {
    final r = await showDialog<Map<String, Object>>(
      context: context,
      builder: (_) => _CompteDialog(compte: compte),
    );
    if (r == null) return;

    try {
      if (compte == null) {
        await DatabaseService.creerCompte(
          numero: r['numero'] as String,
          intitule: r['intitule'] as String,
        );
      } else {
        await DatabaseService.modifierCompte(
          id: compte.id,
          intitule: r['intitule'] as String,
          actif: r['actif'] as bool,
        );
      }
      await _charger();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _importer() async {
    final fait = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ImportPlanPage()),
    );
    if (fait == true) _charger();
  }

  @override
  Widget build(BuildContext context) {
    if (!_autorise) {
      return Scaffold(
        appBar: AppBar(title: const Text('Plan comptable')),
        body: const AccesRefuse(),
      );
    }

    final visibles = _visibles;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan comptable'),
        actions: [
          if (_peutGerer)
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: 'Importer un plan comptable (Excel)',
              onPressed: _importer,
            ),
        ],
      ),
      floatingActionButton: _peutGerer
          ? FloatingActionButton.extended(
              onPressed: () => _ajouterOuModifier(),
              icon: const Icon(Icons.add),
              label: const Text('Nouveau compte'),
            )
          : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 950),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _rechercheController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText:
                        'Rechercher (début du numéro ou mot de l\'intitulé)',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: const Text('Toutes les classes'),
                        selected: _classe == null,
                        onSelected: (_) => setState(() => _classe = null),
                      ),
                      for (var n = 1; n <= 9; n++)
                        ChoiceChip(
                          label: Text('$n'),
                          tooltip: nomsClasses[n],
                          selected: _classe == n,
                          onSelected: (_) => setState(() => _classe = n),
                        ),
                      FilterChip(
                        label: const Text('Comptes imputables seulement'),
                        selected: _imputablesSeulement,
                        onSelected: (v) =>
                            setState(() => _imputablesSeulement = v),
                      ),
                      if (_peutGerer)
                        FilterChip(
                          label: const Text('Afficher les désactivés'),
                          selected: _inactifs,
                          onSelected: (v) => setState(() => _inactifs = v),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${visibles.length} compte(s) affiché(s) sur ${_comptes.length}',
                    style: const TextStyle(color: Colors.black54),
                  ),
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
                    : visibles.isEmpty
                    ? Center(
                        child: Text(
                          _comptes.isEmpty
                              ? "Le plan comptable est vide. Utilisez l'icône d'import."
                              : 'Aucun résultat',
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                        itemCount: visibles.length,
                        itemBuilder: (context, index) {
                          final c = visibles[index];
                          return Card(
                            child: ListTile(
                              dense: true,
                              onTap: _peutGerer
                                  ? () => _ajouterOuModifier(c)
                                  : null,
                              leading: CircleAvatar(
                                radius: 14,
                                child: Text(
                                  '${c.classe}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              title: Text(
                                '${c.numero}   ${c.intitule}',
                                style: TextStyle(
                                  decoration: c.actif
                                      ? null
                                      : TextDecoration.lineThrough,
                                ),
                              ),
                              subtitle: Text(
                                [
                                  nomsClasses[c.classe] ?? 'Classe ${c.classe}',
                                  if (!c.imputable) 'Compte de regroupement',
                                  if (!c.actif) 'Désactivé',
                                ].join(' · '),
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

/// Boîte de dialogue : création ou modification d'un compte.
class _CompteDialog extends StatefulWidget {
  final CompteComptable? compte; // null = nouveau compte

  const _CompteDialog({this.compte});

  @override
  State<_CompteDialog> createState() => _CompteDialogState();
}

class _CompteDialogState extends State<_CompteDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _numeroController;
  late final TextEditingController _intituleController;
  late bool _actif;

  bool get _edition => widget.compte != null;

  @override
  void initState() {
    super.initState();
    _numeroController = TextEditingController(
      text: widget.compte?.numero ?? '',
    );
    _intituleController = TextEditingController(
      text: widget.compte?.intitule ?? '',
    );
    _actif = widget.compte?.actif ?? true;
  }

  @override
  void dispose() {
    _numeroController.dispose();
    _intituleController.dispose();
    super.dispose();
  }

  void _valider() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, <String, Object>{
      'numero': _numeroController.text.trim(),
      'intitule': _intituleController.text.trim(),
      'actif': _actif,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_edition ? 'Modifier le compte' : 'Nouveau compte'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _numeroController,
                enabled: !_edition, // le numéro ne change jamais
                autofocus: !_edition,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 10,
                decoration: InputDecoration(
                  labelText: _edition
                      ? 'Numéro (non modifiable)'
                      : 'Numéro du compte',
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    RegExp(r'^[1-9]\d{1,9}$').hasMatch((v ?? '').trim())
                    ? null
                    : 'De 2 à 10 chiffres, sans zéro au début',
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _intituleController,
                autofocus: _edition,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Intitulé',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Veuillez saisir un intitulé'
                    : null,
              ),
              if (_edition)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Compte actif'),
                  subtitle: const Text(
                    'Désactivé : conservé, mais non proposé',
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
