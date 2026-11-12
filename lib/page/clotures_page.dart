import 'package:flutter/material.dart';
import 'package:gestionyobs/modules/achat.dart';
import 'package:gestionyobs/modules/article.dart';
import 'package:gestionyobs/modules/caisse.dart';
import 'package:gestionyobs/database/database_service.dart';

class CloturesPage extends StatefulWidget {
  const CloturesPage({super.key});

  @override
  State<CloturesPage> createState() => _CloturesPageState();
}

class _CloturesPageState extends State<CloturesPage> {
  List<ClotureResume> _liste = [];
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final l = await DatabaseService.listerClotures();
      if (!mounted) return;
      setState(() {
        _liste = l;
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
    return Scaffold(
      appBar: AppBar(title: const Text('Historique des clôtures')),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _erreur != null
          ? Center(
              child: Text(_erreur!, style: const TextStyle(color: Colors.red)),
            )
          : _liste.isEmpty
          ? const Center(child: Text("Aucune clôture pour l'instant"))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _liste.length,
                  itemBuilder: (context, index) {
                    final c = _liste[index];
                    final juste = c.ecart == 0;
                    return Card(
                      child: ListTile(
                        onTap: () => Navigator.pop(context, c.dateCaisse),
                        leading: Icon(
                          juste ? Icons.check_circle : Icons.warning_amber,
                          color: juste ? Colors.green : Colors.orange.shade800,
                        ),
                        title: Text(
                          '${formaterDate(c.dateCaisse)} · ${c.code}',
                        ),
                        subtitle: Text(
                          'Théorique ${formaterPrix(c.theorique)} · '
                          'Compté ${formaterPrix(c.compte)} · ${c.par}',
                        ),
                        trailing: Text(
                          juste
                              ? 'Juste'
                              : 'Écart ${c.ecart > 0 ? '+' : ''}${formaterPrix(c.ecart)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: juste
                                ? Colors.green.shade800
                                : Colors.red.shade700,
                          ),
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
