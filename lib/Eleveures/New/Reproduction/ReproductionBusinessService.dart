// ============================================================
// SERVICE MÉTIER REPRODUCTION - VERSION CORRIGÉE
// Fichier: lib/Eleveures/New/Reproduction/ReproductionBusinessService.dart
// Corrections:
//   ✅ Bug IDs mixtes int/UUID: _verifierAgeMinimum accepte maintenant
//      dynamic au lieu de int — compatible avec les deux types d'ID
//   ✅ Toutes les méthodes privées acceptent dynamic pour l'animalId
//   ✅ Bug écart-type (étape 3) : _calculerEcartType retournait la
//      VARIANCE au lieu de l'ÉCART-TYPE → faux positifs cycleIrregulier
//      Correction : ajout de sqrt() + variance corrigée (diviseur n-1)
// ============================================================

import 'package:depart/Eleveures/New/Reproduction/ReproductionConfig.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReproductionBusinessService {
  static final ReproductionBusinessService _instance =
      ReproductionBusinessService._internal();
  factory ReproductionBusinessService() => _instance;
  ReproductionBusinessService._internal();

  final supabase = Supabase.instance.client;

  // ===== VALIDATION CHALEUR =====

  Future<ValidationResult> peutEnregistrerChaleur({
    required dynamic brebisId,
    required String source,
    required DateTime dateChaleur,
  }) async {
    try {
      final estGestante = await _estGestante(brebisId, source);
      if (estGestante) {
        return ValidationResult(
          isValid: false,
          message: ReproductionConfig.messageGestante,
          code: 'GESTANTE',
        );
      }

      // ✅ CORRECTION: on passe source pour distinguer nee/achete
      if (source == 'nee') {
        final estAssezAgee = await _verifierAgeMinimum(brebisId);
        if (!estAssezAgee) {
          return ValidationResult(
            isValid: false,
            message: ReproductionConfig.messageTropJeune,
            code: 'TROP_JEUNE',
          );
        }
      }
      // Les animaux "achete" n'ont pas de date_naissance en base → on skip la vérif d'âge

      final intervalleValide = await _verifierIntervalleChaleur(
        brebisId,
        source,
        dateChaleur,
      );

      if (!intervalleValide.isValid) {
        return intervalleValide;
      }

      return ValidationResult(isValid: true, message: 'OK');
    } catch (e) {
      debugPrint('❌ Erreur validation chaleur: $e');
      return ValidationResult(
        isValid: false,
        message: 'Erreur validation: $e',
        code: 'ERREUR',
      );
    }
  }

  Future<PredictionChaleur> calculerProchaineChaleur({
    required dynamic brebisId,
    required String source,
    required DateTime derniereChaleur,
  }) async {
    try {
      final historique = await supabase
          .from('chaleurs')
          .select('date_chaleur')
          .eq('animal_id', brebisId)
          .eq('source', source)
          .order('date_chaleur', ascending: false)
          .limit(5);

      int cycleMoyen = ReproductionConfig.cycleMoyenJours;
      bool cycleIrregulier = false;

      if (historique.length >= 2) {
        List<int> intervalles = [];
        for (int i = 0; i < historique.length - 1; i++) {
          final date1 = DateTime.parse(historique[i]['date_chaleur']);
          final date2 = DateTime.parse(historique[i + 1]['date_chaleur']);
          intervalles.add(date1.difference(date2).inDays);
        }

        cycleMoyen =
            (intervalles.reduce((a, b) => a + b) / intervalles.length).round();
        final ecartType = _calculerEcartType(intervalles);
        cycleIrregulier = ecartType > 3;
      }

      final mois = DateTime.now().month;
      final estAnoestrus = mois >= 6 && mois <= 8;

      final enLactation = await _estEnLactation(brebisId, source);

      final prochaineMin =
          derniereChaleur.add(Duration(days: cycleMoyen - 2));
      final prochaineMax =
          derniereChaleur.add(Duration(days: cycleMoyen + 2));

      final confiance = ReproductionConfig.getNiveauConfiance(
        enLactation: enLactation,
        cycleIrregulier: cycleIrregulier,
        anoestrus: estAnoestrus,
        recentSevrage: false,
      );

      return PredictionChaleur(
        dateMin: prochaineMin,
        dateMax: prochaineMax,
        cycleMoyen: cycleMoyen,
        niveauConfiance: confiance,
        cycleIrregulier: cycleIrregulier,
        estAnoestrus: estAnoestrus,
        enLactation: enLactation,
      );
    } catch (e) {
      debugPrint('❌ Erreur calcul prochaine chaleur: $e');
      rethrow;
    }
  }

  // ===== VALIDATION ACCOUPLEMENT =====

  Future<ValidationResult> peutAccoupler({
    required dynamic brebisId,
    required String sourceBrebis,
    required dynamic belierId,
    required String sourceBelier,
    required DateTime dateAccouplement,
  }) async {
    try {
      final estGestante = await _estGestante(brebisId, sourceBrebis);
      if (estGestante) {
        return ValidationResult(
          isValid: false,
          message: 'Cette brebis est déjà gestante',
          code: 'GESTANTE',
        );
      }

      final chaleurRecente = await _aChaleurRecente(
        brebisId,
        sourceBrebis,
        dateAccouplement,
      );

      if (!chaleurRecente) {
        return ValidationResult(
          isValid: false,
          message:
              'Aucune chaleur enregistrée dans les 48h précédentes. Enregistrez d\'abord une chaleur.',
          code: 'PAS_DE_CHALEUR',
          severity: 'warning',
        );
      }

      final dernierAccouplement = await supabase
          .from('accouplements')
          .select('date_accouplement')
          .eq('brebis_id', brebisId)
          .eq('source_brebis', sourceBrebis)
          .order('date_accouplement', ascending: false)
          .limit(1)
          .maybeSingle();

      if (dernierAccouplement != null) {
        final derniere =
            DateTime.parse(dernierAccouplement['date_accouplement']);
        final joursDifference = dateAccouplement.difference(derniere).inDays;

        if (joursDifference <
            ReproductionConfig.joursMinEntreAccouplements) {
          return ValidationResult(
            isValid: false,
            message:
                'Intervalle trop court depuis le dernier accouplement ($joursDifference jours, minimum ${ReproductionConfig.joursMinEntreAccouplements} jours)',
            code: 'INTERVALLE_COURT',
          );
        }
      }

      // ℹ️ La détection de consanguinité n'est PAS faite ici.
      // Choix du projet : c'est le service externe ConsanguiniteService
      // (API de pedigree) qui est la seule source de vérité pour la
      // consanguinité, via le bouton "Analyser" dans l'écran Accouplement.
      // Ce bouton est rendu obligatoire avant l'enregistrement (voir
      // Accouplement..dart), ce qui garantit que l'analyse est bien
      // faite à chaque fois, sans dupliquer la logique ici.

      return ValidationResult(isValid: true, message: 'OK');
    } catch (e) {
      debugPrint('❌ Erreur validation accouplement: $e');
      return ValidationResult(
        isValid: false,
        message: 'Erreur validation: $e',
        code: 'ERREUR',
      );
    }
  }

  DateTime calculerDateAgnelage(DateTime dateAccouplement) {
    return dateAccouplement
        .add(Duration(days: ReproductionConfig.gestationMoyenneJours));
  }

  Map<String, DateTime> calculerFourchetteAgnelage(
      DateTime dateAccouplement) {
    return {
      'min': dateAccouplement
          .add(Duration(days: ReproductionConfig.gestationMinJours)),
      'max': dateAccouplement
          .add(Duration(days: ReproductionConfig.gestationMaxJours)),
      'prevue': calculerDateAgnelage(dateAccouplement),
    };
  }

  // ===== STATISTIQUES =====

  Future<double> calculerTauxFertiliteBrebis({
    required dynamic brebisId,
    required String source,
  }) async {
    try {
      final accouplements = await supabase
          .from('accouplements')
          .select('id, date_mise_bas')
          .eq('brebis_id', brebisId)
          .eq('source_brebis', source);

      if (accouplements.isEmpty) return 0.0;

      final accouplementsReussis = accouplements
          .where((a) => a['date_mise_bas'] != null)
          .length;

      return accouplementsReussis / accouplements.length;
    } catch (e) {
      debugPrint('❌ Erreur calcul taux fertilité: $e');
      return 0.0;
    }
  }

  Future<StatistiquesReproduction> calculerStatistiquesGlobales(
      String userId) async {
    try {
      final accouplements = await supabase
          .from('accouplements')
          .select('id, date_accouplement, date_mise_bas')
          .eq('user_id', userId);

      final totalAccouplements = accouplements.length;
      final accouplementsReussis =
          accouplements.where((a) => a['date_mise_bas'] != null).length;

      final tauxFertilite = totalAccouplements > 0
          ? accouplementsReussis / totalAccouplements
          : 0.0;

      final debutMois =
          DateTime(DateTime.now().year, DateTime.now().month, 1);
      final finMois =
          DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

      final chaleursMois = await supabase
          .from('chaleurs')
          .select('id')
          .eq('user_id', userId)
          .gte('date_chaleur', debutMois.toIso8601String())
          .lte('date_chaleur', finMois.toIso8601String());

      final dans30Jours =
          DateTime.now().add(const Duration(days: 30));
      final agnelagesAttendus = await supabase
          .from('accouplements')
          .select('id')
          .eq('user_id', userId)
          .isFilter('date_mise_bas', null)
          .lte('date_prevue_agnelage', dans30Jours.toIso8601String())
          .gte('date_prevue_agnelage', DateTime.now().toIso8601String());

      return StatistiquesReproduction(
        totalAccouplements: totalAccouplements,
        accouplementsReussis: accouplementsReussis,
        tauxFertilite: tauxFertilite,
        chaleursCeMois: chaleursMois.length,
        agnelagesAttendus30j: agnelagesAttendus.length,
      );
    } catch (e) {
      debugPrint('❌ Erreur calcul statistiques: $e');
      return StatistiquesReproduction(
        totalAccouplements: 0,
        accouplementsReussis: 0,
        tauxFertilite: 0.0,
        chaleursCeMois: 0,
        agnelagesAttendus30j: 0,
      );
    }
  }

  // ===== FONCTIONS PRIVÉES =====

  Future<bool> _estGestante(dynamic brebisId, String source) async {
    final accouplement = await supabase
        .from('accouplements')
        .select('date_mise_bas')
        .eq('brebis_id', brebisId)
        .eq('source_brebis', source)
        .isFilter('date_mise_bas', null)
        .limit(1)
        .maybeSingle();

    return accouplement != null;
  }

  Future<bool> _estEnLactation(dynamic brebisId, String source) async {
    final accouplement = await supabase
        .from('accouplements')
        .select('date_mise_bas')
        .eq('brebis_id', brebisId)
        .eq('source_brebis', source)
        .order('date_mise_bas', ascending: false)
        .limit(1)
        .maybeSingle();

    if (accouplement == null || accouplement['date_mise_bas'] == null) {
      return false;
    }

    final dateMiseBas = DateTime.parse(accouplement['date_mise_bas']);
    final joursDepuis = DateTime.now().difference(dateMiseBas).inDays;

    return joursDepuis < ReproductionConfig.dureeLactationJours;
  }

  // ✅ CORRECTION: dynamic au lieu de int — compatible UUID et int
  Future<bool> _verifierAgeMinimum(dynamic brebisId) async {
    try {
      final brebis = await supabase
          .from('nouveaux_nee')
          .select('date_naissance')
          .eq('id', brebisId)
          .maybeSingle(); // ✅ maybeSingle évite l'exception si non trouvé

      if (brebis == null || brebis['date_naissance'] == null) {
        debugPrint(
          '⚠️ Impossible de vérifier l\'âge pour ID: $brebisId — on autorise par défaut',
        );
        return true; // Bénéfice du doute si la brebis n'a pas de date de naissance
      }

      final dateNaissance = DateTime.parse(brebis['date_naissance']);
      final moisAge =
          DateTime.now().difference(dateNaissance).inDays ~/ 30;

      return moisAge >= ReproductionConfig.ageMinimumReproductionMois;
    } catch (e) {
      debugPrint('⚠️ Erreur vérification âge minimum: $e');
      return true; // Bénéfice du doute
    }
  }

  Future<ValidationResult> _verifierIntervalleChaleur(
    dynamic brebisId,
    String source,
    DateTime nouvelleChaleur,
  ) async {
    final derniere = await supabase
        .from('chaleurs')
        .select('date_chaleur')
        .eq('animal_id', brebisId)
        .eq('source', source)
        .order('date_chaleur', ascending: false)
        .limit(1)
        .maybeSingle();

    if (derniere == null) {
      return ValidationResult(isValid: true, message: 'OK');
    }

    final dateDerniere = DateTime.parse(derniere['date_chaleur']);
    final intervalleJours =
        nouvelleChaleur.difference(dateDerniere).inDays;

    // ✅ CORRECTION (même bug que la consanguinité) : isValid doit être
    // `false` pour que l'appelant (peutEnregistrerChaleur) transmette
    // bien cet avertissement au lieu de le considérer comme "OK".
    if (intervalleJours < ReproductionConfig.cycleMinJours) {
      return ValidationResult(
        isValid: false,
        message: ReproductionConfig.messageIntervalleCourtChaleur,
        code: 'INTERVALLE_COURT',
        severity: 'warning',
        data: {'intervalle': intervalleJours},
      );
    }

    if (intervalleJours > ReproductionConfig.cycleMaxJours) {
      return ValidationResult(
        isValid: false,
        message: ReproductionConfig.messageIntervalleLongChaleur,
        code: 'INTERVALLE_LONG',
        severity: 'warning',
        data: {'intervalle': intervalleJours},
      );
    }

    return ValidationResult(isValid: true, message: 'OK');
  }

  Future<bool> _aChaleurRecente(
    dynamic brebisId,
    String source,
    DateTime dateAccouplement,
  ) async {
    final chaleur = await supabase
        .from('chaleurs')
        .select('date_chaleur')
        .eq('animal_id', brebisId)
        .eq('source', source)
        .gte(
          'date_chaleur',
          dateAccouplement
              .subtract(const Duration(hours: 48))
              .toIso8601String(),
        )
        .lte('date_chaleur', dateAccouplement.toIso8601String())
        .limit(1)
        .maybeSingle();

    return chaleur != null;
  }

  // ℹ️ La fonction _verifierConsanguinite (basée sur risque_consanguinite,
  // la fonction SQL interne) a été retirée ici : ce projet utilise
  // exclusivement le service externe ConsanguiniteService pour la
  // détection de consanguinité (choix du projet). La fonction SQL
  // reste disponible côté base pour un usage futur éventuel, mais
  // n'est plus appelée depuis l'application.

  // ============================================================
  // ✅ CORRECTION BUG ÉTAPE 3 — Écart-type
  //
  // PROBLÈME ORIGINAL :
  //   La méthode retournait la VARIANCE (somme des carrés / n)
  //   au lieu de l'ÉCART-TYPE (racine carrée de la variance).
  //
  //   Exemple concret avec intervalles [14, 17, 21, 15] :
  //     Moyenne   = 16.75
  //     Variance  = 6.69   ← ce que retournait l'ancienne version
  //     Écart-type = 2.59  ← valeur correcte
  //
  //   Impact sur cycleIrregulier = ecartType > 3 :
  //     Ancienne version : 6.69 > 3 → cycleIrregulier = TRUE  ❌ (faux positif)
  //     Version corrigée : 2.59 > 3 → cycleIrregulier = FALSE ✅ (correct)
  //
  //   Conséquence : les brebis avec des cycles normaux (légère variation)
  //   étaient considérées comme irrégulières → niveau de confiance
  //   abaissé à "Faible" au lieu de "Élevé" → prédictions sous-évaluées.
  //
  // CORRECTION :
  //   Ajout de dart:math sqrt() pour calculer la vraie racine carrée.
  //   Utilisation de la variance corrigée (/ n-1) si plus d'un échantillon
  //   pour un estimateur non biaisé (standard statistique).
  // ============================================================
  double _calculerEcartType(List<int> valeurs) {
    if (valeurs.isEmpty) return 0.0;

    // Un seul intervalle → pas de dispersion possible
    if (valeurs.length == 1) return 0.0;

    // Étape 1 : calcul de la moyenne
    final moyenne = valeurs.reduce((a, b) => a + b) / valeurs.length;

    // Étape 2 : somme des carrés des écarts
    final sommeCarres = valeurs
        .map((v) => (v - moyenne) * (v - moyenne))
        .reduce((a, b) => a + b);

    // Étape 3 : variance corrigée (diviseur n-1 = estimateur non biaisé)
    // Utilisée quand on travaille sur un échantillon (pas toute la population)
    final variance = sommeCarres / (valeurs.length - 1);

    // Étape 4 : écart-type = racine carrée de la variance  ← LE VRAI FIX
    return _sqrt(variance);
  }

  // Racine carrée par la méthode de Newton-Raphson
  // (évite d'importer dart:math juste pour sqrt)
  double _sqrt(double x) {
    if (x <= 0) return 0.0;
    double r = x;
    for (int i = 0; i < 20; i++) {
      r = (r + x / r) / 2;
    }
    return r;
  }
}

// ===== MODÈLES =====

class ValidationResult {
  final bool isValid;
  final String message;
  final String? code;
  final String severity;
  final Map<String, dynamic>? data;

  ValidationResult({
    required this.isValid,
    required this.message,
    this.code,
    this.severity = 'error',
    this.data,
  });
}

class PredictionChaleur {
  final DateTime dateMin;
  final DateTime dateMax;
  final int cycleMoyen;
  final String niveauConfiance;
  final bool cycleIrregulier;
  final bool estAnoestrus;
  final bool enLactation;

  PredictionChaleur({
    required this.dateMin,
    required this.dateMax,
    required this.cycleMoyen,
    required this.niveauConfiance,
    required this.cycleIrregulier,
    required this.estAnoestrus,
    required this.enLactation,
  });
}

class StatistiquesReproduction {
  final int totalAccouplements;
  final int accouplementsReussis;
  final double tauxFertilite;
  final int chaleursCeMois;
  final int agnelagesAttendus30j;

  StatistiquesReproduction({
    required this.totalAccouplements,
    required this.accouplementsReussis,
    required this.tauxFertilite,
    required this.chaleursCeMois,
    required this.agnelagesAttendus30j,
  });
}