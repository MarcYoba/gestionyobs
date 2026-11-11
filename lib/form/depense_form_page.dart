import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/modules/achat.dart';
import 'package:gestionyobs/modules/article.dart';
import 'package:gestionyobs/modules/compte_comptable.dart';
import 'package:gestionyobs/dialog/compte_selecteur_dialog.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/modules/depense.dart';
import 'package:gestionyobs/modules/mode_paiement.dart';
import 'package:gestionyobs/security/utilisateur.dart';

class DepenseFormPage extends StatefulWidget {
  const DepenseFormPage({super.key});

  @override
  State<DepenseFormPage> createState() => _DepenseFormPageState();
}

class _DepenseFormPageState extends State<DepenseFormPage> {
  final _libelleController = TextEditingController();
  final _beneficiaireController = TextEditingController();
  final _montantController = TextEditingController();
  final _referenceController = TextEditingController();
  final _pieceController = TextEditingController();
  final _noteController = TextEditingController();

  String _type = 'charge';
  DateTime _date = DateTime.now();

  CompteComptable? _compte; // le compte choisi
  CompteComptable? _defaut; // le compte par défaut de ce type
  List<CompteComptable> _recents = [];
  List<CompteComptable> _comptes = [];
  List<ModePaiement> _modes = [];
  ModePaiement? _mode;

  bool _pret = false;
  bool _chargement = false;
  String? _erreur;
  String? _message;

