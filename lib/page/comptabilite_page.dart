import 'package:flutter/material.dart';
import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/modules/article.dart';
import 'package:gestionyobs/page/associations_page.dart';
import 'package:gestionyobs/comptabilite/compta.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/page/etat_comptable_page.dart';
import 'package:gestionyobs/modules/stock.dart';
import 'package:gestionyobs/security/utilisateur.dart';

class ComptabilitePage extends StatefulWidget {
  const ComptabilitePage({super.key});

  @override
  State<ComptabilitePage> createState() => _ComptabilitePageState();
}

class _ComptabilitePageState extends State<ComptabilitePage> {
  ResultatComptabilisation? _resultat;
  StatistiquesCompta? _stats;
  bool _chargement = true;
  String? _erreur;

  bool get _autorise =>
      Session.peut('comptabilite.voir') || Session.peut('comptabilite.gerer');

  @override
  void initState() {
    super.initState();
    _actualiser();
  }

  // Comptabilise ce qui est en attente, puis relit les chiffres
  Future<void> _actualiser() async {
    if (!_autorise) {
      setState(() => _chargement = false);
      return;
    }
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final resultat = await DatabaseService.comptabiliserAuto();
      final stats = await DatabaseService.statistiquesCompta();
      if (!mounted) return;
      setState(() {
        _resultat = resultat;
        _stats = stats;
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

  Future<void> _ouvrir(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _actualiser();
  }

  Widget _carteEtat(
    IconData icone,
    String titre,
    String description,
    String type,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icone, size: 34, color: Colors.green),
        title: Text(
          titre,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _ouvrir(EtatComptablePage(type: type)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_autorise) {
      return Scaffold(
        appBar: AppBar(title: const Text('Comptabilité')),
        body: const AccesRefuse(),
      );
    }

    final r = _resultat;
    final s = _stats;

    return Scaffold(
      appBar: AppBar(title: const Text('Comptabilité')),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _erreur != null
          ? Center(
              child: Text(_erreur!, style: const TextStyle(color: Colors.red)),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (s != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Comptabilisation automatique',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                r == null || r.crees == 0
                                    ? 'Tout est à jour : aucune nouvelle écriture à passer.'
                                    : '${r.crees} nouvelle(s) écriture(s) passée(s) à l\'instant.',
                              ),
                              Text(
                                '${s.nbEcritures} écriture(s) au total · '
                                'total des débits : ${formaterPrix(s.totalDebit)}'
                                '${s.derniere == null ? '' : ' · dernière le ${formaterDateHeure(s.derniere!)}'}',
                                style: const TextStyle(color: Colors.black54),
                              ),
                              if (Session.peut('comptabilite.gerer'))
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: _actualiser,
                                    icon: const Icon(Icons.sync),
                                    label: const Text(
                                      'Comptabiliser maintenant',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    if (r != null && r.manquants.isNotEmpty)
                      Card(
                        color: Colors.orange.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber,
                                    color: Colors.orange.shade800,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${r.bloques} opération(s) en attente : il manque un compte pour',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              for (final m in r.manquants) Text('• $m'),
                              const SizedBox(height: 8),
                              const Text(
                                'Associez un compte à ces postes. Les opérations seront '
                                'comptabilisées automatiquement ensuite : rien n\'est perdu.',
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () =>
                                      _ouvrir(const AssociationsPage()),
                                  icon: const Icon(Icons.account_tree),
                                  label: const Text(
                                    'Ouvrir les associations comptables',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (r != null && r.anomalies.isNotEmpty)
                      Card(
                        color: Colors.red.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Anomalies : ces opérations n\'ont pas été comptabilisées',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade800,
                                ),
                              ),
                              for (final a in r.anomalies) Text('• $a'),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    _carteEtat(
                      Icons.menu_book,
                      'Journal',
                      'Toutes les écritures, par date et par journal',
                      'journal',
                    ),
                    _carteEtat(
                      Icons.auto_stories,
                      'Grand livre',
                      "Les mouvements de chaque compte, avec le solde qui s'accumule",
                      'grand_livre',
                    ),
                    _carteEtat(
                      Icons.balance,
                      'Balance',
                      'Le report, les mouvements et le solde de chaque compte',
                      'balance',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'À savoir : les stocks ne sont pas valorisés en comptabilité '
                      '(la variation de stock se fait à la clôture annuelle) et la TVA '
                      "n'est pas activée.",
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
