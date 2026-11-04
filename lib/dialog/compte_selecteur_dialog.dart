import 'package:flutter/material.dart';
import 'package:gestionyobs/modules/compte_comptable.dart';

/// Boîte de dialogue : choisir un compte du plan. Retourne le compte choisi.
class CompteSelecteurDialog extends StatefulWidget {
  final String titre;
  final List<CompteComptable> comptes;
  final List<String> propositions; // numéros à mettre en avant

  // Si renseigné, la recherche se limite d'abord à ces classes de comptes
  final Set<int>? classes;

  const CompteSelecteurDialog({
    super.key,
    required this.titre,
    required this.comptes,
    this.propositions = const [],
    this.classes,
  });

  @override
  State<CompteSelecteurDialog> createState() => _CompteSelecteurDialogState();
}

class _CompteSelecteurDialogState extends State<CompteSelecteurDialog> {
  final _controller = TextEditingController();
  bool _regroupement = false;
  bool _toutesClasses = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _classeAutorisee(CompteComptable c) {
    final classes = widget.classes;
    return classes == null || _toutesClasses || classes.contains(c.classe);
  }

  List<CompteComptable> get _resultats {
    final texte = _controller.text.trim().toLowerCase();
    if (texte.isEmpty) return [];
    return widget.comptes
        .where((c) {
          if (!c.actif) return false;
          if (!_regroupement && !c.imputable) return false;
          if (!_classeAutorisee(c)) return false;
          return c.numero.startsWith(texte) ||
              c.intitule.toLowerCase().contains(texte);
        })
        .take(200)
        .toList();
  }

  List<CompteComptable> get _proposes {
    final liste = <CompteComptable>[];
    for (final numero in widget.propositions) {
      for (final c in widget.comptes) {
        if (c.numero == numero && c.actif && (_regroupement || c.imputable)) {
          liste.add(c);
        }
      }
    }
    return liste;
  }

  @override
  Widget build(BuildContext context) {
    final resultats = _resultats;
    final proposes = _proposes;

    return AlertDialog(
      title: Text('Compte pour : ${widget.titre}'),
      content: SizedBox(
        width: 580,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: "Début du numéro ou mot de l'intitulé",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            if (widget.classes != null)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  'Afficher aussi les autres classes de comptes '
                  '(proposées : ${widget.classes!.join(', ')})',
                ),
                value: _toutesClasses,
                onChanged: (v) => setState(() => _toutesClasses = v ?? false),
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Afficher aussi les comptes de regroupement'),
              value: _regroupement,
              onChanged: (v) => setState(() => _regroupement = v ?? false),
            ),
            if (proposes.isNotEmpty) ...[
              const Text(
                'Compte proposé',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: proposes
                    .map(
                      (c) => ActionChip(
                        avatar: const Icon(Icons.star, size: 16),
                        label: Text('${c.numero}  ${c.intitule}'),
                        onPressed: () => Navigator.pop(context, c),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: _controller.text.trim().isEmpty
                  ? const Center(
                      child: Text(
                        'Tapez un début de numéro (ex. 411) ou un mot (ex. caisse)',
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  : resultats.isEmpty
                  ? const Center(child: Text('Aucun compte trouvé'))
                  : ListView.builder(
                      itemCount: resultats.length,
                      itemBuilder: (context, index) {
                        final c = resultats[index];
                        return ListTile(
                          dense: true,
                          title: Text('${c.numero}  ${c.intitule}'),
                          subtitle: Text(
                            [
                              'Classe ${c.classe} : ${nomsClasses[c.classe] ?? ''}',
                              if (!c.imputable) 'Compte de regroupement',
                            ].join(' · '),
                          ),
                          onTap: () => Navigator.pop(context, c),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
      ],
    );
  }
}
