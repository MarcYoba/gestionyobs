import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Les informations de configuration de l'application.
/// Les informations de configuration de ce poste.
class AppConfig {
  final String type;
  final String cheminBase;
  final String dossierSauvegarde;

  // Impression des tickets sur ce poste
  final int largeurPapier; // 58 ou 80 (mm)
  final String? imprimante; // null = choisir à chaque impression
  final bool impressionAuto; // imprimer après chaque vente
  final bool reglagesImprimante; // utiliser le format du pilote Windows

  const AppConfig({
    required this.type,
    required this.cheminBase,
    required this.dossierSauvegarde,
    this.largeurPapier = 80,
    this.imprimante,
    this.impressionAuto = false,
    this.reglagesImprimante = false,
  });

  AppConfig copyWith({
    int? largeurPapier,
    String? imprimante,
    bool effacerImprimante = false,
    bool? impressionAuto,
    bool? reglagesImprimante,
  }) => AppConfig(
    type: type,
    cheminBase: cheminBase,
    dossierSauvegarde: dossierSauvegarde,
    largeurPapier: largeurPapier ?? this.largeurPapier,
    imprimante: effacerImprimante ? null : (imprimante ?? this.imprimante),
    impressionAuto: impressionAuto ?? this.impressionAuto,
    reglagesImprimante: reglagesImprimante ?? this.reglagesImprimante,
  );

  Map<String, dynamic> toJson() => {
    'type': type,
    'cheminBase': cheminBase,
    'dossierSauvegarde': dossierSauvegarde,
    'largeurPapier': largeurPapier,
    'imprimante': imprimante,
    'impressionAuto': impressionAuto,
    'reglagesImprimante': reglagesImprimante,
  };

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
    type: json['type'] as String,
    cheminBase: json['cheminBase'] as String,
    dossierSauvegarde: json['dossierSauvegarde'] as String,
    largeurPapier: (json['largeurPapier'] as int?) ?? 80,
    imprimante: json['imprimante'] as String?,
    impressionAuto: (json['impressionAuto'] as bool?) ?? false,
    reglagesImprimante: (json['reglagesImprimante'] as bool?) ?? false,
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
