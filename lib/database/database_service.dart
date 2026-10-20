import 'dart:io';

import 'package:bcrypt/bcrypt.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gestionyobs/config_service.dart';
import 'package:gestionyobs/security/utilisateur.dart';

/// Gère la base de données SQLite.
/// Gère la base de données SQLite.
class DatabaseService {
  static Database? _db;
  static bool _ffiInitialise = false;

  // Numéro de version de la structure de la base.
  // Version 1 : table utilisateurs. Version 2 : agences + affiliations+ mise ajour agence.
  static const int _versionBase = 3;

  // Ouvre la base (et la crée ou la met à jour si besoin)
  static Future<void> ouvrir(AppConfig config) async {
    if (config.type != 'sqlite') {
      throw Exception('Type de base non pris en charge : ${config.type}');
    }

    if (!_ffiInitialise) {
      sqfliteFfiInit();
      _ffiInitialise = true;
    }

    final dossier = File(config.cheminBase).parent;
    await dossier.create(recursive: true);

    _db = await databaseFactoryFfi.openDatabase(
      config.cheminBase,
      options: OpenDatabaseOptions(
        version: _versionBase,
        // Active le contrôle des liens entre tables
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        // Base toute neuve : on crée toutes les tables
        onCreate: (db, version) async {
          await _creerTableUtilisateurs(db);
          await _creerTablesAgences(db);
        },
        // Base existante plus ancienne : on ajoute seulement ce qui manque
        onUpgrade: (db, ancienneVersion, nouvelleVersion) async {
          if (ancienneVersion < 2) {
            // _creerTablesAgences contient déjà la colonne description
            await _creerTablesAgences(db);
          }
          // On n'ajoute la colonne que si elle n'existe pas encore
          if (!await _colonneExiste(db, 'agences', 'description')) {
            await db.execute('ALTER TABLE agences ADD COLUMN description TEXT');
          }
        },
      ),
    );
  }

