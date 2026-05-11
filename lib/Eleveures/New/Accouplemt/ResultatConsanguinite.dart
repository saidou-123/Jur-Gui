// ============================================================
// MODÈLE RÉSULTAT CONSANGUINITÉ
// Fichier: lib/Eleveures/New/Accouplemt/ResultatConsanguinite.dart
//
// Classe de données partagée entre :
//   • ConsanguiniteService.dart  (production du résultat)
//   • ResultatConsanguiniteWidget.dart (affichage)
//   • Accouplement.dart  (utilisation dans le formulaire)
// ============================================================

class ResultatConsanguinite {
  // ── Résultat principal ────────────────────────────────────
  final bool   succes;
  final String resultat;   // ACCEPTABLE | MODÉRÉ | ÉLEVÉ | ERREUR
  final String couleur;    // vert | orange | rouge | gris
  final String message;
  final String action;     // AUTORISER | AVERTIR | BLOQUER | INCONNU

  // ── Données Wright ────────────────────────────────────────
  final double       fPourcent;        // F ajusté en %
  final double       fWright;          // F brut calculé par Wright
  final double       fAjuste;          // F corrigé incomplétude
  final String       relation;         // "Demi-frère/sœur", "Cousin"…
  final List<String> ancetresCommuns;  // noms des ancêtres communs
  final double       incompletudeMoyenne;

  // ── Confiance ────────────────────────────────────────────
  final String confiance;        // ÉLEVÉE | MODÉRÉE | FAIBLE | TRÈS FAIBLE
  final String confianceMessage;
  final String methode;          // wright_exact | wright_partiel | ml_seul

  // ── Complément ML ────────────────────────────────────────
  final double confianceAcceptable;
  final double confianceRisque;
  final String mlResultat;       // ACCEPTABLE | RISQUE | INCONNU

  // ── Flags ────────────────────────────────────────────────
  final bool    belierInconnu;
  final String? erreur;

  const ResultatConsanguinite({
    required this.succes,
    required this.resultat,
    required this.couleur,
    required this.message,
    required this.action,
    required this.fPourcent,
    required this.fWright,
    required this.fAjuste,
    required this.relation,
    required this.ancetresCommuns,
    required this.incompletudeMoyenne,
    required this.confiance,
    required this.confianceMessage,
    required this.methode,
    required this.confianceAcceptable,
    required this.confianceRisque,
    required this.mlResultat,
    required this.belierInconnu,
    this.erreur,
  });

  // ── Getters utilitaires ───────────────────────────────────
  bool get estAcceptable => resultat == 'ACCEPTABLE';
  bool get estRisque     => resultat == 'ÉLEVÉ' || resultat == 'RISQUE';
  bool get estModere     => resultat == 'MODÉRÉ';
  bool get estErreur     => resultat == 'ERREUR';

  // ── Constructeur depuis JSON API /analyser-pedigree ───────
  factory ResultatConsanguinite.fromJson(Map<String, dynamic> json) {
    return ResultatConsanguinite(
      succes              : json['succes']               ?? false,
      resultat            : json['niveau']               ?? json['resultat'] ?? 'ACCEPTABLE',
      couleur             : json['couleur']              ?? 'vert',
      message             : json['message']              ?? '',
      action              : json['action']               ?? 'AUTORISER',
      fPourcent           : (json['f_pourcent']          ?? 0.0).toDouble(),
      fWright             : (json['f_wright']            ?? 0.0).toDouble(),
      fAjuste             : (json['f_ajuste']            ?? 0.0).toDouble(),
      relation            : json['relation']             ?? 'Inconnu',
      ancetresCommuns     : List<String>.from(json['ancetres_communs'] ?? []),
      incompletudeMoyenne : (json['incompletude_moyenne'] ?? 1.0).toDouble(),
      confiance           : json['confiance']            ?? 'TRÈS FAIBLE',
      confianceMessage    : json['confiance_message']    ?? '',
      methode             : json['methode']              ?? 'ml_seul',
      confianceAcceptable : (json['ml_confiance_acceptable'] ?? 0.5).toDouble(),
      confianceRisque     : (json['ml_confiance_risque']     ?? 0.5).toDouble(),
      mlResultat          : json['ml_resultat']          ?? 'INCONNU',
      belierInconnu       : json['belier_inconnu']       ?? false,
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
      fPourcent           : 0,
      fWright             : 0,
      fAjuste             : 0,
      relation            : 'Inconnu',
      ancetresCommuns     : [],
      incompletudeMoyenne : 1,
      confiance           : 'TRÈS FAIBLE',
      confianceMessage    : '',
      methode             : 'ml_seul',
      confianceAcceptable : 0,
      confianceRisque     : 0,
      mlResultat          : 'INCONNU',
      belierInconnu       : false,
      erreur              : msg,
    );
  }
}