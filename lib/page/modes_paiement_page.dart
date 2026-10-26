import 'package:flutter/material.dart';
import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/modules/mode_paiement.dart';
import 'package:gestionyobs/security/utilisateur.dart';

class ModesPaiementPage extends StatefulWidget {
  const ModesPaiementPage({super.key});

  @override
  State<ModesPaiementPage> createState() => _ModesPaiementPageState();
}

class _ModesPaiementPageState extends State<ModesPaiementPage> {
  List<ModePaiement> _modes = [];
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  void _message(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  String _nettoyer(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _charger() async {
    try {
      final modes = await DatabaseService.listerModesPaiement(
        inclureInactifs: true,
      );
      if (!mounted) return;
      setState(() {
        _modes = modes;
        _chargement = false;
        _erreur = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = 'Erreur : $e';
      });
    }
  }

  Future<void> _ajouterOuModifier([ModePaiement? mode]) async {
    final r = await showDialog<Map<String, Object>>(
      context: context,
      builder: (_) => _ModeDialog(mode: mode),
    );
    if (r == null) return;

    try {
      if (mode == null) {
        await DatabaseService.creerModePaiement(
          libelle: r['libelle'] as String,
          type: r['type'] as String,
          referenceObligatoire: r['ref'] as bool,
        );
      } else {
        await DatabaseService.modifierModePaiement(
          id: mode.id,
          libelle: r['libelle'] as String,
          type: r['type'] as String,
          referenceObligatoire: r['ref'] as bool,
          actif: r['actif'] as bool,
        );
      }
      await _charger();
    } catch (e) {
      if (!mounted) return;
      _message(_nettoyer(e));
    }
  }

  Future<void> _deplacer(ModePaiement mode, int sens) async {
    try {
      await DatabaseService.deplacerModePaiement(mode.id, sens);
      await _charger();
    } catch (e) {
      if (!mounted) return;
      _message(_nettoyer(e));
    }
  }

  IconData _icone(String type) => switch (type) {
    'caisse' => Icons.payments,
    'mobile' => Icons.smartphone,
    _ => Icons.account_balance,
  };

  @override
  Widget build(BuildContext context) {
    if (!Session.peut('paiements.gerer')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Modes de paiement')),
        body: const AccesRefuse(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Modes de paiement')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _ajouterOuModifier(),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau mode'),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _erreur != null
          ? Center(
              child: Text(_erreur!, style: const TextStyle(color: Colors.red)),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  children: [
                    const Text(
                      "L'ordre ci-dessous est celui de la caisse. "
                      'Le crédit n\'est pas un mode : c\'est le reste à payer '
                      "d'un achat ou d'une vente.",
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < _modes.length; i++)
                      Card(
                        child: ListTile(
                          leading: Icon(
                            _icone(_modes[i].type),
                            color: Colors.green,
                          ),
                          title: Text(
                            _modes[i].libelle,
                            style: TextStyle(
                              decoration: _modes[i].actif
                                  ? null
                                  : TextDecoration.lineThrough,
                            ),
                          ),
                          subtitle: Text(
                            [
                              typesTresorerie[_modes[i].type] ?? _modes[i].type,
                              if (_modes[i].referenceObligatoire)
                                'Référence obligatoire',
                              if (_modes[i].systeme) 'Mode système',
                              if (!_modes[i].actif) 'Désactivé',
                            ].join(' · '),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_upward),
                                tooltip: 'Monter',
                                onPressed: i == 0
                                    ? null
                                    : () => _deplacer(_modes[i], -1),
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_downward),
                                tooltip: 'Descendre',
                                onPressed: i == _modes.length - 1
                                    ? null
                                    : () => _deplacer(_modes[i], 1),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit),
                                tooltip: 'Modifier',
                                onPressed: () => _ajouterOuModifier(_modes[i]),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Boîte de dialogue : création ou modification d'un mode de paiement.
class _ModeDialog extends StatefulWidget {
  final ModePaiement? mode; // null = nouveau mode

  const _ModeDialog({this.mode});

  @override
  State<_ModeDialog> createState() => _ModeDialogState();
}

class _ModeDialogState extends State<_ModeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _libelleController;
  late String _type;
  late bool _ref;
  late bool _actif;

  bool get _edition => widget.mode != null;
  bool get _systeme => widget.mode?.systeme ?? false;

  @override
  void initState() {
    super.initState();
    final m = widget.mode;
    _libelleController = TextEditingController(text: m?.libelle ?? '');
    _type = m?.type ?? 'mobile';
    _ref = m?.referenceObligatoire ?? true;
    _actif = m?.actif ?? true;
  }

  @override
  void dispose() {
    _libelleController.dispose();
    super.dispose();
  }

  void _valider() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, <String, Object>{
      'libelle': _libelleController.text.trim(),
      'type': _type,
      'ref': _ref,
      'actif': _actif,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_edition ? 'Modifier le mode' : 'Nouveau mode de paiement'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _libelleController,
                autofocus: true,
                maxLength: 30,
                decoration: const InputDecoration(
                  labelText: 'Nom (ex. Carte bancaire)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Veuillez saisir un nom'
                    : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: "Où va l'argent ?",
                  border: OutlineInputBorder(),
                ),
                items: typesTresorerie.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                // Le type du mode système est figé
                onChanged: _systeme
                    ? null
                    : (v) {
                        if (v != null) setState(() => _type = v);
                      },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Référence obligatoire'),
                subtitle: const Text(
                  'Numéro de transaction, de virement ou de chèque',
                ),
                value: _ref,
                onChanged: (v) => setState(() => _ref = v),
              ),
              if (_edition)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mode actif'),
                  subtitle: Text(
                    _systeme
                        ? 'Le mode système ne peut pas être désactivé'
                        : 'Proposé à la caisse',
                  ),
                  value: _actif,
                  onChanged: _systeme
                      ? null
                      : (v) => setState(() => _actif = v),
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
