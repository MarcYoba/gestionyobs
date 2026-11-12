import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/modules/achat.dart';
import 'package:gestionyobs/modules/article.dart';
import 'package:gestionyobs/modules/caisse.dart';
import 'package:gestionyobs/pdf/caisse_pdf.dart';

import 'clotures_page.dart';

import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/modules/stock.dart';
import 'package:gestionyobs/security/utilisateur.dart';

class CaissePage extends StatefulWidget {
  const CaissePage({super.key});

  @override
  State<CaissePage> createState() => _CaissePageState();
}

class _CaissePageState extends State<CaissePage> {
  DateTime _date = DateTime.now();
  JourCaisse? _jour;
  bool _chargement = true;
  bool _occupe = false;
  String? _erreur;
  String? _message;

  // Le comptage : une case par valeur de billet ou de pièce
  final Map<int, TextEditingController> _coupures = {
    for (final v in coupuresCaisse) v: TextEditingController(),
  };
  final _fondController = TextEditingController(text: '0');
  final _laisseController = TextEditingController();
  final _noteController = TextEditingController();

  bool get _peutCloturer => Session.peut('caisse.cloturer');

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    for (final c in _coupures.values) {
      c.dispose();
    }
    _fondController.dispose();
    _laisseController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _nettoyer(Object e) => e.toString().replaceFirst('Exception: ', '');

  // Les montants calculés à partir de ce qui est saisi
  int _quantite(int valeur) =>
      int.tryParse(_coupures[valeur]!.text.trim()) ?? 0;

  int get _fond {
    final j = _jour;
    if (j == null) return 0;
    return j.cloture?.fondOuverture ??
        j.fondPrecedent ??
        (int.tryParse(_fondController.text.trim()) ?? 0);
  }

  int get _theorique => _fond + (_jour?.netPhysique ?? 0);
  int get _compte => coupuresCaisse.fold(0, (s, v) => s + v * _quantite(v));
  int get _ecart => _compte - _theorique;

  // Par défaut, on laisse le fond de caisse (sans dépasser ce qui est compté)
  int get _laisse {
    final texte = _laisseController.text.trim();
    if (texte.isEmpty) return _fond < _compte ? _fond : _compte;
    return int.tryParse(texte) ?? 0;
  }

  void _viderSaisie() {
    for (final c in _coupures.values) {
      c.clear();
    }
    _laisseController.clear();
    _noteController.clear();
  }

  Future<void> _charger() async {
    try {
      final j = await DatabaseService.lireJourCaisse(_date);
      if (!mounted) return;
      setState(() {
        _jour = j;
        _chargement = false;
        _erreur = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = _nettoyer(e);
      });
    }
  }

  void _changerDate(DateTime d) {
    setState(() {
      _date = d;
      _message = null;
      _chargement = true;
      _viderSaisie();
    });
    _charger();
  }

