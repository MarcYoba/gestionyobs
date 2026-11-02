import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/rapport/rapport.dart';
import 'package:gestionyobs/rapport/rapport_pdf.dart';
import 'package:gestionyobs/security/utilisateur.dart';

class RapportsPage extends StatefulWidget {
  const RapportsPage({super.key});

  @override
  State<RapportsPage> createState() => _RapportsPageState();
}

class _RapportsPageState extends State<RapportsPage> {
  String _type = 'mois';
  DateTime _reference = DateTime.now();
  bool _detail = true;
  bool _toutes = false;

  RapportDonnees? _rapport;
  bool _chargement = true;
  bool _export = false;
  String? _erreur;
  String? _message;

  bool get _autorise => Session.peut('rapports.voir');
  bool get _estAdmin => Session.utilisateurCourant?.estAdmin ?? false;

  @override
  void initState() {
    super.initState();
    _generer();
  }

  String _nettoyer(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _generer() async {
    if (!_autorise) {
      setState(() => _chargement = false);
      return;
    }

    setState(() {
      _chargement = true;
      _erreur = null;
      _message = null;
    });
    try {
      final r = await DatabaseService.genererRapport(
        type: _type,
        reference: _reference,
        toutesAgences: _toutes,
        detail: _detail,
      );
      if (!mounted) return;
      setState(() {
        _rapport = r;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = _nettoyer(e);
      });
    }
  }

  void _changerType(String type) {
    setState(() {
      _type = type;
      // Le détail est utile pour les périodes courtes
      _detail = type == 'jour' || type == 'semaine' || type == 'mois';
    });
    _generer();
  }

  void _deplacer(int sens) {
    final periode = PeriodeRapport.calculer(_type, _reference);
    setState(() => _reference = periode.decaler(sens));
    _generer();
  }

  Future<void> _choisirDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _reference,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (d == null) return;
    setState(() => _reference = d);
    _generer();
  }

  Future<Uint8List> _octets() async {
    final infos = await DatabaseService.lireInfosEntreprise();
    return RapportPdf.generer(_rapport!, infos);
  }

  // Enregistre le PDF où l'on veut, puis l'ouvre
  Future<void> _enregistrerPdf() async {
    final r = _rapport;
    if (r == null) return;

    setState(() {
      _export = true;
      _message = null;
      _erreur = null;
    });
    try {
      final octets = await _octets();
      final nom = 'rapport_${r.periode.type}_${r.periode.debutTexte}.pdf';

      final resultat = await FilePicker.saveFile(
        dialogTitle: 'Enregistrer le rapport en PDF',
        fileName: nom,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: octets,
      );
      if (resultat == null) return; // annulé

      // Le résultat est un Uri : on le convertit en chemin Windows
      final String chemin = resultat.toFilePath();

      final cible = chemin.toLowerCase().endsWith('.pdf')
          ? chemin
          : '$chemin.pdf';

      // On écrit nous-mêmes le fichier pour être sûr qu'il existe
      await File(cible).writeAsBytes(octets);

      if (!mounted) return;
      setState(() => _message = 'PDF enregistré : $cible');

      // Ouvre le PDF avec le lecteur de Windows
      await Process.run('cmd', ['/c', 'start', '', cible]);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erreur = _nettoyer(e));
    } finally {
      if (mounted) setState(() => _export = false);
    }
  }

  // Ouvre la fenêtre d'impression de Windows (papier A4)
  Future<void> _imprimer() async {
    final r = _rapport;
    if (r == null) return;

    setState(() => _export = true);
    try {
      final octets = await _octets();
      await Printing.layoutPdf(
        onLayout: (_) async => octets,
        name: r.periode.titre,
        format: PdfPageFormat.a4,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _erreur = _nettoyer(e));
    } finally {
      if (mounted) setState(() => _export = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_autorise) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rapports')),
        body: const AccesRefuse(),
      );
    }

    final periode = PeriodeRapport.calculer(_type, _reference);

    return Scaffold(
      appBar: AppBar(title: const Text('Rapports')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              _commandes(periode),
              Expanded(child: _contenu()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _commandes(PeriodeRapport periode) {
    final aujourdhui = DateTime.now();
    final suivantPossible = periode.fin.isBefore(
      DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day),
    );

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final e in PeriodeRapport.types.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _type == e.key,
                    onSelected: (_) => _changerType(e.key),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Période précédente',
                  onPressed: () => _deplacer(-1),
                ),
                Expanded(
                  child: Text(
                    periode.titre,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Période suivante',
                  onPressed: suivantPossible ? () => _deplacer(1) : null,
                ),
                OutlinedButton.icon(
                  onPressed: _choisirDate,
                  icon: const Icon(Icons.event),
                  label: const Text('Choisir une date'),
                ),
              ],
            ),
            Wrap(
              spacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterChip(
                  label: const Text(
                    'Inclure la liste des ventes et des achats',
                  ),
                  selected: _detail,
                  onSelected: (v) {
                    setState(() => _detail = v);
                    _generer();
                  },
                ),
                if (_estAdmin)
                  FilterChip(
                    label: const Text('Toutes les agences'),
                    selected: _toutes,
                    onSelected: (v) {
                      setState(() => _toutes = v);
                      _generer();
                    },
                  ),
                FilledButton.icon(
                  onPressed: (_rapport == null || _export)
                      ? null
                      : _enregistrerPdf,
                  icon: _export
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf),
                  label: const Text('Exporter en PDF (A4)'),
                ),
                OutlinedButton.icon(
                  onPressed: (_rapport == null || _export) ? null : _imprimer,
                  icon: const Icon(Icons.print),
                  label: const Text('Imprimer'),
                ),
              ],
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _message!,
                  style: TextStyle(color: Colors.green.shade800),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _contenu() {
    if (_chargement) return const Center(child: CircularProgressIndicator());
    if (_erreur != null) {
      return Center(
        child: Text(_erreur!, style: const TextStyle(color: Colors.red)),
      );
    }

    final r = _rapport;
    if (r == null) return const SizedBox.shrink();

    final tableaux = construireTableaux(r);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        Text(
          '${r.portee}  ·  du ${r.periode.debutTexte} au ${r.periode.finTexte}',
          style: const TextStyle(color: Colors.black54),
        ),
        for (var i = 0; i < tableaux.length; i++) ...[
          const SizedBox(height: 20),
          _TableauEcran(numero: i + 1, tableau: tableaux[i]),
        ],
      ],
    );
  }
}

