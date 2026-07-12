// ============================================================
// CONSTANTS.DART — Constantes partagées JUR GUI
// ✅ MàJ : Tables.fcmTokens → user_fcm_tokens (unifié)
// ============================================================

class FiltreHistorique {
  FiltreHistorique._();
  static const String tout         = 'tout';
  static const String consultation = 'consultation';
  static const String vaccination  = 'vaccination';
  static const String labelTout         = 'Tout';
  static const String labelConsultation = 'Consultations';
  static const String labelVaccination  = 'Vaccinations';
  static const List<Map<String, String>> filtres = [
    {'label': labelTout,         'value': tout},
    {'label': labelConsultation, 'value': consultation},
    {'label': labelVaccination,  'value': vaccination},
  ];
}

class TypeActe {
  TypeActe._();
  static const String consultation = 'consultation';
  static const String vaccination  = 'vaccination';
}

class TypeNotification {
  TypeNotification._();
  static const String nouvelleConsultation = 'nouvelle_consultation';
  static const String nouvelleVaccination  = 'nouvelle_vaccination';
  static const String rappelVaccin         = 'rappel_vaccin';
  static const String general              = 'general';
}

class FiltreNotification {
  FiltreNotification._();
  static const String tout          = 'Tout';
  static const String nonLues       = 'Non lues';
  static const String consultations = 'Consultations';
  static const String vaccinations  = 'Vaccinations';
  static const List<String> tous = [tout, nonLues, consultations, vaccinations];
}

class Roles {
  Roles._();
  static const String eleveur     = 'eleveur';
  static const String veterinaire = 'veterinaire';
}

class SourceAnimal {
  SourceAnimal._();
  static const String nee    = 'nee';
  static const String achete = 'achete';
  static String table(String source) =>
      source == nee ? 'nouveaux_nee' : 'animal_acheter';
}

class CanalNotification {
  CanalNotification._();
  static const String alerte       = 'alerte_channel';
  static const String reproduction = 'reproduction_channel';
}

class Tables {
  Tables._();
  static const String consultations     = 'consultations';
  static const String vaccinations      = 'vaccinations';
  static const String notifications     = 'notifications';
  static const String nouveauxNee       = 'nouveaux_nee';
  static const String animalAcheter     = 'animal_acheter';
  static const String users             = 'users';
  // ✅ UNIFIÉ : une seule table FCM tokens
  static const String fcmTokens         = 'user_fcm_tokens';
  static const String historiqueComplet = 'historique_medical_complet';
  static const String messages          = 'messages';
}

class EdgeFunctions {
  EdgeFunctions._();
  static const String sendPushNotification = 'send-push-notification';
}