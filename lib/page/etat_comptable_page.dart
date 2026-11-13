import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/modules/achat.dart';
import 'package:gestionyobs/comptabilite/compta.dart';
import 'package:gestionyobs/pdf/compta_pdf.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/rapport/rapport.dart';
import 'package:gestionyobs/modules/selecteur_periode.dart';
import 'package:gestionyobs/widget/tableau_widget.dart';
import 'package:gestionyobs/security/utilisateur.dart';

class EtatComptablePage extends StatefulWidget {
  final String type; // 'journal', 'grand_livre' ou 'balance'

  const EtatComptablePage({super.key, required this.type});

  @override
  State<EtatComptablePage> createState() => _EtatComptablePageState();
}

class _EtatComptablePageState extends State<EtatComptablePage> {
  late DateTime _debut;
  late DateTime _fin;
  String? _journal; // null = tous les journaux
  final _compteController = TextEditingController();
  bool _toutes = false;

  List<TableauRapport> _tableaux = [];
  bool _chargement = true;
  bool _occupe = false;
  String? _erreur;
  String? _message;

  String get _titre => switch (widget.type) {
    'journal' => 'Journal comptable',
    'grand_livre' => 'Grand livre',
    _ => 'Balance des comptes',
  };
  bool get _paysage => widget.type == 'balance';
  int get _maxLignes => switch (widget.type) {
    'journal' => 200,
    'grand_livre' => 100,
    _ => 600,
  };
  bool get _estAdmin => Session.utilisateurCourant?.estAdmin ?? false;
  bool get _autorise =>
      Session.peut('comptabilite.voir') || Session.peut('comptabilite.gerer');

  @override
  void initState() {
    super.initState();
    final p = PeriodeRapport.calculer('mois', DateTime.now());
    _debut = p.debut;
    _fin = p.fin;
    _charger();
  }

  @override
  void dispose() {
    _compteController.dispose();
    super.dispose();
  }

  String _nettoyer(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _charger() async {
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
      final List<TableauRapport> tableaux;
      if (widget.type == 'journal') {
        final d = await DatabaseService.lireJournal(
          debut: _debut,
          fin: _fin,
          journal: _journal,
          toutesAgences: _toutes,
        );
        tableaux = tableauxJournal(d, toutesAgences: _toutes);
      } else if (widget.type == 'grand_livre') {
        final d = await DatabaseService.lireGrandLivre(
          debut: _debut,
          fin: _fin,
          prefixe: _compteController.text,
          toutesAgences: _toutes,
        );
        tableaux = tableauxGrandLivre(d);
      } else {
        final d = await DatabaseService.lireBalance(
          debut: _debut,
          fin: _fin,
          prefixe: _compteController.text,
          toutesAgences: _toutes,
        );
        tableaux = tableauxBalance(d);
      }

      if (!mounted) return;
      setState(() {
        _tableaux = tableaux;
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

  List<String> get _infosLignes => [
    'Période : du ${formaterDate(_debut)} au ${formaterDate(_fin)}',
    _toutes
        ? 'Toutes les agences'
        : 'Agence ${Session.agenceCourante?.nom ?? ''}',
    if (widget.type == 'journal' && _journal != null)
      'Journal : ${journauxCompta[_journal] ?? _journal}',
    if (widget.type != 'journal' && _compteController.text.trim().isNotEmpty)
      'Comptes commençant par ${_compteController.text.trim()}',
  ];

  Future<Uint8List> _octets() async {
    final infos = await DatabaseService.lireInfosEntreprise();
    return ComptaPdf.generer(
      titre: _titre,
      infosLignes: _infosLignes,
      tableaux: _tableaux,
      infos: infos,
      auteur: Session.utilisateurCourant?.nomComplet ?? '',
      paysage: _paysage,
    );
  }

  Future<void> _enregistrerPdf() async {
    setState(() {
      _occupe = true;
      _message = null;
    });
    try {
      final octets = await _octets();
      final nom =
          '${widget.type}_${_debut.year}-'
          '${_debut.month.toString().padLeft(2, '0')}.pdf';

      // On récupère le résultat (qui peut être un Uri ou un String selon la version)
      final cheminResultat = await FilePicker.saveFile(
        dialogTitle: 'Enregistrer le rapport en PDF',
        fileName: nom,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: octets,
      );
      if (cheminResultat == null) return; // annulé

      // Conversion propre en String (gère à la fois le cas Uri et le cas String)
      final String chemin = cheminResultat is Uri
          ? cheminResultat.toFilePath()
          : cheminResultat.toString();

      final cible = chemin.toLowerCase().endsWith('.pdf')
          ? chemin
          : '$chemin.pdf';
      // Note : Si saveFile avec 'bytes' a déjà écrit le fichier,
      // cette ligne garantit l'écriture si le chemin a été modifié ou complété par .pdf :
      await File(cible).writeAsBytes(octets);

      if (!mounted) return;
      setState(() => _message = 'PDF enregistré : $cible');
      await Process.run('cmd', ['/c', 'start', '', cible]);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erreur = _nettoyer(e));
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _imprimer() async {
    setState(() => _occupe = true);
    try {
      final octets = await _octets();
      await Printing.layoutPdf(
        onLayout: (_) async => octets,
        name: _titre,
        format: _paysage ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _erreur = _nettoyer(e));
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_autorise) {
      return Scaffold(
        appBar: AppBar(title: Text(_titre)),
        body: const AccesRefuse(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_titre)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1150),
          child: Column(
            children: [
              Card(
                margin: const EdgeInsets.all(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelecteurPeriode(
                        debut: _debut,
                        fin: _fin,
                        onChange: (d, f) {
                          setState(() {
                            _debut = d;
                            _fin = f;
                          });
                          _charger();
                        },
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (widget.type == 'journal')
                            DropdownButton<String?>(
                              value: _journal,
                              hint: const Text('Tous les journaux'),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Tous les journaux'),
                                ),
                                for (final e in journauxCompta.entries)
                                  DropdownMenuItem<String?>(
                                    value: e.key,
                                    child: Text('${e.key} : ${e.value}'),
                                  ),
                              ],
                              onChanged: (v) {
                                setState(() => _journal = v);
                                _charger();
                              },
                            )
                          else
                            SizedBox(
                              width: 260,
                              child: TextField(
                                controller: _compteController,
                                onSubmitted: (_) => _charger(),
                                decoration: InputDecoration(
                                  labelText: 'Comptes commençant par (ex. 411)',
                                  isDense: true,
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.search),
                                    onPressed: _charger,
                                  ),
                                ),
                              ),
                            ),
                          if (_estAdmin)
                            FilterChip(
                              label: const Text('Toutes les agences'),
                              selected: _toutes,
                              onSelected: (v) {
                                setState(() => _toutes = v);
                                _charger();
                              },
                            ),
                          FilledButton.icon(
                            onPressed: (_chargement || _occupe)
                                ? null
                                : _enregistrerPdf,
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('PDF (A4)'),
                          ),
                          OutlinedButton.icon(
                            onPressed: (_chargement || _occupe)
                                ? null
                                : _imprimer,
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
                    : _tableaux.isEmpty
                    ? const Center(
                        child: Text('Aucune écriture sur cette période'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        itemCount: _tableaux.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: TableauWidget(
                            tableau: _tableaux[index],
                            maxLignes: _maxLignes,
                            minLargeur: widget.type == 'balance' ? 950 : 700,
                          ),
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
