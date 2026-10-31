import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/modules/achat.dart';
import 'package:gestionyobs/modules/article.dart';
import 'package:gestionyobs/dialog/article_caisse_dialog.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/modules/mode_paiement.dart';
import 'package:gestionyobs/modules/tiers.dart';
import 'package:gestionyobs/security/utilisateur.dart';
import 'package:gestionyobs/modules/vente.dart';
import 'package:gestionyobs/page/vente_detail_page.dart';

// Une ligne du panier
class _LigneCaisse {
  final ArticleCaisse article;
  final TextEditingController quantite;
  final TextEditingController prix;
  final TextEditingController remise;

  _LigneCaisse(this.article)
    : quantite = TextEditingController(text: '1'),
      prix = TextEditingController(text: article.prixVente.toString()),
      remise = TextEditingController();

  double get q =>
      double.tryParse(quantite.text.trim().replaceAll(',', '.')) ?? 0;
  int get p => int.tryParse(prix.text.trim()) ?? 0;
  int get r => int.tryParse(remise.text.trim()) ?? 0;
  int get brut => (q * p).round();
  int get net => brut - r;

  void liberer() {
    quantite.dispose();
    prix.dispose();
    remise.dispose();
  }
}

// Un paiement en cours de saisie
class _PaiementCaisse {
  ModePaiement? mode;
  final TextEditingController montant = TextEditingController();
  final TextEditingController reference = TextEditingController();

  _PaiementCaisse(this.mode);

  int get m => int.tryParse(montant.text.trim()) ?? 0;

  void liberer() {
    montant.dispose();
    reference.dispose();
  }
}

class VenteFormPage extends StatefulWidget {
  const VenteFormPage({super.key});

  @override
  State<VenteFormPage> createState() => _VenteFormPageState();
}

class _VenteFormPageState extends State<VenteFormPage> {
  final _noteController = TextEditingController();
  final List<_LigneCaisse> _lignes = [];
  final List<_PaiementCaisse> _paiements = [];

  List<Tiers> _clients = [];
  List<ModePaiement> _modes = [];
  int? _clientId;
  SituationClient? _situation;
  bool _pret = false;
  bool _chargement = false;
  String? _erreur;

  bool get _peutRemise => Session.peut('ventes.remise');
  bool get _peutPrix => Session.peut('ventes.modifier_prix');

  int get _brut => _lignes.fold(0, (somme, l) => somme + l.brut);
  int get _remise => _lignes.fold(0, (somme, l) => somme + l.r);
  int get _net => _brut - _remise;
  int get _paye => _paiements.fold(0, (somme, p) => somme + p.m);
  int get _especes => _paiements
      .where((p) => p.mode?.type == 'caisse')
      .fold(0, (somme, p) => somme + p.m);

