import 'package:flutter/material.dart';
import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/modules/article.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/modules/stock.dart';
import 'package:gestionyobs/security/utilisateur.dart';

class MouvementsPage extends StatefulWidget {
  final int? articleId; // null = tous les articles
  final String? titre;

  const MouvementsPage({super.key, this.articleId, this.titre});

  @override
  State<MouvementsPage> createState() => _MouvementsPageState();
}

class _MouvementsPageState extends State<MouvementsPage> {
  List<Mouvement> _mouvements = [];
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final liste = await DatabaseService.listerMouvements(
        articleId: widget.articleId,
      );
      if (!mounted) return;
      setState(() {
        _mouvements = liste;
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
    final autorise =
        Session.peut('stock.voir') ||
        Session.peut('stock.modifier') ||
        Session.peut('stock.ajuster');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.titre == null
              ? 'Historique du stock'
              : 'Historique - ${widget.titre}',
        ),
      ),
      body: !autorise
          ? const AccesRefuse()
          : _chargement
          ? const Center(child: CircularProgressIndicator())
          : _erreur != null
          ? Center(
              child: Text(_erreur!, style: const TextStyle(color: Colors.red)),
            )
          : _mouvements.isEmpty
          ? const Center(child: Text('Aucun mouvement'))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _mouvements.length,
                  itemBuilder: (context, index) {
                    final m = _mouvements[index];

                    final couleur = switch (m.type) {
                      'entree' => Colors.green,
                      'sortie' => Colors.red,
                      _ => Colors.blue,
                    };
                    final icone = switch (m.type) {
                      'entree' => Icons.arrow_downward,
                      'sortie' => Icons.arrow_upward,
                      _ => Icons.tune,
                    };
                    final signe = m.quantite > 0 ? '+' : '';

                    return Card(
                      child: ListTile(
                        isThreeLine: true,
                        leading: CircleAvatar(
                          backgroundColor: couleur.withOpacity(0.15),
                          child: Icon(icone, color: couleur),
                        ),
                        title: Text(m.designation),
                        subtitle: Text(
                          [
                            '${typesMouvement[m.type] ?? m.type} · ${m.motif}',
                            '${formaterDateHeure(m.date)} · '
                                '${m.utilisateur} · ${m.code}',
                            if (m.commentaire != null &&
                                m.commentaire!.isNotEmpty)
                              m.commentaire!,
                          ].join('\n'),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$signe${formaterQuantite(m.quantite)} ${m.unite}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: couleur,
                              ),
                            ),
                            Text(
                              '${formaterQuantite(m.avant)} → '
                              '${formaterQuantite(m.apres)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
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
