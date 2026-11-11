/// Les types de dépense : code enregistré -> libellé affiché.
const Map<String, String> typesDepense = {
  'salaire': 'Salaire',
  'charge': 'Charge',
  'autre': 'Autre dépense',
};

/// Une ligne de la liste des dépenses.
class DepenseResume {
  final int id;
  final String code;
  final String type;
  final DateTime date;
  final String libelle;
  final String? beneficiaire;
  final String numeroCompte;
  final String intituleCompte;
  final int montant;
  final String? piece;
  final String? mode;
  final String utilisateur;
  final String statut; // 'valide' ou 'annule'

  const DepenseResume({
    required this.id,
    required this.code,
    required this.type,
    required this.date,
    required this.libelle,
    required this.beneficiaire,
    required this.numeroCompte,
    required this.intituleCompte,
    required this.montant,
    required this.piece,
    required this.mode,
    required this.utilisateur,
    required this.statut,
  });

  factory DepenseResume.fromMap(Map<String, Object?> m) => DepenseResume(
    id: m['id'] as int,
    code: m['code'] as String,
    type: m['type'] as String,
    date: DateTime.parse(m['date_depense'] as String),
    libelle: m['libelle'] as String,
    beneficiaire: m['beneficiaire'] as String?,
    numeroCompte: m['numero_compte'] as String,
    intituleCompte: m['intitule_compte'] as String,
    montant: m['montant'] as int,
    piece: m['piece'] as String?,
    mode: m['mode'] as String?,
    utilisateur: m['utilisateur'] as String,
    statut: (m['statut'] as String?) ?? 'valide',
  );
}
