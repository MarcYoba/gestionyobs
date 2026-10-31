import 'package:flutter/material.dart';
import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/association/association.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/modules/postes_comptables.dart';
import 'package:gestionyobs/modules/stock.dart';
import 'package:gestionyobs/security/utilisateur.dart';

class HistoriqueAssociationsPage extends StatefulWidget {
  const HistoriqueAssociationsPage({super.key});

  @override
  State<HistoriqueAssociationsPage> createState() =>
      _HistoriqueAssociationsPageState();
}

class _HistoriqueAssociationsPageState
    extends State<HistoriqueAssociationsPage> {
  List<HistoriqueAssociation> _lignes = [];
  Map<String, String> _libelles = {};
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final lignes = await DatabaseService.listerHistorique();
      final postes = await DatabaseService.listerPostes();
      if (!mounted) return;
      setState(() {
        _lignes = lignes;
        _libelles = {for (final p in postes) p.code: p.libelle};
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final autorise =
        Session.peut('comptabilite.voir') || Session.peut('comptabilite.gerer');

    return Scaffold(
      appBar: AppBar(title: const Text('Historique des associations')),
      body: !autorise
          ? const AccesRefuse()
          : _chargement
          ? const Center(child: CircularProgressIndicator())
          : _erreur != null
          ? Center(
              child: Text(_erreur!, style: const TextStyle(color: Colors.red)),
            )
          : _lignes.isEmpty
          ? const Center(child: Text('Aucune modification'))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _lignes.length,
                  itemBuilder: (context, index) {
                    final h = _lignes[index];
                    final poste = _libelles[h.poste] ?? h.poste;
                    final portee = switch (h.portee) {
                      'agence' => ' (agence ${h.agenceNom ?? '?'})',
                      'classe' => ' (classe ${h.classeNom ?? '?'})',
                      _ => '',
                    };

                    return Card(
                      child: ListTile(
                        isThreeLine: true,
                        leading: const Icon(Icons.history),
                        title: Text('$poste$portee'),
                        subtitle: Text(
                          '${formaterDateHeure(h.date)} · ${h.utilisateur}\n'
                          '${h.ancienCompte ?? '(aucun compte)'}  →  '
                          '${h.nouveauCompte ?? '(association retirée)'}',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }
}
