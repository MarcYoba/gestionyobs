import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/modules/tiers.dart';
import 'package:gestionyobs/security/utilisateur.dart';

class TiersFormPage extends StatefulWidget {
  final String type; // page d'origine : 'client' ou 'fournisseur'
  final Tiers? tiers; // null = création

  const TiersFormPage({super.key, required this.type, this.tiers});

  @override
  State<TiersFormPage> createState() => _TiersFormPageState();
}

class _TiersFormPageState extends State<TiersFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _nomController;
  late final TextEditingController _telephoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _villeController;
  late final TextEditingController _adresseController;
  late final TextEditingController _plafondController;
  late final TextEditingController _notesController;
  late bool _estClient;
  late bool _estFournisseur;
  late bool _actif;

  bool _chargement = false;
  String? _erreur;

  bool get _edition => widget.tiers != null;

  @override
  void initState() {
    super.initState();
    final t = widget.tiers;
    _codeController = TextEditingController(text: t?.code ?? '');
    _nomController = TextEditingController(text: t?.nom ?? '');
    _telephoneController = TextEditingController(text: t?.telephone ?? '');
    _emailController = TextEditingController(text: t?.email ?? '');
    _villeController = TextEditingController(text: t?.ville ?? '');
    _adresseController = TextEditingController(text: t?.adresse ?? '');
    _plafondController = TextEditingController(
      text: (t != null && t.plafondCredit > 0)
          ? t.plafondCredit.toString()
          : '',
    );
    _notesController = TextEditingController(text: t?.notes ?? '');
    _estClient = t?.estClient ?? (widget.type == 'client');
    _estFournisseur = t?.estFournisseur ?? (widget.type == 'fournisseur');
    _actif = t?.actif ?? true;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nomController.dispose();
    _telephoneController.dispose();
    _emailController.dispose();
    _villeController.dispose();
    _adresseController.dispose();
    _plafondController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_estClient && !_estFournisseur) {
      setState(
        () => _erreur = 'Choisissez au moins un type : client ou fournisseur',
      );
      return;
    }

    setState(() {
      _chargement = true;
      _erreur = null;
    });

    try {
      final plafondTexte = _plafondController.text.trim();
      final plafond = plafondTexte.isEmpty ? 0 : int.parse(plafondTexte);

      if (_edition) {
        await DatabaseService.modifierTiers(
          id: widget.tiers!.id,
          nom: _nomController.text.trim(),
          estClient: _estClient,
          estFournisseur: _estFournisseur,
          telephone: _telephoneController.text,
          email: _emailController.text,
          ville: _villeController.text,
          adresse: _adresseController.text,
          plafondCredit: plafond,
          notes: _notesController.text,
          actif: _actif,
        );
      } else {
        final code = await DatabaseService.creerTiers(
          nom: _nomController.text.trim(),
          estClient: _estClient,
          estFournisseur: _estFournisseur,
          telephone: _telephoneController.text,
          email: _emailController.text,
          ville: _villeController.text,
          adresse: _adresseController.text,
          plafondCredit: plafond,
          notes: _notesController.text,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Enregistré - matricule $code')));
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
    if (!Session.peut(droitTiers(widget.type, 'gerer'))) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tiers')),
        body: const AccesRefuse(),
      );
    }

    final titre = widget.type == 'client' ? 'client' : 'fournisseur';

    return Scaffold(
      appBar: AppBar(
        title: Text(_edition ? 'Modifier le $titre' : 'Nouveau $titre'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 540,
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
                      if (_edition) ...[
                        TextFormField(
                          controller: _codeController,
                          enabled: false,
                          decoration: const InputDecoration(
                            labelText: 'Matricule',
                            prefixIcon: Icon(Icons.tag),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      TextFormField(
                        controller: _nomController,
                        decoration: const InputDecoration(
                          labelText: 'Nom ou raison sociale',
                          prefixIcon: Icon(Icons.badge),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Veuillez saisir un nom'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _telephoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Téléphone (facultatif)',
                          prefixIcon: Icon(Icons.phone),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'E-mail (facultatif)',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final texte = (v ?? '').trim();
                          if (texte.isEmpty) return null;
                          return texte.contains('@') && texte.contains('.')
                              ? null
                              : 'Adresse e-mail invalide';
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _villeController,
                        decoration: const InputDecoration(
                          labelText: 'Ville (facultatif)',
                          prefixIcon: Icon(Icons.location_city),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _adresseController,
                        minLines: 2,
                        maxLines: 3,
                        maxLength: 200,
                        decoration: const InputDecoration(
                          labelText: 'Adresse (facultatif)',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Un tiers peut être client, fournisseur, ou les deux.
                      // Chaque case n'est modifiable qu'avec le droit correspondant.
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Est un client'),
                        value: _estClient,
                        onChanged: Session.peut('clients.gerer')
                            ? (v) => setState(() => _estClient = v)
                            : null,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Est un fournisseur'),
                        value: _estFournisseur,
                        onChanged: Session.peut('fournisseurs.gerer')
                            ? (v) => setState(() => _estFournisseur = v)
                            : null,
                      ),

                      if (_estClient) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _plafondController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Plafond de crédit (0 = aucun crédit)',
                            helperText:
                                'Montant maximum que ce client peut devoir',
                            prefixIcon: Icon(Icons.account_balance_wallet),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _notesController,
                        minLines: 2,
                        maxLines: 4,
                        maxLength: 250,
                        decoration: const InputDecoration(
                          labelText: 'Notes (facultatif)',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                      ),

                      if (_edition)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Compte actif'),
                          subtitle: Text(
                            _actif
                                ? 'Utilisable dans les achats et les ventes'
                                : "Désactivé : conservé dans l'historique",
                          ),
                          value: _actif,
                          onChanged: (v) => setState(() => _actif = v),
                        ),

                      if (_erreur != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _erreur!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                      const SizedBox(height: 20),

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
                              : Text(_edition ? 'Enregistrer' : 'Créer'),
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
