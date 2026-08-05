// ============================================================
// MODÈLE RÉSULTAT CONSANGUINITÉ — v5 (Wright seul décisionnel)
// Fichier: lib/Eleveures/New/Accouplemt/ResultatConsanguinite.dart
// ============================================================

class ResultatConsanguinite {
  // ── Résultat Wright (décisionnel) ────────────────────────
  final bool   succes;
  final String resultat;        // ACCEPTABLE | MODÉRÉ | ÉLEVÉ | ERREUR
  final String couleur;         // vert | orange | rouge | gris
  final String message;
  final String action;          // AUTORISER | AVERTIR | BLOQUER | INCONNU
  final String methode;         // wright_exact | wright_partiel | wright_moyen_race

  // ── Coefficient F ────────────────────────────────────────
  final double fPourcent;       // F ajusté en %
  final double fWright;         // F brut calculé par Wright
  final double fAjuste;         // F après correction incomplétude

  // ── Généalogie ───────────────────────────────────────────
  final String       relation;          // "Demi-frère/sœur", "Cousin"…
  final List<String> ancetresCommuns;   // noms des ancêtres communs
  final double       incompletudeMoyenne;

  // ── Confiance Wright ─────────────────────────────────────
  final String confiance;        // ÉLEVÉE | MODÉRÉE | FAIBLE | TRÈS FAIBLE
  final String confianceMessage;

  // ── Flags ────────────────────────────────────────────────
  final bool belierInconnu;

  // ── Erreur ───────────────────────────────────────────────
  final String? erreur;

  const ResultatConsanguinite({
    required this.succes,
    required this.resultat,
    required this.couleur,
    required this.message,
    required this.action,
    required this.methode,
    required this.fPourcent,
    required this.fWright,
    required this.fAjuste,
    required this.relation,
    required this.ancetresCommuns,
    required this.incompletudeMoyenne,
    required this.confiance,
    required this.confianceMessage,
    required this.belierInconnu,
    this.erreur,
  });

  // ── Getters utilitaires ───────────────────────────────────
  bool get estAcceptable  => resultat == 'ACCEPTABLE';
  bool get estModere      => resultat == 'MODÉRÉ';
  bool get estRisque      => resultat == 'ÉLEVÉ';
  bool get estErreur      => resultat == 'ERREUR';
  bool get pedigreeComplet => incompletudeMoyenne <= 0.1;
  bool get pedigreePartiel => incompletudeMoyenne > 0.1 && incompletudeMoyenne <= 0.7;
  bool get pedigreeInconnu => incompletudeMoyenne > 0.7;

  String get methodelabel {
    switch (methode) {
      case 'wright_exact'      : return 'Wright (pedigree complet)';
      case 'wright_partiel'    : return 'Wright + correction incertitude';
      case 'wright_moyen_race' : return 'Moyenne race Ladoum (pedigree inconnu)';
      default                  : return methode;
    }
  }

  String get fFormate => '${fPourcent.toStringAsFixed(1)}%';

  // ── Constructeur depuis JSON API ──────────────────────────
  factory ResultatConsanguinite.fromJson(Map<String, dynamic> json) {
    return ResultatConsanguinite(
      succes              : json['succes']                ?? false,
      resultat            : json['niveau']                ?? json['resultat'] ?? 'ACCEPTABLE',
      couleur             : json['couleur']               ?? 'vert',
      message             : json['message']               ?? '',
      action              : json['action']                ?? 'AUTORISER',
      methode             : json['methode']               ?? 'wright_moyen_race',
      fPourcent           : (json['f_pourcent']           ?? 0.0).toDouble(),
      fWright             : (json['f_wright']             ?? 0.0).toDouble(),
      fAjuste             : (json['f_ajuste']             ?? 0.0).toDouble(),
      relation            : json['relation']              ?? 'Inconnu',
      ancetresCommuns     : List<String>.from(json['ancetres_communs'] ?? []),
      incompletudeMoyenne : (json['incompletude_moyenne'] ?? 1.0).toDouble(),
      confiance           : json['confiance']             ?? 'TRÈS FAIBLE',
      confianceMessage    : json['confiance_message']     ?? '',
      belierInconnu       : json['belier_inconnu']        ?? false,
    );
  }

  // ── Constructeur d'erreur ─────────────────────────────────
  factory ResultatConsanguinite.erreur(String msg) {
    return ResultatConsanguinite(
      succes              : false,
      resultat            : 'ERREUR',
      couleur             : 'gris',
      message             : msg,
      action              : 'INCONNU',
      methode             : 'wright_moyen_race',
      fPourcent           : 0,
      fWright             : 0,
      fAjuste             : 0,
      relation            : 'Inconnu',
      ancetresCommuns     : [],
      incompletudeMoyenne : 1,
      confiance           : 'TRÈS FAIBLE',
      confianceMessage    : '',
      belierInconnu       : false,
      erreur              : msg,
    );
  }
}