import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gestionyobs/modules/article.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/app/messages_app.dart';
import 'package:gestionyobs/modules/tiers.dart';

/// Boîte de dialogue : chercher un client, ou en créer un nouveau.
/// Retourne le client choisi.
class ClientSelecteurDialog extends StatefulWidget {
  final bool creation; // ouvre directement le formulaire de nouveau client

  const ClientSelecteurDialog({super.key, this.creation = false});

  @override
  State<ClientSelecteurDialog> createState() => _ClientSelecteurDialogState();
}

class _ClientSelecteurDialogState extends State<ClientSelecteurDialog> {
  final _formKey = GlobalKey<FormState>();
  final _rechercheController = TextEditingController();
  final _nomController = TextEditingController();
  final _telephoneController = TextEditingController();

  late bool _creation;
  List<Tiers> _resultats = [];
  bool _chargement = true;
  bool _occupe = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _creation = widget.creation;
    _chercher();
  }

  @override
  void dispose() {
    _rechercheController.dispose();
    _nomController.dispose();
    _telephoneController.dispose();
    super.dispose();
  }

  String _nettoyer(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _chercher() async {
    try {
      final liste = await DatabaseService.rechercherClientsVente(
        _rechercheController.text,
      );
      if (!mounted) return;
      setState(() {
        _resultats = liste;
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

  // Passe au formulaire, en reprenant ce qui a été tapé dans la recherche :
  // des chiffres sont un téléphone, du texte est un nom
  void _ouvrirCreation() {
    final saisie = _rechercheController.text.trim();
    if (saisie.isNotEmpty) {
      if (RegExp(r'^[0-9+ ().-]+$').hasMatch(saisie)) {
        _telephoneController.text = saisie;
      } else {
        _nomController.text = saisie;
      }
    }
    setState(() {
      _creation = true;
      _erreur = null;
    });
  }

  Future<void> _creer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _occupe = true;
      _erreur = null;
    });
    try {
      final r = await DatabaseService.creerClientRapide(
        nom: _nomController.text,
        telephone: _telephoneController.text,
      );
      if (!mounted) return;
      if (r.existant) {
        MessagesApp.afficher(
          'Ce numéro appartient déjà à « ${r.client.nom} » : '
          'ce client a été sélectionné.',
        );
      }
      Navigator.pop(context, r.client);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _occupe = false;
        _erreur = _nettoyer(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_creation ? 'Nouveau client' : 'Choisir un client'),
      content: SizedBox(
        width: 560,
        height: _creation ? 330 : 460,
        child: _creation ? _formulaire() : _recherche(),
      ),
      actions: _creation
          ? [
              TextButton(
                onPressed: () {
                  if (widget.creation) {
                    Navigator.pop(context);
                  } else {
                    setState(() => _creation = false);
                  }
                },
                child: Text(widget.creation ? 'Annuler' : 'Retour'),
              ),
              FilledButton(
                onPressed: _occupe ? null : _creer,
                child: const Text('Créer et choisir'),
              ),
            ]
          : [
              TextButton.icon(
                onPressed: _ouvrirCreation,
                icon: const Icon(Icons.person_add),
                label: const Text('Nouveau client'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
            ],
    );
  }

  Widget _recherche() {
    return Column(
      children: [
        TextField(
          controller: _rechercheController,
          autofocus: true,
          onChanged: (_) => _chercher(),
          decoration: const InputDecoration(
            labelText: 'Rechercher (nom, téléphone, matricule)',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
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
              : _resultats.isEmpty
              ? const Center(
                  child: Text(
                    'Aucun client trouvé.\nUtilisez « Nouveau client ».',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  itemCount: _resultats.length,
                  itemBuilder: (context, index) {
                    final c = _resultats[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        c.systeme ? Icons.person_outline : Icons.person,
                        color: Colors.green,
                      ),
                      title: Text(c.nom),
                      subtitle: Text(
                        [
                          c.code,
                          if (c.telephone != null) c.telephone!,
                          if (c.ville != null) c.ville!,
                        ].join(' · '),
                      ),
                      trailing: c.plafondCredit > 0
                          ? Text(
                              'Crédit max : ${formaterPrix(c.plafondCredit)}',
                              style: const TextStyle(fontSize: 12),
                            )
                          : null,
                      onTap: () => Navigator.pop(context, c),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _formulaire() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _nomController,
            autofocus: true,
            maxLength: 60,
            decoration: const InputDecoration(
              labelText: 'Nom du client',
              prefixIcon: Icon(Icons.badge),
              border: OutlineInputBorder(),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Veuillez saisir le nom'
                : null,
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: _telephoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ().-]')),
            ],
            maxLength: 20,
            decoration: const InputDecoration(
              labelText: 'Téléphone (facultatif)',
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              final texte = (v ?? '').trim();
              if (texte.isEmpty) return null;
              return texte.replaceAll(RegExp(r'\D'), '').length < 6
                  ? 'Numéro trop court'
                  : null;
            },
          ),
          if (_erreur != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_erreur!, style: const TextStyle(color: Colors.red)),
            ),
          const Spacer(),
          const Text(
            'Ce client sera créé sans crédit autorisé. Un responsable pourra '
            'régler son plafond dans le module Clients.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
