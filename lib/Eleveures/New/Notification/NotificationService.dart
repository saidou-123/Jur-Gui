// ============================================================
// NOTIFICATION SERVICE - VERSION CORRIGÉE
// Fichier: lib/Eleveures/New/Notification/NotificationService.dart
// Corrections:
//   ✅ Bug hashCode remplacé par NotificationIdManager (IDs uniques garantis)
//   ✅ _generateNotificationId utilise maintenant le registre centralisé
// ============================================================

import 'dart:io';
import 'package:depart/Eleveures/New/Notification/NotificationIdManager.dart';
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

  // ✅ CORRECTION: Utiliser le gestionnaire d'IDs centralisé
  final _idManager = NotificationIdManager();

  // ===== INITIALISATION =====
  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
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

    await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

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

    await _checkAndRequestExactAlarmPermission();

    debugPrint("✅ NotificationService initialisé");
  }

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
      } else {
        debugPrint("✅ Permission alarmes exactes accordée");
      }
    } catch (e) {
      debugPrint("⚠️ Impossible de vérifier permission alarme: $e");
    }
  }

  // ===== GESTION DES TAPS =====
  void _onNotificationTap(NotificationResponse response) {
    if (response.payload == null || response.payload!.isEmpty) return;

    debugPrint("📲 Notification tapped: ${response.payload}");

    try {
      final parts = response.payload!.split(':');
      if (parts.isEmpty) return;

      final type = parts[0];

      switch (type) {
        case 'chaleur_rappel':
        case 'fenetre_fertile':
          navigatorKey.currentState?.pushNamed('/chaleur');
          break;

        case 'agnelage':
          if (parts.length >= 4) {
            navigatorKey.currentState?.pushNamed(
              '/accouplements',
              arguments: {
                'source': parts[1],
                'brebis_id': parts[2],
                'accouplement_id': parts[3],
              },
            );
          }
          break;
      }
    } catch (e) {
      debugPrint("❌ Erreur navigation notification: $e");
    }
  }

  // ===== NOTIFICATIONS CHALEURS =====

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
          // ✅ CORRECTION: ID unique via le gestionnaire centralisé
          id: _idManager.getOrCreate('chaleur_rappel', brebisId),
          title: '🔔 Chaleur prévue bientôt',
          body:
              '$nomBrebis devrait entrer en chaleur dans ${ReproductionConfig.rappelAvantChaleurJours} jours',
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
      }
    } catch (e) {
      debugPrint('❌ Erreur planification rappel chaleur: $e');
    }
  }

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
          // ✅ CORRECTION: ID unique via le gestionnaire centralisé
          id: _idManager.getOrCreate('fenetre_fertile', brebisId),
          title: '🎯 Fenêtre d\'accouplement optimale',
          body:
              '$nomBrebis entre dans sa fenêtre fertile dans ${ReproductionConfig.rappelFenetileFertileHeures}h',
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
      }
    } catch (e) {
      debugPrint('❌ Erreur planification fenêtre fertile: $e');
    }
  }

  // ===== NOTIFICATIONS AGNELAGE =====

  Future<void> planifierRappelsAgnelage({
    required dynamic brebisId,
    required String nomBrebis,
    required DateTime datePrevueAgnelage,
    required String source,
    required dynamic accouplementId,
  }) async {
    try {
      await _planifierRappelAgnelage(
        brebisId: brebisId,
        nomBrebis: nomBrebis,
        datePrevue: datePrevueAgnelage,
        source: source,
        accouplementId: accouplementId,
        joursAvant: ReproductionConfig.rappel1MoisAvantJours,
        titre: '📅 Agnelage dans 1 mois',
        corps:
            '$nomBrebis devrait agneler dans environ 30 jours. Préparez le matériel.',
      );

      await _planifierRappelAgnelage(
        brebisId: brebisId,
        nomBrebis: nomBrebis,
        datePrevue: datePrevueAgnelage,
        source: source,
        accouplementId: accouplementId,
        joursAvant: ReproductionConfig.rappel1SemaineAvantJours,
        titre: '⚠️ Agnelage dans 1 semaine',
        corps:
            '$nomBrebis devrait agneler dans 7 jours. Surveillance accrue recommandée.',
      );

      await _planifierRappelAgnelage(
        brebisId: brebisId,
        nomBrebis: nomBrebis,
        datePrevue: datePrevueAgnelage,
        source: source,
        accouplementId: accouplementId,
        joursAvant: ReproductionConfig.rappel24hAvantJours,
        titre: '🚨 Agnelage imminent',
        corps:
            '$nomBrebis devrait agneler dans les prochaines 24h. Surveillez-la de près.',
      );

      debugPrint("✅ 3 rappels agnelage planifiés pour $nomBrebis");
    } catch (e) {
      debugPrint('❌ Erreur planification rappels agnelage: $e');
    }
  }

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
        // ✅ CORRECTION: préfixe unique par durée → IDs distincts pour les 3 rappels
        id: _idManager.getOrCreate('agnelage_${joursAvant}j', brebisId),
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
    }
  }

  // ===== ANNULATION =====

  Future<void> annulerRappelsBrebis({
    required dynamic brebisId,
    required String source,
  }) async {
    try {
      // ✅ CORRECTION: On récupère les vrais IDs depuis le registre
      final ids = [
        _idManager.getOrCreate('chaleur_rappel', brebisId),
        _idManager.getOrCreate('fenetre_fertile', brebisId),
        _idManager.getOrCreate('agnelage_30j', brebisId),
        _idManager.getOrCreate('agnelage_7j', brebisId),
        _idManager.getOrCreate('agnelage_1j', brebisId),
      ];

      for (var id in ids) {
        await _notifications.cancel(id);
      }

      // Nettoyer le registre
      _idManager.remove('chaleur_rappel', brebisId);
      _idManager.remove('fenetre_fertile', brebisId);
      _idManager.remove('agnelage_30j', brebisId);
      _idManager.remove('agnelage_7j', brebisId);
      _idManager.remove('agnelage_1j', brebisId);

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

  // ===== PLANIFICATION =====

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    try {
      if (scheduledDate.isBefore(DateTime.now())) {
        debugPrint("⚠️ Date dans le passé, notification ignorée: $scheduledDate");
        return;
      }

      if (!tz.timeZoneDatabase.locations.containsKey(tz.local.name)) {
        throw Exception('Timezone non disponible: ${tz.local.name}');
      }

      final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

      if (tzDate.isBefore(tz.TZDateTime.now(tz.local))) {
        debugPrint("⚠️ Date TZ dans le passé après conversion");
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
            channelDescription:
                'Notifications pour le suivi de la reproduction',
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
    }
  }

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
      if (userId == null) return;

      await supabase.from('rappels_reproduction').insert({
        'user_id': userId,
        'type': type,
        'animal_id': animalId.toString(),
        'source': source,
        'date_rappel': dateRappel.toIso8601String(),
        'message': message,
        'statut': 'planifie',
        'metadata': metadata,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('⚠️ Erreur enregistrement rappel BD (non-bloquant): $e');
    }
  }

  // ===== DEBUG =====

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

  Future<void> nettoyerRappelsExpires() async {
    try {
      await supabase
          .from('rappels_reproduction')
          .update({'statut': 'expire'})
          .lt('date_rappel', DateTime.now().toIso8601String())
          .eq('statut', 'planifie');

      debugPrint('✅ Rappels expirés nettoyés');
    } catch (e) {
      debugPrint('❌ Erreur nettoyage rappels: $e');
    }
  }
}