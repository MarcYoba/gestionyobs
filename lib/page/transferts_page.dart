import 'package:flutter/material.dart';
import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/modules/achat.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/modules/transfert.dart';
import 'package:gestionyobs/page/transfert_detail_page.dart';
import 'package:gestionyobs/form/transfert_form_page.dart';
import 'package:gestionyobs/security/utilisateur.dart';

class TransfertsPage extends StatefulWidget {
  const TransfertsPage({super.key});

  @override
  State<TransfertsPage> createState() => _TransfertsPageState();
}

class _TransfertsPageState extends State<TransfertsPage> {
  String _vue = 'demandes'; // 'demandes' ou 'a_traiter'
  String? _statut; // null = tous
  List<TransfertResume> _liste = [];
  Map<String, int> _compteurs = {};
  bool _chargement = true;
  String? _erreur;

  bool get _autorise =>
      Session.peut('transferts.voir') ||
      Session.peut('transferts.demander') ||
      Session.peut('transferts.valider') ||
      Session.peut('transferts.expedier') ||
      Session.peut('transferts.recevoir');
  bool get _peutDemander => Session.peut('transferts.demander');

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    if (!_autorise) {
      setState(() => _chargement = false);
      return;
    }
    try {
      final liste = await DatabaseService.listerTransferts(vue: _vue);
      final compteurs = await DatabaseService.compteursTransferts();
      if (!mounted) return;
      setState(() {
        _liste = liste;
        _compteurs = compteurs;
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

  Future<void> _ouvrir(TransfertResume t) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TransfertDetailPage(id: t.id)),
    );
    _charger();
  }

  Future<void> _nouvelleDemande() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TransfertFormPage()),
    );
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    final agence = Session.agenceCourante;

    if (!_autorise) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transferts')),
        body: const AccesRefuse(),
      );
    }

    final visibles = _statut == null
        ? _liste
        : _liste.where((t) => t.statut == _statut).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          agence == null ? 'Transferts' : 'Transferts - ${agence.nom}',
        ),
      ),
      floatingActionButton: (_peutDemander && _vue == 'demandes')
          ? FloatingActionButton.extended(
              onPressed: _nouvelleDemande,
              icon: const Icon(Icons.add),
              label: const Text('Nouvelle demande'),
            )
          : null,
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
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'demandes',
                          icon: Icon(Icons.call_made),
                          label: Text('Mes demandes'),
                        ),
                        ButtonSegment(
                          value: 'a_traiter',
                          icon: Icon(Icons.call_received),
                          label: Text('À traiter'),
                        ),
                      ],
                      selected: {_vue},
                      onSelectionChanged: (s) {
                        setState(() {
                          _vue = s.first;
                          _statut = null;
                        });
                        _charger();
                      },
                    ),
                    Text(
                      'À valider : ${_compteurs['avalider'] ?? 0}  ·  '
                      'À expédier : ${_compteurs['aexpedier'] ?? 0}  ·  '
                      'À réceptionner : ${_compteurs['areceptionner'] ?? 0}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: const Text('Tous'),
                        selected: _statut == null,
                        onSelected: (_) => setState(() => _statut = null),
                      ),
                      for (final e in statutsTransfert.entries)
                        ChoiceChip(
                          label: Text(e.value),
                          selected: _statut == e.key,
                          onSelected: (_) => setState(() => _statut = e.key),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
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
                    : visibles.isEmpty
                    ? const Center(child: Text('Aucun transfert'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                        itemCount: visibles.length,
                        itemBuilder: (context, index) {
                          final t = visibles[index];
                          final couleur = couleurStatutTransfert(t.statut);
                          return Card(
                            child: ListTile(
                              onTap: () => _ouvrir(t),
                              leading: Icon(
                                Icons.local_shipping,
                                color: couleur.shade700,
                              ),
                              title: Text(
                                '${t.code} · ${t.source} → ${t.demandeuse}',
                              ),
                              subtitle: Text(
                                '${formaterDate(t.demandeLe)} · ${t.nbLignes} article(s)',
                              ),
                              trailing: Chip(
                                label: Text(
                                  statutsTransfert[t.statut] ?? t.statut,
                                  style: TextStyle(
                                    color: couleur.shade800,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                backgroundColor: couleur.shade50,
                                side: BorderSide(color: couleur.shade200),
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
