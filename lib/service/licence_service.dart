import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

/// Résultat du contrôle de la licence.
class EtatLicence {
  final bool autorise; // le logiciel peut-il démarrer ?
  final bool licencie; // une licence valide est installée
  final int joursRestants; // pendant l'essai
  final String codePoste;
  final String? client;
  final DateTime? expiration;
  final String message;

  const EtatLicence({
    required this.autorise,
    required this.licencie,
    required this.joursRestants,
    required this.codePoste,
    required this.message,
    this.client,
    this.expiration,
  });
}

class LicenceService {
  // Durée de l'essai, en jours
  static const int dureeEssai = 30;

  // La clé PUBLIQUE affichée par l'outil de génération (commande « pub »).
  // Elle ne permet que de vérifier, jamais de fabriquer une licence.
  static const String _clePublique =
      'paRFO47W2yKOqQpBwWqR7+GVQ4pdlBQi83bcqXT6pAw=';

  static const String _dossier = 'GestionYobs';
  static const String _cleRegistre = r'HKCU\Software\GestionYobs';

  static String? _codeCache;

  // ---------- Code du poste ----------

  static const _valeursBidon = [
    'to be filled',
    'default string',
    'system serial',
    'not applicable',
    'not specified',
    'none',
    'n/a',
    '00000000-0000-0000-0000-000000000000',
    'ffffffff-ffff-ffff-ffff-ffffffffffff',
  ];

  static bool _valide(String v) {
    final t = v.trim().toLowerCase();
    if (t.length < 4) return false;
    if (RegExp(r'^[0\-:\s]+$').hasMatch(t)) return false;
    return !_valeursBidon.any(t.contains);
  }

