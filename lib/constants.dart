// ============================================================
// CONSTANTS.DART — Constantes partagées JUR GUI
// ============================================================
// Centralise toutes les valeurs répétées dans le code pour :
// - Éviter les incohérences entre fichiers (ex: 'tout' vs 'Tout')
// - Faciliter la maintenance : un seul endroit à modifier
// - Prévenir les bugs dus aux fautes de frappe
//
// USAGE :
//   import 'package:depart/constants.dart';
//   String filtre = FiltreHistorique.tout;
//   String role   = Roles.eleveur;
// ============================================================

// ─── Filtres historique médical ───────────────────────────
// Utilisés dans HistoriqueMedical.dart ET HistoriqueMedicalEleveur.dart
// Avant : vétérinaire utilisait 'tout', éleveur utilisait 'Tout'
// Après : les deux utilisent FiltreHistorique.tout = 'tout'
class FiltreHistorique {
  FiltreHistorique._(); // classe non instanciable

  static const String tout         = 'tout';
  static const String consultation = 'consultation';
  static const String vaccination  = 'vaccination';

  // Labels affichés dans les FilterChip (identiques dans les deux interfaces)
  static const String labelTout         = 'Tout';
  static const String labelConsultation = 'Consultations';
  static const String labelVaccination  = 'Vaccinations';

  // Liste ordonnée pour construire les FilterChip
  static const List<Map<String, String>> filtres = [
    {'label': labelTout,         'value': tout},
    {'label': labelConsultation, 'value': consultation},
    {'label': labelVaccination,  'value': vaccination},
  ];
}

// ─── Types d'actes médicaux (base de données) ─────────────
// Valeurs stockées dans la colonne 'type_acte' de la vue
// et dans la colonne 'type' de la table consultations/vaccinations
class TypeActe {
  TypeActe._();

  static const String consultation = 'consultation';
  static const String vaccination  = 'vaccination';
}

// ─── Types de notifications ────────────────────────────────
// Valeurs stockées dans la colonne 'type' de la table notifications
class TypeNotification {
  TypeNotification._();

  static const String nouvelleConsultation = 'nouvelle_consultation';
  static const String nouvelleVaccination  = 'nouvelle_vaccination';
  static const String rappelVaccin         = 'rappel_vaccin';
  static const String general              = 'general';
}

// ─── Filtres notifications ─────────────────────────────────
class FiltreNotification {
  FiltreNotification._();

  static const String tout         = 'Tout';
  static const String nonLues      = 'Non lues';
  static const String consultations = 'Consultations';
  static const String vaccinations  = 'Vaccinations';

  static const List<String> tous = [tout, nonLues, consultations, vaccinations];
}

// ─── Rôles utilisateurs ────────────────────────────────────
class Roles {
  Roles._();

  static const String eleveur     = 'eleveur';
  static const String veterinaire = 'veterinaire';
}

// ─── Sources animaux (tables Supabase) ────────────────────
class SourceAnimal {
  SourceAnimal._();

  static const String nee    = 'nee';    // table nouveaux_nee
  static const String achete = 'achete'; // table animal_acheter

  static String table(String source) {
    return source == nee ? 'nouveaux_nee' : 'animal_acheter';
  }
}

// ─── Canaux de notifications Android ──────────────────────
class CanalNotification {
  CanalNotification._();

  static const String alerte       = 'alerte_channel';
  static const String reproduction = 'reproduction_channel';
}

// ─── Noms des tables Supabase ──────────────────────────────
class Tables {
  Tables._();

  static const String consultations          = 'consultations';
  static const String vaccinations           = 'vaccinations';
  static const String notifications          = 'notifications';
  static const String nouveauxNee            = 'nouveaux_nee';
  static const String animalAcheter          = 'animal_acheter';
  static const String users                  = 'users';
  static const String userFcmTokens          = 'user_fcm_tokens';
  static const String historiqueComplet      = 'historique_medical_complet';
}

// ─── Noms des Edge Functions ───────────────────────────────
class EdgeFunctions {
  EdgeFunctions._();

  static const String sendPushNotification = 'send-push-notification';
}