import 'package:flutter/material.dart';

import 'achat.dart';

import 'package:gestionyobs/rapport/rapport.dart';

class SelecteurPeriode extends StatelessWidget {
  final DateTime debut;
  final DateTime fin;
  final void Function(DateTime debut, DateTime fin) onChange;

  const SelecteurPeriode({
    super.key,
    required this.debut,
    required this.fin,
    required this.onChange,
  });

  void _appliquer(PeriodeRapport p) => onChange(p.debut, p.fin);

  Future<void> _choisir(BuildContext context, {required bool pourDebut}) async {
    final d = await showDatePicker(
      context: context,
      initialDate: pourDebut ? debut : fin,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
    );
    if (d == null) return;

    if (pourDebut) {
      onChange(d, d.isAfter(fin) ? d : fin);
    } else {
      onChange(d.isBefore(debut) ? d : debut, d);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maintenant = DateTime.now();
    final ceMois = PeriodeRapport.calculer('mois', maintenant);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ActionChip(
          label: const Text('Ce mois'),
          onPressed: () => _appliquer(ceMois),
        ),
        ActionChip(
          label: const Text('Mois précédent'),
          onPressed: () =>
              _appliquer(PeriodeRapport.calculer('mois', ceMois.decaler(-1))),
        ),
        ActionChip(
          label: const Text('Ce trimestre'),
          onPressed: () =>
              _appliquer(PeriodeRapport.calculer('trimestre', maintenant)),
        ),
        ActionChip(
          label: const Text('Cette année'),
          onPressed: () =>
              _appliquer(PeriodeRapport.calculer('annee', maintenant)),
        ),
        ActionChip(
          label: const Text('Année précédente'),
          onPressed: () => _appliquer(
            PeriodeRapport.calculer(
              'annee',
              DateTime(maintenant.year - 1, 6, 15),
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => _choisir(context, pourDebut: true),
          icon: const Icon(Icons.event),
          label: Text('Du ${formaterDate(debut)}'),
        ),
        OutlinedButton.icon(
          onPressed: () => _choisir(context, pourDebut: false),
          icon: const Icon(Icons.event),
          label: Text('au ${formaterDate(fin)}'),
        ),
      ],
    );
  }
}
