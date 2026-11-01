import 'dart:async';
import 'dart:io';

import 'package:gestionyobs/config_service.dart';
import 'package:gestionyobs/database/database_service.dart';
import 'package:gestionyobs/app/messages_app.dart';

/// Un fichier de sauvegarde trouvé dans un dossier.
class FichierSauvegarde {
  final String chemin;
  final String nom;
  final DateTime date;
  final String
  type; // 'auto', 'manuelle', 'avantmigration', 'avantrestauration'
  final int taille;

  const FichierSauvegarde({
    required this.chemin,
    required this.nom,
    required this.date,
    required this.type,
    required this.taille,
  });

  String get libelleType => switch (type) {
    'auto' => 'Automatique',
    'manuelle' => 'Manuelle',
    'avantmigration' => 'Avant mise à jour',
    'avantrestauration' => 'Avant restauration',
    _ => type,
  };
}

class ResultatSauvegarde {
  final FichierSauvegarde fichier;
  final String? avertissement;

  const ResultatSauvegarde({required this.fichier, this.avertissement});
}

class StatutSauvegarde {
  final DateTime? derniere;
  final bool automatique;

  const StatutSauvegarde({required this.derniere, required this.automatique});

  int? get jours =>
      derniere == null ? null : DateTime.now().difference(derniere!).inDays;
}

/// 2,4 Mo
String formaterTaille(int octets) {
  if (octets < 1024) return '$octets o';
  if (octets < 1024 * 1024) return '${(octets / 1024).toStringAsFixed(0)} Ko';
  return '${(octets / (1024 * 1024)).toStringAsFixed(1)} Mo';
}

/// Sauvegarde, planification et restauration de la base de données.
class BackupService {
  static Timer? _minuteur;
  static bool _enCours = false;

  static final RegExp _modele = RegExp(
    r'^quincaillerie_(\d{8})_(\d{6})_([a-z]+)\.db$',
  );

  static String _deux(int n) => n.toString().padLeft(2, '0');

  static String _nomFichier(DateTime d, String type) =>
      'quincaillerie_${d.year}${_deux(d.month)}${_deux(d.day)}'
      '_${_deux(d.hour)}${_deux(d.minute)}${_deux(d.second)}_$type.db';

  // Les sauvegardes d'un dossier, la plus récente d'abord
  static Future<List<FichierSauvegarde>> lister(String dossier) async {
    final repertoire = Directory(dossier);
    if (!await repertoire.exists()) return [];

    final liste = <FichierSauvegarde>[];
    await for (final e in repertoire.list()) {
      if (e is! File) continue;
      final nom = e.uri.pathSegments.last;
      final m = _modele.firstMatch(nom);
      if (m == null) continue; // on ne touche qu'à nos propres fichiers

      final d = m.group(1)!;
      final h = m.group(2)!;
      final date = DateTime(
        int.parse(d.substring(0, 4)),
        int.parse(d.substring(4, 6)),
        int.parse(d.substring(6, 8)),
        int.parse(h.substring(0, 2)),
        int.parse(h.substring(2, 4)),
        int.parse(h.substring(4, 6)),
      );
      liste.add(
        FichierSauvegarde(
          chemin: e.path,
          nom: nom,
          date: date,
          type: m.group(3)!,
          taille: await e.length(),
        ),
      );
    }

    liste.sort((a, b) => b.date.compareTo(a.date));
    return liste;
  }

  // Ne garde que les N dernières sauvegardes (les copies de sécurité à part)
  static Future<void> _appliquerRotation(
    String dossier,
    AppConfig config,
  ) async {
    final fichiers = await lister(dossier);
    final courantes = fichiers
        .where((f) => f.type == 'auto' || f.type == 'manuelle')
        .toList();
    final speciales = fichiers
        .where((f) => f.type != 'auto' && f.type != 'manuelle')
        .toList();

    for (final f in courantes.skip(config.sauvegardesConservees)) {
      try {
        await File(f.chemin).delete();
      } catch (_) {}
    }
    for (final f in speciales.skip(5)) {
      try {
        await File(f.chemin).delete();
      } catch (_) {}
    }
  }

  // Crée une sauvegarde vérifiée, et la copie vers le second emplacement
  static Future<ResultatSauvegarde> sauvegarder({
    String type = 'manuelle',
  }) async {
    if (_enCours) throw Exception('Une sauvegarde est déjà en cours');
    if (!DatabaseService.estOuverte) {
      throw Exception("La base de données n'est pas ouverte");
    }

    _enCours = true;
    try {
      final config = await ConfigService.lire();
      if (config == null) throw Exception('Configuration introuvable');

      final sep = Platform.pathSeparator;
      await Directory(config.dossierSauvegarde).create(recursive: true);

      final maintenant = DateTime.now();
      final nom = _nomFichier(maintenant, type);
      final chemin = '${config.dossierSauvegarde}$sep$nom';

      await DatabaseService.sauvegarderVers(chemin);

      // Une copie qu'on ne peut pas relire ne vaut rien : on la supprime
      if (!await DatabaseService.verifierFichier(chemin)) {
        try {
          await File(chemin).delete();
        } catch (_) {}
        throw Exception('La copie créée est illisible : sauvegarde annulée');
      }

      // Le second emplacement (clé USB, autre disque)
      String? avertissement;
      final autre = config.dossierSauvegarde2?.trim();
      if (autre != null && autre.isNotEmpty) {
        try {
          await Directory(autre).create(recursive: true);
          await File(chemin).copy('$autre$sep$nom');
          await _appliquerRotation(autre, config);
        } catch (e) {
          avertissement = 'La copie vers « $autre » a échoué : $e';
        }
      }

      await _appliquerRotation(config.dossierSauvegarde, config);

      await ConfigService.ecrire(
        config.copyWith(derniereSauvegarde: maintenant.toIso8601String()),
      );

      return ResultatSauvegarde(
        fichier: FichierSauvegarde(
          chemin: chemin,
          nom: nom,
          date: maintenant,
          type: type,
          taille: await File(chemin).length(),
        ),
        avertissement: avertissement,
      );
    } finally {
      _enCours = false;
    }
  }