  // Le client donne plus que le net, en espèces : on lui rend la monnaie
  int get _monnaie =>
      (_paye > _net && _paye - _net <= _especes) ? _paye - _net : 0;
  bool get _depassement => _paye > _net && _paye - _net > _especes;
  int get _reste => _paye >= _net ? 0 : _net - _paye;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _noteController.dispose();
    for (final l in _lignes) {
      l.liberer();
    }
    for (final p in _paiements) {
      p.liberer();
    }
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      final clients = await DatabaseService.clientsPourVente();
      final modes = await DatabaseService.listerModesPaiement();
      if (!mounted) return;
      setState(() {
        _clients = clients;
        _modes = modes;
        _clientId = clients.isEmpty
            ? null
            : clients.first.id; // le client comptant
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
  void _libererPlusTard(void Function() liberer) {
    WidgetsBinding.instance.addPostFrameCallback((_) => liberer());
  }

  Future<void> _changerClient(int? id) async {
    setState(() {
      _clientId = id;
      _situation = null;
    });
    if (id == null) return;

    final client = _clients.firstWhere((c) => c.id == id);
    if (client.systeme) return;

    try {
      final s = await DatabaseService.situationClient(id);
      if (!mounted || _clientId != id) return;
      setState(() => _situation = s);
    } catch (_) {
      // la situation est une aide : on ignore une erreur de lecture
    }
  }

  Future<void> _ajouterArticle() async {
    final article = await showDialog<ArticleCaisse>(
      context: context,
      builder: (_) => const ArticleCaisseDialog(),
    );
    if (article == null) return;

    // Déjà dans le panier : on ajoute 1 à la quantité
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
    setState(() => _lignes.add(_LigneCaisse(article)));
  }

  void _retirerLigne(_LigneCaisse l) {
    setState(() => _lignes.remove(l));
    _libererPlusTard(l.liberer);
  }

  void _ajouterPaiement() {
    setState(
      () =>
          _paiements.add(_PaiementCaisse(_modes.isEmpty ? null : _modes.first)),
    );
  }

  void _retirerPaiement(_PaiementCaisse p) {
    setState(() => _paiements.remove(p));
    _libererPlusTard(p.liberer);
  }

  // Un seul paiement du net, dans ce mode
  void _toutPayer(ModePaiement mode) {
    final anciens = List<_PaiementCaisse>.of(_paiements);
    final nouveau = _PaiementCaisse(mode)..montant.text = _net.toString();
    setState(() {
      _paiements
        ..clear()
        ..add(nouveau);
    });
    _libererPlusTard(() {
      for (final p in anciens) {
        p.liberer();
      }
    });
  }

  // Repart d'une caisse vide pour la vente suivante
  void _reinitialiser() {
    final lignes = List<_LigneCaisse>.of(_lignes);
    final paiements = List<_PaiementCaisse>.of(_paiements);
    setState(() {
      _lignes.clear();
      _paiements.clear();
      _noteController.clear();
      _clientId = _clients.isEmpty ? null : _clients.first.id;
      _situation = null;
      _erreur = null;
      _chargement = false;
    });
    _libererPlusTard(() {
      for (final l in lignes) {
        l.liberer();
      }
      for (final p in paiements) {
        p.liberer();
      }
    });
  }

  Future<void> _valider() async {
    void echec(String message) => setState(() => _erreur = message);
    setState(() => _erreur = null);

    if (_clientId == null) return echec('Choisissez un client');
    if (_lignes.isEmpty) return echec('Ajoutez au moins un article');

    for (final l in _lignes) {
      final nom = l.article.designation;
      if (l.q <= 0) return echec('Quantité invalide pour « $nom »');
      if (l.q > l.article.stock) {
        return echec(
          'Stock insuffisant pour « $nom » '
          '(disponible : ${formaterQuantite(l.article.stock)})',
        );
      }
      if (l.r > l.brut)
        return echec('La remise dépasse le montant de « $nom »');
    }
    if (_net <= 0) return echec('Le net à payer doit être supérieur à zéro');

    for (final p in _paiements) {
      if (p.mode == null || p.m <= 0) {
        return echec('Chaque paiement doit avoir un mode et un montant');
      }
      if (p.mode!.referenceObligatoire && p.reference.text.trim().isEmpty) {
        return echec(
          'Une référence est obligatoire pour « ${p.mode!.libelle} »',
        );
      }
    }
    if (_depassement) {
      return echec('Les paiements dépassent le net à payer');
    }

    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Valider la vente ?'),
        content: Text(
          'Net à payer : ${formaterPrix(_net)}\n'
          'Reçu : ${formaterPrix(_paye)}\n'
          '${_monnaie > 0 ? 'Monnaie à rendre : ${formaterPrix(_monnaie)}\n' : ''}'
          '${_reste > 0 ? 'Reste à payer (crédit client) : ${formaterPrix(_reste)}\n' : ''}'
          '\nLe stock de l\'agence diminuera des quantités vendues. '
          'Une vente enregistrée ne peut plus être modifiée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Revenir'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;

    setState(() => _chargement = true);
    try {
      final vente = await DatabaseService.creerVente(
        clientId: _clientId!,
        note: _noteController.text,
        lignes: _lignes
            .map(
              (l) => LigneVenteSaisie(
                articleId: l.article.id,
                quantite: l.q,
                prixUnitaire: l.p,
                remise: l.r,
              ),
            )
            .toList(),
        paiements: _paiements
            .map(
              (p) => PaiementSaisi(
                modeId: p.mode!.id,
                montant: p.m,
                reference: p.reference.text,
              ),
            )
            .toList(),
      );
      if (!mounted) return;

      final suite = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Vente enregistrée'),
          content: Text(
            'Facture N° ${vente.code}\n'
            'Net à payer : ${formaterPrix(_net)}'
            '${vente.monnaie > 0 ? '\nMonnaie à rendre : ${formaterPrix(vente.monnaie)}' : ''}',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'nouvelle'),
              child: const Text('Nouvelle vente'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'facture'),
              child: const Text('Voir la facture'),
            ),
          ],
        ),
      );
      if (!mounted) return;

      if (suite == 'facture') {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => VenteDetailPage(id: vente.id)),
        );
      }
      if (!mounted) return;
      _reinitialiser();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  InputDecoration _champ(String libelle) => InputDecoration(
    labelText: libelle,
    isDense: true,
    border: const OutlineInputBorder(),
  );

  @override
  Widget build(BuildContext context) {
    if (!Session.peut('ventes.creer')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nouvelle vente')),
        body: const AccesRefuse(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle vente')),
      body: !_pret
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _carteClient(),
                      const SizedBox(height: 12),
                      _cartePanier(),
                      const SizedBox(height: 12),
                      _cartePaiements(),
                      const SizedBox(height: 12),
                      _carteRecapitulatif(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _carteClient() {
    final s = _situation;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _clientId,
              isExpanded: true,
              decoration: _champ('Client'),
              items: _clients
                  .map((c) => DropdownMenuItem(value: c.id, child: Text(c.nom)))
                  .toList(),
              onChanged: _changerClient,
            ),
            if (s != null) ...[
              const SizedBox(height: 8),
              Text(
                s.plafond == 0
                    ? 'Ce client n\'a pas de crédit autorisé (plafond 0).'
                    : 'Plafond : ${formaterPrix(s.plafond)} · '
                          'Déjà dû : ${formaterPrix(s.encours)} · '
                          'Disponible : ${formaterPrix(s.disponible < 0 ? 0 : s.disponible)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: s.disponible <= 0 ? Colors.red : Colors.black87,
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLength: 200,
              decoration: _champ('Note (facultatif)'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartePanier() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Panier',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _ajouterArticle,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter un article'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_lignes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Panier vide. Utilisez « Ajouter un article ».',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            for (final l in _lignes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.article.designation,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${l.article.code} · Stock : '
                            '${formaterQuantite(l.article.stock)} ${l.article.unite}',
                            style: TextStyle(
                              fontSize: 12,
                              color: l.q > l.article.stock
                                  ? Colors.red
                                  : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: l.quantite,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: _champ('Quantité'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Le prix n'est modifiable que par ceux qui en ont le droit
                    SizedBox(
                      width: 110,
                      child: _peutPrix
                          ? TextField(
                              controller: l.prix,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: (_) => setState(() {}),
                              decoration: _champ('Prix unitaire'),
                            )
                          : Text(formaterPrix(l.p), textAlign: TextAlign.right),
                    ),
                    if (_peutRemise) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: l.remise,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) => setState(() {}),
                          decoration: _champ('Remise'),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 100,
                      child: Text(
                        formaterPrix(l.net),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Retirer',
                      onPressed: () => _retirerLigne(l),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cartePaiements() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Paiements',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _modes.isEmpty ? null : _ajouterPaiement,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter un paiement'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in _modes)
                  ActionChip(
                    label: Text('Tout payer : ${m.libelle}'),
                    onPressed: _net > 0 ? () => _toutPayer(m) : null,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_paiements.isEmpty)
              const Text(
                'Aucun paiement : la totalité reste à payer (crédit client).',
                style: TextStyle(color: Colors.black54),
              ),
            for (final p in _paiements)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 200,
                      child: DropdownButtonFormField<ModePaiement>(
                        key: ObjectKey(p),
                        initialValue: p.mode,
                        isExpanded: true,
                        decoration: _champ('Mode'),
                        items: _modes
                            .map(
                              (m) => DropdownMenuItem(
                                value: m,
                                child: Text(m.libelle),
                              ),
                            )
                            .toList(),
                        onChanged: (m) => setState(() => p.mode = m),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 140,
                      child: TextField(
                        controller: p.montant,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: _champ('Montant reçu'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: p.reference,
                        decoration: _champ(
                          p.mode?.referenceObligatoire == true
                              ? 'Référence (obligatoire)'
                              : 'Référence (facultatif)',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Retirer',
                      onPressed: () => _retirerPaiement(p),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _carteRecapitulatif() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total : ${formaterPrix(_brut)}'),
            if (_remise > 0)
              Text(
                'Remise : -${formaterPrix(_remise)}',
                style: TextStyle(color: Colors.orange.shade800),
              ),
            Text(
              'Net à payer : ${formaterPrix(_net)}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text('Reçu : ${formaterPrix(_paye)}'),
            if (_depassement)
              const Text(
                'Les paiements dépassent le net à payer (la monnaie ne se rend qu\'en espèces)',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              )
            else if (_monnaie > 0)
              Text(
                'Monnaie à rendre : ${formaterPrix(_monnaie)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              )
            else if (_reste > 0)
              Text(
                'Reste à payer (crédit client) : ${formaterPrix(_reste)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade800,
                ),
              ),
            if (_erreur != null) ...[
              const SizedBox(height: 8),
              Text(_erreur!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _chargement ? null : _valider,
                icon: _chargement
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.point_of_sale),
                label: const Text(
                  'Valider la vente',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
