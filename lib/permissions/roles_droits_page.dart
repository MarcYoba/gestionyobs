import 'package:flutter/material.dart';

import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/security/role.dart';

class RolesDroitsPage extends StatefulWidget {
  const RolesDroitsPage({super.key});

  @override
  State<RolesDroitsPage> createState() => _RolesDroitsPageState();
}

class _RolesDroitsPageState extends State<RolesDroitsPage> {
  List<Role> _roles = [];
  List<Permission> _permissions = [];
  Set<String> _accordes = {};
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  String _cle(String role, String permission) => '$role|$permission';

  String _nettoyer(Object e) => e.toString().replaceFirst('Exception: ', '');

  void _message(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  Future<void> _charger() async {
    try {
      final roles = await DatabaseService.listerRoles();
      final permissions = await DatabaseService.listerPermissions();
      final accordes = await DatabaseService.droitsAccordes();
      if (!mounted) return;
      setState(() {
        _roles = roles;
        _permissions = permissions;
        _accordes = accordes;
        _chargement = false;
        _erreur = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = 'Erreur : $e';
      });
    }
  }

  // Coche ou décoche un droit : enregistré tout de suite
  Future<void> _basculer(Role role, Permission permission, bool accorde) async {
    try {
      await DatabaseService.definirDroit(role.code, permission.code, accorde);
      if (!mounted) return;
      setState(() {
        final cle = _cle(role.code, permission.code);
        if (accorde) {
          _accordes.add(cle);
        } else {
          _accordes.remove(cle);
        }
      });
    } catch (e) {
      if (!mounted) return;
      _message(_nettoyer(e));
    }
  }

  Future<void> _nouveauRole() async {
    final nom = await showDialog<String>(
      context: context,
      builder: (_) => const _NomRoleDialog(titre: 'Nouveau rôle'),
    );
    if (nom == null) return;

    try {
      await DatabaseService.creerRole(nom);
      await _charger();
      if (!mounted) return;
      _message('Rôle créé : cochez maintenant ses droits dans la grille');
    } catch (e) {
      if (!mounted) return;
      _message(_nettoyer(e));
    }
  }

  Future<void> _renommer(Role role) async {
    final nom = await showDialog<String>(
      context: context,
      builder: (_) => _NomRoleDialog(
        titre: 'Renommer le rôle',
        valeurInitiale: role.libelle,
      ),
    );
    if (nom == null || nom == role.libelle) return;

    try {
      await DatabaseService.renommerRole(role.code, nom);
      await _charger();
    } catch (e) {
      if (!mounted) return;
      _message(_nettoyer(e));
    }
  }

  Future<void> _supprimer(Role role) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer le rôle ?'),
        content: Text(
          'Le rôle « ${role.libelle} » et ses droits seront supprimés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    try {
      await DatabaseService.supprimerRole(role.code);
      await _charger();
    } catch (e) {
      if (!mounted) return;
      _message(_nettoyer(e));
    }
  }

  // ---------- Affichage ----------

  Widget _carteRoles() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Rôles',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _nouveauRole,
                  icon: const Icon(Icons.add),
                  label: const Text('Nouveau rôle'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._roles.map(
              (r) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  r.systeme ? Icons.lock : Icons.badge,
                  color: Colors.green,
                ),
                title: Text(r.libelle),
                subtitle: Text(
                  r.systeme
                      ? 'Rôle système : tous les droits, non modifiable'
                      : '${r.nbUtilisateurs} utilisateur(s)',
                ),
                trailing: r.systeme
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            tooltip: 'Renommer',
                            onPressed: () => _renommer(r),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            tooltip: 'Supprimer',
                            onPressed: () => _supprimer(r),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _carteGroupe(
    String groupe,
    List<Permission> permissions,
    List<Role> roles,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Table(
          columnWidths: <int, TableColumnWidth>{
            0: const FlexColumnWidth(),
            for (var i = 0; i < roles.length; i++)
              i + 1: const FixedColumnWidth(110),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            // Ligne d'en-tête : nom du groupe et nom des rôles
            TableRow(
              children: [
                Text(
                  groupe,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                for (final r in roles)
                  Center(
                    child: Text(
                      r.libelle,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            // Une ligne par fonction, une case par rôle
            for (final p in permissions)
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(p.libelle),
                  ),
                  for (final r in roles)
                    Center(
                      child: Checkbox(
                        value: _accordes.contains(_cle(r.code, p.code)),
                        onChanged: (v) => _basculer(r, p, v ?? false),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _grille() {
    final roles = _roles.where((r) => !r.systeme).toList();
    final permissions = _permissions.where((p) => !p.adminSeulement).toList();

    if (roles.isEmpty) {
      return const Text("Créez d'abord un rôle pour régler ses droits.");
    }

    // Regroupe les fonctions par groupe, dans l'ordre du catalogue
    final groupes = <String, List<Permission>>{};
    for (final p in permissions) {
      groupes.putIfAbsent(p.groupe, () => []).add(p);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 320.0 + 110.0 * roles.length,
        child: Column(
          children: groupes.entries
              .map((g) => _carteGroupe(g.key, g.value, roles))
              .toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rôles et droits')),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _erreur != null
          ? Center(
              child: Text(_erreur!, style: const TextStyle(color: Colors.red)),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _carteRoles(),
                        const SizedBox(height: 24),
                        const Text(
                          'Droits de chaque rôle',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Chaque case est enregistrée dès que vous la cochez. "
                          "L'administrateur a toujours tous les droits.",
                        ),
                        const SizedBox(height: 12),
                        _grille(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Boîte de dialogue : saisie du nom d'un rôle.
class _NomRoleDialog extends StatefulWidget {
  final String titre;
  final String valeurInitiale;

  const _NomRoleDialog({required this.titre, this.valeurInitiale = ''});

  @override
  State<_NomRoleDialog> createState() => _NomRoleDialogState();
}

class _NomRoleDialogState extends State<_NomRoleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.valeurInitiale);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _valider() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, _controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titre),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _controller,
            autofocus: true,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: 'Nom du rôle (ex. Caissier)',
              border: OutlineInputBorder(),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Veuillez saisir un nom'
                : null,
            onFieldSubmitted: (_) => _valider(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _valider, child: const Text('Enregistrer')),
      ],
    );
  }
}
