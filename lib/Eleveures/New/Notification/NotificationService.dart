// ============================================================
// NOTIFICATION SERVICE - VERSION CORRIGÉE ET OPTIMISÉE
// Gestion complète des notifications pour le module reproduction
// Chemin: lib/Eleveures/New/Notification/NotificationService.dart
// ============================================================

import 'dart:io';
import 'dart:math';
import 'package:depart/Eleveures/New/Reproduction/ReproductionConfig.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();
  
  final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  
  final supabase = Supabase.instance.client;
  
  // ✅ NavigatorKey pour navigation depuis notifications
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  // ===== INITIALISATION =====
  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    
    // Demander permission pour iOS
    await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    
    // Demander permission pour Android 13+
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    
    // ✅ CRÉER LE CHANNEL ANDROID EXPLICITEMENT
    const androidChannel = AndroidNotificationChannel(
      'reproduction_channel',
      'Notifications Reproduction',
      description: 'Notifications pour le suivi de la reproduction',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );
    
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
    
    // ✅ NOUVEAU: Vérifier permission alarmes exactes Android 14+
    await _checkAndRequestExactAlarmPermission();
    
    debugPrint("✅ NotificationService initialisé avec channel Android");
  }
  
  // ===== NOUVEAU: VÉRIFICATION PERMISSION ANDROID 14+ =====
  Future<void> _checkAndRequestExactAlarmPermission() async {
    if (!Platform.isAndroid) return;
    
    try {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin == null) return;
      
      final canSchedule = await androidPlugin.canScheduleExactNotifications();
      
      if (canSchedule == false) {
        debugPrint("⚠️ Permission SCHEDULE_EXACT_ALARM non accordée");
        debugPrint("💡 Les notifications seront moins précises");
        // Note: Sur Android 14+, l'utilisateur doit activer manuellement dans les paramètres
      } else {
        debugPrint("✅ Permission alarmes exactes accordée");
      }
    } catch (e) {
      debugPrint("⚠️ Impossible de vérifier permission alarme: $e");
    }
  }
  
  // ===== GESTION DES TAPS SUR NOTIFICATIONS =====
  void _onNotificationTap(NotificationResponse response) {
    if (response.payload == null || response.payload!.isEmpty) {
      debugPrint("⚠️ Notification sans payload");
      return;
    }
    
    debugPrint("📲 Notification tapped: ${response.payload}");
    
    try {
      final parts = response.payload!.split(':');
      if (parts.isEmpty) return;
      
      final type = parts[0];
      
      // Navigation selon le type de notification
      switch (type) {
        case 'chaleur_rappel':
        case 'fenetre_fertile':
          navigatorKey.currentState?.pushNamed('/chaleur');
          debugPrint("➡️ Navigation vers /chaleur");
          break;
          
        case 'agnelage':
          if (parts.length >= 4) {
            final source = parts[1];
            final brebisId = parts[2];
            final accouplementId = parts[3];
            
            navigatorKey.currentState?.pushNamed(
              '/accouplements',
              arguments: {
                'source': source,
                'brebis_id': brebisId,
                'accouplement_id': accouplementId,
              },
            );
            debugPrint("➡️ Navigation vers /accouplements avec args");
          }
          break;
          
        default:
          debugPrint("⚠️ Type de notification inconnu: $type");
      }
    } catch (e) {
      debugPrint("❌ Erreur navigation notification: $e");
    }
  }
  
  // ===== NOTIFICATIONS POUR CHALEURS =====
  
  /// Planifier rappel 2 jours avant la prochaine chaleur prévue
  Future<void> planifierRappelProchaineChaleur({
    required dynamic brebisId,
    required String nomBrebis,
    required DateTime datePrevue,
    required String source,
  }) async {
    try {
      final dateRappel = datePrevue.subtract(
        Duration(days: ReproductionConfig.rappelAvantChaleurJours),
      );
      
      if (dateRappel.isAfter(DateTime.now())) {
        await _scheduleNotification(
          id: _generateNotificationId('chaleur_rappel', brebisId),
          title: '🔔 Chaleur prévue bientôt',
          body: '$nomBrebis devrait entrer en chaleur dans ${ReproductionConfig.rappelAvantChaleurJours} jours',
          scheduledDate: dateRappel,
          payload: 'chaleur_rappel:$source:$brebisId',
        );
        
        await _enregistrerRappelBD(
          type: 'chaleur_prevue',
          animalId: brebisId,
          source: source,
          dateRappel: dateRappel,
          message: 'Rappel prochaine chaleur',
        );
        
        debugPrint("✅ Rappel chaleur planifié pour $nomBrebis le ${_formatDate(dateRappel)}");
      } else {
        debugPrint("⚠️ Date de rappel dans le passé, ignorée");
      }
    } catch (e) {
      debugPrint('❌ Erreur planification rappel chaleur: $e');
    }
  }
  
  /// Planifier rappel 6h avant le début de la fenêtre fertile
  Future<void> planifierRappelFenetreFertile({
    required dynamic brebisId,
    required String nomBrebis,
    required DateTime dateChaleur,
    required String source,
  }) async {
    try {
      final debutFenetre = dateChaleur.add(
        Duration(hours: ReproductionConfig.debutFenetileHeures),
      );
      
      final dateRappel = debutFenetre.subtract(
        Duration(hours: ReproductionConfig.rappelFenetileFertileHeures),
      );
      
      if (dateRappel.isAfter(DateTime.now())) {
        await _scheduleNotification(
          id: _generateNotificationId('fenetre_fertile', brebisId),
          title: '🎯 Fenêtre d\'accouplement optimale',
          body: '$nomBrebis entre dans sa fenêtre fertile dans ${ReproductionConfig.rappelFenetileFertileHeures}h',
          scheduledDate: dateRappel,
          payload: 'fenetre_fertile:$source:$brebisId',
        );
        
        await _enregistrerRappelBD(
          type: 'fenetre_fertile',
          animalId: brebisId,
          source: source,
          dateRappel: dateRappel,
          message: 'Début fenêtre fertile',
        );
        
        debugPrint("✅ Rappel fenêtre fertile planifié pour $nomBrebis le ${_formatDate(dateRappel)}");
      } else {
        debugPrint("⚠️ Date de rappel dans le passé, ignorée");
      }
    } catch (e) {
      debugPrint('❌ Erreur planification fenêtre fertile: $e');
    }
  }
  
  // ===== NOTIFICATIONS POUR AGNELAGE =====
  
  /// Planifier les 3 rappels d'agnelage (30j, 7j, 1j avant)
  Future<void> planifierRappelsAgnelage({
    required dynamic brebisId,
    required String nomBrebis,
    required DateTime datePrevueAgnelage,
    required String source,
    required dynamic accouplementId,
  }) async {
    try {
      // Rappel 30 jours avant
      await _planifierRappelAgnelage(
        brebisId: brebisId,
        nomBrebis: nomBrebis,
        datePrevue: datePrevueAgnelage,
        source: source,
        accouplementId: accouplementId,
        joursAvant: ReproductionConfig.rappel1MoisAvantJours,
        titre: '📅 Agnelage dans 1 mois',
        corps: '$nomBrebis devrait agneler dans environ 30 jours. Préparez le matériel.',
      );
      
      // Rappel 7 jours avant
      await _planifierRappelAgnelage(
        brebisId: brebisId,
        nomBrebis: nomBrebis,
        datePrevue: datePrevueAgnelage,
        source: source,
        accouplementId: accouplementId,
        joursAvant: ReproductionConfig.rappel1SemaineAvantJours,
        titre: '⚠️ Agnelage dans 1 semaine',
        corps: '$nomBrebis devrait agneler dans 7 jours. Surveillance accrue recommandée.',
      );
      
      // Rappel 24h avant
      await _planifierRappelAgnelage(
        brebisId: brebisId,
        nomBrebis: nomBrebis,
        datePrevue: datePrevueAgnelage,
        source: source,
        accouplementId: accouplementId,
        joursAvant: ReproductionConfig.rappel24hAvantJours,
        titre: '🚨 Agnelage imminent',
        corps: '$nomBrebis devrait agneler dans les prochaines 24h. Surveillez-la de près.',
      );
      
      debugPrint("✅ 3 rappels agnelage planifiés pour $nomBrebis");
    } catch (e) {
      debugPrint('❌ Erreur planification rappels agnelage: $e');
    }
  }
  
  /// Planifier un rappel d'agnelage individuel
  Future<void> _planifierRappelAgnelage({
    required dynamic brebisId,
    required String nomBrebis,
    required DateTime datePrevue,
    required String source,
    required dynamic accouplementId,
    required int joursAvant,
    required String titre,
    required String corps,
  }) async {
    final dateRappel = datePrevue.subtract(Duration(days: joursAvant));
    
    if (dateRappel.isAfter(DateTime.now())) {
      await _scheduleNotification(
        id: _generateNotificationId('agnelage_$joursAvant', brebisId),
        title: titre,
        body: corps,
        scheduledDate: dateRappel,
        payload: 'agnelage:$source:$brebisId:$accouplementId',
      );
      
      await _enregistrerRappelBD(
        type: 'agnelage_${joursAvant}j',
        animalId: brebisId,
        source: source,
        dateRappel: dateRappel,
        message: corps,
        metadata: {'accouplement_id': accouplementId.toString()},
      );
      
      debugPrint("✅ Rappel agnelage $joursAvant jours planifié pour $nomBrebis");
    } else {
      debugPrint("⚠️ Date de rappel dans le passé ($joursAvant jours), ignorée");
    }
  }
  
  // ===== ANNULATION DE NOTIFICATIONS =====
  
  /// Annuler tous les rappels pour une brebis (vente, décès, etc.)
  Future<void> annulerRappelsBrebis({
    required dynamic brebisId,
    required String source,
  }) async {
    try {
      final notificationIds = [
        _generateNotificationId('chaleur_rappel', brebisId),
        _generateNotificationId('fenetre_fertile', brebisId),
        _generateNotificationId('agnelage_30', brebisId),
        _generateNotificationId('agnelage_7', brebisId),
        _generateNotificationId('agnelage_1', brebisId),
      ];
      
      for (var id in notificationIds) {
        await _notifications.cancel(id);
      }
      
      // Marquer comme annulés dans la base de données
      await supabase
          .from('rappels_reproduction')
          .update({
            'statut': 'annule',
            'date_annulation': DateTime.now().toIso8601String(),
          })
          .eq('animal_id', brebisId.toString())
          .eq('source', source)
          .eq('statut', 'planifie');
      
      debugPrint('✅ Tous les rappels annulés pour brebis $brebisId');
    } catch (e) {
      debugPrint('❌ Erreur annulation rappels: $e');
    }
  }
  
  // ===== FONCTIONS UTILITAIRES =====
  
  /// ✅ CORRIGÉ: Générer un ID unique et déterministe
  int _generateNotificationId(String prefix, dynamic animalId) {
    final idStr = animalId.toString();
    final combined = '${prefix}_$idStr';
    
    // Hash stable: prendre les 8 premiers chiffres du hashCode
    final hashValue = combined.hashCode.abs();
    final stableId = int.parse(
      hashValue.toString().substring(0, min(8, hashValue.toString().length))
    );
    
    debugPrint('🔑 ID notification généré: $stableId pour $combined');
    return stableId;
  }
  
  /// ✅ CORRIGÉ: Planifier une notification avec validation timezone robuste
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    try {
      // ✅ Vérification 1: Date dans le futur
      if (scheduledDate.isBefore(DateTime.now())) {
        debugPrint("⚠️ Date dans le passé, notification ignorée: $scheduledDate");
        return;
      }
      
      // ✅ Vérification 2: Timezone locale disponible
      if (!tz.timeZoneDatabase.locations.containsKey(tz.local.name)) {
        debugPrint("❌ Timezone locale invalide: ${tz.local.name}");
        throw Exception('Timezone non disponible: ${tz.local.name}');
      }
      
      // ✅ Conversion timezone sécurisée
      final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);
      
      // ✅ Vérification 3: Double-check après conversion
      if (tzDate.isBefore(tz.TZDateTime.now(tz.local))) {
        debugPrint("⚠️ Date TZ dans le passé après conversion: $tzDate");
        return;
      }
      
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tzDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'reproduction_channel',
            'Notifications Reproduction',
            channelDescription: 'Notifications pour le suivi de la reproduction',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
            enableLights: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      
      debugPrint("✅ Notification planifiée: ID=$id, Date=$scheduledDate");
    } catch (e, stack) {
      debugPrint("❌ ERREUR planification notification: $e");
      debugPrint("Stack: $stack");
      // Ne pas propager l'erreur pour ne pas bloquer l'app
    }
  }
  
  /// Enregistrer le rappel dans la base de données
  Future<void> _enregistrerRappelBD({
    required String type,
    required dynamic animalId,
    required String source,
    required DateTime dateRappel,
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        debugPrint("⚠️ Utilisateur non connecté, rappel BD ignoré");
        return;
      }
      
      final idValue = animalId.toString();
      
      await supabase.from('rappels_reproduction').insert({
        'user_id': userId,
        'type': type,
        'animal_id': idValue,
        'source': source,
        'date_rappel': dateRappel.toIso8601String(),
        'message': message,
        'statut': 'planifie',
        'metadata': metadata,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      debugPrint("✅ Rappel enregistré en BD: $type pour $idValue");
    } catch (e) {
      debugPrint('⚠️ Erreur enregistrement rappel BD (non-bloquant): $e');
    }
  }
  
  /// Formater une date pour les logs
  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }
  
  // ===== NETTOYAGE =====
  
  /// Nettoyer les rappels expirés dans la base de données
  Future<void> nettoyerRappelsExpires() async {
    try {
      final maintenant = DateTime.now();
      
      await supabase
          .from('rappels_reproduction')
          .update({'statut': 'expire'})
          .lt('date_rappel', maintenant.toIso8601String())
          .eq('statut', 'planifie');
      
      debugPrint('✅ Rappels expirés nettoyés');
    } catch (e) {
      debugPrint('❌ Erreur nettoyage rappels: $e');
    }
  }
  
  // ===== UTILITAIRES DE DEBUG =====
  
  /// Afficher toutes les notifications en attente (pour debug)
  Future<void> debugPendingNotifications() async {
    try {
      final pending = await _notifications.pendingNotificationRequests();
      debugPrint("📋 ${pending.length} notifications en attente:");
      for (var notif in pending) {
        debugPrint("  - ID: ${notif.id}, Titre: ${notif.title}");
      }
    } catch (e) {
      debugPrint("❌ Erreur récupération notifications: $e");
    }
  }
}