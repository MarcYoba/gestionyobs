import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/config_service.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/service/ticket_service.dart';
import 'package:gestionyobs/security/utilisateur.dart';
import 'package:gestionyobs/modules/vente.dart';

class ImpressionPage extends StatefulWidget {
  const ImpressionPage({super.key});

  @override
  State<ImpressionPage> createState() => _ImpressionPageState();
}

class _ImpressionPageState extends State<ImpressionPage> {
  final _nomController = TextEditingController();
  final _infosController = TextEditingController();
  final _deviseController = TextEditingController();
  final _messageController = TextEditingController();

  AppConfig? _config;
  List<Printer> _imprimantes = [];
  int _largeur = 80;
  String? _imprimante;
  bool _auto = false;
  bool _reglages = false;

  bool _chargement = true;
  bool _occupe = false;
  String? _erreurImprimantes;

  bool get _peutGererEntreprise => Session.peut('parametres.gerer');
  bool get _autorise =>
      Session.peut('ventes.creer') ||
      Session.peut('ventes.voir') ||
      _peutGererEntreprise;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _nomController.dispose();
    _infosController.dispose();
    _deviseController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _message(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  String _nettoyer(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _charger() async {
    final config = await ConfigService.lire();
    final infos = await DatabaseService.lireInfosEntreprise();

    List<Printer> imprimantes = [];
    String? erreur;
    try {
      imprimantes = await TicketService.listerImprimantes();
    } catch (e) {
      erreur = "Impossible de lister les imprimantes : ${_nettoyer(e)}";
    }

    if (!mounted) return;
    setState(() {
      _config = config;
      _imprimantes = imprimantes;
      _erreurImprimantes = erreur;
      _largeur = config?.largeurPapier ?? 80;
      _imprimante = config?.imprimante;
      _auto = config?.impressionAuto ?? false;
      _reglages = config?.reglagesImprimante ?? false;
      _nomController.text = infos.nom;
      _infosController.text = infos.infos;
      _deviseController.text = infos.devise;
      _messageController.text = infos.message;
      _chargement = false;
    });
  }

  // Les réglages tels qu'ils sont à l'écran (pas encore enregistrés)
  AppConfig? get _configEcran => _config?.copyWith(
    largeurPapier: _largeur,
    imprimante: _imprimante,
    effacerImprimante: _imprimante == null,
    impressionAuto: _auto,
    reglagesImprimante: _reglages,
  );

  InfosEntreprise get _infosEcran => InfosEntreprise(
    nom: _nomController.text,
    infos: _infosController.text,
    devise: _deviseController.text,
    message: _messageController.text,
  );

  Future<void> _enregistrerPoste() async {
    final config = _configEcran;
    if (config == null) return;
    try {
      await ConfigService.ecrire(config);
      if (!mounted) return;
      setState(() => _config = config);
      _message('Réglages de ce poste enregistrés');
    } catch (e) {
      if (!mounted) return;
      _message(_nettoyer(e));
    }
  }

  Future<void> _tester() async {
    final config = _configEcran;
    if (config == null) return;
    setState(() => _occupe = true);
    try {
      await TicketService.imprimerTest(config, _infosEcran);
      if (!mounted) return;
      _message('Ticket de test envoyé');
    } catch (e) {
      if (!mounted) return;
      _message(_nettoyer(e));
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _enregistrerEntreprise() async {
    try {
      await DatabaseService.enregistrerInfosEntreprise(_infosEcran);
      if (!mounted) return;
      _message("Informations de l'entreprise enregistrées");
    } catch (e) {
      if (!mounted) return;
      _message(_nettoyer(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_autorise) {
      return Scaffold(
        appBar: AppBar(title: const Text('Impression')),
        body: const AccesRefuse(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Impression des tickets')),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _cartePoste(),
                    const SizedBox(height: 16),
                    _carteEntreprise(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _cartePoste() {
    // Les noms des imprimantes de Windows, plus celle réglée si elle a disparu
    final noms = _imprimantes.map((p) => p.name).toList();
    final introuvable = _imprimante != null && !noms.contains(_imprimante);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ce poste',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text(
              "Ces réglages ne concernent que cet ordinateur.",
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            const Text(
              'Largeur du papier',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 58, label: Text('58 mm')),
                ButtonSegment(value: 80, label: Text('80 mm')),
              ],
              selected: {_largeur},
              onSelectionChanged: (s) => setState(() => _largeur = s.first),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              key: ValueKey('${_imprimantes.length}-$_imprimante'),
              initialValue: _imprimante,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Imprimante',
                prefixIcon: Icon(Icons.print),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Imprimante par défaut de Windows'),
                ),
                for (final p in _imprimantes)
                  DropdownMenuItem<String?>(
                    value: p.name,
                    child: Text(
                      p.isDefault ? '${p.name} (par défaut)' : p.name,
                    ),
                  ),
                if (introuvable)
                  DropdownMenuItem<String?>(
                    value: _imprimante,
                    child: Text('$_imprimante (introuvable)'),
                  ),
              ],
              onChanged: (v) => setState(() => _imprimante = v),
            ),
            if (_erreurImprimantes != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _erreurImprimantes!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _charger,
                icon: const Icon(Icons.refresh),
                label: const Text('Actualiser la liste des imprimantes'),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Imprimer automatiquement après chaque vente'),
              value: _auto,
              onChanged: (v) => setState(() => _auto = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Utiliser le format de papier du pilote Windows',
              ),
              subtitle: const Text(
                "À activer seulement si le ticket sort trop petit, coupé ou sur une page entière",
              ),
              value: _reglages,
              onChanged: (v) => setState(() => _reglages = v),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _enregistrerPoste,
                  icon: const Icon(Icons.save),
                  label: const Text('Enregistrer pour ce poste'),
                ),
                OutlinedButton.icon(
                  onPressed: _occupe ? null : _tester,
                  icon: _occupe
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.receipt_long),
                  label: const Text('Imprimer un ticket de test'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _carteEntreprise() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Informations de l'entreprise",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              _peutGererEntreprise
                  ? 'Communes à tous les postes : elles apparaissent sur chaque ticket.'
                  : "Seul l'administrateur peut les modifier.",
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nomController,
              enabled: _peutGererEntreprise,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: "Nom de l'entreprise",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _infosController,
              enabled: _peutGererEntreprise,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Ligne d\'identification (facultatif)',
                helperText: 'Par exemple : numéro de contribuable, registre de commerce',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _deviseController,
              enabled: _peutGererEntreprise,
              maxLength: 8,
              decoration: const InputDecoration(
                labelText: 'Devise affichée après le net à payer (facultatif)',
                helperText: 'Par exemple : F',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              enabled: _peutGererEntreprise,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Message de fin de ticket',
                border: OutlineInputBorder(),
              ),
            ),
            if (_peutGererEntreprise)
              FilledButton.icon(
                onPressed: _enregistrerEntreprise,
                icon: const Icon(Icons.save),
                label: const Text("Enregistrer les informations"),
              ),
          ],
        ),
      ),
    );
  }
}