  static Future<void> _creerTableUtilisateurs(Database db) async {
    await db.execute('''
      CREATE TABLE utilisateurs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom_complet TEXT NOT NULL,
        identifiant TEXT NOT NULL UNIQUE,
        mot_de_passe_hash TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'vendeur',
        actif INTEGER NOT NULL DEFAULT 1,
        cree_le TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _creerTablesAgences(Database db) async {
    await db.execute('''
      CREATE TABLE agences (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL UNIQUE,
        ville TEXT,
        telephone TEXT,
        description TEXT,
        actif INTEGER NOT NULL DEFAULT 1,
        cree_le TEXT NOT NULL
      )
    ''');

    // Qui travaille dans quelle agence
    await db.execute('''
      CREATE TABLE utilisateur_agences (
        utilisateur_id INTEGER NOT NULL,
        agence_id INTEGER NOT NULL,
        PRIMARY KEY (utilisateur_id, agence_id),
        FOREIGN KEY (utilisateur_id) REFERENCES utilisateurs(id) ON DELETE CASCADE,
        FOREIGN KEY (agence_id) REFERENCES agences(id) ON DELETE CASCADE
      )
    ''');
  }

  // Vérifie si une colonne existe déjà dans une table
  static Future<bool> _colonneExiste(
    Database db,
    String table,
    String colonne,
  ) async {
    final infos = await db.rawQuery('PRAGMA table_info($table)');
    return infos.any((c) => c['name'] == colonne);
  }

  static Database get db {
    final d = _db;
    if (d == null) throw StateError("La base de données n'est pas ouverte");
    return d;
  }

  // ---------- Utilisateurs ----------

  static Future<bool> aDesUtilisateurs() async {
    final resultat = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM utilisateurs',
    );
    final n = resultat.first['n'] as int;
    return n > 0;
  }

  // creation de l'utilisateur du systeme
  static Future<int> creerUtilisateur({
    required String nomComplet,
    required String identifiant,
    required String motDePasse,
    required String role,
    List<int> agenceIds = const [],
  }) async {
    final hash = BCrypt.hashpw(motDePasse, BCrypt.gensalt());

    // Transaction : soit tout est enregistré, soit rien
    return db.transaction((txn) async {
      final id = await txn.insert('utilisateurs', {
        'nom_complet': nomComplet,
        'identifiant': identifiant,
        'mot_de_passe_hash': hash,
        'role': role,
        'actif': 1,
        'cree_le': DateTime.now().toIso8601String(),
      });

      for (final agenceId in agenceIds) {
        await txn.insert('utilisateur_agences', {
          'utilisateur_id': id,
          'agence_id': agenceId,
        });
      }

      return id;
    });
  }

  static Future<Utilisateur?> verifierConnexion(
    String identifiant,
    String motDePasse,
  ) async {
    final lignes = await db.query(
      'utilisateurs',
      where: 'identifiant = ? AND actif = 1',
      whereArgs: [identifiant],
      limit: 1,
    );

    if (lignes.isEmpty) return null;

    final ligne = lignes.first;
    final hash = ligne['mot_de_passe_hash'] as String;

    if (!BCrypt.checkpw(motDePasse, hash)) return null;

    return Utilisateur(
      id: ligne['id'] as int,
      nomComplet: ligne['nom_complet'] as String,
      identifiant: ligne['identifiant'] as String,
      role: ligne['role'] as String,
    );
  }

  // ---------- Agences ----------

  // Les agences auxquelles cet utilisateur a accès :
  // l'admin voit toutes les agences, les autres seulement les leurs.
  static Future<List<Agence>> agencesDisponibles(
    Utilisateur utilisateur,
  ) async {
    final List<Map<String, Object?>> lignes;

    if (utilisateur.estAdmin) {
      lignes = await db.query('agences', where: 'actif = 1', orderBy: 'nom');
    } else {
      lignes = await db.rawQuery(
        '''
        SELECT a.* FROM agences a
        INNER JOIN utilisateur_agences ua ON ua.agence_id = a.id
        WHERE ua.utilisateur_id = ? AND a.actif = 1
        ORDER BY a.nom
      ''',
        [utilisateur.id],
      );
    }

    return lignes.map(Agence.fromMap).toList();
  }

  // Transforme un texte vide en null (rien à enregistrer)
  static String? _videEnNull(String? texte) =>
      (texte == null || texte.trim().isEmpty) ? null : texte.trim();

  static Future<Agence> creerAgence({
    required String nom,
    String? ville,
    String? telephone,
    String? description,
  }) async {
    final villeNettoyee = _videEnNull(ville);
    final telNettoye = _videEnNull(telephone);
    final descriptionNettoyee = _videEnNull(description);

    final id = await db.insert('agences', {
      'nom': nom,
      'ville': villeNettoyee,
      'telephone': telNettoye,
      'description': descriptionNettoyee,
      'actif': 1,
      'cree_le': DateTime.now().toIso8601String(),
    });

    return Agence(
      id: id,
      nom: nom,
      ville: villeNettoyee,
      telephone: telNettoye,
      description: descriptionNettoyee,
    );
  }

  // Liste de tous les utilisateurs, avec le nom de leurs agences
  static Future<List<UtilisateurResume>> listerUtilisateurs() async {
    final lignes = await db.rawQuery('''
      SELECT u.id, u.nom_complet, u.identifiant, u.role, u.actif,
             GROUP_CONCAT(a.nom, ', ') AS agences
      FROM utilisateurs u
      LEFT JOIN utilisateur_agences ua ON ua.utilisateur_id = u.id
      LEFT JOIN agences a ON a.id = ua.agence_id
      GROUP BY u.id
      ORDER BY u.nom_complet
    ''');

    return lignes
        .map(
          (m) => UtilisateurResume(
            id: m['id'] as int,
            nomComplet: m['nom_complet'] as String,
            identifiant: m['identifiant'] as String,
            role: m['role'] as String,
            actif: (m['actif'] as int) == 1,
            agences: (m['agences'] as String?) ?? '',
          ),
        )
        .toList();
  }

  // Les numéros des agences auxquelles cet utilisateur est affilié
  static Future<Set<int>> agenceIdsDeUtilisateur(int utilisateurId) async {
    final lignes = await db.query(
      'utilisateur_agences',
      columns: ['agence_id'],
      where: 'utilisateur_id = ?',
      whereArgs: [utilisateurId],
    );
    return lignes.map((m) => m['agence_id'] as int).toSet();
  }

  static Future<void> modifierUtilisateur({
    required int id,
    required String nomComplet,
    required String role,
    required bool actif,
    required List<int> agenceIds,
  }) async {
    await db.transaction((txn) async {
      final actuel = await txn.query(
        'utilisateurs',
        columns: ['role', 'actif'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (actuel.isEmpty) throw Exception('Utilisateur introuvable');

      // Sécurité : il doit toujours rester un administrateur actif
      final etaitAdminActif =
          actuel.first['role'] == 'admin' && actuel.first['actif'] == 1;
      if (etaitAdminActif && (role != 'admin' || !actif)) {
        final r = await txn.rawQuery(
          "SELECT COUNT(*) AS n FROM utilisateurs WHERE role = 'admin' AND actif = 1",
        );
        if ((r.first['n'] as int) <= 1) {
          throw Exception('Il doit rester au moins un administrateur actif');
        }
      }

      await txn.update(
        'utilisateurs',
        {'nom_complet': nomComplet, 'role': role, 'actif': actif ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );

      // On remplace les affiliations : on efface les anciennes, puis on
      // enregistre les nouvelles (aucune pour un administrateur)
      await txn.delete(
        'utilisateur_agences',
        where: 'utilisateur_id = ?',
        whereArgs: [id],
      );
      if (role != 'admin') {
        for (final agenceId in agenceIds) {
          await txn.insert('utilisateur_agences', {
            'utilisateur_id': id,
            'agence_id': agenceId,
          });
        }
      }
    });
  }

  static Future<void> reinitialiserMotDePasse(
    int id,
    String nouveauMotDePasse,
  ) async {
    final hash = BCrypt.hashpw(nouveauMotDePasse, BCrypt.gensalt());
    await db.update(
      'utilisateurs',
      {'mot_de_passe_hash': hash},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
