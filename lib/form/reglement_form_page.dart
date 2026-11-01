import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/modules/achat.dart';
import 'package:gestionyobs/modules/article.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/modules/mode_paiement.dart';
import 'package:gestionyobs/modules/reglement.dart';
import 'package:gestionyobs/page/reglement_detail_page.dart';
import 'package:gestionyobs/service/ticket_service.dart';
import 'package:gestionyobs/security/utilisateur.dart';

// Une facture avec le montant qu'on veut y régler
class _LigneDu {
  final DocumentDu doc;
  final TextEditingController montant = TextEditingController();

  _LigneDu(this.doc);

  int get m => int.tryParse(montant.text.trim()) ?? 0;

  void liberer() => montant.dispose();
}

// Un paiement en cours de saisie
class _PaiementReg {
  ModePaiement? mode;
  final TextEditingController montant = TextEditingController();
  final TextEditingController reference = TextEditingController();

  _PaiementReg(this.mode);

  int get m => int.tryParse(montant.text.trim()) ?? 0;

  void liberer() {
    montant.dispose();
    reference.dispose();
  }
}

class ReglementFormPage extends StatefulWidget {
  final String type; // 'client' ou 'fournisseur'
  final int tiersId;
  final String tiersNom;

  const ReglementFormPage({
    super.key,
    required this.type,
    required this.tiersId,
    required this.tiersNom,
  });

  @override
  State<ReglementFormPage> createState() => _ReglementFormPageState();
}

class _ReglementFormPageState extends State<ReglementFormPage> {
  final _noteController = TextEditingController();
  final List<_LigneDu> _lignes = [];
  final List<_PaiementReg> _paiements = [];
  List<ModePaiement> _modes = [];
  bool _pret = false;
  bool _chargement = false;
  String? _erreur;

  bool get _client => widget.type == 'client';
  int get _totalDu => _lignes.fold(0, (somme, l) => somme + l.doc.reste);
  int get _alloue => _lignes.fold(0, (somme, l) => somme + l.m);
  int get _paye => _paiements.fold(0, (somme, p) => somme + p.m);

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
      final docs = await DatabaseService.documentsOuverts(
        widget.type,
        widget.tiersId,
      );
      final modes = await DatabaseService.listerModesPaiement();
      if (!mounted) return;
      setState(() {
        for (final l in _lignes) {
          l.liberer();
        }
        _lignes
          ..clear()
          ..addAll(docs.map((d) => _LigneDu(d)));
        _modes = modes;
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

  void _solder(_LigneDu l) {
    setState(() => l.montant.text = l.doc.reste.toString());
  }

  // Répartit ce qui est payé sur les factures, les plus anciennes d'abord
  void _repartirAuto() {
    var disponible = _paye;
    setState(() {
      for (final l in _lignes) {
        final part = disponible < l.doc.reste ? disponible : l.doc.reste;
        l.montant.text = part > 0 ? part.toString() : '';
        disponible -= part;
      }
    });
  }

  void _ajouterPaiement() {
    setState(
      () => _paiements.add(_PaiementReg(_modes.isEmpty ? null : _modes.first)),
    );
  }

  void _retirerPaiement(_PaiementReg p) {
    setState(() => _paiements.remove(p));
    _libererPlusTard(p.liberer);
  }

  // Un seul paiement, égal au total réparti, dans ce mode
  void _toutPayer(ModePaiement mode) {
    final anciens = List<_PaiementReg>.of(_paiements);
    final nouveau = _PaiementReg(mode)..montant.text = _alloue.toString();
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

    if (_alloue <= 0)
      return echec('Indiquez le montant à régler sur au moins une facture');
    for (final l in _lignes) {
      if (l.m > l.doc.reste) {
        return echec(
          'Le montant dépasse le reste dû de la facture ${l.doc.code} '
          '(reste ${formaterPrix(l.doc.reste)})',
        );
      }
    }

    if (_paiements.isEmpty) return echec('Ajoutez au moins un paiement');
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
    if (_paye != _alloue) {
      return echec(
        'Le total des paiements (${formaterPrix(_paye)}) doit être égal '
        'au total réparti (${formaterPrix(_alloue)})',
      );
    }

    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Valider le règlement ?'),
        content: Text(
          '${_client ? 'Encaissement de' : 'Paiement de'} ${formaterPrix(_alloue)} '
          '${_client ? 'de' : 'à'} ${widget.tiersNom}.\n'
          'Solde restant dû après règlement : ${formaterPrix(_totalDu - _alloue)}\n\n'
          'Un règlement enregistré ne peut plus être modifié.',
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
      final reglement = await DatabaseService.creerReglement(
        type: widget.type,
        tiersId: widget.tiersId,
        note: _noteController.text,
        allocations: _lignes
            .where((l) => l.m > 0)
            .map((l) => AllocationSaisie(documentId: l.doc.id, montant: l.m))
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
      final montant = _alloue;

      // Impression automatique, selon les réglages de ce poste
      String? message;
      try {
        await _imprimerSiAuto(reglement.id);
      } catch (e) {
        message =
            'Impression impossible : ${e.toString().replaceFirst('Exception: ', '')}';
      }
      if (!mounted) return;

      String? suite;
      while (suite == null || suite == 'imprimer') {
        suite = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Règlement enregistré'),
            content: Text(
              'Reçu N° ${reglement.code}\n'
              'Montant : ${formaterPrix(montant)}'
              '${message != null ? '\n\n$message' : ''}',
              style: const TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, 'fermer'),
                child: const Text('Fermer'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, 'imprimer'),
                child: const Text('Imprimer le reçu'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, 'voir'),
                child: const Text('Voir le reçu'),
              ),
            ],
          ),
        );
        if (!mounted) return;

        if (suite == 'imprimer') {
          try {
            await TicketService.imprimerReglement(reglement.id);
            message = "Reçu envoyé à l'imprimante";
          } catch (e) {
            message =
                'Impression impossible : ${e.toString().replaceFirst('Exception: ', '')}';
          }
        }
      }

      if (suite == 'voir') {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReglementDetailPage(id: reglement.id),
          ),
        );
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