  // Le type Salaire n'est proposé qu'à ceux qui y ont droit
  List<String> get _types => [
    if (Session.peut('depenses.salaires')) 'salaire',
    'charge',
    'autre',
  ];

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _libelleController.dispose();
    _beneficiaireController.dispose();
    _montantController.dispose();
    _referenceController.dispose();
    _pieceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _nettoyer(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _charger() async {
    try {
      final comptes = await DatabaseService.comptesPourDepense();
      final modes = await DatabaseService.listerModesPaiement();
      if (!mounted) return;
      setState(() {
        _comptes = comptes;
        _modes = modes;
        _mode = modes.isEmpty ? null : modes.first;
        _pret = true;
      });
      await _chargerSuggestions();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pret = true;
        _erreur = _nettoyer(e);
      });
    }
  }

  // Le compte par défaut du type, et les comptes récents
  Future<void> _chargerSuggestions() async {
    try {
      final defaut = await DatabaseService.compteParDefautDepense(_type);
      final recents = await DatabaseService.comptesRecentsDepense(_type);
      if (!mounted) return;
      setState(() {
        _defaut = defaut;
        _recents = recents;
        // On propose d'office le compte par défaut, sinon le plus récent
        _compte ??= defaut ?? (recents.isEmpty ? null : recents.first);
      });
    } catch (_) {
      // les suggestions sont une aide : on ignore une erreur de lecture
    }
  }

  void _changerType(String type) {
    setState(() {
      _type = type;
      _compte = null;
      _defaut = null;
      _recents = [];
      _erreur = null;
    });
    _chargerSuggestions();
  }

  Future<void> _choisirCompte() async {
    final propositions = <String>[
      if (_defaut != null) _defaut!.numero,
      ..._recents.map((c) => c.numero),
    ];

    final choix = await showDialog<CompteComptable>(
      context: context,
      builder: (_) => CompteSelecteurDialog(
        titre: typesDepense[_type] ?? 'Dépense',
        comptes: _comptes,
        propositions: propositions,
        classes: const {6}, // les comptes de charges d'abord
      ),
    );
    if (choix != null) setState(() => _compte = choix);
  }

  Future<void> _choisirDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _date = d);
  }

  int get _montant => int.tryParse(_montantController.text.trim()) ?? 0;

  Future<void> _enregistrer() async {
    void echec(String message) => setState(() {
      _erreur = message;
      _message = null;
    });
    setState(() => _erreur = null);

    if (_compte == null) return echec('Choisissez le compte comptable');
    if (_libelleController.text.trim().isEmpty) {
      return echec('Saisissez le libellé de la dépense');
    }
    if (_type == 'salaire' && _beneficiaireController.text.trim().isEmpty) {
      return echec("Indiquez l'employé concerné par ce salaire");
    }
    if (_montant <= 0) return echec('Saisissez un montant supérieur à zéro');
    if (_mode == null) return echec('Choisissez un mode de paiement');
    if (_mode!.referenceObligatoire &&
        _referenceController.text.trim().isEmpty) {
      return echec('Une référence est obligatoire pour « ${_mode!.libelle} »');
    }

    setState(() => _chargement = true);
    try {
      final code = await DatabaseService.creerDepense(
        type: _type,
        date: _date,
        libelle: _libelleController.text,
        beneficiaire: _beneficiaireController.text,
        compteId: _compte!.id,
        montant: _montant,
        modeId: _mode!.id,
        reference: _referenceController.text,
        piece: _pieceController.text,
        note: _noteController.text,
      );

      if (!mounted) return;
      // On garde le type, le compte, la date et le mode pour enchaîner
      // plusieurs dépenses (par exemple les salaires du mois)
      final enregistre =
          '${_libelleController.text.trim()} : ${formaterPrix(_montant)}';
      setState(() {
        _libelleController.clear();
        _beneficiaireController.clear();
        _montantController.clear();
        _referenceController.clear();
        _pieceController.clear();
        _noteController.clear();
        _chargement = false;
        _message = 'Dépense enregistrée (matricule $code) : $enregistre';
      });
      _chargerSuggestions();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = _nettoyer(e);
      });
    }
  }

  InputDecoration _champ(String libelle, {IconData? icone, String? aide}) =>
      InputDecoration(
        labelText: libelle,
        helperText: aide,
        prefixIcon: icone == null ? null : Icon(icone),
        border: const OutlineInputBorder(),
      );

  @override
  Widget build(BuildContext context) {
    if (!Session.peut('depenses.creer')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nouvelle dépense')),
        body: const AccesRefuse(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle dépense')),
      body: !_pret
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Type de dépense',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          SegmentedButton<String>(
                            segments: [
                              for (final t in _types)
                                ButtonSegment(
                                  value: t,
                                  label: Text(typesDepense[t]!),
                                ),
                            ],
                            selected: {_type},
                            onSelectionChanged: (s) => _changerType(s.first),
                          ),
                          const SizedBox(height: 20),
                          _blocCompte(),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _libelleController,
                            maxLength: 100,
                            decoration: _champ(
                              'Libellé de la dépense',
                              icone: Icons.notes,
                              aide: _type == 'salaire'
                                  ? 'Par exemple : Salaire d\'octobre 2026'
                                  : 'Par exemple : Facture d\'électricité d\'octobre',
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _beneficiaireController,
                            maxLength: 60,
                            decoration: _champ(
                              _type == 'salaire'
                                  ? 'Employé (obligatoire)'
                                  : 'Bénéficiaire (facultatif)',
                              icone: Icons.person,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _montantController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  onChanged: (_) => setState(() {}),
                                  decoration: _champ(
                                    'Montant',
                                    icone: Icons.payments,
                                    aide: _montant > 0
                                        ? formaterPrix(_montant)
                                        : null,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: _choisirDate,
                                icon: const Icon(Icons.event),
                                label: Text(formaterDate(_date)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<ModePaiement>(
                                  initialValue: _mode,
                                  isExpanded: true,
                                  decoration: _champ(
                                    'Payé par',
                                    icone: Icons.account_balance_wallet,
                                  ),
                                  items: _modes
                                      .map(
                                        (m) => DropdownMenuItem(
                                          value: m,
                                          child: Text(m.libelle),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (m) => setState(() => _mode = m),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _referenceController,
                                  decoration: _champ(
                                    _mode?.referenceObligatoire == true
                                        ? 'Référence (obligatoire)'
                                        : 'Référence (facultatif)',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _pieceController,
                            maxLength: 40,
                            decoration: _champ(
                              'N° de pièce justificative (facultatif)',
                              icone: Icons.attach_file,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _noteController,
                            maxLength: 200,
                            decoration: _champ('Note (facultatif)'),
                          ),
                          if (_erreur != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _erreur!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          if (_message != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _message!,
                                style: TextStyle(
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: FilledButton.icon(
                              onPressed: _chargement ? null : _enregistrer,
                              icon: _chargement
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.check),
                              label: const Text('Enregistrer la dépense'),
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

  // Le compte comptable : numéro et libellé bien visibles, avec des suggestions
  Widget _blocCompte() {
    final c = _compte;

    // Le compte par défaut d'abord, puis les récents, sans doublon
    final suggestions = <CompteComptable>[
      if (_defaut != null) _defaut!,
      ..._recents.where((r) => r.id != _defaut?.id),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Compte comptable',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Card(
          margin: EdgeInsets.zero,
          color: c == null ? Colors.orange.shade50 : Colors.green.shade50,
          child: ListTile(
            leading: Icon(
              Icons.account_balance,
              color: c == null ? Colors.orange.shade800 : Colors.green.shade800,
            ),
            title: Text(
              c == null ? 'Aucun compte choisi' : '${c.numero}  ${c.intitule}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              c == null
                  ? 'Choisissez le compte comptable de cette dépense (obligatoire)'
                  : 'Classe ${c.classe} : ${nomsClasses[c.classe] ?? ''}',
            ),
            trailing: FilledButton.tonal(
              onPressed: _choisirCompte,
              child: Text(c == null ? 'Choisir' : 'Changer'),
            ),
          ),
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in suggestions)
                ActionChip(
                  avatar: s.id == _defaut?.id
                      ? const Icon(Icons.star, size: 16)
                      : null,
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: Text(
                      '${s.numero}  ${s.intitule}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  onPressed: () => setState(() => _compte = s),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              _defaut != null
                  ? "L'étoile marque le compte par défaut de ce type ; les autres sont vos comptes récents."
                  : 'Vos comptes récents pour ce type de dépense.',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ],
      ],
    );
  }
}
