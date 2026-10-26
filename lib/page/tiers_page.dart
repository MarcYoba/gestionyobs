import 'package:flutter/material.dart';
import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/modules/article.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/modules/tiers.dart';
import 'package:gestionyobs/form/tiers_form_page.dart';
import 'package:gestionyobs/security/utilisateur.dart';

class TiersPage extends StatefulWidget {
  final String type; // 'client' ou 'fournisseur'

  const TiersPage({super.key, required this.type});

  @override
  State<TiersPage> createState() => _TiersPageState();
}

class _TiersPageState extends State<TiersPage> {
  final _rechercheController = TextEditingController();
  List<Tiers> _liste = [];
  bool _chargement = true;
  bool _inclureInactifs = false;
  String? _erreur;

  bool get _client => widget.type == 'client';
  String get _titre => _client ? 'Clients' : 'Fournisseurs';
  bool get _peutGerer => Session.peut(droitTiers(widget.type, 'gerer'));

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
    try {
      final liste = await DatabaseService.listerTiers(
        type: widget.type,
        recherche: _rechercheController.text,
        inclureInactifs: _inclureInactifs,
      );
      if (!mounted) return;
      setState(() {
        _liste = liste;
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

  Future<void> _ouvrirFormulaire([Tiers? tiers]) async {
    final modifie = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TiersFormPage(type: widget.type, tiers: tiers),
      ),
    );
    if (modifie == true) _charger();
  }

  @override
  Widget build(BuildContext context) {
    if (!peutVoirTiers(widget.type)) {
      return Scaffold(
        appBar: AppBar(title: Text(_titre)),
        body: const AccesRefuse(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_titre)),
      floatingActionButton: _peutGerer
          ? FloatingActionButton.extended(
              onPressed: () => _ouvrirFormulaire(),
              icon: const Icon(Icons.add),
              label: Text(_client ? 'Nouveau client' : 'Nouveau fournisseur'),
            )
          : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _rechercheController,
                        onChanged: (_) => _charger(),
                        decoration: const InputDecoration(
                          labelText:
                              'Rechercher (matricule, nom, téléphone, ville)',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    if (_peutGerer) ...[
                      const SizedBox(width: 12),
                      FilterChip(
                        label: const Text('Afficher les désactivés'),
                        selected: _inclureInactifs,
                        onSelected: (v) {
                          setState(() => _inclureInactifs = v);
                          _charger();
                        },
                      ),
                    ],
                  ],
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
                    : _liste.isEmpty
                    ? const Center(child: Text('Aucun résultat'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                        itemCount: _liste.length,
                        itemBuilder: (context, index) {
                          final t = _liste[index];
                          final details = [
                            t.code,
                            if (t.telephone != null) t.telephone!,
                            if (t.ville != null) t.ville!,
                            if (t.estClient && t.estFournisseur)
                              _client ? 'Aussi fournisseur' : 'Aussi client',
                            if (t.systeme) 'Compte système',
                            if (!t.actif) 'Désactivé',
                          ].join(' · ');

                          return Card(
                            child: ListTile(
                              onTap: (_peutGerer && !t.systeme)
                                  ? () => _ouvrirFormulaire(t)
                                  : null,
                              leading: Icon(
                                t.systeme ? Icons.lock : Icons.person,
                                color: Colors.green,
                              ),
                              title: Text(
                                t.nom,
                                style: TextStyle(
                                  decoration: t.actif
                                      ? null
                                      : TextDecoration.lineThrough,
                                ),
                              ),
                              subtitle: Text(details),
                              trailing: (_client && t.plafondCredit > 0)
                                  ? Text(
                                      'Crédit max : ${formaterPrix(t.plafondCredit)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    )
                                  : null,
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
