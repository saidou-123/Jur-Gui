// ============================================================
// SERVICE ALERTES CYCLES ANORMAUX — Jur-Gui 4.0
// Fichier: lib/Eleveures/New/chaleur/AlerteCycleService.dart
//
// Détecte automatiquement :
//   • Cycle court  : < 14 jours entre deux chaleurs
//   • Cycle long   : > 21 jours entre deux chaleurs
//   • Absence      : > 21 jours sans chaleur (via pg_cron)
// Et suggère une consultation vétérinaire
// ============================================================

import 'package:depart/Eleveures/New/Notification/NotificationService.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AlerteCycleService {
  static final AlerteCycleService _instance = AlerteCycleService._internal();
  factory AlerteCycleService() => _instance;
  AlerteCycleService._internal();

  final supabase = Supabase.instance.client;
  final _notif = NotificationService();

  // ── Seuils (jours) ──────────────────────────────────────
  static const int seuilCycleCourt   = 14;
  static const int seuilCycleLong    = 21;
  static const int seuilAbsence      = 21;

  // ============================================================
  // ANALYSER LE CYCLE À L'ENREGISTREMENT D'UNE CHALEUR
  // Appelé depuis EnrChaleurPageAmelioree après insertion
  // ============================================================

  Future<ResultatAnalyseCycle> analyserCycle({
    required dynamic animalId,
    required String source,
    required String nomAnimal,
    required DateTime nouvelleChaleur,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return ResultatAnalyseCycle.normal();

      // Récupérer la chaleur précédente
      final precedente = await supabase
          .from('chaleurs')
          .select('date_chaleur')
          .eq('animal_id', animalId)
          .eq('source', source)
          .lt('date_chaleur', nouvelleChaleur.toIso8601String())
          .order('date_chaleur', ascending: false)
          .limit(1)
          .maybeSingle();

      if (precedente == null) {
        debugPrint('ℹ️ Première chaleur enregistrée pour $nomAnimal');
        return ResultatAnalyseCycle.normal();
      }

      final datePrecedente = DateTime.parse(precedente['date_chaleur']);
      final intervalleJours = nouvelleChaleur.difference(datePrecedente).inDays;

      debugPrint('📊 Intervalle cycle $nomAnimal: $intervalleJours jours');

      // ── Cycle court ────────────────────────────────────────
      if (intervalleJours < seuilCycleCourt) {
        final alerte = ResultatAnalyseCycle(
          type: TypeAlerteCycle.cycleCourt,
          intervalleJours: intervalleJours,
          message: '⚠️ Cycle anormalement court détecté pour $nomAnimal : '
              '$intervalleJours jours (normal : 14-21 jours)',
          suggestion: 'Un cycle trop court peut indiquer un déséquilibre '
              'hormonal, un stress ou une infection. '
              'Une consultation vétérinaire est recommandée.',
          nomAnimal: nomAnimal,
        );
        await _enregistrerAlerte(
          userId: userId, animalId: animalId, source: source,
          nomAnimal: nomAnimal, alerte: alerte,
        );
        await _envoyerNotificationAlerte(alerte, animalId, source, userId);
        return alerte;
      }

      // ── Cycle long ─────────────────────────────────────────
      if (intervalleJours > seuilCycleLong) {
        final alerte = ResultatAnalyseCycle(
          type: TypeAlerteCycle.cycleLong,
          intervalleJours: intervalleJours,
          message: '⚠️ Cycle anormalement long détecté pour $nomAnimal : '
              '$intervalleJours jours (normal : 14-21 jours)',
          suggestion: 'Un cycle trop long peut indiquer une période d\'anœstrus, '
              'une gestation non détectée, ou un problème ovarien. '
              'Une consultation vétérinaire est recommandée.',
          nomAnimal: nomAnimal,
        );
        await _enregistrerAlerte(
          userId: userId, animalId: animalId, source: source,
          nomAnimal: nomAnimal, alerte: alerte,
        );
        await _envoyerNotificationAlerte(alerte, animalId, source, userId);
        return alerte;
      }

      // ── Cycle normal ───────────────────────────────────────
      debugPrint('✅ Cycle normal pour $nomAnimal: $intervalleJours jours');
      return ResultatAnalyseCycle.normal();

    } catch (e) {
      debugPrint('❌ Erreur analyse cycle: $e');
      return ResultatAnalyseCycle.normal();
    }
  }

  // ============================================================
  // VÉRIFIER L'ABSENCE DE CHALEURS (> 21 JOURS)
  // Appelé au chargement de la page ou via pg_cron
  // ============================================================

  Future<List<ResultatAnalyseCycle>> verifierAbsenceChaleurs({
    required dynamic animalId,
    required String source,
    required String nomAnimal,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return [];

      // Dernière chaleur enregistrée
      final derniere = await supabase
          .from('chaleurs')
          .select('date_chaleur')
          .eq('animal_id', animalId)
          .eq('source', source)
          .order('date_chaleur', ascending: false)
          .limit(1)
          .maybeSingle();

      // Vérifier si pas en gestation
      final enGestation = await supabase
          .from('accouplements')
          .select('id')
          .eq('brebis_id', animalId)
          .eq('source_brebis', source)
          .isFilter('date_mise_bas', null)
          .limit(1)
          .maybeSingle();

      // Si en gestation → pas d'alerte
      if (enGestation != null) {
        debugPrint('ℹ️ $nomAnimal est en gestation — pas d\'alerte absence');
        return [];
      }

      // Calculer jours depuis dernière chaleur
      int joursDepuis;
      if (derniere == null) {
        // Jamais de chaleur enregistrée — pas d'alerte (données insuffisantes)
        return [];
      } else {
        final dateDerniere = DateTime.parse(derniere['date_chaleur']);
        joursDepuis = DateTime.now().difference(dateDerniere).inDays;
      }

      if (joursDepuis <= seuilAbsence) return [];

      // Vérifier si une alerte récente existe déjà (éviter doublons)
      final alerteRecente = await supabase
          .from('alertes_cycle')
          .select('id, created_at')
          .eq('animal_id', animalId.toString())
          .eq('type_alerte', 'absence_chaleurs')
          .eq('statut', 'active')
          .gte('created_at',
              DateTime.now().subtract(const Duration(days: 3)).toIso8601String())
          .maybeSingle();

      if (alerteRecente != null) {
        debugPrint('ℹ️ Alerte absence récente déjà envoyée pour $nomAnimal');
        return [];
      }

      // Détecter anœstrus saisonnier (juin-août)
      final moisActuel = DateTime.now().month;
      final estAnoestrus = moisActuel >= 6 && moisActuel <= 8;

      final alerte = ResultatAnalyseCycle(
        type: estAnoestrus
            ? TypeAlerteCycle.anoestrus
            : TypeAlerteCycle.absenceChaleurs,
        intervalleJours: joursDepuis,
        message: estAnoestrus
            ? '🌡️ Période d\'anœstrus saisonnier pour $nomAnimal : '
                'pas de chaleur depuis $joursDepuis jours'
            : '🚨 Absence de chaleurs anormale pour $nomAnimal : '
                'pas de chaleur depuis $joursDepuis jours (seuil : $seuilAbsence jours)',
        suggestion: estAnoestrus
            ? 'L\'anœstrus saisonnier est normal en période estivale. '
                'Si cela persiste après septembre, consultez votre vétérinaire.'
            : 'L\'absence prolongée de chaleurs peut indiquer une gestation '
                'non détectée, un problème ovarien (kystes), ou un déficit '
                'nutritionnel. Une consultation vétérinaire est fortement recommandée.',
        nomAnimal: nomAnimal,
      );

      await _enregistrerAlerte(
        userId: userId, animalId: animalId, source: source,
        nomAnimal: nomAnimal, alerte: alerte,
      );
      await _envoyerNotificationAlerte(alerte, animalId, source, userId);

      return [alerte];
    } catch (e) {
      debugPrint('❌ Erreur vérification absence chaleurs: $e');
      return [];
    }
  }

  // ============================================================
  // RÉCUPÉRER LES ALERTES ACTIVES D'UN ANIMAL
  // ============================================================

  Future<List<Map<String, dynamic>>> getAlertesActives({
    required dynamic animalId,
    required String source,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final alertes = await supabase
          .from('alertes_cycle')
          .select('*')
          .eq('user_id', userId)
          .eq('animal_id', animalId.toString())
          .eq('statut', 'active')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(alertes);
    } catch (e) {
      debugPrint('❌ Erreur récupération alertes: $e');
      return [];
    }
  }

  // ============================================================
  // MARQUER UNE ALERTE COMME VUE OU RÉSOLUE
  // ============================================================

  Future<void> marquerAlerte({
    required String alerteId,
    required String statut, // 'vue' ou 'resolue'
  }) async {
    try {
      await supabase
          .from('alertes_cycle')
          .update({'statut': statut})
          .eq('id', alerteId);
      debugPrint('✅ Alerte $alerteId marquée: $statut');
    } catch (e) {
      debugPrint('❌ Erreur mise à jour alerte: $e');
    }
  }

  // ============================================================
  // PRIVÉ — Enregistrer alerte en BD
  // ============================================================

  Future<void> _enregistrerAlerte({
    required String userId,
    required dynamic animalId,
    required String source,
    required String nomAnimal,
    required ResultatAnalyseCycle alerte,
  }) async {
    try {
      await supabase.from('alertes_cycle').insert({
        'user_id'         : userId,
        'animal_id'       : animalId.toString(),
        'source'          : source,
        'nom_animal'      : nomAnimal,
        'type_alerte'     : alerte.type.name,
        'intervalle_jours': alerte.intervalleJours,
        'message'         : alerte.message,
        'suggestion'      : alerte.suggestion,
        'statut'          : 'active',
        'date_alerte'     : DateTime.now().toIso8601String(),
      });
      debugPrint('✅ Alerte cycle enregistrée en BD: ${alerte.type.name}');
    } catch (e) {
      debugPrint('❌ Erreur enregistrement alerte: $e');
    }
  }

  // ============================================================
  // PRIVÉ — Envoyer notification push + locale
  // ============================================================

  Future<void> _envoyerNotificationAlerte(
    ResultatAnalyseCycle alerte,
    dynamic animalId,
    String source,
    String userId,
  ) async {
    // Notification locale immédiate
    await _notif.afficherNotificationImmediateLocal(
      titre: alerte.titreNotification,
      corps: alerte.message,
      type: alerte.type.name,
    );

    // Push distant programmé (dans 5 minutes pour laisser le temps de lire)
    final dateEnvoi = DateTime.now().add(const Duration(minutes: 5));
    await supabase.from('notifications_programmees').insert({
      'user_id'   : userId,
      'animal_id' : animalId.toString(),
      'source'    : source,
      'nom_animal': alerte.nomAnimal,
      'type'      : alerte.type.name,
      'titre'     : alerte.titreNotification,
      'corps'     : '${alerte.message}\n\n💡 ${alerte.suggestion}',
      'date_envoi': dateEnvoi.toIso8601String(),
      'statut'    : 'planifie',
      'metadata'  : {
        'animal_id': animalId.toString(),
        'source'   : source,
        'priorite' : alerte.type == TypeAlerteCycle.absenceChaleurs ? 'haute' : 'normale',
      },
    });

    debugPrint('✅ Notification alerte cycle envoyée: ${alerte.type.name}');
  }
}

