import 'dart:io';

import 'package:bcrypt/bcrypt.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gestionyobs/config_service.dart';
import 'package:gestionyobs/security/utilisateur.dart';
import 'package:gestionyobs/permissions/permissions_catalogue.dart';
import 'package:gestionyobs/security/role.dart';
import 'package:gestionyobs/modules/article.dart';
import 'package:gestionyobs/modules/stock.dart';
import 'package:gestionyobs/modules/tiers.dart';
import 'package:gestionyobs/modules/mode_paiement.dart';
import 'package:gestionyobs/modules/compte_comptable.dart';

import 'package:gestionyobs/association/association.dart';
import 'package:gestionyobs/modules/postes_comptables.dart';
import 'package:gestionyobs/modules/classe_article.dart';
import 'package:gestionyobs/modules/achat.dart';
import 'package:gestionyobs/modules/vente.dart';

/// Gère la base de données SQLite.
/// Gère la base de données SQLite.
class DatabaseService {
  static Database? _db;
  static bool _ffiInitialise = false;

  // Numéro de version de la structure de la base.
  // Version 1 : table utilisateurs.
  //Version 2 : agences + affiliations+ mise ajour agence.
  // Version 4 : rôles, permissions et droits des rôles.
  //static const int _versionBase = 4;
  // Version 5 : table des articles.
  //static const int _versionBase = 5;
  // Version 6 : stock par agence et mouvements de stock.
  // static const int _versionBase = 6;
  // Version 7 : clients et fournisseurs (table tiers).
  // static const int _versionBase = 7;
  // Version 8 : modes de paiement.
  //static const int _versionBase = 8;
  // Version 9 : plan comptable.
  //static const int _versionBase = 9;
  // Version 10 : associations comptables et leur historique.
  //static const int _versionBase = 10;
  // Version 11 : classes d'articles (remplacent les catégories en texte libre).
  //static const int _versionBase = 11;
  // Version 12 : achats, lignes d'achat et paiements.
  // static const int _versionBase = 12;
  // Version 13 : ventes, lignes de vente (les paiements existent déjà).
  //static const int _versionBase = 13;
  // Version 14 : paramètres de l'entreprise et compteur d'impressions.
  static const int _versionBase = 14;

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
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await _creerTableUtilisateurs(db);
          await _creerTablesAgences(db);
          await _creerTablesRoles(db);
          await _initialiserRoles(db);
          await _creerTableArticles(db);
          await _creerTablesStock(db);
          await _creerTableTiers(db);
          await _creerTiersParDefaut(db);
          await _creerTableModesPaiement(db);
          await _creerModesParDefaut(db);
          await _creerTableComptes(db);
          await _creerTablesAssociations(db);
          await _migrerClasses(db);
          await _creerTablesAchats(db);
          await _creerTablesVentes(db);
          await _creerTablesImpression(db);
        },
        onUpgrade: (db, ancienneVersion, nouvelleVersion) async {
          if (ancienneVersion < 2) {
            await _creerTablesAgences(db);
          }
          if (!await _colonneExiste(db, 'agences', 'description')) {
            await db.execute('ALTER TABLE agences ADD COLUMN description TEXT');
          }
          if (ancienneVersion < 4) {
            await _creerTablesRoles(db);
            await _initialiserRoles(db);
          }
          if (ancienneVersion < 5) {
            await _creerTableArticles(db);
          }
          if (ancienneVersion < 6) {
            await _creerTablesStock(db);
          }
          if (ancienneVersion < 7) {
            await _creerTableTiers(db);
            await _creerTiersParDefaut(db);
          }
          if (ancienneVersion < 8) {
            await _creerTableModesPaiement(db);
            await _creerModesParDefaut(db);
          }
          if (ancienneVersion < 9) {
            await _creerTableComptes(db);
          }
          if (ancienneVersion < 10) {
            await _creerTablesAssociations(db);
          }
          if (ancienneVersion < 11) {
            await _migrerClasses(db);
          }
          if (ancienneVersion < 12) {
            await _creerTablesAchats(db);
          }
          if (ancienneVersion < 13) {
            await _creerTablesVentes(db);
          }
          if (ancienneVersion < 14) {
            await _creerTablesImpression(db);
          }
        },
      ),
    );

    // À chaque démarrage : le catalogue du code est recopié dans la base
    await _synchroniserPermissions(_db!);
    await rafraichirRoles();
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
    // Le premier compte (administrateur) se crée sans être connecté
    if (await aDesUtilisateurs()) {
      Session.exiger('utilisateurs.gerer');
    }

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
    Session.exiger('agences.gerer');
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
    Session.exiger('utilisateurs.gerer');
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
    Session.exiger('utilisateurs.gerer');
    final hash = BCrypt.hashpw(nouveauMotDePasse, BCrypt.gensalt());
    await db.update(
      'utilisateurs',
      {'mot_de_passe_hash': hash},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> _creerTablesRoles(Database db) async {
    await db.execute('''
      CREATE TABLE roles (
        code TEXT PRIMARY KEY,
        libelle TEXT NOT NULL UNIQUE,
        systeme INTEGER NOT NULL DEFAULT 0,
        cree_le TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE permissions (
        code TEXT PRIMARY KEY,
        libelle TEXT NOT NULL,
        groupe TEXT NOT NULL,
        admin_seulement INTEGER NOT NULL DEFAULT 0,
        ordre INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE role_permissions (
        role_code TEXT NOT NULL,
        permission_code TEXT NOT NULL,
        PRIMARY KEY (role_code, permission_code),
        FOREIGN KEY (role_code) REFERENCES roles(code) ON DELETE CASCADE,
        FOREIGN KEY (permission_code) REFERENCES permissions(code) ON DELETE CASCADE
      )
    ''');
  }

  // Crée les rôles de base et leurs droits de départ
  static Future<void> _initialiserRoles(Database db) async {
    // Les permissions doivent exister avant d'être accordées
    await _synchroniserPermissions(db);

    final maintenant = DateTime.now().toIso8601String();
    final roles = <Map<String, Object>>[
      {'code': 'admin', 'libelle': 'Administrateur', 'systeme': 1},
      {'code': 'vendeur', 'libelle': 'Vendeur', 'systeme': 0},
      {'code': 'comptable', 'libelle': 'Comptable', 'systeme': 0},
      {'code': 'magasinier', 'libelle': 'Magasinier', 'systeme': 0},
    ];

    for (final role in roles) {
      await db.insert('roles', {
        ...role,
        'cree_le': maintenant,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    for (final entree in droitsParDefaut.entries) {
      for (final permission in entree.value) {
        await db.insert('role_permissions', {
          'role_code': entree.key,
          'permission_code': permission,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
  }

  // Recopie le catalogue du code dans la table permissions
  static Future<void> _synchroniserPermissions(Database db) async {
    for (var i = 0; i < cataloguePermissions.length; i++) {
      final p = cataloguePermissions[i];
      await db.execute(
        '''
        INSERT INTO permissions (code, libelle, groupe, admin_seulement, ordre)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(code) DO UPDATE SET
          libelle = excluded.libelle,
          groupe = excluded.groupe,
          admin_seulement = excluded.admin_seulement,
          ordre = excluded.ordre
      ''',
        [p.code, p.libelle, p.groupe, p.adminSeulement ? 1 : 0, i],
      );
    }

    // On supprime les permissions qui ne sont plus dans le code
    final codes = cataloguePermissions.map((p) => p.code).toList();
    final marques = List.filled(codes.length, '?').join(', ');
    await db.delete(
      'permissions',
      where: 'code NOT IN ($marques)',
      whereArgs: codes,
    );
  }

  // Les droits d'un rôle (l'administrateur a toutes les permissions)
  static Future<Set<String>> droitsDuRole(String roleCode) async {
    if (roleCode == 'admin') {
      final lignes = await db.query('permissions', columns: ['code']);
      return lignes.map((m) => m['code'] as String).toSet();
    }

    final lignes = await db.query(
      'role_permissions',
      columns: ['permission_code'],
      where: 'role_code = ?',
      whereArgs: [roleCode],
    );
    return lignes.map((m) => m['permission_code'] as String).toSet();
  }

  // ---------- Rôles et droits ----------

  // Recharge la liste des rôles en mémoire (listes déroulantes, libellés)
  static Future<void> rafraichirRoles() async {
    final lignes = await db.query('roles', orderBy: 'systeme, libelle');
    rolesDisponibles
      ..clear()
      ..addEntries(
        lignes.map(
          (m) => MapEntry(m['code'] as String, m['libelle'] as String),
        ),
      );
  }

  static Future<List<Role>> listerRoles() async {
    final lignes = await db.rawQuery('''
      SELECT r.code, r.libelle, r.systeme,
             (SELECT COUNT(*) FROM utilisateurs u WHERE u.role = r.code) AS nb
      FROM roles r
      ORDER BY r.systeme, r.libelle
    ''');

    return lignes
        .map(
          (m) => Role(
            code: m['code'] as String,
            libelle: m['libelle'] as String,
            systeme: (m['systeme'] as int) == 1,
            nbUtilisateurs: m['nb'] as int,
          ),
        )
        .toList();
  }

  static Future<List<Permission>> listerPermissions() async {
    final lignes = await db.query('permissions', orderBy: 'ordre');
    return lignes
        .map(
          (m) => Permission(
            code: m['code'] as String,
            libelle: m['libelle'] as String,
            groupe: m['groupe'] as String,
            adminSeulement: (m['admin_seulement'] as int) == 1,
          ),
        )
        .toList();
  }

  // Toutes les paires accordées, sous la forme "role|permission"
  static Future<Set<String>> droitsAccordes() async {
    final lignes = await db.query('role_permissions');
    return lignes
        .map((m) => '${m['role_code']}|${m['permission_code']}')
        .toSet();
  }

  static Future<void> definirDroit(
    String roleCode,
    String permissionCode,
    bool accorde,
  ) async {
    Session.exiger('droits.gerer');
    if (roleCode == 'admin') {
      throw Exception("Les droits de l'administrateur ne sont pas modifiables");
    }

    if (accorde) {
      final p = await db.query(
        'permissions',
        columns: ['admin_seulement'],
        where: 'code = ?',
        whereArgs: [permissionCode],
        limit: 1,
      );
      if (p.isEmpty) throw Exception('Permission inconnue');
      if (p.first['admin_seulement'] == 1) {
        throw Exception("Cette permission est réservée à l'administrateur");
      }

      await db.insert('role_permissions', {
        'role_code': roleCode,
        'permission_code': permissionCode,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await db.delete(
        'role_permissions',
        where: 'role_code = ? AND permission_code = ?',
        whereArgs: [roleCode, permissionCode],
      );
    }
  }

  // Vérifie qu'aucun autre rôle ne porte déjà ce nom
  static Future<void> _verifierLibelleLibre(
    String libelle, {
    String? sauf,
  }) async {
    final lignes = await db.query(
      'roles',
      columns: ['code'],
      where: sauf == null
          ? 'LOWER(libelle) = LOWER(?)'
          : 'LOWER(libelle) = LOWER(?) AND code != ?',
      whereArgs: sauf == null ? [libelle] : [libelle, sauf],
    );
    if (lignes.isNotEmpty) throw Exception('Un rôle porte déjà ce nom');
  }

  // Fabrique un code simple à partir d'un nom : "Chef de rayon" -> "chef_de_rayon"
  static String _versCode(String texte) {
    const accents = {
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'î': 'i',
      'ï': 'i',
      'ô': 'o',
      'ö': 'o',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
    };
    var t = texte.toLowerCase();
    accents.forEach((a, b) => t = t.replaceAll(a, b));
    t = t.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    t = t.replaceAll(RegExp(r'^_+|_+$'), '');
    return t.isEmpty ? 'role' : t;
  }

  static Future<void> creerRole(String libelle) async {
    Session.exiger('droits.gerer');
    final propre = libelle.trim();
    if (propre.isEmpty) throw Exception('Le nom du rôle est vide');
    await _verifierLibelleLibre(propre);

    // Le code doit être unique : on ajoute un numéro si besoin
    final base = _versCode(propre);
    var code = base;
    var numero = 2;
    while ((await db.query(
      'roles',
      columns: ['code'],
      where: 'code = ?',
      whereArgs: [code],
    )).isNotEmpty) {
      code = '${base}_$numero';
      numero++;
    }

    await db.insert('roles', {
      'code': code,
      'libelle': propre,
      'systeme': 0,
      'cree_le': DateTime.now().toIso8601String(),
    });
    await rafraichirRoles();
  }

  static Future<void> renommerRole(String code, String nouveauLibelle) async {
    Session.exiger('droits.gerer');
    final propre = nouveauLibelle.trim();
    if (propre.isEmpty) throw Exception('Le nom du rôle est vide');

    final role = await db.query(
      'roles',
      where: 'code = ?',
      whereArgs: [code],
      limit: 1,
    );
    if (role.isEmpty) throw Exception('Rôle introuvable');
    if (role.first['systeme'] == 1) {
      throw Exception('Un rôle système ne peut pas être renommé');
    }

    await _verifierLibelleLibre(propre, sauf: code);
    await db.update(
      'roles',
      {'libelle': propre},
      where: 'code = ?',
      whereArgs: [code],
    );
    await rafraichirRoles();
  }

  static Future<void> supprimerRole(String code) async {
    Session.exiger('droits.gerer');
    final role = await db.query(
      'roles',
      where: 'code = ?',
      whereArgs: [code],
      limit: 1,
    );
    if (role.isEmpty) throw Exception('Rôle introuvable');
    if (role.first['systeme'] == 1) {
      throw Exception('Un rôle système ne peut pas être supprimé');
    }

    final r = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM utilisateurs WHERE role = ?',
      [code],
    );
    final nb = r.first['n'] as int;
    if (nb > 0) {
      throw Exception(
        "Ce rôle est utilisé par $nb utilisateur(s). "
        "Changez d'abord leur rôle.",
      );
    }

    // Les droits du rôle disparaissent avec lui (ON DELETE CASCADE)
    await db.delete('roles', where: 'code = ?', whereArgs: [code]);
    await rafraichirRoles();
  }

  // ---------- Articles ----------

  static Future<void> _creerTableArticles(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS articles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        designation TEXT NOT NULL,
        categorie TEXT,
        unite TEXT NOT NULL DEFAULT 'pièce',
        prix_achat INTEGER,
        prix_vente INTEGER NOT NULL DEFAULT 0,
        seuil_alerte REAL NOT NULL DEFAULT 0,
        actif INTEGER NOT NULL DEFAULT 1,
        cree_le TEXT NOT NULL
      )
    ''');
  }

  static Future<List<Article>> listerArticles({
    String recherche = '',
    bool inclureInactifs = false,
  }) async {
    if (!Session.peut('articles.voir') && !Session.peut('articles.gerer')) {
      throw Exception('Action non autorisée');
    }

    final conditions = <String>[];
    final args = <Object>[];

    if (!inclureInactifs) conditions.add('a.actif = 1');

    final texte = recherche.trim();
    if (texte.isNotEmpty) {
      conditions.add(
        '(a.code LIKE ? OR a.designation LIKE ? OR cl.nom LIKE ?)',
      );
      args.addAll(['%$texte%', '%$texte%', '%$texte%']);
    }

    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

    final lignes = await db.rawQuery('''
      SELECT a.id, a.code, a.designation, a.classe_id, cl.nom AS categorie,
             a.unite, a.prix_achat, a.prix_vente, a.seuil_alerte, a.actif
      FROM articles a
      LEFT JOIN classes_articles cl ON cl.id = a.classe_id
      $where
      ORDER BY a.designation COLLATE NOCASE
    ''', args);

    // Le prix d'achat n'est lu que pour ceux qui ont le droit de le voir
    final voirPrixAchat = Session.peut('achats.prix_achat_voir');
    return lignes
        .map((m) => Article.fromMap(m, avecPrixAchat: voirPrixAchat))
        .toList();
  }

  // Les catégories déjà utilisées (pour les proposer à la saisie)
  static Future<List<String>> categoriesArticles() async {
    final lignes = await db.rawQuery('''
      SELECT DISTINCT categorie FROM articles
      WHERE categorie IS NOT NULL AND categorie != ''
      ORDER BY categorie COLLATE NOCASE
    ''');
    return lignes.map((m) => m['categorie'] as String).toList();
  }

  // Retourne le matricule attribué à l'article
  // Retourne le matricule attribué à l'article
  static Future<String> creerArticle({
    required String designation,
    int? classeId,
    required String unite,
    int? prixAchat,
    required int prixVente,
    required double seuilAlerte,
  }) async {
    Session.exiger('articles.gerer');

    return db.transaction((txn) async {
      final code = await _prochainMatricule(txn, 'articles');

      await txn.insert('articles', {
        'code': code,
        'designation': designation,
        'classe_id': classeId,
        'unite': unite,
        'prix_achat': Session.peut('achats.prix_achat_voir') ? prixAchat : null,
        'prix_vente': prixVente,
        'seuil_alerte': seuilAlerte,
        'actif': 1,
        'cree_le': DateTime.now().toIso8601String(),
      });

      return code;
    });
  }

  static Future<void> modifierArticle({
    required int id,
    required String designation,
    int? classeId,
    required String unite,
    int? prixAchat,
    required int prixVente,
    required double seuilAlerte,
    required bool actif,
  }) async {
    Session.exiger('articles.gerer');

    final valeurs = <String, Object?>{
      'designation': designation,
      'classe_id': classeId,
      'unite': unite,
      'prix_vente': prixVente,
      'seuil_alerte': seuilAlerte,
      'actif': actif ? 1 : 0,
    };

    // Sans le droit de voir les prix d'achat, on ne les modifie pas
    if (Session.peut('achats.prix_achat_voir')) {
      valeurs['prix_achat'] = prixAchat;
    }

    await db.update('articles', valeurs, where: 'id = ?', whereArgs: [id]);
  }

  // Matricule automatique : AAMMJJ + numéro du jour sur 5 chiffres
  // Exemple : 26 (année) 10 (mois) 26 (jour) + 00001 -> 26102600001
  static Future<String> _prochainMatricule(
    DatabaseExecutor executeur,
    String table,
  ) async {
    final maintenant = DateTime.now();
    final annee = (maintenant.year % 100).toString().padLeft(2, '0');
    final mois = maintenant.month.toString().padLeft(2, '0');
    final jour = maintenant.day.toString().padLeft(2, '0');
    final prefixe = '$annee$mois$jour';

    // Le plus grand matricule déjà attribué aujourd'hui (11 chiffres)
    final lignes = await executeur.rawQuery(
      'SELECT MAX(code) AS dernier FROM $table WHERE code GLOB ?',
      ['${prefixe}[0-9][0-9][0-9][0-9][0-9]'],
    );

    final dernier = lignes.first['dernier'] as String?;
    final numero = dernier == null ? 1 : int.parse(dernier.substring(6)) + 1;

    if (numero > 99999) {
      throw Exception('Limite de 99 999 matricules par jour atteinte');
    }

    return '$prefixe${numero.toString().padLeft(5, '0')}';
  }

  // Aperçu du prochain matricule (le vrai est attribué à l'enregistrement)
  static Future<String> apercuProchainMatriculeArticle() =>
      _prochainMatricule(db, 'articles');
  // ---------- Stock ----------

  static Future<void> _creerTablesStock(Database db) async {
    // La quantité actuelle d'un article dans une agence
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock (
        article_id INTEGER NOT NULL,
        agence_id INTEGER NOT NULL,
        quantite REAL NOT NULL DEFAULT 0,
        PRIMARY KEY (article_id, agence_id),
        FOREIGN KEY (article_id) REFERENCES articles(id),
        FOREIGN KEY (agence_id) REFERENCES agences(id)
      )
    ''');

    // L'historique : chaque changement de quantité, jamais modifié
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mouvements_stock (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        article_id INTEGER NOT NULL,
        agence_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        quantite REAL NOT NULL,
        quantite_avant REAL NOT NULL,
        quantite_apres REAL NOT NULL,
        motif TEXT NOT NULL,
        commentaire TEXT,
        utilisateur_id INTEGER NOT NULL,
        cree_le TEXT NOT NULL,
        FOREIGN KEY (article_id) REFERENCES articles(id),
        FOREIGN KEY (agence_id) REFERENCES agences(id),
        FOREIGN KEY (utilisateur_id) REFERENCES utilisateurs(id)
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_mouvements_agence
      ON mouvements_stock (agence_id, id)
    ''');
  }

  // Arrondi à 3 décimales (évite 0.1 + 0.2 = 0.30000000000000004)
  static double _arrondir(double valeur) =>
      double.parse(valeur.toStringAsFixed(3));

  static void _exigerVueStock() {
    if (!Session.peut('stock.voir') &&
        !Session.peut('stock.modifier') &&
        !Session.peut('stock.ajuster')) {
      throw Exception('Action non autorisée');
    }
  }

  // Le stock de l'agence courante : tous les articles actifs
  static Future<List<LigneStock>> listerStock({
    String recherche = '',
    bool alertesSeulement = false,
  }) async {
    _exigerVueStock();

    final agence = Session.agenceCourante;
    if (agence == null) throw Exception('Aucune agence sélectionnée');

    final args = <Object>[agence.id];
    var filtre = '';

    final texte = recherche.trim();
    if (texte.isNotEmpty) {
      filtre = 'AND (a.code LIKE ? OR a.designation LIKE ? OR cl.nom LIKE ?)';
      args.addAll(['%$texte%', '%$texte%', '%$texte%']);
    }

    final lignes = await db.rawQuery('''
      SELECT a.id, a.code, a.designation, cl.nom AS categorie, a.unite,
             a.seuil_alerte, COALESCE(s.quantite, 0) AS quantite
      FROM articles a
      LEFT JOIN classes_articles cl ON cl.id = a.classe_id
      LEFT JOIN stock s ON s.article_id = a.id AND s.agence_id = ?
      WHERE a.actif = 1 $filtre
      ORDER BY a.designation COLLATE NOCASE
    ''', args);

    final liste = lignes.map(LigneStock.fromMap).toList();
    return alertesSeulement
        ? liste.where((l) => l.enRupture || l.enAlerte).toList()
        : liste;
  }

  // Enregistre un mouvement et met le stock à jour. Retourne son matricule.
  //  - 'entree'     : quantite = quantité reçue
  //  - 'sortie'     : quantite = quantité sortie
  //  - 'ajustement' : quantite = quantité réellement comptée
  // Applique un mouvement de stock dans une transaction. Aucun contrôle de
  // droit ici : l'appelant l'a déjà fait. Retourne le matricule du mouvement.
  static Future<String> _mouvementStock(
    Transaction txn, {
    required int articleId,
    required int agenceId,
    required int utilisateurId,
    required String type, // 'entree', 'sortie' ou 'ajustement'
    required double quantite,
    required String motif,
    String? commentaire,
    String? sourceType, // par exemple 'achat'
    int? sourceId,
  }) async {
    final q = _arrondir(quantite);

    final article = await txn.query(
      'articles',
      columns: ['actif'],
      where: 'id = ?',
      whereArgs: [articleId],
      limit: 1,
    );
    if (article.isEmpty) throw Exception('Article introuvable');
    if (article.first['actif'] != 1) {
      throw Exception('Cet article est désactivé');
    }

    final actuel = await txn.query(
      'stock',
      columns: ['quantite'],
      where: 'article_id = ? AND agence_id = ?',
      whereArgs: [articleId, agenceId],
      limit: 1,
    );
    final avant = actuel.isEmpty
        ? 0.0
        : (actuel.first['quantite'] as num).toDouble();

    double apres;
    switch (type) {
      case 'entree':
        if (q <= 0) throw Exception('La quantité doit être supérieure à zéro');
        apres = _arrondir(avant + q);
      case 'sortie':
        if (q <= 0) throw Exception('La quantité doit être supérieure à zéro');
        if (q > avant) {
          throw Exception(
            'Stock insuffisant (disponible : ${formaterQuantite(avant)})',
          );
        }
        apres = _arrondir(avant - q);
      case 'ajustement':
        if (q < 0) {
          throw Exception('La quantité comptée ne peut pas être négative');
        }
        apres = q;
      default:
        throw Exception('Type de mouvement inconnu');
    }

    final ecart = _arrondir(apres - avant);
    if (type == 'ajustement' && ecart == 0) {
      throw Exception('La quantité comptée est identique au stock actuel');
    }

    await txn.execute(
      '''
      INSERT INTO stock (article_id, agence_id, quantite) VALUES (?, ?, ?)
      ON CONFLICT(article_id, agence_id) DO UPDATE SET quantite = excluded.quantite
    ''',
      [articleId, agenceId, apres],
    );

    final code = await _prochainMatricule(txn, 'mouvements_stock');
    await txn.insert('mouvements_stock', {
      'code': code,
      'article_id': articleId,
      'agence_id': agenceId,
      'type': type,
      'quantite': ecart,
      'quantite_avant': avant,
      'quantite_apres': apres,
      'motif': motif,
      'commentaire': _videEnNull(commentaire),
      'utilisateur_id': utilisateurId,
      'cree_le': DateTime.now().toIso8601String(),
      'source_type': sourceType,
      'source_id': sourceId,
    });

    return code;
  }

  // Un mouvement saisi à la main depuis la page Stock
  static Future<String> enregistrerMouvement({
    required int articleId,
    required String type,
    required double quantite,
    required String motif,
    String? commentaire,
  }) async {
    Session.exiger(type == 'entree' ? 'stock.modifier' : 'stock.ajuster');

    final agence = Session.agenceCourante;
    final utilisateur = Session.utilisateurCourant;
    if (agence == null || utilisateur == null) {
      throw Exception('Aucune agence sélectionnée');
    }

    return db.transaction(
      (txn) => _mouvementStock(
        txn,
        articleId: articleId,
        agenceId: agence.id,
        utilisateurId: utilisateur.id,
        type: type,
        quantite: quantite,
        motif: motif,
        commentaire: commentaire,
      ),
    );
  }

  // L'historique de l'agence courante (le plus récent d'abord)
  static Future<List<Mouvement>> listerMouvements({
    int? articleId,
    int limite = 200,
  }) async {
    _exigerVueStock();

    final agence = Session.agenceCourante;
    if (agence == null) throw Exception('Aucune agence sélectionnée');

    final args = <Object>[agence.id];
    var filtre = '';
    if (articleId != null) {
      filtre = 'AND m.article_id = ?';
      args.add(articleId);
    }
    args.add(limite);

    final lignes = await db.rawQuery('''
      SELECT m.code, m.type, m.quantite, m.quantite_avant, m.quantite_apres,
             m.motif, m.commentaire, m.cree_le,
             a.designation, a.code AS article_code, a.unite,
             u.nom_complet AS utilisateur
      FROM mouvements_stock m
      INNER JOIN articles a ON a.id = m.article_id
      INNER JOIN utilisateurs u ON u.id = m.utilisateur_id
      WHERE m.agence_id = ? $filtre
      ORDER BY m.id DESC
      LIMIT ?
    ''', args);

    return lignes.map(Mouvement.fromMap).toList();
  }

  // ---------- Clients et fournisseurs ----------

  static Future<void> _creerTableTiers(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tiers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        nom TEXT NOT NULL,
        est_client INTEGER NOT NULL DEFAULT 0,
        est_fournisseur INTEGER NOT NULL DEFAULT 0,
        telephone TEXT,
        email TEXT,
        ville TEXT,
        adresse TEXT,
        plafond_credit INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        systeme INTEGER NOT NULL DEFAULT 0,
        actif INTEGER NOT NULL DEFAULT 1,
        cree_le TEXT NOT NULL
      )
    ''');
  }

  // Les comptes système : pour les ventes et achats sans tiers précis
  static Future<void> _creerTiersParDefaut(Database db) async {
    final existants = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM tiers WHERE systeme = 1',
    );
    if ((existants.first['n'] as int) > 0) return;

    final defauts = <Map<String, Object>>[
      {'nom': 'Client comptant', 'est_client': 1, 'est_fournisseur': 0},
      {'nom': 'Fournisseur occasionnel', 'est_client': 0, 'est_fournisseur': 1},
    ];

    for (final t in defauts) {
      final code = await _prochainMatricule(db, 'tiers');
      await db.insert('tiers', {
        ...t,
        'code': code,
        'systeme': 1,
        'actif': 1,
        'cree_le': DateTime.now().toIso8601String(),
      });
    }
  }

  // type : 'client' ou 'fournisseur'
  static Future<List<Tiers>> listerTiers({
    required String type,
    String recherche = '',
    bool inclureInactifs = false,
  }) async {
    if (!peutVoirTiers(type)) throw Exception('Action non autorisée');

    final conditions = <String>[
      type == 'client' ? 'est_client = 1' : 'est_fournisseur = 1',
    ];
    final args = <Object>[];

    if (!inclureInactifs) conditions.add('actif = 1');

    final texte = recherche.trim();
    if (texte.isNotEmpty) {
      conditions.add(
        '(code LIKE ? OR nom LIKE ? OR telephone LIKE ? OR ville LIKE ?)',
      );
      args.addAll(List.filled(4, '%$texte%'));
    }

    final lignes = await db.query(
      'tiers',
      where: conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'nom COLLATE NOCASE',
    );
    return lignes.map(Tiers.fromMap).toList();
  }

  // Retourne le matricule attribué
  static Future<String> creerTiers({
    required String nom,
    required bool estClient,
    required bool estFournisseur,
    String? telephone,
    String? email,
    String? ville,
    String? adresse,
    int plafondCredit = 0,
    String? notes,
  }) async {
    if (!estClient && !estFournisseur) {
      throw Exception('Choisissez au moins un type : client ou fournisseur');
    }
    if (estClient) Session.exiger('clients.gerer');
    if (estFournisseur) Session.exiger('fournisseurs.gerer');

    return db.transaction((txn) async {
      final code = await _prochainMatricule(txn, 'tiers');

      await txn.insert('tiers', {
        'code': code,
        'nom': nom,
        'est_client': estClient ? 1 : 0,
        'est_fournisseur': estFournisseur ? 1 : 0,
        'telephone': _videEnNull(telephone),
        'email': _videEnNull(email),
        'ville': _videEnNull(ville),
        'adresse': _videEnNull(adresse),
        'plafond_credit': estClient ? plafondCredit : 0,
        'notes': _videEnNull(notes),
        'systeme': 0,
        'actif': 1,
        'cree_le': DateTime.now().toIso8601String(),
      });

      return code;
    });
  }

  static Future<void> modifierTiers({
    required int id,
    required String nom,
    required bool estClient,
    required bool estFournisseur,
    String? telephone,
    String? email,
    String? ville,
    String? adresse,
    int plafondCredit = 0,
    String? notes,
    required bool actif,
  }) async {
    if (!estClient && !estFournisseur) {
      throw Exception('Choisissez au moins un type : client ou fournisseur');
    }

    final actuel = await db.query(
      'tiers',
      columns: ['systeme', 'est_client', 'est_fournisseur'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (actuel.isEmpty) throw Exception('Tiers introuvable');
    if (actuel.first['systeme'] == 1) {
      throw Exception('Un compte système ne peut pas être modifié');
    }

    // Il faut le droit de gérer chaque rôle concerné, ancien ou nouveau
    if (estClient || actuel.first['est_client'] == 1) {
      Session.exiger('clients.gerer');
    }
    if (estFournisseur || actuel.first['est_fournisseur'] == 1) {
      Session.exiger('fournisseurs.gerer');
    }

    await db.update(
      'tiers',
      {
        'nom': nom,
        'est_client': estClient ? 1 : 0,
        'est_fournisseur': estFournisseur ? 1 : 0,
        'telephone': _videEnNull(telephone),
        'email': _videEnNull(email),
        'ville': _videEnNull(ville),
        'adresse': _videEnNull(adresse),
        'plafond_credit': estClient ? plafondCredit : 0,
        'notes': _videEnNull(notes),
        'actif': actif ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------- Modes de paiement ----------

  static Future<void> _creerTableModesPaiement(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS modes_paiement (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        libelle TEXT NOT NULL UNIQUE,
        type TEXT NOT NULL,
        reference_obligatoire INTEGER NOT NULL DEFAULT 0,
        systeme INTEGER NOT NULL DEFAULT 0,
        actif INTEGER NOT NULL DEFAULT 1,
        ordre INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  static Future<void> _creerModesParDefaut(Database db) async {
    final defauts = <Map<String, Object>>[
      {
        'code': 'especes',
        'libelle': 'Espèces',
        'type': 'caisse',
        'reference_obligatoire': 0,
        'systeme': 1,
      },
      {
        'code': 'orange_money',
        'libelle': 'Orange Money',
        'type': 'mobile',
        'reference_obligatoire': 1,
        'systeme': 0,
      },
      {
        'code': 'mobile_money',
        'libelle': 'Mobile Money',
        'type': 'mobile',
        'reference_obligatoire': 1,
        'systeme': 0,
      },
      {
        'code': 'banque',
        'libelle': 'Banque',
        'type': 'banque',
        'reference_obligatoire': 1,
        'systeme': 0,
      },
    ];

    for (var i = 0; i < defauts.length; i++) {
      await db.insert('modes_paiement', {
        ...defauts[i],
        'actif': 1,
        'ordre': i + 1,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // Aucun droit exigé : tous les utilisateurs en ont besoin pour encaisser
  static Future<List<ModePaiement>> listerModesPaiement({
    bool inclureInactifs = false,
  }) async {
    final lignes = await db.query(
      'modes_paiement',
      where: inclureInactifs ? null : 'actif = 1',
      orderBy: 'ordre, id',
    );
    return lignes.map(ModePaiement.fromMap).toList();
  }

  // Vérifie qu'aucun autre mode ne porte déjà ce nom
  static Future<void> _verifierModeLibelleLibre(
    String libelle, {
    int? sauf,
  }) async {
    final lignes = await db.query(
      'modes_paiement',
      columns: ['id'],
      where: sauf == null
          ? 'LOWER(libelle) = LOWER(?)'
          : 'LOWER(libelle) = LOWER(?) AND id != ?',
      whereArgs: sauf == null ? [libelle] : [libelle, sauf],
    );
    if (lignes.isNotEmpty) {
      throw Exception('Un mode de paiement porte déjà ce nom');
    }
  }

  // Ajoute un numéro (_2, _3...) si le code existe déjà
  static Future<String> _codeLibre(String table, String base) async {
    var code = base;
    var numero = 2;
    while ((await db.query(
      table,
      columns: ['code'],
      where: 'code = ?',
      whereArgs: [code],
    )).isNotEmpty) {
      code = '${base}_$numero';
      numero++;
    }
    return code;
  }

  static Future<void> creerModePaiement({
    required String libelle,
    required String type,
    required bool referenceObligatoire,
  }) async {
    Session.exiger('paiements.gerer');

    final propre = libelle.trim();
    if (propre.isEmpty) throw Exception('Le nom est vide');
    if (!typesTresorerie.containsKey(type)) throw Exception('Type inconnu');
    await _verifierModeLibelleLibre(propre);

    final code = await _codeLibre('modes_paiement', _versCode(propre));
    final r = await db.rawQuery(
      'SELECT COALESCE(MAX(ordre), 0) + 1 AS suivant FROM modes_paiement',
    );

    await db.insert('modes_paiement', {
      'code': code,
      'libelle': propre,
      'type': type,
      'reference_obligatoire': referenceObligatoire ? 1 : 0,
      'systeme': 0,
      'actif': 1,
      'ordre': r.first['suivant'],
    });
  }

  static Future<void> modifierModePaiement({
    required int id,
    required String libelle,
    required String type,
    required bool referenceObligatoire,
    required bool actif,
  }) async {
    Session.exiger('paiements.gerer');

    final propre = libelle.trim();
    if (propre.isEmpty) throw Exception('Le nom est vide');
    if (!typesTresorerie.containsKey(type)) throw Exception('Type inconnu');

    final lignes = await db.query(
      'modes_paiement',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (lignes.isEmpty) throw Exception('Mode de paiement introuvable');

    if (lignes.first['systeme'] == 1) {
      if (type != lignes.first['type']) {
        throw Exception('Le type du mode système ne peut pas changer');
      }
      if (!actif) {
        throw Exception('Le mode système ne peut pas être désactivé');
      }
    }

    await _verifierModeLibelleLibre(propre, sauf: id);

    await db.update(
      'modes_paiement',
      {
        'libelle': propre,
        'type': type,
        'reference_obligatoire': referenceObligatoire ? 1 : 0,
        'actif': actif ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // sens : -1 pour monter, +1 pour descendre
  static Future<void> deplacerModePaiement(int id, int sens) async {
    Session.exiger('paiements.gerer');

    final modes = await db.query(
      'modes_paiement',
      columns: ['id'],
      orderBy: 'ordre, id',
    );
    final ids = modes.map((m) => m['id'] as int).toList();

    final i = ids.indexOf(id);
    final j = i + sens;
    if (i < 0 || j < 0 || j >= ids.length) return;

    final temporaire = ids[i];
    ids[i] = ids[j];
    ids[j] = temporaire;

    // On renumérote tout : 1, 2, 3...
    await db.transaction((txn) async {
      for (var k = 0; k < ids.length; k++) {
        await txn.update(
          'modes_paiement',
          {'ordre': k + 1},
          where: 'id = ?',
          whereArgs: [ids[k]],
        );
      }
    });
  }

  // ---------- Plan comptable ----------

  static Future<void> _creerTableComptes(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS comptes_comptables (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        numero TEXT NOT NULL UNIQUE,
        intitule TEXT NOT NULL,
        classe INTEGER NOT NULL,
        actif INTEGER NOT NULL DEFAULT 1,
        cree_le TEXT NOT NULL
      )
    ''');
  }

  static void _exigerVueCompta() {
    if (!Session.peut('comptabilite.voir') &&
        !Session.peut('comptabilite.gerer')) {
      throw Exception('Action non autorisée');
    }
  }

  // Tous les comptes, dans l'ordre des numéros
  static Future<List<CompteComptable>> listerComptes() async {
    _exigerVueCompta();

    final lignes = await db.query('comptes_comptables', orderBy: 'numero');
    final numeros = lignes.map((m) => m['numero'] as String).toList();

    final comptes = <CompteComptable>[];
    for (var i = 0; i < lignes.length; i++) {
      final m = lignes[i];
      // Dans l'ordre des numéros, les sous-comptes suivent leur compte :
      // si le suivant commence par ce numéro, c'est un compte de regroupement
      final regroupement =
          i + 1 < numeros.length && numeros[i + 1].startsWith(numeros[i]);

      comptes.add(
        CompteComptable(
          id: m['id'] as int,
          numero: numeros[i],
          intitule: m['intitule'] as String,
          classe: m['classe'] as int,
          actif: (m['actif'] as int) == 1,
          imputable: !regroupement,
        ),
      );
    }
    return comptes;
  }

  // numéro -> intitulé, pour comparer avec un fichier à importer
  static Future<Map<String, String>> comptesExistants() async {
    Session.exiger('comptabilite.gerer');
    final lignes = await db.query(
      'comptes_comptables',
      columns: ['numero', 'intitule'],
    );
    return {
      for (final m in lignes) m['numero'] as String: m['intitule'] as String,
    };
  }

  static Future<void> creerCompte({
    required String numero,
    required String intitule,
  }) async {
    Session.exiger('comptabilite.gerer');

    final n = numero.trim();
    final texte = intitule.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (!RegExp(r'^[1-9]\d{1,9}$').hasMatch(n)) {
      throw Exception(
        'Numéro invalide : de 2 à 10 chiffres, sans zéro au début',
      );
    }
    if (texte.isEmpty) throw Exception("L'intitulé est vide");

    final existe = await db.query(
      'comptes_comptables',
      columns: ['id'],
      where: 'numero = ?',
      whereArgs: [n],
      limit: 1,
    );
    if (existe.isNotEmpty) throw Exception('Ce numéro de compte existe déjà');

    await db.insert('comptes_comptables', {
      'numero': n,
      'intitule': texte,
      'classe': int.parse(n[0]),
      'actif': 1,
      'cree_le': DateTime.now().toIso8601String(),
    });
  }

  // Le numéro ne change jamais : des associations pourront s'appuyer dessus
  static Future<void> modifierCompte({
    required int id,
    required String intitule,
    required bool actif,
  }) async {
    Session.exiger('comptabilite.gerer');

    final texte = intitule.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (texte.isEmpty) throw Exception("L'intitulé est vide");

    await db.update(
      'comptes_comptables',
      {'intitule': texte, 'actif': actif ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Ajoute les nouveaux comptes, met à jour les intitulés différents.
  // Ne supprime jamais rien. Tout ou rien (transaction).
  static Future<ResultatImport> importerComptes(
    List<CompteAImporter> comptes,
  ) async {
    Session.exiger('comptabilite.gerer');

    var ajoutes = 0;
    var misAJour = 0;
    var inchanges = 0;

    await db.transaction((txn) async {
      final lignes = await txn.query(
        'comptes_comptables',
        columns: ['numero', 'intitule'],
      );
      final existants = {
        for (final m in lignes) m['numero'] as String: m['intitule'] as String,
      };

      final maintenant = DateTime.now().toIso8601String();
      final vus = <String>{};
      final lot = txn.batch();

      for (final c in comptes) {
        if (!RegExp(r'^[1-9]\d{1,9}$').hasMatch(c.numero)) {
          throw Exception('Numéro invalide : ${c.numero}');
        }
        if (c.intitule.trim().isEmpty) {
          throw Exception('Intitulé vide pour le compte ${c.numero}');
        }
        if (!vus.add(c.numero)) {
          throw Exception('Numéro en double : ${c.numero}');
        }

        final actuel = existants[c.numero];
        if (actuel == null) {
          lot.insert('comptes_comptables', {
            'numero': c.numero,
            'intitule': c.intitule,
            'classe': int.parse(c.numero[0]),
            'actif': 1,
            'cree_le': maintenant,
          });
          ajoutes++;
        } else if (actuel != c.intitule) {
          lot.update(
            'comptes_comptables',
            {'intitule': c.intitule},
            where: 'numero = ?',
            whereArgs: [c.numero],
          );
          misAJour++;
        } else {
          inchanges++;
        }
      }

      await lot.commit(noResult: true);
    });

    return ResultatImport(
      ajoutes: ajoutes,
      misAJour: misAJour,
      inchanges: inchanges,
    );
  }

  // ---------- Associations comptables ----------

  static Future<void> _creerTablesAssociations(Database db) async {
    // Un compte pour un poste, dans une portée : le défaut, ou une agence
    await db.execute('''
      CREATE TABLE IF NOT EXISTS associations_comptables (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        poste TEXT NOT NULL,
        portee TEXT NOT NULL DEFAULT 'defaut',
        portee_id INTEGER NOT NULL DEFAULT 0,
        compte_id INTEGER NOT NULL,
        cree_le TEXT NOT NULL,
        modifie_le TEXT NOT NULL,
        UNIQUE (poste, portee, portee_id),
        FOREIGN KEY (compte_id) REFERENCES comptes_comptables(id)
      )
    ''');

    // La trace de chaque changement, avec les numéros de compte de l'époque
    await db.execute('''
      CREATE TABLE IF NOT EXISTS historique_associations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        poste TEXT NOT NULL,
        portee TEXT NOT NULL,
        portee_id INTEGER NOT NULL,
        ancien_compte TEXT,
        nouveau_compte TEXT,
        utilisateur_id INTEGER NOT NULL,
        cree_le TEXT NOT NULL,
        FOREIGN KEY (utilisateur_id) REFERENCES utilisateurs(id)
      )
    ''');
  }

  // Les postes fixes + un poste par mode de paiement
  static Future<List<PosteComptable>> listerPostes() async {
    final modes = await listerModesPaiement(inclureInactifs: true);
    return [
      ...cataloguePostes,
      for (final m in modes)
        PosteComptable(
          'paiement.${m.code}',
          m.libelle,
          'Paiements',
          'Compte de trésorerie pour les paiements en ${m.libelle}',
          propositionsPaiement[m.type] ?? const [],
          parAgence: true,
        ),
    ];
  }

  static Future<List<Agence>> listerToutesLesAgences() async {
    _exigerVueCompta();
    final lignes = await db.query(
      'agences',
      where: 'actif = 1',
      orderBy: 'nom',
    );
    return lignes.map(Agence.fromMap).toList();
  }

  static Future<List<Association>> listerAssociations() async {
    _exigerVueCompta();
    final lignes = await db.rawQuery('''
      SELECT a.id, a.poste, a.portee, a.portee_id, a.compte_id,
             c.numero, c.intitule, ag.nom AS agence_nom, cl.nom AS classe_nom
      FROM associations_comptables a
      INNER JOIN comptes_comptables c ON c.id = a.compte_id
      LEFT JOIN agences ag ON a.portee = 'agence' AND ag.id = a.portee_id
      LEFT JOIN classes_articles cl ON a.portee = 'classe' AND cl.id = a.portee_id
      ORDER BY a.poste, a.portee, ag.nom, cl.nom
    ''');
    return lignes.map(Association.fromMap).toList();
  }

  static Future<void> _noterHistorique(
    DatabaseExecutor executeur,
    String poste,
    String portee,
    int porteeId,
    String? ancien,
    String? nouveau,
  ) async {
    await executeur.insert('historique_associations', {
      'poste': poste,
      'portee': portee,
      'portee_id': porteeId,
      'ancien_compte': ancien,
      'nouveau_compte': nouveau,
      'utilisateur_id': Session.utilisateurCourant!.id,
      'cree_le': DateTime.now().toIso8601String(),
    });
  }

  // Relie un poste à un compte (le crée ou remplace l'ancien). Tout est tracé.
  static Future<void> definirAssociation({
    required String poste,
    required int compteId,
    String portee = 'defaut', // 'defaut', 'agence' ou 'classe'
    int porteeId = 0,
  }) async {
    Session.exiger('comptabilite.gerer');

    final postes = await listerPostes();
    final definition = postes.where((p) => p.code == poste).toList();
    if (definition.isEmpty) throw Exception('Poste comptable inconnu');
    if (portee != 'defaut' && portee != 'agence' && portee != 'classe') {
      throw Exception('Portée inconnue');
    }
    if (portee == 'agence' && !definition.first.parAgence) {
      throw Exception("Ce poste n'accepte pas de compte par agence");
    }
    if (portee == 'classe' && !definition.first.parClasse) {
      throw Exception("Ce poste n'accepte pas de compte par classe d'articles");
    }
    final pid = portee == 'defaut' ? 0 : porteeId;

    await db.transaction((txn) async {
      final compte = await txn.query(
        'comptes_comptables',
        columns: ['numero', 'actif'],
        where: 'id = ?',
        whereArgs: [compteId],
        limit: 1,
      );
      if (compte.isEmpty) throw Exception('Compte introuvable');
      if (compte.first['actif'] != 1)
        throw Exception('Ce compte est désactivé');

      if (portee == 'agence') {
        final agence = await txn.query(
          'agences',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [pid],
          limit: 1,
        );
        if (agence.isEmpty) throw Exception('Agence introuvable');
      }

      if (portee == 'classe') {
        final classe = await txn.query(
          'classes_articles',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [pid],
          limit: 1,
        );
        if (classe.isEmpty) throw Exception('Classe introuvable');
      }

      final actuel = await txn.rawQuery(
        '''
        SELECT a.compte_id, c.numero
        FROM associations_comptables a
        INNER JOIN comptes_comptables c ON c.id = a.compte_id
        WHERE a.poste = ? AND a.portee = ? AND a.portee_id = ?
      ''',
        [poste, portee, pid],
      );

      if (actuel.isNotEmpty && actuel.first['compte_id'] == compteId) {
        return; // rien à changer
      }

      final maintenant = DateTime.now().toIso8601String();
      await txn.execute(
        '''
        INSERT INTO associations_comptables
          (poste, portee, portee_id, compte_id, cree_le, modifie_le)
        VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(poste, portee, portee_id) DO UPDATE SET
          compte_id = excluded.compte_id,
          modifie_le = excluded.modifie_le
      ''',
        [poste, portee, pid, compteId, maintenant, maintenant],
      );

      await _noterHistorique(
        txn,
        poste,
        portee,
        pid,
        actuel.isEmpty ? null : actuel.first['numero'] as String,
        compte.first['numero'] as String,
      );
    });
  }

  static Future<void> supprimerAssociation({
    required String poste,
    String portee = 'defaut',
    int porteeId = 0,
  }) async {
    Session.exiger('comptabilite.gerer');

    final pid = portee == 'defaut' ? 0 : porteeId;

    await db.transaction((txn) async {
      final actuel = await txn.rawQuery(
        '''
        SELECT c.numero
        FROM associations_comptables a
        INNER JOIN comptes_comptables c ON c.id = a.compte_id
        WHERE a.poste = ? AND a.portee = ? AND a.portee_id = ?
      ''',
        [poste, portee, pid],
      );
      if (actuel.isEmpty) return;

      await txn.delete(
        'associations_comptables',
        where: 'poste = ? AND portee = ? AND portee_id = ?',
        whereArgs: [poste, portee, pid],
      );

      await _noterHistorique(
        txn,
        poste,
        portee,
        pid,
        actuel.first['numero'] as String,
        null,
      );
    });
  }

  // Applique les comptes proposés aux postes qui n'ont encore aucun compte
  static Future<ResultatPropositions> appliquerPropositions() async {
    Session.exiger('comptabilite.gerer');

    final postes = await listerPostes();
    final comptes = await listerComptes();
    final associations = await listerAssociations();

    final parNumero = {for (final c in comptes) c.numero: c};
    final dejaAssocies = associations
        .where((a) => a.portee == 'defaut')
        .map((a) => a.poste)
        .toSet();

    var appliquees = 0;
    var ignorees = 0;

    for (final p in postes) {
      if (dejaAssocies.contains(p.code)) continue;

      // Le premier compte proposé qui existe, est actif et n'est pas
      // un compte de regroupement
      CompteComptable? trouve;
      for (final numero in p.propositions) {
        final c = parNumero[numero];
        if (c != null && c.actif && c.imputable) {
          trouve = c;
          break;
        }
      }

      if (trouve == null) {
        ignorees++;
        continue;
      }

      await definirAssociation(poste: p.code, compteId: trouve.id);
      appliquees++;
    }

    return ResultatPropositions(appliquees: appliquees, ignorees: ignorees);
  }

  static Future<List<HistoriqueAssociation>> listerHistorique({
    int limite = 300,
  }) async {
    _exigerVueCompta();
    final lignes = await db.rawQuery(
      '''
      SELECT h.poste, h.portee, h.ancien_compte, h.nouveau_compte, h.cree_le,
             u.nom_complet AS utilisateur, ag.nom AS agence_nom,
             cl.nom AS classe_nom
      FROM historique_associations h
      INNER JOIN utilisateurs u ON u.id = h.utilisateur_id
      LEFT JOIN agences ag ON h.portee = 'agence' AND ag.id = h.portee_id
      LEFT JOIN classes_articles cl ON h.portee = 'classe' AND cl.id = h.portee_id
      ORDER BY h.id DESC
      LIMIT ?
    ''',
      [limite],
    );
    return lignes.map(HistoriqueAssociation.fromMap).toList();
  }

  // ---------- Classes d'articles ----------

  // Crée la table, rattache les articles et reprend les anciennes catégories
  static Future<void> _migrerClasses(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS classes_articles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL UNIQUE,
        actif INTEGER NOT NULL DEFAULT 1,
        cree_le TEXT NOT NULL
      )
    ''');

    if (!await _colonneExiste(db, 'articles', 'classe_id')) {
      await db.execute(
        'ALTER TABLE articles ADD COLUMN classe_id INTEGER '
        'REFERENCES classes_articles(id)',
      );
    }

    // Les catégories saisies à la main deviennent des classes
    if (await _colonneExiste(db, 'articles', 'categorie')) {
      final articles = await db.rawQuery(
        'SELECT id, TRIM(categorie) AS categorie FROM articles '
        "WHERE categorie IS NOT NULL AND TRIM(categorie) != '' ORDER BY id",
      );

      final classes = <String, int>{}; // nom en minuscules -> numéro de classe
      final maintenant = DateTime.now().toIso8601String();

      for (final a in articles) {
        final nom = (a['categorie'] as String).replaceAll(RegExp(r'\s+'), ' ');
        final cle = nom.toLowerCase();

        var classeId = classes[cle];
        if (classeId == null) {
          classeId = await db.insert('classes_articles', {
            'nom': nom,
            'actif': 1,
            'cree_le': maintenant,
          });
          classes[cle] = classeId;
        }

        await db.update(
          'articles',
          {'classe_id': classeId},
          where: 'id = ?',
          whereArgs: [a['id']],
        );
      }

      // L'ancienne colonne est renommée : elle ne sert plus
      await db.execute(
        'ALTER TABLE articles RENAME COLUMN categorie TO categorie_ancienne',
      );
    }
  }

  // Lecture libre : la fiche article en a besoin
  static Future<List<ClasseArticle>> listerClasses({
    bool inclureInactives = false,
  }) async {
    final lignes = await db.rawQuery('''
      SELECT cl.id, cl.nom, cl.actif,
             (SELECT COUNT(*) FROM articles a WHERE a.classe_id = cl.id) AS nb
      FROM classes_articles cl
      ${inclureInactives ? '' : 'WHERE cl.actif = 1'}
      ORDER BY cl.nom COLLATE NOCASE
    ''');

    return lignes
        .map(
          (m) => ClasseArticle(
            id: m['id'] as int,
            nom: m['nom'] as String,
            actif: (m['actif'] as int) == 1,
            nbArticles: m['nb'] as int,
          ),
        )
        .toList();
  }

  // Compare sans tenir compte des majuscules (accents compris)
  static Future<void> _verifierClasseLibre(String nom, {int? sauf}) async {
    final lignes = await db.query('classes_articles', columns: ['id', 'nom']);
    for (final m in lignes) {
      if (m['id'] == sauf) continue;
      if ((m['nom'] as String).toLowerCase() == nom.toLowerCase()) {
        throw Exception('Une classe porte déjà ce nom');
      }
    }
  }

  static Future<int> creerClasse(String nom) async {
    Session.exiger('articles.gerer');

    final propre = nom.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (propre.isEmpty) throw Exception('Le nom est vide');
    await _verifierClasseLibre(propre);

    return db.insert('classes_articles', {
      'nom': propre,
      'actif': 1,
      'cree_le': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> modifierClasse({
    required int id,
    required String nom,
    required bool actif,
  }) async {
    Session.exiger('articles.gerer');

    final propre = nom.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (propre.isEmpty) throw Exception('Le nom est vide');
    await _verifierClasseLibre(propre, sauf: id);

    await db.update(
      'classes_articles',
      {'nom': propre, 'actif': actif ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Le compte retenu pour un poste, selon la règle :
  // classe de l'article, puis agence, puis compte par défaut.
  // Aucun droit exigé : c'est une fonction interne, appelée à la caisse.
  static Future<ComptePourPoste?> resoudreCompte({
    required String poste,
    int? agenceId,
    int? classeId,
  }) async {
    final postes = await listerPostes();
    final definition = postes.where((p) => p.code == poste).toList();
    if (definition.isEmpty) throw Exception('Poste comptable inconnu');
    final d = definition.first;

    final lignes = await db.rawQuery(
      '''
      SELECT c.numero, c.intitule, a.portee
      FROM associations_comptables a
      INNER JOIN comptes_comptables c ON c.id = a.compte_id
      WHERE a.poste = ?
        AND ((a.portee = 'classe' AND a.portee_id = ?)
          OR (a.portee = 'agence' AND a.portee_id = ?)
          OR a.portee = 'defaut')
      ORDER BY CASE a.portee WHEN 'classe' THEN 1 WHEN 'agence' THEN 2 ELSE 3 END
      LIMIT 1
    ''',
      [
        poste,
        d.parClasse ? (classeId ?? -1) : -1,
        d.parAgence ? (agenceId ?? -1) : -1,
      ],
    );

    if (lignes.isEmpty) return null;
    final m = lignes.first;
    return ComptePourPoste(
      numero: m['numero'] as String,
      intitule: m['intitule'] as String,
      origine: m['portee'] as String,
    );
  }

  // ---------- Achats ----------

  static Future<void> _creerTablesAchats(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS achats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        agence_id INTEGER NOT NULL,
        fournisseur_id INTEGER NOT NULL,
        date_achat TEXT NOT NULL,
        reference_fournisseur TEXT,
        note TEXT,
        total_ht INTEGER NOT NULL,
        total_tva INTEGER NOT NULL DEFAULT 0,
        total_ttc INTEGER NOT NULL,
        statut TEXT NOT NULL DEFAULT 'valide',
        utilisateur_id INTEGER NOT NULL,
        cree_le TEXT NOT NULL,
        FOREIGN KEY (agence_id) REFERENCES agences(id),
        FOREIGN KEY (fournisseur_id) REFERENCES tiers(id),
        FOREIGN KEY (utilisateur_id) REFERENCES utilisateurs(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_achats_agence ON achats (agence_id, date_achat)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS achat_lignes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        achat_id INTEGER NOT NULL,
        article_id INTEGER NOT NULL,
        code_article TEXT NOT NULL,
        designation TEXT NOT NULL,
        quantite REAL NOT NULL,
        prix_unitaire INTEGER NOT NULL,
        taux_tva REAL NOT NULL DEFAULT 0,
        total_ht INTEGER NOT NULL,
        montant_tva INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (achat_id) REFERENCES achats(id) ON DELETE CASCADE,
        FOREIGN KEY (article_id) REFERENCES articles(id)
      )
    ''');

    // Les paiements serviront aussi aux ventes et aux règlements
    await db.execute('''
      CREATE TABLE IF NOT EXISTS paiements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type_document TEXT NOT NULL,
        document_id INTEGER NOT NULL,
        mode_id INTEGER NOT NULL,
        montant INTEGER NOT NULL,
        reference TEXT,
        date_paiement TEXT NOT NULL,
        utilisateur_id INTEGER NOT NULL,
        cree_le TEXT NOT NULL,
        FOREIGN KEY (mode_id) REFERENCES modes_paiement(id),
        FOREIGN KEY (utilisateur_id) REFERENCES utilisateurs(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_paiements_document '
      'ON paiements (type_document, document_id)',
    );

    // Un mouvement de stock sait de quel document il vient
    if (!await _colonneExiste(db, 'mouvements_stock', 'source_type')) {
      await db.execute(
        'ALTER TABLE mouvements_stock ADD COLUMN source_type TEXT',
      );
    }
    if (!await _colonneExiste(db, 'mouvements_stock', 'source_id')) {
      await db.execute(
        'ALTER TABLE mouvements_stock ADD COLUMN source_id INTEGER',
      );
    }
  }

  // Les fournisseurs proposés dans le formulaire d'achat
  // (le fournisseur occasionnel en premier)
  static Future<List<Tiers>> fournisseursPourAchat() async {
    Session.exiger('achats.creer');
    final lignes = await db.query(
      'tiers',
      where: 'est_fournisseur = 1 AND actif = 1',
      orderBy: 'systeme DESC, nom COLLATE NOCASE',
    );
    return lignes.map(Tiers.fromMap).toList();
  }

  // Les articles proposés dans le formulaire d'achat, avec leur dernier prix
  static Future<List<Article>> rechercherArticlesAchat(String recherche) async {
    Session.exiger('achats.creer');

    final args = <Object>[];
    var filtre = '';
    final texte = recherche.trim();
    if (texte.isNotEmpty) {
      filtre = 'AND (a.code LIKE ? OR a.designation LIKE ? OR cl.nom LIKE ?)';
      args.addAll(['%$texte%', '%$texte%', '%$texte%']);
    }

    final lignes = await db.rawQuery('''
      SELECT a.id, a.code, a.designation, a.classe_id, cl.nom AS categorie,
             a.unite, a.prix_achat, a.prix_vente, a.seuil_alerte, a.actif
      FROM articles a
      LEFT JOIN classes_articles cl ON cl.id = a.classe_id
      WHERE a.actif = 1 $filtre
      ORDER BY a.designation COLLATE NOCASE
      LIMIT 50
    ''', args);

    return lignes.map((m) => Article.fromMap(m, avecPrixAchat: true)).toList();
  }

  // Enregistre un achat entier. Retourne son matricule.
  static Future<String> creerAchat({
    required int fournisseurId,
    required DateTime date,
    String? referenceFournisseur,
    String? note,
    required List<LigneAchatSaisie> lignes,
    required List<PaiementSaisi> paiements,
    bool majPrixCatalogue = false,
  }) async {
    Session.exiger('achats.creer');

    final agence = Session.agenceCourante;
    final utilisateur = Session.utilisateurCourant;
    if (agence == null || utilisateur == null) {
      throw Exception('Aucune agence sélectionnée');
    }
    if (lignes.isEmpty) {
      throw Exception("L'achat doit contenir au moins un article");
    }

    final maintenant = DateTime.now();
    final jour = DateTime(date.year, date.month, date.day);
    if (jour.isAfter(
      DateTime(maintenant.year, maintenant.month, maintenant.day),
    )) {
      throw Exception('La date ne peut pas être dans le futur');
    }
    String deux(int n) => n.toString().padLeft(2, '0');
    final dateTexte = '${jour.year}-${deux(jour.month)}-${deux(jour.day)}';

    return db.transaction((txn) async {
      // Le fournisseur
      final f = await txn.query(
        'tiers',
        columns: ['systeme', 'est_fournisseur', 'actif'],
        where: 'id = ?',
        whereArgs: [fournisseurId],
        limit: 1,
      );
      if (f.isEmpty) throw Exception('Fournisseur introuvable');
      if (f.first['est_fournisseur'] != 1 || f.first['actif'] != 1) {
        throw Exception('Ce fournisseur est indisponible');
      }
      final fournisseurSysteme = f.first['systeme'] == 1;

      // Les lignes
      var totalHt = 0;
      const totalTva = 0; // la TVA sera activée plus tard
      final preparees = <Map<String, Object?>>[];

      for (final l in lignes) {
        final q = _arrondir(l.quantite);
        if (q <= 0)
          throw Exception('Chaque quantité doit être supérieure à zéro');
        if (l.prixUnitaire < 0)
          throw Exception('Un prix ne peut pas être négatif');

        final art = await txn.query(
          'articles',
          columns: ['code', 'designation', 'actif'],
          where: 'id = ?',
          whereArgs: [l.articleId],
          limit: 1,
        );
        if (art.isEmpty) throw Exception('Article introuvable');
        if (art.first['actif'] != 1) {
          throw Exception('« ${art.first['designation']} » est désactivé');
        }

        final ht = (q * l.prixUnitaire).round();
        totalHt += ht;
        preparees.add({
          'article_id': l.articleId,
          'code_article': art.first['code'],
          'designation': art.first['designation'],
          'quantite': q,
          'prix_unitaire': l.prixUnitaire,
          'taux_tva': 0.0,
          'total_ht': ht,
          'montant_tva': 0,
        });
      }
      final totalTtc = totalHt + totalTva;

      // Les paiements
      var totalPaye = 0;
      for (final p in paiements) {
        if (p.montant <= 0) {
          throw Exception('Chaque paiement doit être supérieur à zéro');
        }
        final mode = await txn.query(
          'modes_paiement',
          columns: ['libelle', 'reference_obligatoire', 'actif'],
          where: 'id = ?',
          whereArgs: [p.modeId],
          limit: 1,
        );
        if (mode.isEmpty || mode.first['actif'] != 1) {
          throw Exception('Mode de paiement indisponible');
        }
        if (mode.first['reference_obligatoire'] == 1 &&
            (p.reference ?? '').trim().isEmpty) {
          throw Exception(
            'Une référence est obligatoire pour « ${mode.first['libelle']} »',
          );
        }
        totalPaye += p.montant;
      }

      if (totalPaye > totalTtc) {
        throw Exception("Les paiements dépassent le total de l'achat");
      }
      final reste = totalTtc - totalPaye;
      if (reste > 0 && fournisseurSysteme) {
        throw Exception(
          'Un achat à crédit demande un fournisseur identifié '
          "(pas « Fournisseur occasionnel »)",
        );
      }

      // L'achat
      final code = await _prochainMatricule(txn, 'achats');
      final achatId = await txn.insert('achats', {
        'code': code,
        'agence_id': agence.id,
        'fournisseur_id': fournisseurId,
        'date_achat': dateTexte,
        'reference_fournisseur': _videEnNull(referenceFournisseur),
        'note': _videEnNull(note),
        'total_ht': totalHt,
        'total_tva': totalTva,
        'total_ttc': totalTtc,
        'statut': 'valide',
        'utilisateur_id': utilisateur.id,
        'cree_le': maintenant.toIso8601String(),
      });

      // Les lignes, l'entrée en stock et (si voulu) le dernier prix du catalogue
      for (var i = 0; i < preparees.length; i++) {
        final ligne = preparees[i];
        await txn.insert('achat_lignes', {...ligne, 'achat_id': achatId});

        await _mouvementStock(
          txn,
          articleId: ligne['article_id'] as int,
          agenceId: agence.id,
          utilisateurId: utilisateur.id,
          type: 'entree',
          quantite: ligne['quantite'] as double,
          motif: 'Réception fournisseur',
          commentaire: 'Achat $code',
          sourceType: 'achat',
          sourceId: achatId,
        );

        if (majPrixCatalogue && Session.peut('articles.gerer')) {
          await txn.update(
            'articles',
            {'prix_achat': ligne['prix_unitaire']},
            where: 'id = ?',
            whereArgs: [ligne['article_id']],
          );
        }
      }

      // Les paiements
      for (final p in paiements) {
        await txn.insert('paiements', {
          'type_document': 'achat',
          'document_id': achatId,
          'mode_id': p.modeId,
          'montant': p.montant,
          'reference': _videEnNull(p.reference),
          'date_paiement': dateTexte,
          'utilisateur_id': utilisateur.id,
          'cree_le': maintenant.toIso8601String(),
        });
      }

      return code;
    });
  }

  // Les achats de l'agence courante, le plus récent d'abord
  static Future<List<AchatResume>> listerAchats({
    String recherche = '',
    bool creditSeulement = false,
  }) async {
    if (!Session.peut('achats.voir') && !Session.peut('achats.creer')) {
      throw Exception('Action non autorisée');
    }

    final agence = Session.agenceCourante;
    if (agence == null) throw Exception('Aucune agence sélectionnée');

    final args = <Object>[agence.id];
    var filtre = '';
    final texte = recherche.trim();
    if (texte.isNotEmpty) {
      filtre = 'AND (a.code LIKE ? OR t.nom LIKE ? OR a.reference_fournisseur LIKE ?)';
      args.addAll(List.filled(3, '%$texte%'));
    }

    final lignes = await db.rawQuery('''
      SELECT a.id, a.code, a.date_achat, a.reference_fournisseur, a.total_ttc,
             a.statut, t.nom AS fournisseur,
             COALESCE((SELECT SUM(p.montant) FROM paiements p
                       WHERE p.type_document = 'achat' AND p.document_id = a.id), 0) AS paye
      FROM achats a
      INNER JOIN tiers t ON t.id = a.fournisseur_id
      WHERE a.agence_id = ? $filtre
      ORDER BY a.date_achat DESC, a.id DESC
      LIMIT 300
    ''', args);

    final liste = lignes.map(AchatResume.fromMap).toList();
    return creditSeulement
        ? liste.where((a) => a.statut == 'valide' && a.reste > 0).toList()
        : liste;
  }

  static Future<AchatDetail> detailAchat(int id) async {
    if (!Session.peut('achats.voir') && !Session.peut('achats.creer')) {
      throw Exception('Action non autorisée');
    }

    final agence = Session.agenceCourante;
    if (agence == null) throw Exception('Aucune agence sélectionnée');

    final entete = await db.rawQuery(
      '''
      SELECT a.code, a.date_achat, a.reference_fournisseur, a.note, a.statut,
             a.total_ht, a.total_tva, a.total_ttc,
             t.nom AS fournisseur, u.nom_complet AS utilisateur, ag.nom AS agence
      FROM achats a
      INNER JOIN tiers t ON t.id = a.fournisseur_id
      INNER JOIN utilisateurs u ON u.id = a.utilisateur_id
      INNER JOIN agences ag ON ag.id = a.agence_id
      WHERE a.id = ? AND a.agence_id = ?
    ''',
      [id, agence.id],
    );
    if (entete.isEmpty) throw Exception('Achat introuvable');

    final lignes = await db.query(
      'achat_lignes',
      where: 'achat_id = ?',
      whereArgs: [id],
      orderBy: 'id',
    );

    final paiements = await db.rawQuery(
      '''
      SELECT p.montant, p.reference, p.date_paiement,
             m.libelle AS mode, u.nom_complet AS utilisateur
      FROM paiements p
      INNER JOIN modes_paiement m ON m.id = p.mode_id
      INNER JOIN utilisateurs u ON u.id = p.utilisateur_id
      WHERE p.type_document = 'achat' AND p.document_id = ?
      ORDER BY p.id
    ''',
      [id],
    );

    final e = entete.first;
    return AchatDetail(
      code: e['code'] as String,
      date: DateTime.parse(e['date_achat'] as String),
      fournisseur: e['fournisseur'] as String,
      referenceFournisseur: e['reference_fournisseur'] as String?,
      note: e['note'] as String?,
      agence: e['agence'] as String,
      utilisateur: e['utilisateur'] as String,
      statut: e['statut'] as String,
      totalHt: e['total_ht'] as int,
      totalTva: e['total_tva'] as int,
      totalTtc: e['total_ttc'] as int,
      lignes: lignes.map(LigneAchat.fromMap).toList(),
      paiements: paiements.map(PaiementAchat.fromMap).toList(),
    );
  }

  // ---------- Ventes ----------

  static Future<void> _creerTablesVentes(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ventes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        agence_id INTEGER NOT NULL,
        client_id INTEGER NOT NULL,
        date_vente TEXT NOT NULL,
        note TEXT,
        total_brut INTEGER NOT NULL,
        total_remise INTEGER NOT NULL DEFAULT 0,
        total_tva INTEGER NOT NULL DEFAULT 0,
        net_a_payer INTEGER NOT NULL,
        monnaie_rendue INTEGER NOT NULL DEFAULT 0,
        statut TEXT NOT NULL DEFAULT 'valide',
        utilisateur_id INTEGER NOT NULL,
        cree_le TEXT NOT NULL,
        FOREIGN KEY (agence_id) REFERENCES agences(id),
        FOREIGN KEY (client_id) REFERENCES tiers(id),
        FOREIGN KEY (utilisateur_id) REFERENCES utilisateurs(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ventes_agence ON ventes (agence_id, date_vente)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ventes_client ON ventes (client_id)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS vente_lignes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vente_id INTEGER NOT NULL,
        article_id INTEGER NOT NULL,
        code_article TEXT NOT NULL,
        designation TEXT NOT NULL,
        unite TEXT NOT NULL,
        quantite REAL NOT NULL,
        prix_catalogue INTEGER NOT NULL,
        prix_unitaire INTEGER NOT NULL,
        prix_achat INTEGER,
        remise INTEGER NOT NULL DEFAULT 0,
        taux_tva REAL NOT NULL DEFAULT 0,
        montant_tva INTEGER NOT NULL DEFAULT 0,
        total_brut INTEGER NOT NULL,
        total_net INTEGER NOT NULL,
        FOREIGN KEY (vente_id) REFERENCES ventes(id) ON DELETE CASCADE,
        FOREIGN KEY (article_id) REFERENCES articles(id)
      )
    ''');
  }

  // Ce qu'un client doit déjà : ventes à crédit moins ce qu'il a payé
  static Future<int> _encoursClient(
    DatabaseExecutor executeur,
    int clientId,
  ) async {
    final r = await executeur.rawQuery(
      '''
      SELECT COALESCE(SUM(v.net_a_payer - COALESCE(
               (SELECT SUM(p.montant) FROM paiements p
                WHERE p.type_document = 'vente' AND p.document_id = v.id), 0)), 0) AS encours
      FROM ventes v
      WHERE v.client_id = ? AND v.statut = 'valide'
    ''',
      [clientId],
    );
    return (r.first['encours'] as num).toInt();
  }

  // Les clients proposés à la caisse (le client comptant en premier)
  static Future<List<Tiers>> clientsPourVente() async {
    Session.exiger('ventes.creer');
    final lignes = await db.query(
      'tiers',
      where: 'est_client = 1 AND actif = 1',
      orderBy: 'systeme DESC, nom COLLATE NOCASE',
    );
    return lignes.map(Tiers.fromMap).toList();
  }

  static Future<SituationClient> situationClient(int clientId) async {
    Session.exiger('ventes.creer');
    final c = await db.query(
      'tiers',
      columns: ['systeme', 'plafond_credit'],
      where: 'id = ?',
      whereArgs: [clientId],
      limit: 1,
    );
    if (c.isEmpty) throw Exception('Client introuvable');

    return SituationClient(
      plafond: c.first['plafond_credit'] as int,
      encours: await _encoursClient(db, clientId),
      systeme: c.first['systeme'] == 1,
    );
  }

  // Les articles proposés à la caisse, avec le stock de l'agence courante
  static Future<List<ArticleCaisse>> rechercherArticlesCaisse(
    String recherche,
  ) async {
    Session.exiger('ventes.creer');

    final agence = Session.agenceCourante;
    if (agence == null) throw Exception('Aucune agence sélectionnée');

    final args = <Object>[agence.id];
    var filtre = '';
    final texte = recherche.trim();
    if (texte.isNotEmpty) {
      filtre = 'AND (a.code LIKE ? OR a.designation LIKE ? OR cl.nom LIKE ?)';
      args.addAll(['%$texte%', '%$texte%', '%$texte%']);
    }

    final lignes = await db.rawQuery('''
      SELECT a.id, a.code, a.designation, cl.nom AS categorie, a.unite,
             a.prix_vente, COALESCE(s.quantite, 0) AS stock
      FROM articles a
      LEFT JOIN classes_articles cl ON cl.id = a.classe_id
      LEFT JOIN stock s ON s.article_id = a.id AND s.agence_id = ?
      WHERE a.actif = 1 $filtre
      ORDER BY a.designation COLLATE NOCASE
      LIMIT 50
    ''', args);

    return lignes.map(ArticleCaisse.fromMap).toList();
  }

  // Enregistre une vente entière : facture, stock, paiements. Tout ou rien.
  static Future<VenteEnregistree> creerVente({
    required int clientId,
    String? note,
    required List<LigneVenteSaisie> lignes,
    required List<PaiementSaisi> paiements,
  }) async {
    Session.exiger('ventes.creer');

    final agence = Session.agenceCourante;
    final utilisateur = Session.utilisateurCourant;
    if (agence == null || utilisateur == null) {
      throw Exception('Aucune agence sélectionnée');
    }
    if (lignes.isEmpty) {
      throw Exception('La vente doit contenir au moins un article');
    }

    final maintenant = DateTime.now();
    String deux(int n) => n.toString().padLeft(2, '0');
    final dateTexte =
        '${maintenant.year}-${deux(maintenant.month)}-${deux(maintenant.day)}';

    return db.transaction((txn) async {
      // Le client
      final c = await txn.query(
        'tiers',
        columns: ['systeme', 'est_client', 'actif', 'plafond_credit'],
        where: 'id = ?',
        whereArgs: [clientId],
        limit: 1,
      );
      if (c.isEmpty) throw Exception('Client introuvable');
      if (c.first['est_client'] != 1 || c.first['actif'] != 1) {
        throw Exception('Ce client est indisponible');
      }
      final clientSysteme = c.first['systeme'] == 1;
      final plafond = c.first['plafond_credit'] as int;

      // Les lignes
      var totalBrut = 0;
      var totalRemise = 0;
      final preparees = <Map<String, Object?>>[];
      final demandees = <int, double>{}; // quantité totale demandée par article

      for (final l in lignes) {
        final q = _arrondir(l.quantite);
        if (q <= 0)
          throw Exception('Chaque quantité doit être supérieure à zéro');
        if (l.prixUnitaire < 0)
          throw Exception('Un prix ne peut pas être négatif');
        if (l.remise < 0)
          throw Exception('Une remise ne peut pas être négative');

        final art = await txn.query(
          'articles',
          columns: [
            'code',
            'designation',
            'unite',
            'prix_vente',
            'prix_achat',
            'actif',
          ],
          where: 'id = ?',
          whereArgs: [l.articleId],
          limit: 1,
        );
        if (art.isEmpty) throw Exception('Article introuvable');
        final designation = art.first['designation'] as String;
        if (art.first['actif'] != 1)
          throw Exception('« $designation » est désactivé');

        // Le prix vient du catalogue, sauf droit particulier
        final prixCatalogue = art.first['prix_vente'] as int;
        if (l.prixUnitaire != prixCatalogue &&
            !Session.peut('ventes.modifier_prix')) {
          throw Exception('Le prix de vente ne peut pas être modifié');
        }
        if (l.remise > 0 && !Session.peut('ventes.remise')) {
          throw Exception("Vous n'avez pas le droit d'accorder une remise");
        }

        final brut = (q * l.prixUnitaire).round();
        if (l.remise > brut) {
          throw Exception('La remise dépasse le montant de « $designation »');
        }

        totalBrut += brut;
        totalRemise += l.remise;
        demandees[l.articleId] = (demandees[l.articleId] ?? 0) + q;

        preparees.add({
          'article_id': l.articleId,
          'code_article': art.first['code'],
          'designation': designation,
          'unite': art.first['unite'],
          'quantite': q,
          'prix_catalogue': prixCatalogue,
          'prix_unitaire': l.prixUnitaire,
          'prix_achat': art.first['prix_achat'],
          'remise': l.remise,
          'taux_tva': 0.0,
          'montant_tva': 0,
          'total_brut': brut,
          'total_net': brut - l.remise,
        });
      }

      final netAPayer = totalBrut - totalRemise;
      if (netAPayer <= 0) {
        throw Exception('Le net à payer doit être supérieur à zéro');
      }

      // Le stock, vérifié avant d'écrire quoi que ce soit
      for (final e in demandees.entries) {
        final s = await txn.query(
          'stock',
          columns: ['quantite'],
          where: 'article_id = ? AND agence_id = ?',
          whereArgs: [e.key, agence.id],
          limit: 1,
        );
        final dispo = s.isEmpty ? 0.0 : (s.first['quantite'] as num).toDouble();
        if (e.value > dispo) {
          final nom = preparees.firstWhere(
            (p) => p['article_id'] == e.key,
          )['designation'];
          throw Exception(
            'Stock insuffisant pour « $nom » (disponible : ${formaterQuantite(dispo)})',
          );
        }
      }

      // Les paiements saisis
      var totalSaisi = 0;
      final modes = <int, Map<String, Object?>>{};
      for (final p in paiements) {
        if (p.montant <= 0) {
          throw Exception('Chaque paiement doit être supérieur à zéro');
        }
        final m = await txn.query(
          'modes_paiement',
          columns: ['libelle', 'type', 'reference_obligatoire', 'actif'],
          where: 'id = ?',
          whereArgs: [p.modeId],
          limit: 1,
        );
        if (m.isEmpty || m.first['actif'] != 1) {
          throw Exception('Mode de paiement indisponible');
        }
        if (m.first['reference_obligatoire'] == 1 &&
            (p.reference ?? '').trim().isEmpty) {
          throw Exception(
            'Une référence est obligatoire pour « ${m.first['libelle']} »',
          );
        }
        modes[p.modeId] = m.first;
        totalSaisi += p.montant;
      }

      final finaux = <Map<String, Object?>>[
        for (final p in paiements)
          {'mode': p.modeId, 'montant': p.montant, 'reference': p.reference},
      ];

      // La monnaie rendue : seulement sur des paiements en espèces
      var monnaie = 0;
      if (totalSaisi > netAPayer) {
        var exces = totalSaisi - netAPayer;
        final especes = finaux
            .where((f) => modes[f['mode']]!['type'] == 'caisse')
            .fold<int>(0, (somme, f) => somme + (f['montant'] as int));
        if (exces > especes) {
          throw Exception('Les paiements dépassent le net à payer');
        }
        monnaie = exces;

        // On retire la monnaie des paiements en espèces, en partant du dernier
        for (var i = finaux.length - 1; i >= 0 && exces > 0; i--) {
          if (modes[finaux[i]['mode']]!['type'] != 'caisse') continue;
          final montant = finaux[i]['montant'] as int;
          final retrait = exces < montant ? exces : montant;
          finaux[i]['montant'] = montant - retrait;
          exces -= retrait;
        }
        finaux.removeWhere((f) => (f['montant'] as int) == 0);
      }

      final totalPaye = finaux.fold<int>(
        0,
        (somme, f) => somme + (f['montant'] as int),
      );
      final reste = netAPayer - totalPaye;

      // Le crédit : client identifié et plafond respecté
      if (reste > 0) {
        if (clientSysteme) {
          throw Exception(
            'Une vente à crédit demande un client identifié '
            '(pas « Client comptant »)',
          );
        }
        final encours = await _encoursClient(txn, clientId);
        if (encours + reste > plafond) {
          throw Exception(
            'Plafond de crédit dépassé : plafond ${formaterPrix(plafond)}, '
            'déjà dû ${formaterPrix(encours)}, '
            'reste de cette vente ${formaterPrix(reste)}',
          );
        }
      }

      // La vente
      final code = await _prochainMatricule(txn, 'ventes');
      final venteId = await txn.insert('ventes', {
        'code': code,
        'agence_id': agence.id,
        'client_id': clientId,
        'date_vente': dateTexte,
        'note': _videEnNull(note),
        'total_brut': totalBrut,
        'total_remise': totalRemise,
        'total_tva': 0,
        'net_a_payer': netAPayer,
        'monnaie_rendue': monnaie,
        'statut': 'valide',
        'utilisateur_id': utilisateur.id,
        'cree_le': maintenant.toIso8601String(),
      });

      // Les lignes et la sortie de stock
      for (final ligne in preparees) {
        await txn.insert('vente_lignes', {...ligne, 'vente_id': venteId});

        await _mouvementStock(
          txn,
          articleId: ligne['article_id'] as int,
          agenceId: agence.id,
          utilisateurId: utilisateur.id,
          type: 'sortie',
          quantite: ligne['quantite'] as double,
          motif: 'Vente',
          commentaire: 'Vente $code',
          sourceType: 'vente',
          sourceId: venteId,
        );
      }

      // Les paiements
      for (final f in finaux) {
        await txn.insert('paiements', {
          'type_document': 'vente',
          'document_id': venteId,
          'mode_id': f['mode'],
          'montant': f['montant'],
          'reference': _videEnNull(f['reference'] as String?),
          'date_paiement': dateTexte,
          'utilisateur_id': utilisateur.id,
          'cree_le': maintenant.toIso8601String(),
        });
      }

      return VenteEnregistree(id: venteId, code: code, monnaie: monnaie);
    });
  }

  // Les ventes de l'agence courante. Sans le droit ventes.voir,
  // on ne voit que ses propres ventes.
  static Future<List<VenteResume>> listerVentes({
    String recherche = '',
    bool creditSeulement = false,
  }) async {
    final voirTout = Session.peut('ventes.voir');
    if (!voirTout && !Session.peut('ventes.creer')) {
      throw Exception('Action non autorisée');
    }

    final agence = Session.agenceCourante;
    if (agence == null) throw Exception('Aucune agence sélectionnée');

    final args = <Object>[agence.id];
    var filtre = '';
    if (!voirTout) {
      filtre += ' AND v.utilisateur_id = ?';
      args.add(Session.utilisateurCourant!.id);
    }
    final texte = recherche.trim();
    if (texte.isNotEmpty) {
      filtre += ' AND (v.code LIKE ? OR t.nom LIKE ?)';
      args.addAll(['%$texte%', '%$texte%']);
    }

    final lignes = await db.rawQuery('''
      SELECT v.id, v.code, v.cree_le, v.net_a_payer, v.statut,
             t.nom AS client, u.nom_complet AS vendeur,
             COALESCE((SELECT SUM(p.montant) FROM paiements p
                       WHERE p.type_document = 'vente' AND p.document_id = v.id), 0) AS paye
      FROM ventes v
      INNER JOIN tiers t ON t.id = v.client_id
      INNER JOIN utilisateurs u ON u.id = v.utilisateur_id
      WHERE v.agence_id = ? $filtre
      ORDER BY v.id DESC
      LIMIT 300
    ''', args);

    final liste = lignes.map(VenteResume.fromMap).toList();
    return creditSeulement
        ? liste.where((v) => v.statut == 'valide' && v.reste > 0).toList()
        : liste;
  }

  static Future<VenteDetail> detailVente(int id) async {
    final voirTout = Session.peut('ventes.voir');
    if (!voirTout && !Session.peut('ventes.creer')) {
      throw Exception('Action non autorisée');
    }

    final agence = Session.agenceCourante;
    if (agence == null) throw Exception('Aucune agence sélectionnée');

    final args = <Object>[id, agence.id];
    var filtre = '';
    if (!voirTout) {
      filtre = ' AND v.utilisateur_id = ?';
      args.add(Session.utilisateurCourant!.id);
    }

    final entete = await db.rawQuery('''
      SELECT v.code, v.cree_le, v.note, v.statut, v.total_brut, v.total_remise,
             v.total_tva, v.net_a_payer, v.monnaie_rendue, v.nb_impressions,
             t.nom AS client, u.nom_complet AS vendeur, ag.nom AS agence,
             ag.ville AS agence_ville, ag.telephone AS agence_telephone
      FROM ventes v
      INNER JOIN tiers t ON t.id = v.client_id
      INNER JOIN utilisateurs u ON u.id = v.utilisateur_id
      INNER JOIN agences ag ON ag.id = v.agence_id
      WHERE v.id = ? AND v.agence_id = ? $filtre
    ''', args);
    if (entete.isEmpty) throw Exception('Vente introuvable');

    final lignes = await db.query(
      'vente_lignes',
      where: 'vente_id = ?',
      whereArgs: [id],
      orderBy: 'id',
    );

    final paiements = await db.rawQuery(
      '''
      SELECT p.montant, p.reference, p.date_paiement,
             m.libelle AS mode, u.nom_complet AS utilisateur
      FROM paiements p
      INNER JOIN modes_paiement m ON m.id = p.mode_id
      INNER JOIN utilisateurs u ON u.id = p.utilisateur_id
      WHERE p.type_document = 'vente' AND p.document_id = ?
      ORDER BY p.id
    ''',
      [id],
    );

    final e = entete.first;
    return VenteDetail(
      code: e['code'] as String,
      date: DateTime.parse(e['cree_le'] as String),
      agence: e['agence'] as String,
      client: e['client'] as String,
      vendeur: e['vendeur'] as String,
      note: e['note'] as String?,
      statut: e['statut'] as String,
      totalBrut: e['total_brut'] as int,
      totalRemise: e['total_remise'] as int,
      totalTva: e['total_tva'] as int,
      netAPayer: e['net_a_payer'] as int,
      monnaieRendue: e['monnaie_rendue'] as int,
      lignes: lignes.map(LigneVente.fromMap).toList(),
      paiements: paiements.map(PaiementVente.fromMap).toList(),
      agenceVille: e['agence_ville'] as String?,
      agenceTelephone: e['agence_telephone'] as String?,
      nbImpressions: e['nb_impressions'] as int,
    );
  }

  // ---------- Impression et paramètres de l'entreprise ----------

  static Future<void> _creerTablesImpression(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS parametres (
        cle TEXT PRIMARY KEY,
        valeur TEXT NOT NULL
      )
    ''');

    if (!await _colonneExiste(db, 'ventes', 'nb_impressions')) {
      await db.execute(
        'ALTER TABLE ventes ADD COLUMN nb_impressions INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  // Lecture libre : tous les postes en ont besoin pour imprimer
  static Future<InfosEntreprise> lireInfosEntreprise() async {
    final lignes = await db.query('parametres');
    final m = {
      for (final l in lignes) l['cle'] as String: l['valeur'] as String,
    };
    return InfosEntreprise(
      nom: m['entreprise_nom'] ?? '',
      infos: m['entreprise_infos'] ?? '',
      devise: m['entreprise_devise'] ?? '',
      message: m['ticket_message'] ?? 'Merci de votre visite',
    );
  }

  static Future<void> enregistrerInfosEntreprise(InfosEntreprise i) async {
    Session.exiger('parametres.gerer');

    final valeurs = {
      'entreprise_nom': i.nom.trim(),
      'entreprise_infos': i.infos.trim(),
      'entreprise_devise': i.devise.trim(),
      'ticket_message': i.message.trim(),
    };

    await db.transaction((txn) async {
      for (final e in valeurs.entries) {
        await txn.execute(
          '''
          INSERT INTO parametres (cle, valeur) VALUES (?, ?)
          ON CONFLICT(cle) DO UPDATE SET valeur = excluded.valeur
        ''',
          [e.key, e.value],
        );
      }
    });
  }

  // Compte une impression de plus (la 2e et les suivantes sont des duplicatas)
  static Future<void> noterImpression(int venteId) async {
    if (!Session.peut('ventes.voir') && !Session.peut('ventes.creer')) {
      throw Exception('Action non autorisée');
    }
    await db.rawUpdate(
      'UPDATE ventes SET nb_impressions = nb_impressions + 1 WHERE id = ?',
      [venteId],
    );
  }
}