  // Si ce poste imprime automatiquement, on imprime le reçu
  Future<void> _imprimerSiAuto(int reglementId) async {
    if (await TicketService.impressionAutoActive()) {
      await TicketService.imprimerReglement(reglementId);
    }
  }

  InputDecoration _champ(String libelle) => InputDecoration(
    labelText: libelle,
    isDense: true,
    border: const OutlineInputBorder(),
  );

  @override
  Widget build(BuildContext context) {
    final droit = _client ? 'reglements.clients' : 'reglements.fournisseurs';
    if (!Session.peut(droit)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Règlement')),
        body: const AccesRefuse(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _client ? 'Encaisser un règlement' : 'Payer un fournisseur',
        ),
      ),
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
                      _carteEntete(),
                      const SizedBox(height: 12),
                      _cartePaiements(),
                      const SizedBox(height: 12),
                      _carteFactures(),
                      const SizedBox(height: 12),
                      _carteRecapitulatif(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _carteEntete() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.tiersNom,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              _client
                  ? 'Total dû par ce client : ${formaterPrix(_totalDu)}'
                  : 'Total dû à ce fournisseur : ${formaterPrix(_totalDu)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade800,
              ),
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

  Widget _cartePaiements() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _client
                        ? '1. Ce que le client règle'
                        : '1. Ce que vous payez',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
            if (_paiements.isEmpty)
              const Text(
                'Ajoutez un paiement, ou répartissez d\'abord sur les factures '
                'puis utilisez « Tout payer ».',
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
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in _modes)
                  ActionChip(
                    label: Text('Tout payer : ${m.libelle}'),
                    onPressed: _alloue > 0 ? () => _toutPayer(m) : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _carteFactures() {
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
                    '2. Factures à régler',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _paye > 0 ? _repartirAuto : null,
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Répartir automatiquement'),
                ),
              ],
            ),
            const Text(
              'La répartition automatique solde les factures les plus anciennes d\'abord.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            if (_lignes.isEmpty) const Text('Aucune facture à régler.'),
            for (final l in _lignes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Facture ${l.doc.code}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${formaterDate(l.doc.date)} · Total ${formaterPrix(l.doc.total)} · '
                            'Payé ${formaterPrix(l.doc.paye)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 110,
                      child: Text(
                        'Reste ${formaterPrix(l.doc.reste)}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 130,
                      child: TextField(
                        controller: l.montant,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: _champ('À régler'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.done_all),
                      tooltip: 'Solder cette facture',
                      onPressed: () => _solder(l),
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
    final equilibre = _paye == _alloue;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Réparti sur les factures : ${formaterPrix(_alloue)}'),
            Text('Total des paiements : ${formaterPrix(_paye)}'),
            Text(
              equilibre
                  ? 'Solde restant dû après règlement : ${formaterPrix(_totalDu - _alloue)}'
                  : 'Le total des paiements doit être égal au total réparti '
                        '(écart : ${formaterPrix((_paye - _alloue).abs())})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: equilibre ? Colors.green.shade800 : Colors.red,
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
                    : const Icon(Icons.check),
                label: Text(
                  _client ? 'Valider le règlement' : 'Valider le paiement',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
