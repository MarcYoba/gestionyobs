import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Les informations de configuration de l'application.
class AppConfig {
  final String type;
  final String cheminBase;
  final String dossierSauvegarde;

  const AppConfig({
    required this.type,
    required this.cheminBase,
    required this.dossierSauvegarde,
  });

  // Transforme l'objet en données JSON (pour l'écrire dans le fichier)
  Map<String, dynamic> toJson() => {
        'type': type,
        'cheminBase': cheminBase,
        'dossierSauvegarde': dossierSauvegarde,
      };

  // Transforme des données JSON en objet (pour lire le fichier)
  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
        type: json['type'] as String,
        cheminBase: json['cheminBase'] as String,
        dossierSauvegarde: json['dossierSauvegarde'] as String,
      );
}

/// Gère le fichier config.json : existe, lire, écrire, supprimer.
class ConfigService {
  static const _nomFichier = 'config.json';

  // Retourne le fichier config.json (sans le créer)
  static Future<File> _fichier() async {
    final dossier = await getApplicationSupportDirectory();
    return File('${dossier.path}${Platform.pathSeparator}$_nomFichier');
  }

  static Future<String> chemin() async => (await _fichier()).path;

  static Future<bool> existe() async => (await _fichier()).exists();

  // Retourne la configuration, ou null si absente ou illisible
  static Future<AppConfig?> lire() async {
    final fichier = await _fichier();
    if (!await fichier.exists()) return null;
    try {
      final texte = await fichier.readAsString();
      final json = jsonDecode(texte) as Map<String, dynamic>;
      return AppConfig.fromJson(json);
    } catch (_) {
      return null; // fichier abîmé ou incomplet
    }
  }

  static Future<void> ecrire(AppConfig config) async {
    final fichier = await _fichier();
    await fichier.create(recursive: true);
    await fichier.writeAsString(
      const JsonEncoder.withIndent('  ').convert(config.toJson()),
    );
  }

  static Future<void> supprimer() async {
    final fichier = await _fichier();
    if (await fichier.exists()) {
      await fichier.delete();
    }
  }
}