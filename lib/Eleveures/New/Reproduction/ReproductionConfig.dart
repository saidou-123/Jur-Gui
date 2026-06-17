// ============================================================
// CONFIGURATION MODULE REPRODUCTION
// Constantes et paramètres métier pour l'élevage ovin
// Chemin: lib/Eleveures/New/Reproduction/ReproductionConfig.dart
//
// ★ ÉTAPE 7 — Nouveaux paliers de rappel :
//   rappel15JoursAvantJours : J-15 (manquait)
//   rappel3JoursAvantJours  : J-3  (manquait)
//   Les existants J-30, J-7, J-1 sont conservés intacts.
// ============================================================
 
class ReproductionConfig {
  // ===== CYCLES DE REPRODUCTION =====
  static const int cycleMoyenJours = 17;
  static const int cycleMinJours   = 14;
  static const int cycleMaxJours   = 25;
 
  // Durée de la chaleur
  static const int dureeChaleurHeures  = 30;
  static const int debutFenetileHeures = 12;
 
  // ===== CONTRÔLE RETOUR EN CHALEUR (ÉTAPE 5) =====
  static const int retourChaleurDebutJours     = 17;
  static const int retourChaleurFinJours       = 21;
  static const double probabiliteGestationBase    = 0.65;
  static const double probabiliteGestationElevee  = 0.80;
  static const double probabiliteGestationModeree = 0.60;
 
  // ===== GESTATION =====
  static const int gestationMoyenneJours = 150;
  static const int gestationMinJours     = 142;
  static const int gestationMaxJours     = 157;
 
  // ===== LACTATION =====
  static const int dureeLactationJours = 90;
  static const int periodeSevrageJours = 30;
 
  // ===== RAPPELS ET NOTIFICATIONS =====
  static const int rappelAvantChaleurJours      = 2;
  static const int rappelFenetileFertileHeures  = 6;
 
  // Rappels agnelage — 5 paliers complets (étape 7)
  static const int rappel1MoisAvantJours    = 30; // J-30 existant
  static const int rappel15JoursAvantJours  = 15; // ★ J-15 ajouté
  static const int rappel1SemaineAvantJours =  7; // J-7  existant
  static const int rappel3JoursAvantJours   =  3; // ★ J-3 ajouté
  static const int rappel24hAvantJours      =  1; // J-1  existant
 
  // ===== SAISONS DE REPRODUCTION =====
  static const List<int> saisonActiveDebut      = [9]; // Septembre
  static const List<int> saisonActiveFin        = [2]; // Février
  static const List<int> saisonTransitionDebut  = [3]; // Mars
  static const List<int> saisonTransitionFin    = [5]; // Mai
  static const List<int> anoestrusSaisonnierDebut = [6]; // Juin
  static const List<int> anoestrusSaisonnierFin   = [8]; // Août
 
  // ===== RÈGLES MÉTIER =====
  static const int ageMinimumReproductionMois    = 8;
  static const int joursMinEntreAccouplements    = 30;
  static const int nombreMaxAccouplementsParAn   = 2;
 
  // ===== STATISTIQUES =====
  static const double tauxFertiliteNormalMin = 0.75;
  static const double tauxFertiliteNormalMax = 0.90;
 
  // ===== MESSAGES =====
  static const String messageAnoestrus =
      "Période d'anœstrus saisonnier. Les chaleurs sont rares et irrégulières durant cette période.";
 
  static const String messageGestante =
      "Cette brebis est actuellement gestante. Aucun accouplement possible.";
 
  static const String messageLactation =
      "Brebis en période de lactation. Les chaleurs peuvent être irrégulières.";
 
  static const String messageTropJeune =
      "Cette brebis est trop jeune pour la reproduction (minimum 8 mois).";
 
  static const String messageIntervalleCourtChaleur =
      "⚠️ Intervalle trop court entre les chaleurs. Cela peut indiquer un problème hormonal. Consultez un vétérinaire si cela se répète.";
 
  static const String messageIntervalleLongChaleur =
      "⚠️ Intervalle plus long que la normale. Cela peut indiquer du stress ou un problème de santé.";
 
  // ===== NIVEAUX DE CONFIANCE PRÉDICTION =====
  static String getNiveauConfiance({
    required bool enLactation,
    required bool cycleIrregulier,
    required bool anoestrus,
    required bool recentSevrage,
  }) {
    if (anoestrus)                    return "Très faible";
    if (cycleIrregulier)              return "Faible";
    if (enLactation || recentSevrage) return "Modéré";
    return "Élevé";
  }
 
  // ===== COULEURS INTERFACE =====
  static const int colorPrimary   = 0xFFE91E63; // Pink
  static const int colorSecondary = 0xFF9C27B0; // Purple
  static const int colorSuccess   = 0xFF4CAF50; // Green
  static const int colorWarning   = 0xFFFF9800; // Orange
  static const int colorDanger    = 0xFFF44336; // Red
  static const int colorInfo      = 0xFF2196F3; // Blue
}
 