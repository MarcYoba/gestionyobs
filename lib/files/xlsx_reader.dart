import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Une ligne lue dans une feuille Excel.
class LigneXlsx {
  final int numero; // numéro de ligne affiché dans Excel (1 = première ligne)
  final List<String?> cases; // une case par colonne, null si elle est vide

  const LigneXlsx(this.numero, this.cases);
}

// 'B12' -> 1 (la colonne A vaut 0)
int _indexColonne(String reference) {
  var n = 0;
  var trouve = false;
  for (final unite in reference.codeUnits) {
    if (unite >= 65 && unite <= 90) {
      n = n * 26 + (unite - 64);
      trouve = true;
    } else {
      break;
    }
  }
  return trouve ? n - 1 : -1;
}

/// Lit la première feuille d'un fichier .xlsx.
Future<List<LigneXlsx>> lireXlsx(String chemin) async {
  final octets = await File(chemin).readAsBytes();

  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(octets);
  } catch (_) {
    throw Exception(
      'Fichier illisible : seuls les fichiers .xlsx sont pris en charge',
    );
  }

  String? lireTexte(String nom) {
    final fichier = archive.findFile(nom);
    if (fichier == null) return null;
    return utf8.decode(fichier.content as List<int>);
  }

  // Les textes sont rangés une seule fois dans sharedStrings.xml
  final partages = <String>[];
  final xmlPartages = lireTexte('xl/sharedStrings.xml');
  if (xmlPartages != null) {
    final doc = XmlDocument.parse(xmlPartages);
    for (final si in doc.findAllElements('si')) {
      partages.add(si.findAllElements('t').map((t) => t.innerText).join());
    }
  }

  // La première feuille de calcul
  final feuilles =
      archive.files
          .where(
            (f) =>
                f.isFile &&
                f.name.startsWith('xl/worksheets/sheet') &&
                f.name.endsWith('.xml'),
          )
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
  if (feuilles.isEmpty)
    throw Exception('Aucune feuille trouvée dans ce fichier');

  final doc = XmlDocument.parse(
    utf8.decode(feuilles.first.content as List<int>),
  );
  final lignes = <LigneXlsx>[];

  for (final ligne in doc.findAllElements('row')) {
    final cases = <int, String>{};
    var derniere = -1;

    for (final c in ligne.findElements('c')) {
      final col = _indexColonne(c.getAttribute('r') ?? '');
      if (col < 0) continue;

      final type = c.getAttribute('t');
      String? valeur;
      if (type == 's') {
        final index = int.tryParse(c.getElement('v')?.innerText ?? '');
        if (index != null && index < partages.length) valeur = partages[index];
      } else if (type == 'inlineStr') {
        valeur = c.findAllElements('t').map((t) => t.innerText).join();
      } else {
        valeur = c.getElement('v')?.innerText;
      }

      if (valeur != null) {
        cases[col] = valeur;
        if (col > derniere) derniere = col;
      }
    }

    final liste = List<String?>.filled(derniere + 1, null);
    cases.forEach((col, valeur) => liste[col] = valeur);

    final numero =
        int.tryParse(ligne.getAttribute('r') ?? '') ?? (lignes.length + 1);
    lignes.add(LigneXlsx(numero, liste));
  }

  return lignes;
}
