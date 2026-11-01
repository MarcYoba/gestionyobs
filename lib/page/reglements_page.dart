import 'package:flutter/material.dart';
import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/modules/achat.dart';
import 'package:gestionyobs/modules/article.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/modules/reglement.dart';

import 'reglement_detail_page.dart';

import 'package:gestionyobs/form/reglement_form_page.dart';
import 'package:gestionyobs/security/utilisateur.dart';

class ReglementsPage extends StatefulWidget {
  const ReglementsPage({super.key});

  @override
  State<ReglementsPage> createState() => _ReglementsPageState();
}

class _ReglementsPageState extends State<ReglementsPage> {
  final _rechercheController = TextEditingController();
  String _type = 'client'; // 'client' ou 'fournisseur'
  String _vue = 'soldes'; // 'soldes' ou 'historique'
  List<SoldeTiers> _soldes = [];
  List<ReglementResume> _historique = [];
  bool _chargement = true;
  String? _erreur;

  bool _peutVoir(String type) =>
      Session.peut('reglements.voir') ||
      Session.peut(
        type == 'client' ? 'reglements.clients' : 'reglements.fournisseurs',
      );

  bool _peutCreer(String type) => Session.peut(
    type == 'client' ? 'reglements.clients' : 'reglements.fournisseurs',
  );

  List<String> get _types =>
      ['client', 'fournisseur'].where((t) => _peutVoir(t)).toList();

  @override
  void initState() {
    super.initState();
    final types = _types;
    if (types.isNotEmpty) _type = types.first;
    _charger();
  }

  @override
  void dispose() {
    _rechercheController.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    if (_types.isEmpty) {
      setState(() => _chargement = false);
      return;
    }
    setState(() => _chargement = true);
    try {
      if (_vue == 'soldes') {
        final liste = await DatabaseService.listerSoldes(_type);
        if (!mounted) return;
        setState(() {
          _soldes = liste;
          _erreur = null;
          _chargement = false;
        });
      } else {
        final liste = await DatabaseService.listerReglements(_type);
        if (!mounted) return;
        setState(() {
          _historique = liste;
          _erreur = null;
          _chargement = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _ouvrirFormulaire(SoldeTiers s) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ReglementFormPage(type: _type, tiersId: s.tiersId, tiersNom: s.nom),
      ),
    );
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    final agence = Session.agenceCourante;
    final types = _types;

    if (types.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Règlements')),
        body: const AccesRefuse(),
      );
    }

    final client = _type == 'client';
    final texte = _rechercheController.text.trim().toLowerCase();

    final soldes = _soldes
        .where(
          (s) =>
              texte.isEmpty ||
              s.nom.toLowerCase().contains(texte) ||
              s.code.contains(texte) ||
              (s.telephone ?? '').contains(texte),
        )
        .toList();
    final historique = _historique
        .where(
          (r) =>
              texte.isEmpty ||
              r.tiers.toLowerCase().contains(texte) ||
              r.code.contains(texte),
        )
        .toList();
    final totalDu = _soldes.fold(0, (somme, s) => somme + s.du);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          agence == null ? 'Règlements' : 'Règlements - ${agence.nom}',
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 950),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    if (types.length > 1)
                      SegmentedButton<String>(
                        segments: [
                          for (final t in types)
                            ButtonSegment(
                              value: t,
                              label: Text(
                                t == 'client' ? 'Clients' : 'Fournisseurs',
                              ),
                            ),
                        ],
                        selected: {_type},
                        onSelectionChanged: (s) {
                          setState(() => _type = s.first);
                          _charger();
                        },
                      ),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'soldes', label: Text('À régler')),
                        ButtonSegment(
                          value: 'historique',
                          label: Text('Historique'),
                        ),
                      ],
                      selected: {_vue},
                      onSelectionChanged: (s) {
                        setState(() => _vue = s.first);
                        _charger();
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _rechercheController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: client
                        ? 'Rechercher un client'
                        : 'Rechercher un fournisseur',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              if (_vue == 'soldes')
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      client
                          ? 'Total dû par les clients : ${formaterPrix(totalDu)}'
                          : 'Total dû aux fournisseurs : ${formaterPrix(totalDu)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
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
                    : _vue == 'soldes'
                    ? _listeSoldes(soldes, client)
                    : _listeHistorique(historique),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _listeSoldes(List<SoldeTiers> soldes, bool client) {
    if (soldes.isEmpty) {
      return Center(
        child: Text(
          client ? 'Aucun client ne doit rien' : 'Aucune dette fournisseur',
        ),
      );
    }

    final peutCreer = _peutCreer(_type);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: soldes.length,
      itemBuilder: (context, index) {
        final s = soldes[index];
        return Card(
          child: ListTile(
            onTap: peutCreer ? () => _ouvrirFormulaire(s) : null,
            leading: const Icon(Icons.person, color: Colors.green),
            title: Text(s.nom),
            subtitle: Text(
              [
                s.code,
                '${s.nbDocuments} facture(s) à régler',
                if (s.telephone != null) s.telephone!,
              ].join(' · '),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formaterPrix(s.du),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.orange.shade800,
                  ),
                ),
                if (peutCreer)
                  const Text(
                    'Régler',
                    style: TextStyle(fontSize: 12, color: Colors.green),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _listeHistorique(List<ReglementResume> historique) {
    if (historique.isEmpty) {
      return const Center(child: Text('Aucun règlement'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: historique.length,
      itemBuilder: (context, index) {
        final r = historique[index];
        return Card(
          child: ListTile(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ReglementDetailPage(id: r.id)),
            ),
            leading: const Icon(Icons.receipt_long, color: Colors.green),
            title: Text('${r.code} · ${r.tiers}'),
            subtitle: Text('${formaterDate(r.date)} · ${r.utilisateur}'),
            trailing: Text(
              formaterPrix(r.montant),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        );
      },
    );
  }
}
