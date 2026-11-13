import 'package:flutter/material.dart';

import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/comptabilite/etats_financiers.dart';
import 'package:gestionyobs/security/utilisateur.dart';

class ReglesEtatsPage extends StatefulWidget {
  const ReglesEtatsPage({super.key});

  @override
  State<ReglesEtatsPage> createState() => _ReglesEtatsPageState();
}

class _ReglesEtatsPageState extends State<ReglesEtatsPage> {
  Map<String, String> _perso = {};
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

  Future<void> _charger() async {
    if (!_autorise) {
      setState(() => _chargement = false);
      return;
    }
    try {
      final p = await DatabaseService.lireFormulesEtats();
      if (!mounted) return;
      setState(() {
        _perso = p;
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

  // La formule en vigueur : la tienne, ou celle d'origine
  String _formule(String etat, LigneEtat l, String colonne) =>
      _perso['$etat|${l.ref}|$colonne'] ??
      (colonne == 'amort' ? l.formuleAmort : l.formule) ??
      '';

  bool _personnalisee(String etat, LigneEtat l) =>
      _perso.keys.any((k) => k.startsWith('$etat|${l.ref}|'));

  String _colonneValeur(String etat) => etat == 'actif' ? 'brut' : 'net';

  Future<void> _modifier(String etat, LigneEtat l) async {
    final r = await showDialog<_ResultatFormule>(
      context: context,
      builder: (_) => _FormuleDialog(
        titre: '${l.ref}  ${l.libelle}',
        etat: etat,
        formule: _formule(etat, l, _colonneValeur(etat)),
        formuleAmort: l.formuleAmort == null
            ? null
            : _formule(etat, l, 'amort'),
        defaut: l.formule,
        defautAmort: l.formuleAmort,
      ),
    );
    if (r == null) return;

    try {
      if (r.retablir) {
        await DatabaseService.retablirFormuleEtat(etat, l.ref);
      } else {
        await DatabaseService.enregistrerFormuleEtat(
          etat: etat,
          ref: l.ref,
          colonne: _colonneValeur(etat),
          formule: r.valeur,
        );
        if (r.amort != null) {
          await DatabaseService.enregistrerFormuleEtat(
            etat: etat,
            ref: l.ref,
            colonne: 'amort',
            formule: r.amort!,
          );
        }
      }
      await _charger();
    } catch (e) {
      if (!mounted) return;
      _message(_nettoyer(e));
    }
  }

  Widget _section(String etat) {
    final lignes = lignesDeEtat(etat);
    final nbPerso = lignes.where((l) => _personnalisee(etat, l)).length;

    return Card(
      child: ExpansionTile(
        title: Text(
          nomsEtats[etat]!,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          nbPerso == 0 ? 'Règles d\'origine' : '$nbPerso ligne(s) modifiée(s)',
        ),
        children: [
          for (final l in lignes)
            ListTile(
              dense: true,
              title: Text(
                '${l.ref}  ${l.libelle}',
                style: TextStyle(
                  fontWeight: l.total ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                etat == 'actif'
                    ? 'Brut : ${_formule(etat, l, 'brut')}'
                          '${l.formuleAmort == null ? '' : '\nAmort. : ${_formule(etat, l, 'amort')}'}'
                    : _formule(etat, l, 'net'),
                style: const TextStyle(fontFamily: 'Consolas', fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_personnalisee(etat, l))
                    const Tooltip(
                      message: 'Règle modifiée',
                      child: Icon(Icons.edit_note, color: Colors.orange),
                    ),
                  if (_peutGerer)
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Modifier la règle',
                      onPressed: () => _modifier(etat, l),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_autorise) {
      return Scaffold(
        appBar: AppBar(title: const Text('Règles de calcul')),
        body: const AccesRefuse(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Règles de calcul des états')),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _erreur != null
          ? Center(
              child: Text(_erreur!, style: const TextStyle(color: Colors.red)),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Comment lire une règle',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'SD(211,212) : soldes débiteurs des comptes qui commencent par 211 ou 212.\n'
                              'SC(2811) : soldes créditeurs.\n'
                              '{AE}+{AF} : valeur d\'autres lignes (par leur repère).\n'
                              'RESULTAT : le résultat net de l\'exercice. '
                              'RESULTAT_ANT : le résultat des exercices précédents non affectés.\n'
                              'Chaque compte est jugé séparément : un compte en débit n\'est '
                              'jamais compté dans un SC, et inversement.\n'
                              'Dans le compte de résultat, les charges sont en négatif '
                              '(-SD(...)), les produits en positif (SC(...)).',
                              style: TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _section('actif'),
                    _section('passif'),
                    _section('resultat'),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ResultatFormule {
  final String valeur;
  final String? amort;
  final bool retablir;

  const _ResultatFormule({
    required this.valeur,
    this.amort,
    this.retablir = false,
  });
}

class _FormuleDialog extends StatefulWidget {
  final String titre;
  final String etat;
  final String formule;
  final String? formuleAmort;
  final String defaut;
  final String? defautAmort;

  const _FormuleDialog({
    required this.titre,
    required this.etat,
    required this.formule,
    required this.formuleAmort,
    required this.defaut,
    required this.defautAmort,
  });

  @override
  State<_FormuleDialog> createState() => _FormuleDialogState();
}

class _FormuleDialogState extends State<_FormuleDialog> {
  late final TextEditingController _valeur;
  late final TextEditingController _amort;

  @override
  void initState() {
    super.initState();
    _valeur = TextEditingController(text: widget.formule);
    _amort = TextEditingController(text: widget.formuleAmort ?? '');
  }

  @override
  void dispose() {
    _valeur.dispose();
    _amort.dispose();
    super.dispose();
  }

  String? get _erreurValeur => validerFormule(_valeur.text);
  String? get _erreurAmort => widget.formuleAmort == null
      ? null
      : validerFormule(_amort.text, videAutorise: true);

  @override
  Widget build(BuildContext context) {
    final valide = _erreurValeur == null && _erreurAmort == null;

    return AlertDialog(
      title: Text(widget.titre),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _valeur,
                maxLines: 3,
                minLines: 1,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontFamily: 'Consolas'),
                decoration: InputDecoration(
                  labelText: widget.etat == 'actif'
                      ? 'Colonne Brut (soldes débiteurs)'
                      : 'Formule',
                  errorText: _erreurValeur,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (widget.formuleAmort != null) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _amort,
                  maxLines: 3,
                  minLines: 1,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontFamily: 'Consolas'),
                  decoration: InputDecoration(
                    labelText:
                        'Colonne Amort. et dépréciations (soldes créditeurs)',
                    helperText: 'Vide = aucun amortissement pour cette ligne',
                    errorText: _erreurAmort,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                "Règle d'origine : ${widget.defaut}"
                "${widget.defautAmort == null ? '' : '\nAmort. : ${widget.defautAmort}'}",
                style: const TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            const _ResultatFormule(valeur: '', retablir: true),
          ),
          child: const Text("Revenir à la règle d'origine"),
        ),
        FilledButton(
          onPressed: valide
              ? () => Navigator.pop(
                  context,
                  _ResultatFormule(
                    valeur: _valeur.text,
                    amort: widget.formuleAmort == null ? null : _amort.text,
                  ),
                )
              : null,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
