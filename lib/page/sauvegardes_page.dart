import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/service/backup_service.dart';
import 'package:gestionyobs/config_service.dart';
import 'package:gestionyobs/app/messages_app.dart';
import 'package:gestionyobs/startup_page.dart';
import 'package:gestionyobs/modules/stock.dart';
import 'package:gestionyobs/security/utilisateur.dart';

class SauvegardesPage extends StatefulWidget {
  const SauvegardesPage({super.key});

  @override
  State<SauvegardesPage> createState() => _SauvegardesPageState();
}

class _SauvegardesPageState extends State<SauvegardesPage> {
  static const _intervalles = [1, 2, 4, 8, 12, 24];
  static const _nombres = [5, 10, 20, 40, 60, 100, 200];

  final _dossierController = TextEditingController();
  final _dossier2Controller = TextEditingController();

  AppConfig? _config;
  List<FichierSauvegarde> _fichiers = [];
  bool _chargement = true;
  bool _occupe = false;
  bool _auto = true;
  bool _fermeture = true;
  int _intervalle = 12;
  int _conservees = 60;
  String? _message;
  bool _messageErreur = false;

  bool get _autorise => Session.peut('sauvegardes.gerer');

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _dossierController.dispose();
    _dossier2Controller.dispose();
    super.dispose();
  }

  String _nettoyer(Object e) => e.toString().replaceFirst('Exception: ', '');

  void _afficher(String texte, {bool erreur = false}) {
    setState(() {
      _message = texte;
      _messageErreur = erreur;
    });
  }

  Future<void> _charger() async {
    final config = await ConfigService.lire();
    var fichiers = <FichierSauvegarde>[];
    if (config != null) {
      try {
        fichiers = await BackupService.lister(config.dossierSauvegarde);
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _config = config;
      _fichiers = fichiers;
      _auto = config?.sauvegardeAuto ?? true;
      _fermeture = config?.sauvegardeFermeture ?? true;
      _intervalle = config?.sauvegardeIntervalleHeures ?? 12;
      _conservees = config?.sauvegardesConservees ?? 60;
      _dossierController.text = config?.dossierSauvegarde ?? '';
      _dossier2Controller.text = config?.dossierSauvegarde2 ?? '';
      _chargement = false;
    });
  }

  Future<bool> _enregistrer({bool silencieux = false}) async {
    final dossier = _dossierController.text.trim();
    if (dossier.isEmpty) {
      _afficher('Indiquez le dossier des sauvegardes', erreur: true);
      return false;
    }

    try {
      final base = await ConfigService.lire(); // la version la plus récente
      if (base == null) return false;
      final dossier2 = _dossier2Controller.text.trim();

      await ConfigService.ecrire(
        base.copyWith(
          dossierSauvegarde: dossier,
          dossierSauvegarde2: dossier2.isEmpty ? null : dossier2,
          effacerDossier2: dossier2.isEmpty,
          sauvegardeAuto: _auto,
          sauvegardeFermeture: _fermeture,
          sauvegardeIntervalleHeures: _intervalle,
          sauvegardesConservees: _conservees,
        ),
      );

      if (!silencieux) _afficher('Réglages enregistrés');
      await _charger();
      return true;
    } catch (e) {
      _afficher(_nettoyer(e), erreur: true);
      return false;
    }
  }

  Future<void> _sauvegarderMaintenant() async {
    if (!await _enregistrer(silencieux: true)) return;

    setState(() {
      _occupe = true;
      _message = null;
    });
    try {
      final r = await BackupService.sauvegarder(type: 'manuelle');
      if (!mounted) return;
      _afficher(
        'Sauvegarde créée : ${r.fichier.nom} (${formaterTaille(r.fichier.taille)})'
        '${r.avertissement == null ? '' : '\n${r.avertissement}'}',
        erreur: r.avertissement != null,
      );
      await _charger();
    } catch (e) {
      if (!mounted) return;
      _afficher(_nettoyer(e), erreur: true);
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _choisirDossier(TextEditingController controleur) async {
    final dossier = await FilePicker.getDirectoryPath();
    if (dossier != null) setState(() => controleur.text = dossier);
  }

  Future<void> _restaurer(FichierSauvegarde f) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmationRestauration(fichier: f),
    );
    if (confirme != true || !mounted) return;

    setState(() => _occupe = true);

    String? erreur;
    try {
      await BackupService.restaurer(f.chemin);
    } catch (e) {
      erreur = _nettoyer(e);
    }
    if (!mounted) return;

    // Dans tous les cas, on repart du démarrage : il rouvre la base
    Session.deconnecter();
    MessagesApp.afficher(
      erreur ??
          'Base restaurée depuis la sauvegarde du ${formaterDateHeure(f.date)}',
    );
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const StartupPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_autorise) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sauvegardes')),
        body: const AccesRefuse(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sauvegardes')),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _carteStatut(),
                    const SizedBox(height: 12),
                    _carteReglages(),
                    const SizedBox(height: 12),
                    _carteListe(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _carteStatut() {
    final derniere = _config?.derniereSauvegarde == null
        ? null
        : DateTime.tryParse(_config!.derniereSauvegarde!);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              derniere == null
                  ? 'Aucune sauvegarde enregistrée'
                  : 'Dernière sauvegarde : ${formaterDateHeure(derniere)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: derniere == null ? Colors.red : Colors.green.shade800,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _occupe ? null : _sauvegarderMaintenant,
              icon: _occupe
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.backup),
              label: const Text('Sauvegarder maintenant'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 8),
              Text(
                _message!,
                style: TextStyle(
                  color: _messageErreur ? Colors.red : Colors.green.shade800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _carteReglages() {
    final intervalles = _intervalles.contains(_intervalle)
        ? _intervalles
        : [..._intervalles, _intervalle];
    final nombres = _nombres.contains(_conservees)
        ? _nombres
        : [..._nombres, _conservees];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Réglages de ce poste',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sauvegardes automatiques'),
              subtitle: const Text(
                'Au démarrage et pendant que le logiciel est ouvert',
              ),
              value: _auto,
              onChanged: (v) => setState(() => _auto = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sauvegarder aussi à la fermeture du logiciel'),
              value: _fermeture,
              onChanged: (v) => setState(() => _fermeture = v),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _intervalle,
                    decoration: const InputDecoration(
                      labelText: 'Sauvegarder toutes les',
                      border: OutlineInputBorder(),
                    ),
                    items: intervalles
                        .map(
                          (h) => DropdownMenuItem(
                            value: h,
                            child: Text(h == 1 ? '1 heure' : '$h heures'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _intervalle = v ?? 12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _conservees,
                    decoration: const InputDecoration(
                      labelText: 'Sauvegardes conservées',
                      border: OutlineInputBorder(),
                    ),
                    items: nombres
                        .map(
                          (n) => DropdownMenuItem(value: n, child: Text('$n')),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _conservees = v ?? 60),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dossierController,
                    decoration: const InputDecoration(
                      labelText: 'Dossier des sauvegardes',
                      prefixIcon: Icon(Icons.folder),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.folder_open),
                  tooltip: 'Choisir un dossier',
                  onPressed: () => _choisirDossier(_dossierController),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dossier2Controller,
                    decoration: const InputDecoration(
                      labelText: 'Second emplacement (clé USB, autre disque) : facultatif',
                      prefixIcon: Icon(Icons.usb),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.folder_open),
                  tooltip: 'Choisir un dossier',
                  onPressed: () => _choisirDossier(_dossier2Controller),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _occupe ? null : () => _enregistrer(),
              icon: const Icon(Icons.save),
              label: const Text('Enregistrer les réglages'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _carteListe() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sauvegardes disponibles (${_fichiers.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_fichiers.isEmpty)
              const Text('Aucune sauvegarde dans ce dossier.'),
            for (final f in _fichiers)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  f.type == 'auto' ? Icons.schedule : Icons.touch_app,
                  color: Colors.green,
                ),
                title: Text(formaterDateHeure(f.date)),
                subtitle: Text(
                  '${f.libelleType} · ${formaterTaille(f.taille)}',
                ),
                trailing: TextButton(
                  onPressed: _occupe ? null : () => _restaurer(f),
                  child: const Text('Restaurer'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Confirmation forte : il faut taper RESTAURER.
class _ConfirmationRestauration extends StatefulWidget {
  final FichierSauvegarde fichier;

  const _ConfirmationRestauration({required this.fichier});

  @override
  State<_ConfirmationRestauration> createState() =>
      _ConfirmationRestaurationState();
}

class _ConfirmationRestaurationState extends State<_ConfirmationRestauration> {
  final _controller = TextEditingController();

  bool get _valide => _controller.text.trim().toUpperCase() == 'RESTAURER';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.fichier;

    return AlertDialog(
      title: const Text('Restaurer cette sauvegarde ?'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sauvegarde du ${formaterDateHeure(f.date)} '
              '(${f.libelleType}, ${formaterTaille(f.taille)}).',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tout ce qui a été enregistré APRÈS cette date sera perdu : '
              'ventes, achats, règlements, mouvements de stock...',
              style: TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 8),
            const Text(
              'Une copie de la base actuelle est faite juste avant. Elle apparaîtra '
              'dans la liste sous « Avant restauration » : vous pourrez revenir en arrière.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Pour confirmer, tapez RESTAURER',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: _valide ? () => Navigator.pop(context, true) : null,
          child: const Text('Restaurer'),
        ),
      ],
    );
  }
}
