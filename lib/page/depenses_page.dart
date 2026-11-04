import 'package:flutter/material.dart';
import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/modules/achat.dart';
import 'package:gestionyobs/modules/article.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/modules/depense.dart';
import 'package:gestionyobs/form/depense_form_page.dart';
import 'package:gestionyobs/rapport/rapport.dart';
import 'package:gestionyobs/security/utilisateur.dart';

class DepensesPage extends StatefulWidget {
  const DepensesPage({super.key});

  @override
  State<DepensesPage> createState() => _DepensesPageState();
}

class _DepensesPageState extends State<DepensesPage> {
  static const _mois = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];

  final _rechercheController = TextEditingController();
  DateTime _reference = DateTime.now();
  String? _type; // null = tous
  List<DepenseResume> _depenses = [];
  bool _chargement = true;
  String? _erreur;

  bool get _peutVoir => Session.peut('depenses.voir');
  bool get _peutCreer => Session.peut('depenses.creer');

  PeriodeRapport get _periode => PeriodeRapport.calculer('mois', _reference);

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _rechercheController.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    if (!_peutVoir) {
      setState(() => _chargement = false);
      return;
    }
    try {
      final p = _periode;
      final liste = await DatabaseService.listerDepenses(
        debut: p.debut,
        fin: p.fin,
        type: _type,
        recherche: _rechercheController.text,
      );
      if (!mounted) return;
      setState(() {
        _depenses = liste;
        _chargement = false;
        _erreur = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _deplacer(int sens) {
    setState(() => _reference = _periode.decaler(sens));
    _charger();
  }

  Future<void> _nouvelleDepense() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DepenseFormPage()),
    );
    _charger();
  }

  int _total(String? type) => _depenses
      .where((d) => type == null || d.type == type)
      .fold(0, (somme, d) => somme + d.montant);

  IconData _icone(String type) => switch (type) {
    'salaire' => Icons.groups,
    'charge' => Icons.receipt_long,
    _ => Icons.more_horiz,
  };

  @override
  Widget build(BuildContext context) {
    final agence = Session.agenceCourante;

    if (!_peutVoir && !_peutCreer) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dépenses')),
        body: const AccesRefuse(),
      );
    }

    // Peut enregistrer, mais pas consulter
    if (!_peutVoir) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dépenses')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Vous pouvez enregistrer des dépenses, sans les consulter.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _nouvelleDepense,
                icon: const Icon(Icons.add),
                label: const Text('Nouvelle dépense'),
              ),
            ],
          ),
        ),
      );
    }

    final periode = _periode;
    final aujourdhui = DateTime.now();
    final suivantPossible = periode.fin.isBefore(
      DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day),
    );
    final titreMois =
        '${_mois[periode.debut.month - 1][0].toUpperCase()}'
        '${_mois[periode.debut.month - 1].substring(1)} ${periode.debut.year}';

    return Scaffold(
      appBar: AppBar(
        title: Text(agence == null ? 'Dépenses' : 'Dépenses - ${agence.nom}'),
      ),
      floatingActionButton: _peutCreer
          ? FloatingActionButton.extended(
              onPressed: _nouvelleDepense,
              icon: const Icon(Icons.add),
              label: const Text('Nouvelle dépense'),
            )
          : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      tooltip: 'Mois précédent',
                      onPressed: () => _deplacer(-1),
                    ),
                    Expanded(
                      child: Text(
                        titreMois,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      tooltip: 'Mois suivant',
                      onPressed: suivantPossible ? () => _deplacer(1) : null,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('Toutes'),
                      selected: _type == null,
                      onSelected: (_) {
                        setState(() => _type = null);
                        _charger();
                      },
                    ),
                    for (final e in typesDepense.entries)
                      if (e.key != 'salaire' ||
                          Session.peut('depenses.salaires'))
                        ChoiceChip(
                          label: Text(e.value),
                          selected: _type == e.key,
                          onSelected: (_) {
                            setState(() => _type = e.key);
                            _charger();
                          },
                        ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  controller: _rechercheController,
                  onChanged: (_) => _charger(),
                  decoration: const InputDecoration(
                    labelText:
                        'Rechercher (libellé, bénéficiaire, compte, matricule)',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 16,
                    children: [
                      if (Session.peut('depenses.salaires'))
                        Text('Salaires : ${formaterPrix(_total('salaire'))}'),
                      Text('Charges : ${formaterPrix(_total('charge'))}'),
                      Text('Autres : ${formaterPrix(_total('autre'))}'),
                      Text(
                        'TOTAL : ${formaterPrix(_total(null))}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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
                    : _depenses.isEmpty
                    ? const Center(
                        child: Text('Aucune dépense sur cette période'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                        itemCount: _depenses.length,
                        itemBuilder: (context, index) {
                          final d = _depenses[index];
                          return Card(
                            child: ListTile(
                              isThreeLine: true,
                              leading: Icon(
                                _icone(d.type),
                                color: Colors.green,
                              ),
                              title: Text('${d.libelle}'),
                              subtitle: Text(
                                [
                                  '${formaterDate(d.date)} · ${typesDepense[d.type] ?? d.type}'
                                      '${d.mode == null ? '' : ' · ${d.mode}'}',
                                  'Compte : ${d.numeroCompte}  ${d.intituleCompte}',
                                  [
                                    d.code,
                                    if (d.beneficiaire != null) d.beneficiaire!,
                                    if (d.piece != null) 'Pièce ${d.piece}',
                                  ].join(' · '),
                                ].join('\n'),
                              ),
                              trailing: Text(
                                formaterPrix(d.montant),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
