import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gestionyobs/modules/achat.dart' show formaterDate;
import 'package:gestionyobs/service/licence_service.dart';
import 'package:gestionyobs/app/messages_app.dart';
import 'package:gestionyobs/startup_page.dart';

class LicencePage extends StatefulWidget {
  // vrai quand la page s'ouvre au démarrage du logiciel
  final bool demarrage;

  const LicencePage({super.key, this.demarrage = false});

  @override
  State<LicencePage> createState() => _LicencePageState();
}

class _LicencePageState extends State<LicencePage> {
  final _cleController = TextEditingController();
  EtatLicence? _etat;
  bool _occupe = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _cleController.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    final e = await LicenceService.verifier();
    if (!mounted) return;
    setState(() => _etat = e);
  }

  void _continuer() {
    if (widget.demarrage) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const StartupPage()),
        (route) => false,
      );
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _activer() async {
    setState(() {
      _occupe = true;
      _erreur = null;
    });
    try {
      await LicenceService.activer(_cleController.text);
      if (!mounted) return;
      MessagesApp.afficher('Licence activée');
      _continuer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _occupe = false;
        _erreur = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _etat;

    return Scaffold(
      appBar: AppBar(title: const Text('Licence du logiciel')),
      body: e == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.message,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: e.licencie
                                    ? Colors.green.shade800
                                    : (e.autorise
                                          ? Colors.orange.shade800
                                          : Colors.red),
                              ),
                            ),
                            if (e.licencie) ...[
                              const SizedBox(height: 4),
                              if (e.client != null)
                                Text('Client : ${e.client}'),
                              Text(
                                e.expiration == null
                                    ? 'Validité : illimitée'
                                    : "Valable jusqu'au ${formaterDate(e.expiration!)}",
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Code de ce poste',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: SelectableText(
                                    e.codePoste.isEmpty ? '-' : e.codePoste,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  tooltip: 'Copier',
                                  onPressed: e.codePoste.isEmpty
                                      ? null
                                      : () {
                                          Clipboard.setData(
                                            ClipboardData(text: e.codePoste),
                                          );
                                          MessagesApp.afficher('Code copié');
                                        },
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Envoyez ce code à votre fournisseur pour recevoir '
                              'la clé de licence de cet ordinateur.',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!e.licencie) ...[
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Activer avec une clé de licence',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _cleController,
                                minLines: 3,
                                maxLines: 6,
                                decoration: const InputDecoration(
                                  labelText: 'Clé de licence',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              if (_erreur != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _erreur!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  FilledButton.icon(
                                    onPressed: _occupe ? null : _activer,
                                    icon: const Icon(Icons.verified_user),
                                    label: const Text('Activer'),
                                  ),
                                  const SizedBox(width: 12),
                                  if (e.autorise && widget.demarrage)
                                    OutlinedButton(
                                      onPressed: _continuer,
                                      child: const Text("Continuer l'essai"),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
