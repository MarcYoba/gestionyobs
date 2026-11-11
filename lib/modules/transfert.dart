import 'package:flutter/material.dart';

import 'annulation.dart';

/// Les étapes d'un transfert : code enregistré -> libellé affiché.
const Map<String, String> statutsTransfert = {
  'demande': 'Demandé',
  'accepte': 'Accepté',
  'refuse': 'Refusé',
  'expedie': 'En transit',
  'recu': 'Reçu',
  'annule': 'Annulé',
};

/// La couleur de chaque étape.
MaterialColor couleurStatutTransfert(String statut) => switch (statut) {
  'demande' => Colors.orange,
  'accepte' => Colors.blue,
  'refuse' => Colors.red,
  'expedie' => Colors.purple,
  'recu' => Colors.green,
  _ => Colors.grey,
};

/// Une ligne saisie dans le formulaire de demande.
class LigneTransfertSaisie {
  final int articleId;
  final double quantite;

  const LigneTransfertSaisie({required this.articleId, required this.quantite});
}

/// Une quantité saisie pour une ligne (acceptée, expédiée ou reçue).
class QuantiteLigneSaisie {
  final int ligneId;
  final double quantite;

  const QuantiteLigneSaisie({required this.ligneId, required this.quantite});
}

/// Une ligne de la liste des transferts.
class TransfertResume {
  final int id;
  final String code;
  final String statut;
  final String source;
  final String demandeuse;
  final DateTime demandeLe;
  final int nbLignes;

  const TransfertResume({
    required this.id,
    required this.code,
    required this.statut,
    required this.source,
    required this.demandeuse,
    required this.demandeLe,
    required this.nbLignes,
  });

  factory TransfertResume.fromMap(Map<String, Object?> m) => TransfertResume(
    id: m['id'] as int,
    code: m['code'] as String,
    statut: m['statut'] as String,
    source: m['source'] as String,
    demandeuse: m['demandeuse'] as String,
    demandeLe: DateTime.parse(m['demande_le'] as String),
    nbLignes: m['nb'] as int,
  );
}

/// Un article d'un transfert, avec ses quantités à chaque étape.
class LigneTransfert {
  final int id;
  final int articleId;
  final String code;
  final String designation;
  final String unite;
  final double demandee;
  final double? acceptee;
  final double? expediee;
  final double? recue;

  const LigneTransfert({
    required this.id,
    required this.articleId,
    required this.code,
    required this.designation,
    required this.unite,
    required this.demandee,
    required this.acceptee,
    required this.expediee,
    required this.recue,
  });

  factory LigneTransfert.fromMap(Map<String, Object?> m) => LigneTransfert(
    id: m['id'] as int,
    articleId: m['article_id'] as int,
    code: m['code_article'] as String,
    designation: m['designation'] as String,
    unite: m['unite'] as String,
    demandee: (m['quantite_demandee'] as num).toDouble(),
    acceptee: (m['quantite_acceptee'] as num?)?.toDouble(),
    expediee: (m['quantite_expediee'] as num?)?.toDouble(),
    recue: (m['quantite_recue'] as num?)?.toDouble(),
  );

  // Une différence entre ce qui est parti et ce qui est arrivé
  bool get ecart =>
      expediee != null && recue != null && (expediee! - recue!).abs() > 0.0005;
}

/// Un transfert complet : le déroulement et les lignes.
class TransfertDetail {
  final int id;
  final String code;
  final String statut;
  final int sourceId;
  final String source;
  final int demandeuseId;
  final String demandeuse;
  final String? note;
  final String demandePar;
  final DateTime demandeLe;
  final String? decisionPar;
  final DateTime? decisionLe;
  final String? motifRefus;
  final String? expediePar;
  final DateTime? expedieLe;
  final String? recuPar;
  final DateTime? recuLe;
  final String? noteReception;
  final InfoAnnulation? annulation;
  final List<LigneTransfert> lignes;

  const TransfertDetail({
    required this.id,
    required this.code,
    required this.statut,
    required this.sourceId,
    required this.source,
    required this.demandeuseId,
    required this.demandeuse,
    required this.note,
    required this.demandePar,
    required this.demandeLe,
    required this.decisionPar,
    required this.decisionLe,
    required this.motifRefus,
    required this.expediePar,
    required this.expedieLe,
    required this.recuPar,
    required this.recuLe,
    required this.noteReception,
    required this.annulation,
    required this.lignes,
  });
}
