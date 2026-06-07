// ============================================================
// NOTIFICATION SERVICE — VERSION CORRIGÉE v2
//
// ✅ CORRECTION 1 : ID immédiat → Random().nextInt() (plus de collision)
// ✅ CORRECTION 2 : Payload tap → JSON base64 (résistant aux UUIDs avec ':')
// ✅ CORRECTION 3 : Canal séparé 'alerte_channel' (Importance.max) pour urgences
// ✅ CORRECTION 4 : annulerRappelsBrebis() → contains() avant getOrCreate()
//                   (plus de création d'IDs fantômes)
// ✅ CORRECTION 5 : Notifications locales → canal alerte pour alertes vétérinaires
// ============================================================
 
import 'dart:convert';
import 'dart:io';
import 'dart:math';
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
 
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
 
  final _idManager = NotificationIdManager();
 
  // ✅ CORRECTION 1 : générateur d'IDs uniques sûrs
  final _random = Random();
  int _genererIdUnique() => _random.nextInt(2147483647);
 
  // ============================================================
  // CANAUX ANDROID
  // ── 'reproduction_channel' : rappels normaux (Importance.high)
  // ── 'alerte_channel'       : urgences vétérinaires (Importance.max)
  // ============================================================
 
  static const _canalReproduction = AndroidNotificationChannel(
    'reproduction_channel',
    'Notifications Reproduction',
    description: 'Rappels chaleurs, agnelage et suivi de reproduction',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    enableLights: true,
  );
 
  // ✅ CORRECTION 3 : canal dédié aux alertes urgentes
  static const _canalAlerte = AndroidNotificationChannel(
    'alerte_channel',
    'Alertes vétérinaires',
    description: 'Alertes urgentes : cycle anormal, consultation vétérinaire',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    enableLights: true,
  );
 
  // ============================================================
  // INITIALISATION
  // ============================================================
 
  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
 
    await _notifications.initialize(
      InitializationSettings(android: androidSettings, iOS: iosSettings),
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
 
    // ✅ Créer les deux canaux
    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_canalReproduction);
    await androidImpl?.createNotificationChannel(_canalAlerte);
 
    await _checkAndRequestExactAlarmPermission();
    debugPrint("✅ NotificationService initialisé (2 canaux créés)");
  }
 
  Future<void> _checkAndRequestExactAlarmPermission() async {
    if (!Platform.isAndroid) return;
    try {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin == null) return;
      final canSchedule = await androidPlugin.canScheduleExactNotifications();
      debugPrint(canSchedule == false
          ? "⚠️ Permission SCHEDULE_EXACT_ALARM non accordée"
          : "✅ Permission alarmes exactes accordée");
    } catch (e) {
      debugPrint("⚠️ Impossible de vérifier permission alarme: $e");
    }
  }
 
  // ============================================================
  // ✅ CORRECTION 2 : PAYLOAD JSON BASE64
  // Encode les données en JSON → base64 pour éviter tout conflit
  // avec le séparateur ':' présent dans les UUIDs Supabase.
  // ============================================================
 
  /// Encode un payload Map en base64 pour stockage dans la notification.
  String _encodePayload(Map<String, String> data) {
    return base64Url.encode(utf8.encode(jsonEncode(data)));
  }
 
  /// Décode un payload base64 en Map. Retourne {} si invalide.
  Map<String, dynamic> _decodePayload(String raw) {
    try {
      return jsonDecode(utf8.decode(base64Url.decode(raw)))
          as Map<String, dynamic>;
    } catch (_) {
      debugPrint('⚠️ Payload notification illisible: $raw');
      return {};
    }
  }
 
  // ============================================================
  // ✅ CORRECTION 2 : GESTION DES TAPS — lecture JSON base64
  // ============================================================
 
  void _onNotificationTap(NotificationResponse response) {
    if (response.payload == null || response.payload!.isEmpty) return;
 
    final data = _decodePayload(response.payload!);
    if (data.isEmpty) return;
 
    final type = data['type'] ?? '';
 
    switch (type) {
      case 'chaleur_rappel':
      case 'fenetre_fertile':
      case 'preparation_accouplement':
      case 'derniere_chance':
      case 'cycle_suivant':
        navigatorKey.currentState?.pushNamed('/chaleur');
        break;
 
      case 'agnelage':
        navigatorKey.currentState?.pushNamed(
          '/accouplements',
          arguments: {
            'source'          : data['source'],
            'brebis_id'       : data['brebis_id'],
            'accouplement_id' : data['accouplement_id'],
          },
        );
        break;
 
      case 'cycleCourt':
      case 'cycleLong':
      case 'absenceChaleurs':
      case 'anoestrus':
      case 'alerte_eleveur':
      case 'consultation_validee':
        navigatorKey.currentState?.pushNamed('/sante');
        break;
 
      default:
        debugPrint('ℹ️ Type de notification non géré pour navigation: $type');
    }
  }
 
  // ============================================================
  // TOKEN FCM
  // ============================================================
 
  Future<void> saveFcmToken(String fcmToken) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      await supabase.from('user_fcm_tokens').upsert(
        {
          'user_id'   : userId,
          'fcm_token' : fcmToken,
          'platform'  : Platform.isAndroid ? 'android' : 'ios',
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id',
      );
      debugPrint('✅ FCM token sauvegardé pour $userId');
    } catch (e) {
      debugPrint('❌ Erreur saveFcmToken: $e');
    }
  }
 
  // ============================================================
  // ✅ CORRECTION 1 : PUSH IMMÉDIAT — ID aléatoire garanti unique
  // ============================================================
 
  Future<void> afficherNotificationImmediateLocal({
    required String titre,
    required String corps,
    required String type,
    bool urgente = false, // ✅ CORRECTION 3 : canal alerte si urgente
  }) async {
    try {
      // ✅ ID aléatoire : pas de collision entre appels rapprochés
      final id = _genererIdUnique();
 
      final String canalId  = urgente ? 'alerte_channel' : 'reproduction_channel';
      final String canalNom = urgente ? 'Alertes vétérinaires' : 'Notifications Reproduction';
      final Importance importance = urgente ? Importance.max : Importance.high;
      final Priority   priority   = urgente ? Priority.max  : Priority.high;
 
      await _notifications.show(
        id,
        titre,
        corps,
        NotificationDetails(
          android: AndroidNotificationDetails(
            canalId, canalNom,
            channelDescription: urgente
                ? 'Alertes urgentes : cycle anormal, consultation vétérinaire'
                : 'Notifications pour le suivi de la reproduction',
            importance: importance,
            priority  : priority,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: _encodePayload({'type': type}),
      );
      debugPrint('✅ Notification immédiate affichée [ID=$id]: $titre');
    } catch (e) {
      debugPrint('❌ Erreur notification immédiate: $e');
    }
  }
 
  // ============================================================
  // ★ PROGRAMMATION PUSH DISTANT (via BD — professionnel)
  // ============================================================
 
  Future<void> _programmerPushDistant({
    required String type,
    required String titre,
    required String corps,
    required String animalId,
    required String source,
    required String nomAnimal,
    required DateTime dateEnvoi,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
 
      if (dateEnvoi.isBefore(DateTime.now())) {
        debugPrint('⚠️ Date passée, push ignoré: $type à $dateEnvoi');
        return;
      }
 
      await supabase.from('notifications_programmees').insert({
        'user_id'   : userId,
        'animal_id' : animalId.toString(),
        'source'    : source,
        'nom_animal': nomAnimal,
        'type'      : type,
        'titre'     : titre,
        'corps'     : corps,
        'date_envoi': dateEnvoi.toIso8601String(),
        'statut'    : 'planifie',
        'metadata'  : metadata,
        'created_at': DateTime.now().toIso8601String(),
      });
 
      debugPrint('📅 Push programmé: $type → ${_formatDate(dateEnvoi)}');
    } catch (e) {
      debugPrint('❌ Erreur programmation push: $e');
    }
  }
 
  // ============================================================
  // ★ N1 — PRÉPARATION ACCOUPLEMENT
  // ============================================================
 
  Future<void> planifierAlertPreparationAccouplement({
    required dynamic brebisId,
    required String nomBrebis,
    required DateTime dateChaleur,
    required String source,
  }) async {
    try {
      // 1. Notification locale immédiate (confirmation visuelle)
      await afficherNotificationImmediateLocal(
        titre: '🐑 Fenêtre d\'accouplement ouverte !',
        corps: '$nomBrebis est en chaleur. Préparez l\'accouplement maintenant.',
        type : 'preparation_accouplement',
      );
 
      // 2. Notification locale à H+6
      final rappelH6 = dateChaleur.add(const Duration(hours: 6));
      if (rappelH6.isAfter(DateTime.now())) {
        await _scheduleNotification(
          id: await _idManager.getOrCreate('prep_accouplement_h6', brebisId),
          title: '🎯 $nomBrebis — Fenêtre fertile active',
          body : 'La fenêtre d\'accouplement est ouverte depuis 6h. N\'attendez pas !',
          scheduledDate: rappelH6,
          // ✅ CORRECTION 2 : payload JSON base64
          payload: _encodePayload({
            'type'    : 'preparation_accouplement',
            'source'  : source,
            'brebis_id': brebisId.toString(),
          }),
        );
      }
 
      // 3. Push distant à H+6
      await _programmerPushDistant(
        type     : 'preparation_accouplement_h6',
        titre    : '🎯 $nomBrebis — Rappel accouplement',
        corps    : 'La fenêtre fertile de $nomBrebis est ouverte depuis 6h. C\'est le moment optimal !',
        animalId : brebisId.toString(),
        source   : source,
        nomAnimal: nomBrebis,
        dateEnvoi: rappelH6,
        metadata : {'brebis_id': brebisId.toString()},
      );
 
      debugPrint('✅ N1 planifiée pour $nomBrebis');
    } catch (e) {
      debugPrint('❌ Erreur N1: $e');
    }
  }
 
  // ============================================================
  // ★ N2 — ALERTE J+15 SANS GESTATION
  // ============================================================
 
  Future<void> planifierAlertJ15SansGestation({
    required dynamic brebisId,
    required String nomBrebis,
    required DateTime dateChaleur,
    required String source,
    required DateTime prochaineChaleeurPrevue,
  }) async {
    try {
      final dateJ15 = dateChaleur.add(const Duration(days: 15));
 
      await _scheduleNotification(
        id: await _idManager.getOrCreate('j15_sans_gestation', brebisId),
        title: '📅 $nomBrebis — Suivi J+15',
        body : 'Aucune gestation confirmée. Prochain cycle prévu le '
               '${_formatDate(prochaineChaleeurPrevue)}.',
        scheduledDate: dateJ15,
        payload: _encodePayload({
          'type'             : 'cycle_suivant',
          'source'           : source,
          'brebis_id'        : brebisId.toString(),
          'prochaine_chaleur': prochaineChaleeurPrevue.toIso8601String(),
        }),
      );
 
      await _programmerPushDistant(
        type     : 'j15_sans_gestation',
        titre    : '📅 $nomBrebis — Pas de gestation à J+15',
        corps    : 'Prochain cycle prévu le ${_formatDate(prochaineChaleeurPrevue)}. '
                   'Préparez l\'accouplement à l\'avance !',
        animalId : brebisId.toString(),
        source   : source,
        nomAnimal: nomBrebis,
        dateEnvoi: dateJ15,
        metadata : {
          'brebis_id'        : brebisId.toString(),
          'prochaine_chaleur': prochaineChaleeurPrevue.toIso8601String(),
        },
      );
 
      debugPrint('✅ N2 planifiée à J+15 pour $nomBrebis (${_formatDate(dateJ15)})');
    } catch (e) {
      debugPrint('❌ Erreur N2: $e');
    }
  }
 
  // ============================================================
  // ★ N3 — DERNIÈRE CHANCE À H+20
  // ============================================================
 
  Future<void> planifierAlerteDerniereChance({
    required dynamic brebisId,
    required String nomBrebis,
    required DateTime dateChaleur,
    required String source,
  }) async {
    try {
      final dateH20 = dateChaleur.add(const Duration(hours: 20));
 
      await _scheduleNotification(
        id: await _idManager.getOrCreate('derniere_chance_h20', brebisId),
        title: '🚨 DERNIÈRE CHANCE — $nomBrebis',
        body : 'La fenêtre fertile ferme dans 4h ! Si aucun accouplement '
               'n\'a été fait, c\'est maintenant ou jamais.',
        scheduledDate: dateH20,
        payload: _encodePayload({
          'type'    : 'derniere_chance',
          'source'  : source,
          'brebis_id': brebisId.toString(),
        }),
      );
 
      await _programmerPushDistant(
        type     : 'derniere_chance',
        titre    : '🚨 URGENT — Dernière chance $nomBrebis',
        corps    : 'Fenêtre fertile ferme dans 4h ! Aucun accouplement enregistré.',
        animalId : brebisId.toString(),
        source   : source,
        nomAnimal: nomBrebis,
        dateEnvoi: dateH20,
        metadata : {
          'brebis_id': brebisId.toString(),
          'fermeture': dateChaleur.add(const Duration(hours: 24)).toIso8601String(),
        },
      );
 
      debugPrint('✅ N3 planifiée à H+20 pour $nomBrebis (${_formatDate(dateH20)})');
    } catch (e) {
      debugPrint('❌ Erreur N3: $e');
    }
  }
 
  // ============================================================
  // ANNULER N3 SI ACCOUPLEMENT ENREGISTRÉ
  // ============================================================
 
  Future<void> annulerAlerteDerniereChance({
    required dynamic brebisId,
    required String source,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
 
      if (!_idManager.contains('derniere_chance_h20', brebisId)) {
        debugPrint('ℹ️ Aucune alerte dernière chance planifiée pour $brebisId');
        return;
      }
 
      final id = await _idManager.getOrCreate('derniere_chance_h20', brebisId);
      await _notifications.cancel(id);
      await _idManager.remove('derniere_chance_h20', brebisId);
 
      await supabase.from('notifications_programmees')
          .update({'statut': 'annule'})
          .eq('user_id', userId)
          .eq('animal_id', brebisId.toString())
          .eq('type', 'derniere_chance')
          .eq('statut', 'planifie');
 
      debugPrint('✅ Alerte dernière chance annulée — accouplement enregistré');
    } catch (e) {
      debugPrint('❌ Erreur annulation N3: $e');
    }
  }
 
  // ============================================================
  // NOTIFICATIONS CHALEURS
  // ============================================================
 
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
          id: await _idManager.getOrCreate('chaleur_rappel', brebisId),
          title: '🔔 Chaleur prévue bientôt',
          body : '$nomBrebis devrait entrer en chaleur dans '
                 '${ReproductionConfig.rappelAvantChaleurJours} jours',
          scheduledDate: dateRappel,
          payload: _encodePayload({
            'type'    : 'chaleur_rappel',
            'source'  : source,
            'brebis_id': brebisId.toString(),
          }),
        );
        await _enregistrerRappelBD(
          type: 'chaleur_prevue', animalId: brebisId, source: source,
          dateRappel: dateRappel,
          message: 'Rappel prochaine chaleur de $nomBrebis',
        );
        await _programmerPushDistant(
          type     : 'chaleur_prevue',
          titre    : '🔔 Chaleur prévue bientôt',
          corps    : '$nomBrebis devrait entrer en chaleur dans '
                     '${ReproductionConfig.rappelAvantChaleurJours} jours',
          animalId : brebisId.toString(),
          source   : source,
          nomAnimal: nomBrebis,
          dateEnvoi: dateRappel,
          metadata : {'brebis_id': brebisId.toString()},
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur rappel chaleur: $e');
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
          id: await _idManager.getOrCreate('fenetre_fertile', brebisId),
          title: '🎯 Fenêtre d\'accouplement optimale',
          body : '$nomBrebis entre dans sa fenêtre fertile dans '
                 '${ReproductionConfig.rappelFenetileFertileHeures}h',
          scheduledDate: dateRappel,
          payload: _encodePayload({
            'type'    : 'fenetre_fertile',
            'source'  : source,
            'brebis_id': brebisId.toString(),
          }),
        );
        await _enregistrerRappelBD(
          type: 'fenetre_fertile', animalId: brebisId, source: source,
          dateRappel: dateRappel,
          message: 'Début fenêtre fertile de $nomBrebis',
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur fenêtre fertile: $e');
    }
  }
 
  // ============================================================
  // NOTIFICATIONS AGNELAGE
  // ============================================================
 
  Future<void> planifierRappelsAgnelage({
    required dynamic brebisId,
    required String nomBrebis,
    required DateTime datePrevueAgnelage,
    required String source,
    required dynamic accouplementId,
  }) async {
    try {
      final rappels = [
        (ReproductionConfig.rappel1MoisAvantJours,
         '📅 Agnelage dans 1 mois',
         '$nomBrebis devrait agneler dans environ 30 jours. Préparez le matériel.'),
        (ReproductionConfig.rappel1SemaineAvantJours,
         '⚠️ Agnelage dans 1 semaine',
         '$nomBrebis devrait agneler dans 7 jours. Surveillance accrue recommandée.'),
        (ReproductionConfig.rappel24hAvantJours,
         '🚨 Agnelage imminent',
         '$nomBrebis devrait agneler dans les prochaines 24h. Surveillez-la de près.'),
      ];
 
      for (final (jours, titre, corps) in rappels) {
        final dateRappel = datePrevueAgnelage.subtract(Duration(days: jours));
        if (dateRappel.isAfter(DateTime.now())) {
          await _scheduleNotification(
            id: await _idManager.getOrCreate('agnelage_${jours}j', brebisId),
            title: titre,
            body : corps,
            scheduledDate: dateRappel,
            payload: _encodePayload({
              'type'           : 'agnelage',
              'source'         : source,
              'brebis_id'      : brebisId.toString(),
              'accouplement_id': accouplementId.toString(),
            }),
          );
          await _enregistrerRappelBD(
            type: 'agnelage_${jours}j', animalId: brebisId,
            source: source, dateRappel: dateRappel, message: corps,
            metadata: {'accouplement_id': accouplementId.toString()},
          );
          await _programmerPushDistant(
            type     : 'agnelage_${jours}j',
            titre    : titre,
            corps    : corps,
            animalId : brebisId.toString(),
            source   : source,
            nomAnimal: nomBrebis,
            dateEnvoi: dateRappel,
            metadata : {
              'brebis_id'      : brebisId.toString(),
              'accouplement_id': accouplementId.toString(),
            },
          );
        }
      }
      debugPrint("✅ Rappels agnelage planifiés pour $nomBrebis");
    } catch (e) {
      debugPrint('❌ Erreur agnelage: $e');
    }
  }
 
  // ============================================================
  // ✅ CORRECTION 3 : PUSH VÉTÉRINAIRE — canal 'alerte_channel'
  // ============================================================
 
  Future<void> notifierVeterinaire({
    required String veterinaireId,
    required String nomBrebis,
    required String message,
    required String animalId,
    required String source,
  }) async {
    try {
      await supabase.functions.invoke('send-push-notification', body: {
        'user_id': veterinaireId,
        'title'  : '🚨 Anomalie signalée',
        'body'   : '$nomBrebis — $message',
        'type'   : 'alerte_eleveur',
        'data'   : {'animal_id': animalId, 'source': source},
        'channel': 'alerte_channel', // ✅ hint pour le worker FCM côté serveur
      });
      // ✅ Notification locale urgente sur le bon canal
      await afficherNotificationImmediateLocal(
        titre  : '🚨 Anomalie signalée — $nomBrebis',
        corps  : message,
        type   : 'alerte_eleveur',
        urgente: true,
      );
      debugPrint('✅ Vétérinaire notifié immédiatement pour $nomBrebis');
    } catch (e) {
      debugPrint('❌ Erreur notification vétérinaire: $e');
    }
  }
 
  Future<void> notifierEleveurConsultation({
    required String eleveurId,
    required String nomBrebis,
    required String diagnostic,
    required String animalId,
    required String source,
  }) async {
    try {
      await supabase.functions.invoke('send-push-notification', body: {
        'user_id': eleveurId,
        'title'  : '✅ Consultation validée',
        'body'   : '$nomBrebis — $diagnostic',
        'type'   : 'consultation_validee',
        'data'   : {'animal_id': animalId, 'source': source},
      });
      debugPrint('✅ Éleveur notifié immédiatement pour $nomBrebis');
    } catch (e) {
      debugPrint('❌ Erreur notification éleveur: $e');
    }
  }
 
  // ============================================================
  // ✅ CORRECTION 4 : ANNULATION GÉNÉRALE — sans IDs fantômes
  // Vérifie contains() avant de tenter une annulation.
  // Avant : getOrCreate() créait l'entrée si absente, puis remove()
  //         la supprimait → écriture inutile + état pollué.
  // ============================================================
 
  Future<void> annulerRappelsBrebis({
    required dynamic brebisId,
    required String source,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
 
      final agnelageKeys = [
        'agnelage_${ReproductionConfig.rappel1MoisAvantJours}j',
        'agnelage_${ReproductionConfig.rappel1SemaineAvantJours}j',
        'agnelage_${ReproductionConfig.rappel24hAvantJours}j',
      ];
 
      final prefixes = [
        'chaleur_rappel', 'fenetre_fertile', 'prep_accouplement_h6',
        'j15_sans_gestation', 'derniere_chance_h20',
        ...agnelageKeys,
      ];
 
      // ✅ CORRECTION 4 : annuler uniquement les IDs qui existent vraiment
      for (final prefix in prefixes) {
        if (_idManager.contains(prefix, brebisId)) {
          final id = await _idManager.getOrCreate(prefix, brebisId);
          await _notifications.cancel(id);
          await _idManager.remove(prefix, brebisId);
          debugPrint('🗑️ Rappel annulé: $prefix → $brebisId');
        }
      }
 
      await supabase.from('rappels_reproduction').update({
        'statut'          : 'annule',
        'date_annulation' : DateTime.now().toIso8601String(),
      }).eq('animal_id', brebisId.toString())
        .eq('source', source)
        .eq('statut', 'planifie');
 
      if (userId != null) {
        await supabase.from('notifications_programmees').update({
          'statut': 'annule',
        }).eq('user_id', userId)
          .eq('animal_id', brebisId.toString())
          .eq('statut', 'planifie');
      }
 
      debugPrint('✅ Tous les rappels annulés pour brebis $brebisId');
    } catch (e) {
      debugPrint('❌ Erreur annulation: $e');
    }
  }
 
  // ============================================================
  // PLANIFICATION LOCALE
  // ============================================================
 
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    try {
      if (scheduledDate.isBefore(DateTime.now())) return;
      if (!tz.timeZoneDatabase.locations.containsKey(tz.local.name)) return;
      final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);
      if (tzDate.isBefore(tz.TZDateTime.now(tz.local))) return;
 
      await _notifications.zonedSchedule(
        id, title, body, tzDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'reproduction_channel', 'Notifications Reproduction',
            channelDescription: 'Notifications pour le suivi de la reproduction',
            importance: Importance.high,
            priority  : Priority.high,
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
      debugPrint("✅ Notification locale planifiée: ID=$id à $scheduledDate");
    } catch (e, stack) {
      debugPrint("❌ ERREUR planification: $e\n$stack");
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
        'user_id'   : userId,
        'type'      : type,
        'animal_id' : animalId.toString(),
        'source'    : source,
        'date_rappel': dateRappel.toIso8601String(),
        'message'   : message,
        'statut'    : 'planifie',
        'metadata'  : metadata,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('⚠️ Erreur enregistrement rappel BD: $e');
    }
  }
 
  // ============================================================
  // DEBUG
  // ============================================================
 
  Future<void> debugPendingNotifications() async {
    try {
      final pending = await _notifications.pendingNotificationRequests();
      debugPrint("📋 ${pending.length} notifications locales en attente:");
      for (var n in pending) {
        debugPrint("  - ID: ${n.id}, Titre: ${n.title}");
      }
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final pushProgrammes = await supabase
            .from('notifications_programmees')
            .select('type, nom_animal, date_envoi, statut')
            .eq('user_id', userId)
            .eq('statut', 'planifie')
            .order('date_envoi');
        debugPrint("📋 ${pushProgrammes.length} push distants programmés:");
        for (var p in pushProgrammes) {
          debugPrint(
              "  - ${p['type']} → ${p['nom_animal']} le ${p['date_envoi']}");
        }
      }
    } catch (e) {
      debugPrint("❌ Erreur debug: $e");
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
      debugPrint('❌ Erreur nettoyage: $e');
    }
  }
 
  // ============================================================
  // UTILITAIRES
  // ============================================================
 
  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}