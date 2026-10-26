import 'package:gestionyobs/security/utilisateur.dart';

/// Un client et/ou un fournisseur.
class Tiers {
  final int id;
  final String code; // matricule automatique
  final String nom;
  final bool estClient;
  final bool estFournisseur;
  final String? telephone;
  final String? email;
  final String? ville;
  final String? adresse;
  final int plafondCredit; // 0 = aucun crédit autorisé
  final String? notes;
  final bool systeme; // compte système : non modifiable
  final bool actif;

  const Tiers({
    required this.id,
    required this.code,
    required this.nom,
    required this.estClient,
    required this.estFournisseur,
    required this.telephone,
    required this.email,
    required this.ville,
    required this.adresse,
    required this.plafondCredit,
    required this.notes,
    required this.systeme,
    required this.actif,
  });

  factory Tiers.fromMap(Map<String, Object?> m) => Tiers(
    id: m['id'] as int,
    code: m['code'] as String,
    nom: m['nom'] as String,
    estClient: (m['est_client'] as int) == 1,
    estFournisseur: (m['est_fournisseur'] as int) == 1,
    telephone: m['telephone'] as String?,
    email: m['email'] as String?,
    ville: m['ville'] as String?,
    adresse: m['adresse'] as String?,
    plafondCredit: m['plafond_credit'] as int,
    notes: m['notes'] as String?,
    systeme: (m['systeme'] as int) == 1,
    actif: (m['actif'] as int) == 1,
  );
}

/// Le code du droit : droitTiers('client', 'gerer') -> 'clients.gerer'
String droitTiers(String type, String action) =>
    type == 'client' ? 'clients.$action' : 'fournisseurs.$action';

/// L'utilisateur peut-il consulter les clients (ou les fournisseurs) ?
bool peutVoirTiers(String type) =>
    Session.peut(droitTiers(type, 'voir')) ||
    Session.peut(droitTiers(type, 'gerer'));
