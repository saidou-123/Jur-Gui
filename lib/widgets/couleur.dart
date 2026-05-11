import 'package:flutter/material.dart';

/// Couleurs et textes globaux de l'application Jur Gui.
/// Unifie l'ancien fichier couleur.dart avec AppColors.
class Couleur {
  // ── Palette principale ─────────────────────────────────────
  static const Color premierColor  = Color.fromARGB(255, 5, 87, 46);   // vert foncé (primaire)
  static const Color deuxiemeColor = Color.fromARGB(255, 0, 149, 75);  // vert moyen (secondaire)
  static const Color troisiemeColor = Color.fromARGB(255, 69, 43, 2);  // brun (accent)
  static const Color quatriemeColor = Color.fromARGB(255, 255, 252, 248); // blanc cassé (fond)

  // ── Couleurs fonctionnelles ────────────────────────────────
  static const Color veterinaire  = Color(0xFF2E7D32); // vert vétérinaire
  static const Color vaccination  = Color(0xFF1565C0); // bleu vaccinations
  static const Color alerte       = Color(0xFFE65100); // orange alertes
  static const Color urgence      = Color(0xFFC62828); // rouge urgences
  static const Color collaboration = Color(0xFF00838F); // teal collaboration
  static const Color historique   = Color(0xFF6A1B9A); // violet historique

  // ── Surfaces ──────────────────────────────────────────────
  static const Color surface  = Color(0xFFF5F5F5);
  static const Color cardBg   = Colors.white;

  // ── Textes de l'onboarding ────────────────────────────────
  static const String titleOne =
      "Suivi sanitaire numérique\ndes moutons Ladoum";
  static const String descriptionOne =
      "Enregistrez consultations, diagnostics et traitements. Suivez l'état de santé de chaque animal via son tag RFID.";

  static const String titleTwo =
      "Collaboration éleveur-vétérinaire";
  static const String descriptionTwo =
      "Envoyez des recommandations et alertes à l'éleveur pour améliorer la prévention des maladies.";

  static const String titleThree =
      "Historique médical complet";
  static const String descriptionThree =
      "Consultez l'historique médical de chaque animal, les vaccinations et les rappels à venir.";

  // ── Thème Flutter ─────────────────────────────────────────
  static ThemeData get theme => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: premierColor,
      primary: premierColor,
      secondary: deuxiemeColor,
    ),
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      backgroundColor: premierColor,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: premierColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: premierColor, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
    ),
  );
}