/// Où va l'argent : code enregistré -> libellé affiché.
const Map<String, String> typesTresorerie = {
  'caisse': 'Caisse (espèces)',
  'mobile': 'Mobile money',
  'banque': 'Banque',
};

/// Un mode de paiement (espèces, Orange Money, banque...).
class ModePaiement {
  final int id;
  final String code;
  final String libelle;
  final String type;
  final bool referenceObligatoire;
  final bool systeme; // non désactivable, type non modifiable
  final bool actif;
  final int ordre;

  const ModePaiement({
    required this.id,
    required this.code,
    required this.libelle,
    required this.type,
    required this.referenceObligatoire,
    required this.systeme,
    required this.actif,
    required this.ordre,
  });

  factory ModePaiement.fromMap(Map<String, Object?> m) => ModePaiement(
    id: m['id'] as int,
    code: m['code'] as String,
    libelle: m['libelle'] as String,
    type: m['type'] as String,
    referenceObligatoire: (m['reference_obligatoire'] as int) == 1,
    systeme: (m['systeme'] as int) == 1,
    actif: (m['actif'] as int) == 1,
    ordre: m['ordre'] as int,
  );
}
