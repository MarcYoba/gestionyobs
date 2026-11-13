import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/modules/achat.dart';
import 'package:gestionyobs/pdf/compta_pdf.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/comptabilite/etats_financiers.dart';
import 'package:gestionyobs/page/regles_etats_page.dart';
import 'package:gestionyobs/rapport/rapport.dart';
import 'package:gestionyobs/modules/selecteur_periode.dart';
import 'package:gestionyobs/widget/tableau_widget.dart';
import 'package:gestionyobs/security/utilisateur.dart';

class EtatsFinanciersPage extends StatefulWidget {
  const EtatsFinanciersPage({super.key});

  @override
  State<EtatsFinanciersPage> createState() => _EtatsFinanciersPageState();
}

class _EtatsFinanciersPageState extends State<EtatsFinanciersPage> {
  late DateTime _debut;
  late DateTime _fin;
  bool _toutes = false;

  EtatsFinanciers? _etats;
  bool _chargement = true;
  bool _occupe = false;
  String? _erreur;
  String? _message;

  bool get _estAdmin => Session.utilisateurCourant?.estAdmin ?? false;
  bool get _autorise =>
      Session.peut('comptabilite.voir') || Session.peut('comptabilite.gerer');

  @override
  void initState() {
    super.initState();
    // Par défaut : l'année en cours, jusqu'à aujourd'hui
    final annee = PeriodeRapport.calculer('annee', DateTime.now());
    _debut = annee.debut;
    _fin = DateTime.now();
    _charger();
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
      final e = await DatabaseService.calculerEtatsFinanciers(
        debut: _debut,
        fin: _fin,
        toutesAgences: _toutes,
      );
      if (!mounted) return;
      setState(() {
        _etats = e;
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

  Future<Uint8List> _octets() async {
    final e = _etats!;
    final infos = await DatabaseService.lireInfosEntreprise();
    return ComptaPdf.generer(
      titre: 'États financiers',
      infosLignes: [
        'Exercice du ${formaterDate(e.debut)} au ${formaterDate(e.fin)}',
        e.portee,
      ],
      tableaux: [
        ...tableauxEtats(e),
        if (e.nbControles > 0) ...tableauxControles(e),
      ],
      infos: infos,
      auteur: Session.utilisateurCourant?.nomComplet ?? '',
      sautDePage: true,
    );
  }

  Future<void> _enregistrerPdf() async {
    if (_etats == null) return;
    setState(() {
      _occupe = true;
      _message = null;
    });
    try {
      final octets = await _octets();
      final chemin = await FilePicker.saveFile(
        dialogTitle: 'Enregistrer les états financiers en PDF',
        fileName: 'etats_financiers_${_fin.year}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: octets,
      );
      if (chemin == null) return;

      // Gestion sécurisée si le chemin retourné est un String ou un Uri
      final cheminStr = chemin.toString();

      final cible = cheminStr.toLowerCase().endsWith('.pdf')
          ? cheminStr
          : '$cheminStr.pdf';
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
    if (_etats == null) return;
    setState(() => _occupe = true);
    try {
      final octets = await _octets();
      await Printing.layoutPdf(
        onLayout: (_) async => octets,
        name: 'États financiers',
        format: PdfPageFormat.a4,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _erreur = _nettoyer(e));
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _ouvrirRegles() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReglesEtatsPage()),
    );
    _charger(); // les formules ont peut-être changé
  }

  Widget _onglet(List<TableauRapport> tableaux) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        for (final t in tableaux)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: TableauWidget(tableau: t, maxLignes: 500, minLargeur: 820),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_autorise) {
      return Scaffold(
        appBar: AppBar(title: const Text('États financiers')),
        body: const AccesRefuse(),
      );
    }

    final e = _etats;
    final tableaux = e == null ? <TableauRapport>[] : tableauxEtats(e);
    final controles = e == null ? <TableauRapport>[] : tableauxControles(e);
    final nbControles = e?.nbControles ?? 0;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('États financiers'),
          actions: [
            IconButton(
              icon: const Icon(Icons.rule),
              tooltip: 'Règles de calcul',
              onPressed: _ouvrirRegles,
            ),
          ],
          bottom: TabBar(
            tabs: [
              const Tab(text: 'Bilan : actif'),
              const Tab(text: 'Bilan : passif'),
              const Tab(text: 'Compte de résultat'),
              Tab(
                text: nbControles == 0
                    ? 'Contrôles'
                    : 'Contrôles ($nbControles)',
              ),
            ],
          ),
        ),
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
                        const Text(
                          "Exercice (le bilan est arrêté à la date de fin)",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
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
                      : TabBarView(
                          children: [
                            _onglet([tableaux[0]]),
                            _onglet([tableaux[1]]),
                            _onglet([tableaux[2]]),
                            _onglet(controles),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
