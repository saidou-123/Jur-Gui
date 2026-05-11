import 'package:flutter/material.dart';

class AppColors {
  static const primary    = Color(0xFF2E7D32); // vert vétérinaire
  static const secondary  = Color(0xFF00838F); // teal collaboration
  static const accent     = Color(0xFF6A1B9A); // violet vaccinations
  static const warning    = Color(0xFFE65100); // orange alertes
  static const danger     = Color(0xFFC62828); // rouge urgences
  static const info       = Color(0xFF1565C0); // bleu historique

  static const surface    = Color(0xFFF5F5F5);
  static const cardBg     = Colors.white;
}

class AppRoutes {
  static const home           = '/veterinaire';
  static const dashboard      = '/veterinaire/dashboard';
  static const scanRfid       = '/veterinaire/scan';
  static const fichesSante    = '/veterinaire/fiches';
  static const ficheSanteDetail = '/veterinaire/fiches/detail';
  static const consultation   = '/veterinaire/consultation';
  static const vaccinations   = '/veterinaire/vaccinations';
  static const historique     = '/veterinaire/historique';
  static const notes          = '/veterinaire/notes';
}

/// Valeurs de référence cliniques pour les moutons Ladoum
class NormalesLadoum {
  static const double tempMin    = 38.5;
  static const double tempMax    = 39.5;
  static const int    fcMin      = 70;
  static const int    fcMax      = 90;
  static const double poidsMinF  = 40.0; // brebis
  static const double poidsMaxF  = 80.0;
  static const double poidsMinM  = 60.0; // bélier
  static const double poidsMaxM  = 120.0;

  static String evaluerTemp(double? t) {
    if (t == null) return '';
    if (t < tempMin) return '⬇️ Hypothermie';
    if (t > tempMax) return '⬆️ Hyperthermie';
    return '✅ Normal';
  }

  static String evaluerFC(int? fc) {
    if (fc == null) return '';
    if (fc < fcMin) return '⬇️ Bradycardie';
    if (fc > fcMax) return '⬆️ Tachycardie';
    return '✅ Normal';
  }
}

/// Vaccins courants pour moutons Ladoum au Sénégal
class VaccinsCourants {
  static const List<String> liste = [
    'Pasteurellose',
    'Entérotoxémie (Clostridium)',
    'Fièvre aphteuse',
    'Brucellose',
    'Variole ovine (Clavelée)',
    'Peste des Petits Ruminants (PPR)',
    'Charbon bactéridien (Anthrax)',
    'Ecthyma contagieux',
    'Botulisme',
    'Antirabique',
  ];
}

/// Maladies fréquentes Ladoum pour aide au diagnostic
class MaladiesFrequentes {
  static const List<String> liste = [
    'Boiterie / Piétin',
    'Pneumonie',
    'Entérite / Diarrhée',
    'Pasteurellose',
    'Gale sarcoptique',
    'Fasciolose (grande douve)',
    'Coccidiose',
    'Strongylose gastro-intestinale',
    'Ecthyma contagieux',
    'Conjonctivite infectieuse',
  ];
}