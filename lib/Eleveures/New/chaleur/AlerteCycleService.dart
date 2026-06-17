// ============================================================
// SERVICE ALERTES CYCLES ANORMAUX — Jur-Gui 4.0 CORRIGÉ
// Fichier: lib/Eleveures/New/chaleur/AlerteCycleService.dart
//
// ✅ CORRECTION : alerte.type.name retournait 'cycleCourt' (camelCase Dart)
//    mais la BD a une contrainte CHECK qui attend 'cycle_court' (snake_case).
//
//    SOLUTION : ajout d'un getter `valeurBD` sur TypeAlerteCycle qui convertit
//    le nom Dart en snake_case attendu par Supabase.
//    Tous les endroits qui utilisaient alerte.type.name pour la BD
//    utilisent maintenant alerte.type.valeurBD.
//    Les usages non-BD (debugPrint, notifications push) gardent .name.
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
  static const int seuilCycleCourt = 14;
  static const int seuilCycleLong  = 21;
  static const int seuilAbsence    = 21;
 
  // ============================================================
  // ANALYSER LE CYCLE À L'ENREGISTREMENT D'UNE CHALEUR
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
 
      final datePrecedente  = DateTime.parse(precedente['date_chaleur']);
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
 
      debugPrint('✅ Cycle normal pour $nomAnimal: $intervalleJours jours');
      return ResultatAnalyseCycle.normal();
 
    } catch (e) {
      debugPrint('❌ Erreur analyse cycle: $e');
      return ResultatAnalyseCycle.normal();
    }
  }
 
  // ============================================================
  // VÉRIFIER L'ABSENCE DE CHALEURS (> 21 JOURS)
  // ============================================================
 
  Future<List<ResultatAnalyseCycle>> verifierAbsenceChaleurs({
    required dynamic animalId,
    required String source,
    required String nomAnimal,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return [];
 
      final derniere = await supabase
          .from('chaleurs')
          .select('date_chaleur')
          .eq('animal_id', animalId)
          .eq('source', source)
          .order('date_chaleur', ascending: false)
          .limit(1)
          .maybeSingle();
 
      final enGestation = await supabase
          .from('accouplements')
          .select('id')
          .eq('brebis_id', animalId)
          .eq('source_brebis', source)
          .isFilter('date_mise_bas', null)
          .limit(1)
          .maybeSingle();
 
      if (enGestation != null) {
        debugPrint('ℹ️ $nomAnimal est en gestation — pas d\'alerte absence');
        return [];
      }
 
      if (derniere == null) return [];
 
      final dateDerniere = DateTime.parse(derniere['date_chaleur']);
      final joursDepuis  = DateTime.now().difference(dateDerniere).inDays;
 
      if (joursDepuis <= seuilAbsence) return [];
 
      // ✅ Requête avec valeurBD (snake_case) pour le filtre BD
      final alerteRecente = await supabase
          .from('alertes_cycle')
          .select('id, created_at')
          .eq('animal_id', animalId.toString())
          .eq('type_alerte', TypeAlerteCycle.absenceChaleurs.valeurBD)
          .eq('statut', 'active')
          .gte('created_at',
              DateTime.now().subtract(const Duration(days: 3)).toIso8601String())
          .maybeSingle();
 
      if (alerteRecente != null) {
        debugPrint('ℹ️ Alerte absence récente déjà envoyée pour $nomAnimal');
        return [];
      }
 
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
  // ✅ CORRECTION : utilise alerte.type.valeurBD (snake_case)
  //    au lieu de alerte.type.name (camelCase Dart)
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
        // ✅ CORRECTION : valeurBD = 'cycle_court' au lieu de 'cycleCourt'
        'type_alerte'     : alerte.type.valeurBD,
        'intervalle_jours': alerte.intervalleJours,
        'message'         : alerte.message,
        'suggestion'      : alerte.suggestion,
        'statut'          : 'active',
        'date_alerte'     : DateTime.now().toIso8601String(),
      });
      debugPrint('✅ Alerte cycle enregistrée en BD: ${alerte.type.valeurBD}');
    } catch (e) {
      debugPrint('❌ Erreur enregistrement alerte: $e');
    }
  }
 
  // ============================================================
  // PRIVÉ — Envoyer notification push + locale
  // Note : pour les notifications, on garde .name (lisible en log)
  // ============================================================
 
  Future<void> _envoyerNotificationAlerte(
    ResultatAnalyseCycle alerte,
    dynamic animalId,
    String source,
    String userId,
  ) async {
    await _notif.afficherNotificationImmediateLocal(
      titre: alerte.titreNotification,
      corps: alerte.message,
      type : alerte.type.name,
    );
 
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
  normal;
 
  // ✅ CORRECTION : getter qui retourne la valeur snake_case
  // attendue par la contrainte CHECK de Supabase.
  // Dart .name = 'cycleCourt'  →  .valeurBD = 'cycle_court'
  String get valeurBD {
    switch (this) {
      case TypeAlerteCycle.cycleCourt:
        return 'cycle_court';
      case TypeAlerteCycle.cycleLong:
        return 'cycle_long';
      case TypeAlerteCycle.absenceChaleurs:
        return 'absence_chaleurs';
      case TypeAlerteCycle.anoestrus:
        return 'anoestrus';
      case TypeAlerteCycle.normal:
        return 'normal';
    }
  }
 
  // Reconstruction depuis la valeur BD (pour lecture)
  static TypeAlerteCycle fromBD(String? valeur) {
    switch (valeur) {
      case 'cycle_court':
        return TypeAlerteCycle.cycleCourt;
      case 'cycle_long':
        return TypeAlerteCycle.cycleLong;
      case 'absence_chaleurs':
        return TypeAlerteCycle.absenceChaleurs;
      case 'anoestrus':
        return TypeAlerteCycle.anoestrus;
      default:
        return TypeAlerteCycle.normal;
    }
  }
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
        type      : TypeAlerteCycle.normal,
        message   : '',
        suggestion: '',
        nomAnimal : '',
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
 