  Future<void> _choisirDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (d != null) _changerDate(d);
  }

  Future<void> _ouvrirHistorique() async {
    final d = await Navigator.push<DateTime>(
      context,
      MaterialPageRoute(builder: (_) => const CloturesPage()),
    );
    if (d != null) _changerDate(d);
  }

  Future<void> _cloturer() async {
    final j = _jour;
    if (j == null) return;

    final compte = _compte;
    final ecart = _ecart;
    final laisse = _laisse;

    void echec(String m) => setState(() => _erreur = m);
    setState(() => _erreur = null);

    if (compte <= 0 && _theorique > 0) {
      return echec("Faites d'abord le comptage de la caisse");
    }
    if (ecart != 0 && _noteController.text.trim().length < 5) {
      return echec(
        'Il y a un écart de ${formaterPrix(ecart)} : '
        'expliquez-le dans la note (5 caractères minimum)',
      );
    }
    if (laisse > compte) {
      return echec(
        'Le montant laissé en caisse ne peut pas dépasser ce qui est compté',
      );
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Clôturer la journée du ${formaterDate(_date)} ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Montant théorique : ${formaterPrix(_theorique)}'),
            Text('Montant compté : ${formaterPrix(compte)}'),
            Text(
              ecart == 0
                  ? 'Écart : aucun, la caisse est juste'
                  : 'Écart : ${ecart > 0 ? '+' : ''}${formaterPrix(ecart)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: ecart == 0 ? Colors.green.shade800 : Colors.red.shade700,
              ),
            ),
            Text('Laissé en caisse : ${formaterPrix(laisse)}'),
            Text('Retiré de la caisse : ${formaterPrix(compte - laisse)}'),
            const SizedBox(height: 8),
            const Text(
              'Une fois clôturée, la journée ne se modifie plus.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Revenir'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clôturer'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _occupe = true);
    try {
      final code = await DatabaseService.cloturerCaisse(
        date: _date,
        coupures: {
          for (final v in coupuresCaisse)
            if (_quantite(v) > 0) v: _quantite(v),
        },
        laisse: laisse,
        fondInitial: j.fondPrecedent == null ? _fond : 0,
        note: _noteController.text,
      );
      if (!mounted) return;
      _viderSaisie();
      _message = 'Journée clôturée (N° $code)';
      await _charger();
    } catch (e) {
      if (!mounted) return;
      setState(() => _erreur = _nettoyer(e));
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _rouvrir(ClotureCaisse c) async {
    final controller = TextEditingController();
    final motif = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Rouvrir la clôture ${c.code} ?'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'La clôture est annulée (elle reste dans la base, marquée annulée) '
                  'et vous pourrez refaire le comptage.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: 120,
                  onChanged: (_) => setLocal(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Motif (obligatoire)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Revenir'),
            ),
            FilledButton(
              onPressed: controller.text.trim().length >= 5
                  ? () => Navigator.pop(dialogContext, controller.text.trim())
                  : null,
              child: const Text('Rouvrir'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (motif == null) return;

    try {
      await DatabaseService.rouvrirCloture(c.id, motif);
      if (!mounted) return;
      _message = 'Clôture annulée : vous pouvez refaire le comptage';
      await _charger();
    } catch (e) {
      if (!mounted) return;
      setState(() => _erreur = _nettoyer(e));
    }
  }

  Future<Uint8List> _octets() async {
    final infos = await DatabaseService.lireInfosEntreprise();
    return CaissePdf.generer(_jour!, infos, _fond);
  }

  Future<void> _enregistrerPdf() async {
    final j = _jour;
    if (j == null) return;

    setState(() => _occupe = true);
    try {
      final octets = await _octets();
      final d = j.date;
      final nom =
          'caisse_${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}.pdf';

      // On passe les octets directement ici et on récupère le chemin final du fichier enregistré
      final chemin = await FilePicker.saveFile(
        dialogTitle: 'Enregistrer le journal de caisse en PDF',
        fileName: nom,
        bytes: octets, // <-- Ajout du paramètre requis
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (chemin == null) return;

      // Gestion sécurisée si le chemin retourné est un String ou un Uri
      final cheminStr = chemin.toString();
      final cible = cheminStr.toLowerCase().endsWith('.pdf')
          ? cheminStr
          : '$cheminStr.pdf';

      if (!mounted) return;
      setState(() => _message = 'PDF enregistré : $cible');

      // Ouvre le fichier PDF généré
      await Process.run('cmd', ['/c', 'start', '', cible]);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erreur = _nettoyer(e));
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _imprimer() async {
    final j = _jour;
    if (j == null) return;

    setState(() => _occupe = true);
    try {
      final octets = await _octets();
      await Printing.layoutPdf(
        onLayout: (_) async => octets,
        name: 'Caisse du ${formaterDate(j.date)}',
        format: PdfPageFormat.a4,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _erreur = _nettoyer(e));
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  // ----- Affichage -----

  Widget _ligne(
    String libelle,
    String valeur, {
    bool gras = false,
    Color? couleur,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              libelle,
              style: TextStyle(fontWeight: gras ? FontWeight.bold : null),
            ),
          ),
          Text(
            valeur,
            style: TextStyle(
              fontWeight: gras ? FontWeight.bold : FontWeight.w500,
              color: couleur,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bandeau(
    String texte,
    MaterialColor couleur,
    IconData icone, {
    Widget? action,
  }) {
    return Card(
      color: couleur.shade50,
      child: ListTile(
        leading: Icon(icone, color: couleur.shade800),
        title: Text(texte, style: TextStyle(color: couleur.shade900)),
        trailing: action,
      ),
    );
  }

  Widget _barreDate() {
    final n = DateTime.now();
    final aujourdhui =
        _date.year == n.year && _date.month == n.month && _date.day == n.day;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Jour précédent',
          onPressed: () =>
              _changerDate(DateTime(_date.year, _date.month, _date.day - 1)),
        ),
        OutlinedButton.icon(
          onPressed: _choisirDate,
          icon: const Icon(Icons.event),
          label: Text(
            aujourdhui
                ? "Aujourd'hui (${formaterDate(_date)})"
                : formaterDate(_date),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Jour suivant',
          onPressed: aujourdhui
              ? null
              : () => _changerDate(
                  DateTime(_date.year, _date.month, _date.day + 1),
                ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: _ouvrirHistorique,
          icon: const Icon(Icons.history),
          label: const Text('Historique des clôtures'),
        ),
        FilledButton.icon(
          onPressed: (_jour == null || _occupe) ? null : _enregistrerPdf,
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('PDF (A4)'),
        ),
        OutlinedButton.icon(
          onPressed: (_jour == null || _occupe) ? null : _imprimer,
          icon: const Icon(Icons.print),
          label: const Text('Imprimer'),
        ),
      ],
    );
  }

  Widget _carteMode(LigneModeCaisse m) {
    final etiquette = switch (m.type) {
      'caisse' => 'Espèces en caisse',
      'mobile' => 'Mobile',
      'banque' => 'Banque',
      _ => '',
    };

    return SizedBox(
      width: 300,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                m.libelle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (etiquette.isNotEmpty)
                Text(
                  etiquette,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              const Divider(),
              if (m.ventes != 0)
                _ligne('Ventes encaissées', formaterPrix(m.ventes)),
              if (m.reglements != 0)
                _ligne('Règlements reçus', formaterPrix(m.reglements)),
              if (m.rembRecus != 0)
                _ligne('Remboursements reçus', formaterPrix(m.rembRecus)),
              if (m.fournisseurs != 0)
                _ligne(
                  'Paiements fournisseurs',
                  '-${formaterPrix(m.fournisseurs)}',
                ),
              if (m.depenses != 0)
                _ligne('Dépenses', '-${formaterPrix(m.depenses)}'),
              if (m.rembClients != 0)
                _ligne(
                  'Remboursements clients',
                  '-${formaterPrix(m.rembClients)}',
                ),
              if (m.entrees == 0 && m.sorties == 0)
                const Text(
                  'Aucun mouvement',
                  style: TextStyle(color: Colors.black54),
                ),
              const Divider(),
              _ligne('Net du jour', formaterPrix(m.net), gras: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _carteEspeces(JourCaisse j) {
    final c = j.cloture;
    final premiere = j.fondPrecedent == null && c == null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Caisse en espèces',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            if (premiere && _peutCloturer) ...[
              TextField(
                controller: _fondController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: "Fond de caisse à l'ouverture",
                  helperText: "Première clôture : l'argent déjà présent dans le tiroir ce matin",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
            ] else
              _ligne("Fond de caisse à l'ouverture", formaterPrix(_fond)),
            _ligne(
              '+ Entrées en espèces',
              formaterPrix(c?.entrees ?? j.entreesPhysiques),
            ),
            _ligne(
              '- Sorties en espèces',
              formaterPrix(c?.sorties ?? j.sortiesPhysiques),
            ),
            const Divider(),
            _ligne(
              '= Montant théorique en caisse',
              formaterPrix(c?.theorique ?? _theorique),
              gras: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _carteResultat(ClotureCaisse c) {
    final juste = c.ecart == 0;
    return Card(
      color: juste ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Journée clôturée (${c.code})',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text('Le ${formaterDateHeure(c.creeLe)} par ${c.par}'),
            const Divider(),
            _ligne('Montant compté', formaterPrix(c.compte)),
            _ligne(
              'Écart (compté - théorique)',
              juste
                  ? 'Aucun'
                  : '${c.ecart > 0 ? '+' : ''}${formaterPrix(c.ecart)}',
              gras: true,
              couleur: juste ? Colors.green.shade800 : Colors.red.shade700,
            ),
            _ligne('Laissé en caisse pour demain', formaterPrix(c.laisse)),
            _ligne('Retiré de la caisse (versement)', formaterPrix(c.verse)),
            if (c.note != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text("Note d'écart : ${c.note}"),
              ),
            if (Session.peut('caisse.rouvrir'))
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _rouvrir(c),
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Rouvrir (annuler la clôture)'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _carteComptage() {
    final ecart = _ecart;
    final compte = _compte;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Comptage de la caisse',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const Text(
              'Saisissez le nombre de billets et de pièces de chaque valeur.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 8),
            for (final v in coupuresCaisse)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 190,
                      child: Text(
                        v == 1 ? 'Autre (montant)' : formaterPrix(v),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    SizedBox(
                      width: 110,
                      child: TextField(
                        controller: _coupures[v],
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          isDense: true,
                          border: const OutlineInputBorder(),
                          hintText: v == 1 ? 'montant' : '0',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _quantite(v) > 0
                          ? '= ${formaterPrix(v * _quantite(v))}'
                          : '',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            const Divider(height: 24),
            _ligne('Montant compté', formaterPrix(compte), gras: true),
            _ligne('Montant théorique', formaterPrix(_theorique)),
            _ligne(
              'Écart',
              ecart == 0
                  ? 'Aucun'
                  : '${ecart > 0 ? '+' : ''}${formaterPrix(ecart)}',
              gras: true,
              couleur: ecart == 0 ? Colors.green.shade800 : Colors.red.shade700,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _laisseController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Laissé en caisse pour demain',
                helperText:
                    'Par défaut : le fond de caisse (${formaterPrix(_laisse)}). '
                    'Retiré de la caisse : ${formaterPrix(compte - _laisse)}',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLength: 200,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: ecart == 0
                    ? 'Note (facultatif)'
                    : "Note d'écart (obligatoire)",
                border: const OutlineInputBorder(),
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _occupe ? null : _cloturer,
                icon: const Icon(Icons.lock),
                label: const Text('Clôturer la journée'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _journal(JourCaisse j) {
    const max = 150;
    final lignes = j.mouvements.take(max).toList();
    final entrees = j.mouvements
        .where((m) => m.flux > 0)
        .fold(0, (s, m) => s + m.flux);
    final sorties = j.mouvements
        .where((m) => m.flux < 0)
        .fold(0, (s, m) => s - m.flux);

    Widget cellule(
      String texte, {
      bool droite = false,
      bool gras = false,
      Color? couleur,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Text(
          texte,
          textAlign: droite ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: gras ? FontWeight.bold : null,
            color: couleur,
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Journal du jour',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            if (j.mouvements.isEmpty)
              const Text(
                'Aucun mouvement ce jour-là.',
                style: TextStyle(color: Colors.black54),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 860),
                  child: Table(
                    border: TableBorder.all(
                      color: Colors.grey.shade400,
                      width: 0.6,
                    ),
                    columnWidths: const {
                      0: FlexColumnWidth(1),
                      1: FlexColumnWidth(3),
                      2: FlexColumnWidth(3),
                      3: FlexColumnWidth(4),
                      4: FlexColumnWidth(2),
                      5: FlexColumnWidth(2),
                      6: FlexColumnWidth(2),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: Colors.green.shade700),
                        children: [
                          for (final t in [
                            'Heure',
                            'Nature',
                            'Document',
                            'Libellé',
                            'Mode',
                            'Entrée',
                            'Sortie',
                          ])
                            cellule(
                              t,
                              gras: true,
                              couleur: Colors.white,
                              droite: t == 'Entrée' || t == 'Sortie',
                            ),
                        ],
                      ),
                      for (var k = 0; k < lignes.length; k++)
                        TableRow(
                          decoration: BoxDecoration(
                            color: k.isOdd
                                ? Colors.grey.shade100
                                : Colors.white,
                          ),
                          children: [
                            cellule(
                              '${lignes[k].heure.hour.toString().padLeft(2, '0')}:'
                              '${lignes[k].heure.minute.toString().padLeft(2, '0')}',
                            ),
                            cellule(lignes[k].nature),
                            cellule(lignes[k].document),
                            cellule(lignes[k].libelle),
                            cellule(lignes[k].mode),
                            cellule(
                              lignes[k].flux > 0
                                  ? formaterPrix(lignes[k].flux)
                                  : '',
                              droite: true,
                            ),
                            cellule(
                              lignes[k].flux < 0
                                  ? formaterPrix(-lignes[k].flux)
                                  : '',
                              droite: true,
                            ),
                          ],
                        ),
                      TableRow(
                        decoration: BoxDecoration(color: Colors.green.shade100),
                        children: [
                          cellule(''),
                          cellule('TOTAL', gras: true),
                          cellule(''),
                          cellule(''),
                          cellule(''),
                          cellule(
                            formaterPrix(entrees),
                            droite: true,
                            gras: true,
                          ),
                          cellule(
                            formaterPrix(sorties),
                            droite: true,
                            gras: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (j.mouvements.length > max)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${j.mouvements.length} mouvements : les $max premiers sont affichés ici. '
                  'La liste complète est dans le PDF.',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final agence = Session.agenceCourante;

    if (!Session.peut('caisse.voir')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Caisse')),
        body: const AccesRefuse(),
      );
    }

    final j = _jour;

    return Scaffold(
      appBar: AppBar(
        title: Text(agence == null ? 'Caisse' : 'Caisse - ${agence.nom}'),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : j == null
          ? Center(
              child: Text(
                _erreur ?? 'Caisse indisponible',
                style: const TextStyle(color: Colors.red),
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _barreDate(),
                    const SizedBox(height: 8),
                    if (_message != null)
                      _bandeau(_message!, Colors.green, Icons.check_circle),
                    if (_erreur != null)
                      _bandeau(_erreur!, Colors.red, Icons.error_outline),
                    if (j.cloture == null)
                      _bandeau(
                        'Journée non clôturée : les chiffres sont provisoires.',
                        Colors.orange,
                        Icons.lock_open,
                      ),
                    if (j.cloture != null && j.cloture!.mouvementsApres > 0)
                      _bandeau(
                        '${j.cloture!.mouvementsApres} mouvement(s) enregistré(s) '
                        'après la clôture : ils ne sont pas dans le comptage.',
                        Colors.orange,
                        Icons.warning_amber,
                      ),
                    if (j.jourARegulariser != null && j.cloture == null)
                      _bandeau(
                        'Le ${formaterDate(j.jourARegulariser!)} n\'est pas clôturé : '
                        'clôturez-le avant cette journée.',
                        Colors.red,
                        Icons.block,
                        action: TextButton(
                          onPressed: () => _changerDate(j.jourARegulariser!),
                          child: const Text('Y aller'),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [for (final m in j.modes) _carteMode(m)],
                    ),
                    const SizedBox(height: 8),
                    _carteEspeces(j),
                    if (j.cloture != null) _carteResultat(j.cloture!),
                    if (j.cloture == null &&
                        _peutCloturer &&
                        j.jourARegulariser == null)
                      _carteComptage(),
                    const SizedBox(height: 8),
                    _journal(j),
                  ],
                ),
              ),
            ),
    );
  }
}