  // Sauvegarde seulement si l'intervalle choisi est écoulé
  static Future<ResultatSauvegarde?> sauvegarderSiNecessaire() async {
    final config = await ConfigService.lire();
    if (config == null || !config.sauvegardeAuto) return null;

    final derniere = config.derniereSauvegarde == null
        ? null
        : DateTime.tryParse(config.derniereSauvegarde!);
    final seuil = Duration(hours: config.sauvegardeIntervalleHeures);
    if (derniere != null && DateTime.now().difference(derniere) < seuil) {
      return null;
    }

    return sauvegarder(type: 'auto');
  }

  // Lance la surveillance : tout de suite, puis toutes les 15 minutes
  static void demarrerPlanification() {
    _minuteur?.cancel();
    _minuteur = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _tacheAuto(),
    );
    _tacheAuto();
  }

  static Future<void> _tacheAuto() async {
    if (_enCours || !DatabaseService.estOuverte) return;
    try {
      final r = await sauvegarderSiNecessaire();
      if (r?.avertissement != null) MessagesApp.afficher(r!.avertissement!);
    } catch (e) {
      MessagesApp.afficher(
        'La sauvegarde automatique a échoué : '
        '${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  // Appelée à la fermeture du logiciel : ne doit jamais la bloquer
  static Future<void> sauvegardeALaFermeture() async {
    try {
      if (!DatabaseService.estOuverte || _enCours) return;
      final config = await ConfigService.lire();
      if (config == null || !config.sauvegardeFermeture) return;

      final derniere = config.derniereSauvegarde == null
          ? null
          : DateTime.tryParse(config.derniereSauvegarde!);
      if (derniere != null &&
          DateTime.now().difference(derniere) < const Duration(hours: 1)) {
        return;
      }
      await sauvegarder(type: 'auto');
    } catch (_) {
      // on ne bloque jamais la fermeture
    }
  }

  // Copie de sécurité avant que la structure de la base soit mise à jour.
  // Appelée avant d'ouvrir la base : le fichier est fermé, une copie simple suffit.
  static Future<void> avantMigration(AppConfig config) async {
    final fichier = File(config.cheminBase);
    if (!await fichier.exists()) return;

    int version;
    try {
      version = await DatabaseService.versionDuFichier(config.cheminBase);
    } catch (_) {
      return;
    }
    if (version <= 0 || version >= DatabaseService.versionBase) return;

    await Directory(config.dossierSauvegarde).create(recursive: true);
    final nom = _nomFichier(DateTime.now(), 'avantmigration');
    await fichier.copy(
      '${config.dossierSauvegarde}${Platform.pathSeparator}$nom',
    );
    await _appliquerRotation(config.dossierSauvegarde, config);
  }

  // Remplace la base par une sauvegarde. Après l'appel, il faut redémarrer
  // la séquence de démarrage (elle rouvre la base).
  static Future<void> restaurer(String cheminSource) async {
    final config = await ConfigService.lire();
    if (config == null) throw Exception('Configuration introuvable');

    if (!await DatabaseService.verifierFichier(cheminSource)) {
      throw Exception(
        'Ce fichier de sauvegarde est illisible ou incomplet : restauration annulée',
      );
    }

    // 1. Une copie de sécurité de la base actuelle
    if (DatabaseService.estOuverte) {
      await sauvegarder(type: 'avantrestauration');
    }

    // 2. On arrête la surveillance et on ferme la base
    _minuteur?.cancel();
    _minuteur = null;
    await DatabaseService.fermer();

    // 3. On remplace le fichier : copie à côté, puis renommage, pour ne jamais
    // laisser une base à moitié copiée
    final cible = config.cheminBase;
    final temporaire = '$cible.restauration';
    await File(cheminSource).copy(temporaire);

    for (final suffixe in ['-wal', '-shm', '-journal']) {
      final annexe = File('$cible$suffixe');
      if (await annexe.exists()) await annexe.delete();
    }
    await File(temporaire).rename(cible);
  }

  static Future<StatutSauvegarde> statut() async {
    final config = await ConfigService.lire();
    final derniere = config?.derniereSauvegarde == null
        ? null
        : DateTime.tryParse(config!.derniereSauvegarde!);
    return StatutSauvegarde(
      derniere: derniere,
      automatique: config?.sauvegardeAuto ?? false,
    );
  }
}
