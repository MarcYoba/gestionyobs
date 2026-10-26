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
  static const int _versionBase = 7;

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

    if (!inclureInactifs) conditions.add('actif = 1');

    final texte = recherche.trim();
    if (texte.isNotEmpty) {
      conditions.add('(code LIKE ? OR designation LIKE ? OR categorie LIKE ?)');
      args.addAll(['%$texte%', '%$texte%', '%$texte%']);
    }

    final lignes = await db.query(
      'articles',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'designation COLLATE NOCASE',
    );

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
  static Future<String> creerArticle({
    required String designation,
    String? categorie,
    required String unite,
    int? prixAchat,
    required int prixVente,
    required double seuilAlerte,
  }) async {
    Session.exiger('articles.gerer');

    // Transaction : le numéro est calculé et utilisé sans que rien
    // ne puisse s'intercaler entre les deux
    return db.transaction((txn) async {
      final code = await _prochainMatricule(txn, 'articles');

      await txn.insert('articles', {
        'code': code,
        'designation': designation,
        'categorie': _videEnNull(categorie),
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
    String? categorie,
    required String unite,
    int? prixAchat,
    required int prixVente,
    required double seuilAlerte,
    required bool actif,
  }) async {
    Session.exiger('articles.gerer');

    final valeurs = <String, Object?>{
      'designation': designation,
      'categorie': _videEnNull(categorie),
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
      filtre =
          'AND (a.code LIKE ? OR a.designation LIKE ? OR a.categorie LIKE ?)';
      args.addAll(['%$texte%', '%$texte%', '%$texte%']);
    }

    final lignes = await db.rawQuery('''
      SELECT a.id, a.code, a.designation, a.categorie, a.unite, a.seuil_alerte,
             COALESCE(s.quantite, 0) AS quantite
      FROM articles a
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

    final q = _arrondir(quantite);

    // Transaction : le stock et l'historique changent ensemble, ou pas du tout
    return db.transaction((txn) async {
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
        whereArgs: [articleId, agence.id],
        limit: 1,
      );
      final avant = actuel.isEmpty
          ? 0.0
          : (actuel.first['quantite'] as num).toDouble();

      double apres;
      switch (type) {
        case 'entree':
          if (q <= 0)
            throw Exception('La quantité doit être supérieure à zéro');
          apres = _arrondir(avant + q);
        case 'sortie':
          if (q <= 0)
            throw Exception('La quantité doit être supérieure à zéro');
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

      // Met à jour la quantité (la crée si c'est la première fois)
      await txn.execute(
        '''
        INSERT INTO stock (article_id, agence_id, quantite) VALUES (?, ?, ?)
        ON CONFLICT(article_id, agence_id) DO UPDATE SET quantite = excluded.quantite
      ''',
        [articleId, agence.id, apres],
      );

      final code = await _prochainMatricule(txn, 'mouvements_stock');
      await txn.insert('mouvements_stock', {
        'code': code,
        'article_id': articleId,
        'agence_id': agence.id,
        'type': type,
        'quantite': ecart,
        'quantite_avant': avant,
        'quantite_apres': apres,
        'motif': motif,
        'commentaire': _videEnNull(commentaire),
        'utilisateur_id': utilisateur.id,
        'cree_le': DateTime.now().toIso8601String(),
      });

      return code;
    });
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
}
