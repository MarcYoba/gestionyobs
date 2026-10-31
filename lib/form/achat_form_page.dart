import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/modules/achat.dart';
import 'package:gestionyobs/modules/article.dart';
import 'package:gestionyobs/dialog/article_selecteur_dialog.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/modules/mode_paiement.dart';
import 'package:gestionyobs/modules/tiers.dart';
import 'package:gestionyobs/security/utilisateur.dart';

// Une ligne en cours de saisie
class _LigneSaisie {
  final Article article;
  final TextEditingController quantite;
  final TextEditingController prix;

  _LigneSaisie(this.article)
    : quantite = TextEditingController(text: '1'),
      prix = TextEditingController(text: article.prixAchat?.toString() ?? '');

  double get q =>
      double.tryParse(quantite.text.trim().replaceAll(',', '.')) ?? 0;
  int get p => int.tryParse(prix.text.trim()) ?? 0;
  int get total => (q * p).round();

  void liberer() {
    quantite.dispose();
    prix.dispose();
  }
}

// Un paiement en cours de saisie
class _PaiementSaisie {
  ModePaiement? mode;
  final TextEditingController montant = TextEditingController();
  final TextEditingController reference = TextEditingController();

  _PaiementSaisie(this.mode);

  int get m => int.tryParse(montant.text.trim()) ?? 0;

  void liberer() {
    montant.dispose();
    reference.dispose();
  }
}

class AchatFormPage extends StatefulWidget {
  const AchatFormPage({super.key});

  @override
  State<AchatFormPage> createState() => _AchatFormPageState();
}

class _AchatFormPageState extends State<AchatFormPage> {
  final _referenceController = TextEditingController();
  final _noteController = TextEditingController();
  final List<_LigneSaisie> _lignes = [];
  final List<_PaiementSaisie> _paiements = [];

  List<Tiers> _fournisseurs = [];
  List<ModePaiement> _modes = [];
  int? _fournisseurId;
  DateTime _date = DateTime.now();
  bool _majPrix = false;
  bool _pret = false;
  bool _chargement = false;
  String? _erreur;

  int get _total => _lignes.fold(0, (somme, l) => somme + l.total);
  int get _paye => _paiements.fold(0, (somme, p) => somme + p.m);
  int get _reste => _total - _paye;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _referenceController.dispose();
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
      final fournisseurs = await DatabaseService.fournisseursPourAchat();
      final modes = await DatabaseService.listerModesPaiement();
      if (!mounted) return;
      setState(() {
        _fournisseurs = fournisseurs;
        _modes = modes;
        // Le fournisseur occasionnel est en tête de liste
        _fournisseurId = fournisseurs.isEmpty ? null : fournisseurs.first.id;
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

  Future<void> _choisirDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _ajouterArticle() async {
    final article = await showDialog<Article>(
      context: context,
      builder: (_) => const ArticleSelecteurDialog(),
    );
    if (article == null) return;

    // Déjà dans l'achat : on ajoute 1 à la quantité
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
    setState(() => _lignes.add(_LigneSaisie(article)));
  }

  void _retirerLigne(_LigneSaisie l) {
    setState(() => _lignes.remove(l));
    _libererPlusTard(l.liberer);
  }

  void _ajouterPaiement() {
    setState(
      () =>
          _paiements.add(_PaiementSaisie(_modes.isEmpty ? null : _modes.first)),
    );
  }

  void _retirerPaiement(_PaiementSaisie p) {
    setState(() => _paiements.remove(p));
    _libererPlusTard(p.liberer);
  }

  // Un seul paiement du total, dans ce mode
  void _toutPayer(ModePaiement mode) {
    final anciens = List<_PaiementSaisie>.of(_paiements);
    final nouveau = _PaiementSaisie(mode)..montant.text = _total.toString();
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

  Future<void> _valider() async {
    void echec(String message) => setState(() => _erreur = message);
    setState(() => _erreur = null);

    if (_fournisseurId == null) return echec('Choisissez un fournisseur');
    if (_lignes.isEmpty) return echec('Ajoutez au moins un article');

    for (final l in _lignes) {
      if (l.q <= 0) {
        return echec('Quantité invalide pour « ${l.article.designation} »');
      }
    }
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
    if (_paye > _total) {
      return echec(
        'Les paiements (${formaterPrix(_paye)}) dépassent '
        'le total (${formaterPrix(_total)})',
      );
    }

    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Valider l'achat ?"),
        content: Text(
          'Total : ${formaterPrix(_total)}\n'
          'Payé : ${formaterPrix(_paye)}\n'
          'Reste à payer (dette fournisseur) : ${formaterPrix(_reste)}\n\n'
          "Le stock de l'agence augmentera des quantités reçues. "
          'Un achat enregistré ne peut plus être modifié.',
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
      final code = await DatabaseService.creerAchat(
        fournisseurId: _fournisseurId!,
        date: _date,
        referenceFournisseur: _referenceController.text,
        note: _noteController.text,
        majPrixCatalogue: _majPrix,
        lignes: _lignes
            .map(
              (l) => LigneAchatSaisie(
                articleId: l.article.id,
                quantite: l.q,
                prixUnitaire: l.p,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Achat enregistré - matricule $code')),
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

  InputDecoration _champ(String libelle) => InputDecoration(
    labelText: libelle,
    isDense: true,
    border: const OutlineInputBorder(),
  );

  @override
  Widget build(BuildContext context) {
    if (!Session.peut('achats.creer')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nouvel achat')),
        body: const AccesRefuse(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvel achat')),
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
                      _carteInfos(),
                      const SizedBox(height: 12),
                      _carteLignes(),
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

  Widget _carteInfos() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _fournisseurId,
                    isExpanded: true,
                    decoration: _champ('Fournisseur'),
                    items: _fournisseurs
                        .map(
                          (f) =>
                              DropdownMenuItem(value: f.id, child: Text(f.nom)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _fournisseurId = v),
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
            TextField(
              controller: _referenceController,
              decoration: _champ('N° de facture du fournisseur (facultatif)'),
            ),
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

  Widget _carteLignes() {
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
                    'Articles reçus',
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
                  'Aucun article. Utilisez « Ajouter un article ».',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            for (final l in _lignes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
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
                            '${l.article.code} · ${l.article.unite}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
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
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: l.prix,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: _champ('Prix unitaire'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 100,
                      child: Text(
                        formaterPrix(l.total),
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
                    onPressed: _total > 0 ? () => _toutPayer(m) : null,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_paiements.isEmpty)
              const Text(
                'Aucun paiement : la totalité reste à payer (crédit fournisseur).',
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
                        decoration: _champ('Montant'),
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
    final depassement = _paye > _total;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total : ${formaterPrix(_total)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text('Payé : ${formaterPrix(_paye)}'),
            Text(
              depassement
                  ? 'Les paiements dépassent le total'
                  : 'Reste à payer (crédit fournisseur) : ${formaterPrix(_reste)}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: depassement
                    ? Colors.red
                    : (_reste > 0
                          ? Colors.orange.shade800
                          : Colors.green.shade800),
              ),
            ),
            if (Session.peut('articles.gerer'))
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _majPrix,
                onChanged: (v) => setState(() => _majPrix = v ?? false),
                title: const Text("Mettre à jour le prix d'achat du catalogue"),
                subtitle: const Text(
                  'Le prix de chaque article devient le dernier prix payé',
                ),
              ),
            if (_erreur != null) ...[
              const SizedBox(height: 8),
              Text(_erreur!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _chargement ? null : _valider,
                icon: _chargement
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text("Valider l'achat"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
