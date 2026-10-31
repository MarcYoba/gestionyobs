import 'package:flutter/material.dart';
import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/association/association.dart';
import 'package:gestionyobs/modules/compte_comptable.dart';
import 'package:gestionyobs/dialog/compte_selecteur_dialog.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/modules/postes_comptables.dart';
import 'package:gestionyobs/security/utilisateur.dart';

class ExceptionsAgencePage extends StatefulWidget {
  final PosteComptable poste;

  const ExceptionsAgencePage({super.key, required this.poste});

  @override
  State<ExceptionsAgencePage> createState() => _ExceptionsAgencePageState();
}

class _ExceptionsAgencePageState extends State<ExceptionsAgencePage> {
  List<Agence> _agences = [];
  List<Association> _associations = []; // celles de ce poste seulement
  bool _chargement = true;
  String? _erreur;

  bool get _peutGerer => Session.peut('comptabilite.gerer');
  bool get _autorise => Session.peut('comptabilite.voir') || _peutGerer;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  String _nettoyer(Object e) => e.toString().replaceFirst('Exception: ', '');

  void _message(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  Association? get _defaut {
    for (final a in _associations) {
      if (a.portee == 'defaut') return a;
    }
    return null;
  }

  Association? _exception(int agenceId) {
    for (final a in _associations) {
      if (a.portee == 'agence' && a.porteeId == agenceId) return a;
    }
    return null;
  }

  Future<void> _charger() async {
    try {
      final agences = await DatabaseService.listerToutesLesAgences();
      final toutes = await DatabaseService.listerAssociations();
      if (!mounted) return;
      setState(() {
        _agences = agences;
        _associations = toutes
            .where((a) => a.poste == widget.poste.code)
            .toList();
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

  Future<void> _choisir(Agence agence) async {
    try {
      final comptes = await DatabaseService.listerComptes();
      if (!mounted) return;

      final choix = await showDialog<CompteComptable>(
        context: context,
        builder: (_) => CompteSelecteurDialog(
          titre: '${widget.poste.libelle} - ${agence.nom}',
          comptes: comptes,
          propositions: widget.poste.propositions,
        ),
      );
      if (choix == null) return;

      await DatabaseService.definirAssociation(
        poste: widget.poste.code,
        compteId: choix.id,
        portee: 'agence',
        porteeId: agence.id,
      );
      await _charger();
    } catch (e) {
      if (!mounted) return;
      _message(_nettoyer(e));
    }
  }

  Future<void> _retirer(Agence agence) async {
    try {
      await DatabaseService.supprimerAssociation(
        poste: widget.poste.code,
        portee: 'agence',
        porteeId: agence.id,
      );
      await _charger();
    } catch (e) {
      if (!mounted) return;
      _message(_nettoyer(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_autorise) {
      return Scaffold(
        appBar: AppBar(title: const Text('Compte par agence')),
        body: const AccesRefuse(),
      );
    }

    final defaut = _defaut;

    return Scaffold(
      appBar: AppBar(title: Text('${widget.poste.libelle} : par agence')),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _erreur != null
          ? Center(
              child: Text(_erreur!, style: const TextStyle(color: Colors.red)),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      defaut == null
                          ? 'Compte par défaut : aucun'
                          : 'Compte par défaut : ${defaut.numero}  ${defaut.intitule}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Une agence sans compte particulier utilise le compte par défaut.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    if (_agences.isEmpty) const Text('Aucune agence'),
                    for (final agence in _agences)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.store, color: Colors.green),
                          title: Text(agence.nom),
                          subtitle: Text(
                            _exception(agence.id) == null
                                ? 'Utilise le compte par défaut'
                                : 'Compte : ${_exception(agence.id)!.numero}  '
                                      '${_exception(agence.id)!.intitule}',
                          ),
                          trailing: _peutGerer
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      tooltip:
                                          'Choisir un compte pour cette agence',
                                      onPressed: () => _choisir(agence),
                                    ),
                                    if (_exception(agence.id) != null)
                                      IconButton(
                                        icon: const Icon(Icons.link_off),
                                        tooltip: 'Revenir au compte par défaut',
                                        onPressed: () => _retirer(agence),
                                      ),
                                  ],
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