  static Future<String> _powershell(String script) async {
    try {
      final r = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        script,
      ]);
      return r.exitCode == 0 ? (r.stdout as String).trim() : '';
    } catch (_) {
      return '';
    }
  }

  static String _hex(List<int> octets) =>
      octets.map((o) => o.toRadixString(16).padLeft(2, '0')).join();

  // Le code du poste : « A1B2C-3D4E5-F6A7B-8C9D0 »
  static Future<String> codePoste() async {
    if (_codeCache != null) return _codeCache!;

    final sources = <String, String>{
      'carte': r'(Get-CimInstance Win32_BaseBoard).SerialNumber',
      'uuid': r'(Get-CimInstance Win32_ComputerSystemProduct).UUID',
      'reseau':
          r"(Get-NetAdapter -Physical | "
          r"Where-Object { $_.InterfaceDescription -notmatch 'Bluetooth|Virtual|VPN' } | "
          r"Sort-Object InterfaceIndex | Select-Object -First 1).MacAddress",
    };

    String identifiant = '';
    for (final e in sources.entries) {
      final valeur = await _powershell(e.value);
      if (_valide(valeur)) {
        identifiant = '${e.key}|${valeur.toUpperCase()}';
        break;
      }
    }
    if (identifiant.isEmpty) {
      throw Exception("Impossible de lire l'identifiant de cet ordinateur");
    }

    final h = await Sha256().hash(utf8.encode('YOBS|$identifiant'));
    final c = _hex(h.bytes).substring(0, 20).toUpperCase();
    _codeCache =
        '${c.substring(0, 5)}-${c.substring(5, 10)}-${c.substring(10, 15)}-${c.substring(15, 20)}';
    return _codeCache!;
  }

  // ---------- Licence ----------

  static String _dossierLocal() =>
      '${Platform.environment['LOCALAPPDATA'] ?? '.'}\\$_dossier';
  static String _dossierRoaming() =>
      '${Platform.environment['APPDATA'] ?? '.'}\\$_dossier';

  // Lit et contrôle une clé de licence pour ce poste
  static Future<({Map<String, dynamic>? infos, String? erreur})> _analyser(
    String cle,
    String code,
  ) async {
    if (_clePublique.startsWith('COLLER')) {
      return (
        infos: null,
        erreur: 'La clé publique du logiciel n\'est pas configurée',
      );
    }
    try {
      final parts = cle.replaceAll(RegExp(r'\s'), '').split('.');
      if (parts.length != 3 || parts[0] != 'YOBS1') {
        return (infos: null, erreur: 'Clé de licence invalide');
      }
      final payload = base64Url.decode(parts[1]);
      final signature = base64Url.decode(parts[2]);

      final ok = await Ed25519().verify(
        payload,
        signature: Signature(
          signature,
          publicKey: SimplePublicKey(
            base64.decode(_clePublique),
            type: KeyPairType.ed25519,
          ),
        ),
      );
      if (!ok) return (infos: null, erreur: 'Clé de licence invalide');

      final infos = jsonDecode(utf8.decode(payload)) as Map<String, dynamic>;
      if (infos['poste'] != code) {
        return (
          infos: null,
          erreur: 'Cette licence est destinée à un autre ordinateur',
        );
      }
      final exp = infos['exp'] as String?;
      if (exp != null) {
        final fin = DateTime.parse(exp).add(const Duration(days: 1));
        if (DateTime.now().isAfter(fin)) {
          return (infos: null, erreur: 'Cette licence a expiré le $exp');
        }
      }
      return (infos: infos, erreur: null);
    } catch (_) {
      return (infos: null, erreur: 'Clé de licence invalide');
    }
  }

  static Future<String?> _lireLicence() async {
    for (final d in [_dossierLocal(), _dossierRoaming()]) {
      final f = File('$d\\licence.key');
      if (await f.exists()) return f.readAsString();
    }
    return null;
  }

  // Enregistre la licence sur ce poste après l'avoir vérifiée
  static Future<void> activer(String cle) async {
    final code = await codePoste();
    final r = await _analyser(cle, code);
    if (r.erreur != null) throw Exception(r.erreur);

    final texte = cle.replaceAll(RegExp(r'\s'), '');
    for (final d in [_dossierLocal(), _dossierRoaming()]) {
      try {
        await Directory(d).create(recursive: true);
        await File('$d\\licence.key').writeAsString(texte);
      } catch (_) {}
    }
  }

  // ---------- Période d'essai ----------

  static Future<String> _mac(String donnees, String code) async {
    final m = await Hmac.sha256().calculateMac(
      utf8.encode(donnees),
      secretKey: SecretKey(utf8.encode('essai-yobs|$code')),
    );
    return _hex(m.bytes);
  }

  static Future<String> _emballer(
    DateTime premier,
    DateTime dernier,
    String code,
  ) async {
    final corps = base64Url.encode(
      utf8.encode(
        jsonEncode({
          'p': premier.toIso8601String(),
          'd': dernier.toIso8601String(),
        }),
      ),
    );
    return '$corps.${await _mac(corps, code)}';
  }

  static Future<(DateTime, DateTime)?> _deballer(
    String texte,
    String code,
  ) async {
    final parts = texte.trim().split('.');
    if (parts.length != 2) return null;
    if (await _mac(parts[0], code) != parts[1]) return null;
    try {
      final m = jsonDecode(
        utf8.decode(base64Url.decode(parts[0])),
      ) as Map<String, dynamic>;
      return (
        DateTime.parse(m['p'] as String),
        DateTime.parse(m['d'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  // Trois emplacements : fichier local, fichier roaming, registre
  static Future<String?> _lire(int i) async {
    try {
      if (i == 0 || i == 1) {
        final d = i == 0 ? _dossierLocal() : _dossierRoaming();
        final f = File('$d\\essai.dat');
        return await f.exists() ? await f.readAsString() : null;
      }
      final r = await Process.run('reg', ['query', _cleRegistre, '/v', 'Etat']);
      if (r.exitCode != 0) return null;
      for (final ligne in (r.stdout as String).split('\n')) {
        if (ligne.contains('REG_SZ'))
          return ligne.trim().split(RegExp(r'\s+')).last;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> _ecrire(int i, String valeur) async {
    try {
      if (i == 0 || i == 1) {
        final d = i == 0 ? _dossierLocal() : _dossierRoaming();
        await Directory(d).create(recursive: true);
        await File('$d\\essai.dat').writeAsString(valeur);
        return;
      }
      await Process.run('reg', [
        'add',
        _cleRegistre,
        '/v',
        'Etat',
        '/t',
        'REG_SZ',
        '/d',
        valeur,
        '/f',
      ]);
    } catch (_) {}
  }

  static EtatLicence _essaiTermine(String code, String raison) => EtatLicence(
    autorise: false,
    licencie: false,
    joursRestants: 0,
    codePoste: code,
    message: raison,
  );

  static Future<EtatLicence> _essai(String code) async {
    final maintenant = DateTime.now();
    DateTime? premier;
    DateTime? dernier;
    var invalides = 0;

    for (var i = 0; i < 3; i++) {
      final texte = await _lire(i);
      if (texte == null) continue;
      final d = await _deballer(texte, code);
      if (d == null) {
        invalides++;
        continue;
      }
      if (premier == null || d.$1.isBefore(premier)) premier = d.$1;
      if (dernier == null || d.$2.isAfter(dernier)) dernier = d.$2;
    }

    if (premier == null || dernier == null) {
      if (invalides > 0) {
        return _essaiTermine(
          code,
          "Les données de la période d'essai sont illisibles ou ont été modifiées. "
          'Activez le logiciel avec une licence.',
        );
      }
      // Première installation
      premier = maintenant;
      dernier = maintenant;
    }

    // L'horloge a été reculée
    if (maintenant.isBefore(dernier.subtract(const Duration(hours: 2)))) {
      return _essaiTermine(
        code,
        "La date de l'ordinateur a été reculée. Activez le logiciel avec une licence.",
      );
    }
    if (maintenant.isAfter(dernier)) dernier = maintenant;

    // On réécrit partout : un emplacement effacé est reconstitué
    final valeur = await _emballer(premier, dernier, code);
    for (var i = 0; i < 3; i++) {
      await _ecrire(i, valeur);
    }

    final restants = dureeEssai - maintenant.difference(premier).inDays;
    if (restants <= 0) {
      return _essaiTermine(
        code,
        "La période d'essai de $dureeEssai jours est terminée. "
        'Activez le logiciel avec une licence.',
      );
    }
    return EtatLicence(
      autorise: true,
      licencie: false,
      joursRestants: restants,
      codePoste: code,
      message:
          "Période d'essai : $restants jour${restants > 1 ? 's' : ''} restant${restants > 1 ? 's' : ''}",
    );
  }

  // ---------- Le contrôle principal ----------

  static Future<EtatLicence> verifier() async {
    final String code;
    try {
      code = await codePoste();
    } catch (e) {
      return EtatLicence(
        autorise: false,
        licencie: false,
        joursRestants: 0,
        codePoste: '',
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }

    final cle = await _lireLicence();
    if (cle != null) {
      final r = await _analyser(cle, code);
      if (r.infos != null) {
        final exp = r.infos!['exp'] as String?;
        return EtatLicence(
          autorise: true,
          licencie: true,
          joursRestants: 0,
          codePoste: code,
          client: r.infos!['client'] as String?,
          expiration: exp == null ? null : DateTime.parse(exp),
          message: 'Licence valide',
        );
      }
      // Une licence présente mais refusée (expirée, autre poste) : on retombe
      // sur l'essai, qui sera probablement terminé.
    }
    return _essai(code);
  }
}