/// Un tableau du rapport, à l'écran.
class _TableauEcran extends StatelessWidget {
  final int numero;
  final TableauRapport tableau;

  // Pour rester fluide, l'écran n'affiche que le début des longues listes
  static const int _maxLignes = 60;

  const _TableauEcran({required this.numero, required this.tableau});

  Widget _cellule(
    String texte,
    int colonne, {
    bool gras = false,
    Color? couleur,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        texte,
        textAlign: tableau.droite.contains(colonne)
            ? TextAlign.right
            : TextAlign.left,
        style: TextStyle(
          fontSize: 13,
          fontWeight: gras ? FontWeight.bold : FontWeight.normal,
          color: couleur,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lignes = tableau.lignes.take(_maxLignes).toList();
    final coupe = tableau.lignes.length > _maxLignes;

    final rangees = <TableRow>[
      TableRow(
        decoration: BoxDecoration(color: Colors.green.shade700),
        children: [
          for (var i = 0; i < tableau.entetes.length; i++)
            _cellule(tableau.entetes[i], i, gras: true, couleur: Colors.white),
        ],
      ),
      for (var k = 0; k < lignes.length; k++)
        TableRow(
          decoration: BoxDecoration(
            color: k.isOdd ? Colors.grey.shade100 : Colors.white,
          ),
          children: [
            for (var i = 0; i < lignes[k].length; i++)
              _cellule(lignes[k][i], i),
          ],
        ),
      if (tableau.total != null)
        TableRow(
          decoration: BoxDecoration(color: Colors.green.shade100),
          children: [
            for (var i = 0; i < tableau.total!.length; i++)
              _cellule(tableau.total![i], i, gras: true),
          ],
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$numero. ${tableau.titre}',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        if (tableau.lignes.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Aucune opération sur cette période.',
              style: TextStyle(
                color: Colors.black54,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        Table(
          border: TableBorder.all(color: Colors.grey.shade400, width: 0.6),
          columnWidths: {
            for (var i = 0; i < tableau.flex.length; i++)
              i: FlexColumnWidth(tableau.flex[i].toDouble()),
          },
          children: rangees,
        ),
        if (coupe)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${tableau.lignes.length} lignes : les $_maxLignes premières sont affichées ici. '
              'La liste complète est dans le PDF.',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        if (tableau.note != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              tableau.note!,
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }
}