// ============================================================
// MODÈLES
// ============================================================

enum TypeAlerteCycle {
  cycleCourt,
  cycleLong,
  absenceChaleurs,
  anoestrus,
  normal,
}

class ResultatAnalyseCycle {
  final TypeAlerteCycle type;
  final int? intervalleJours;
  final String message;
  final String suggestion;
  final String nomAnimal;

  const ResultatAnalyseCycle({
    required this.type,
    this.intervalleJours,
    required this.message,
    required this.suggestion,
    required this.nomAnimal,
  });

  factory ResultatAnalyseCycle.normal() => const ResultatAnalyseCycle(
        type       : TypeAlerteCycle.normal,
        message    : '',
        suggestion : '',
        nomAnimal  : '',
      );

  bool get estNormal => type == TypeAlerteCycle.normal;
  bool get estUrgent => type == TypeAlerteCycle.absenceChaleurs;

  String get titreNotification {
    switch (type) {
      case TypeAlerteCycle.cycleCourt:
        return '⚠️ Cycle court détecté — $nomAnimal';
      case TypeAlerteCycle.cycleLong:
        return '⚠️ Cycle long détecté — $nomAnimal';
      case TypeAlerteCycle.absenceChaleurs:
        return '🚨 Absence de chaleurs — $nomAnimal';
      case TypeAlerteCycle.anoestrus:
        return '🌡️ Anœstrus saisonnier — $nomAnimal';
      case TypeAlerteCycle.normal:
        return '';
    }
  }

  Color get couleur {
    switch (type) {
      case TypeAlerteCycle.cycleCourt:
        return Colors.orange;
      case TypeAlerteCycle.cycleLong:
        return Colors.orange;
      case TypeAlerteCycle.absenceChaleurs:
        return Colors.red;
      case TypeAlerteCycle.anoestrus:
        return Colors.blue;
      case TypeAlerteCycle.normal:
        return Colors.green;
    }
  }

  IconData get icone {
    switch (type) {
      case TypeAlerteCycle.cycleCourt:
        return Icons.fast_forward;
      case TypeAlerteCycle.cycleLong:
        return Icons.hourglass_empty;
      case TypeAlerteCycle.absenceChaleurs:
        return Icons.warning_rounded;
      case TypeAlerteCycle.anoestrus:
        return Icons.wb_sunny;
      case TypeAlerteCycle.normal:
        return Icons.check_circle;
    }
  }
}