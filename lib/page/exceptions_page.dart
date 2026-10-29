import 'package:flutter/material.dart';
import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/association/association.dart';
import 'package:gestionyobs/modules/compte_comptable.dart';
import 'package:gestionyobs/dialog/compte_selecteur_dialog.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/modules/postes_comptables.dart';
import 'package:gestionyobs/security/utilisateur.dart';

class _Element {
  final int id;
  final String nom;

  const _Element(this.id, this.nom);
}

class ExceptionsPage extends StatefulWidget {
  final PosteComptable poste;
  final String portee; // 'agence' ou 'classe'

  const ExceptionsPage({super.key, required this.poste, required this.portee});

  @override
  State<ExceptionsPage> createState() => _ExceptionsPageState();
}

class _ExceptionsPageState extends State<ExceptionsPage> {
  List<_Element> _elements = [];
  List<Association> _associations = []; // celles de ce poste seulement
  bool _chargement = true;
  String? _erreur;

  bool get _agence => widget.portee == 'agence';
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

  Association? _exception(int id) {
    for (final a in _associations) {
      if (a.portee == widget.portee && a.porteeId == id) return a;
    }
    return null;
  }

  Future<void> _charger() async {
    try {
      final elements = _agence
          ? (await DatabaseService.listerToutesLesAgences())
                .map((a) => _Element(a.id, a.nom))
                .toList()
          : (await DatabaseService.listerClasses())
                .map((c) => _Element(c.id, c.nom))
                .toList();
      final toutes = await DatabaseService.listerAssociations();
      if (!mounted) return;
      setState(() {
        _elements = elements;
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

  Future<void> _choisir(_Element element) async {
    try {
      final comptes = await DatabaseService.listerComptes();
      if (!mounted) return;

      final choix = await showDialog<CompteComptable>(
        context: context,
        builder: (_) => CompteSelecteurDialog(
          titre: '${widget.poste.libelle} - ${element.nom}',
          comptes: comptes,
          propositions: widget.poste.propositions,
        ),
      );
      if (choix == null) return;

      await DatabaseService.definirAssociation(
        poste: widget.poste.code,
        compteId: choix.id,
        portee: widget.portee,
        porteeId: element.id,
      );
      await _charger();
    } catch (e) {
      if (!mounted) return;
      _message(_nettoyer(e));
    }
  }

  Future<void> _retirer(_Element element) async {
    try {
      await DatabaseService.supprimerAssociation(
        poste: widget.poste.code,
        portee: widget.portee,
        porteeId: element.id,
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
        appBar: AppBar(title: const Text('Comptes particuliers')),
        body: const AccesRefuse(),
      );
    }

    final defaut = _defaut;
    final par = _agence ? 'agence' : "classe d'articles";

    return Scaffold(
      appBar: AppBar(title: Text('${widget.poste.libelle} : par $par')),
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
                    Text(
                      _agence
                          ? 'Une agence sans compte particulier utilise le compte par défaut.'
                          : 'Une classe sans compte particulier utilise le compte par défaut.',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    if (_elements.isEmpty)
                      Text(
                        _agence ? 'Aucune agence' : "Aucune classe d'articles",
                      ),
                    for (final element in _elements)
                      Card(
                        child: ListTile(
                          leading: Icon(
                            _agence ? Icons.store : Icons.category,
                            color: Colors.green,
                          ),
                          title: Text(element.nom),
                          subtitle: Text(
                            _exception(element.id) == null
                                ? 'Utilise le compte par défaut'
                                : 'Compte : ${_exception(element.id)!.numero}  '
                                      '${_exception(element.id)!.intitule}',
                          ),
                          trailing: _peutGerer
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      tooltip: 'Choisir un compte',
                                      onPressed: () => _choisir(element),
                                    ),
                                    if (_exception(element.id) != null)
                                      IconButton(
                                        icon: const Icon(Icons.link_off),
                                        tooltip: 'Revenir au compte par défaut',
                                        onPressed: () => _retirer(element),
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
