// ============================================================
// MAIN.DART — VERSION CORRIGÉE
//
// ✅ Étape 2 intégrée : NotificationIdManager().initialize()
//    appelé avant runApp() — les IDs survivent au redémarrage
//
// ✅ Firebase Messaging — vrai token FCM
// ✅ Supabase — sauvegarde token au login
// ✅ Notifications locales + push distantes
// ✅ Affichage notification quand app est ouverte (foreground)
//
// ⚠️  SÉCURITÉ — clé Supabase :
//   La anonKey ne doit PAS être en clair dans le code source.
//   Solution recommandée : fichier .env + package flutter_dotenv
//
//   1. Ajouter dans pubspec.yaml :
//        flutter_dotenv: ^5.1.0
//
//   2. Créer un fichier .env à la racine du projet :
//        SUPABASE_URL=https://oyudfyxlyxggforfxdin.supabase.co
//        SUPABASE_ANON_KEY=eyJhbGci...
//
//   3. Ajouter .env dans pubspec.yaml assets :
//        flutter:
//          assets:
//            - .env
//
//   4. Ajouter .env dans .gitignore :
//        .env
//
//   En attendant, la clé est conservée ici mais NE PAS
//   pousser ce fichier sur GitHub/GitLab sans protection.
// ============================================================

import 'dart:io';
import 'package:depart/Eleveures/New/Accouplemt/Accouplement..dart';
import 'package:depart/Eleveures/New/Notification/NotificationIdManager.dart';
import 'package:depart/Eleveures/New/Notification/NotificationService.dart';
import 'package:depart/Eleveures/New/chaleur/ChaleurModule.dart';
import 'package:depart/pages/Bienvenue/acceuil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;

// ── Constantes Supabase ──────────────────────────────────
// ⚠️ À déplacer dans un fichier .env (voir commentaire en haut)
const String _supabaseUrl     = 'https://oyudfyxlyxggforfxdin.supabase.co';
const String _supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
    '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95dWRmeXhseXhnZ2ZvcmZ4ZGluIiwi'
    'cm9sZSI6ImFub24iLCJpYXQiOjE3NjE3NDg1NzAsImV4cCI6MjA3NzMyNDU3MH0'
    '.ccVliXQ82DOBGowLMOuzUClekXb9zXUZSUfPGwGPQoA';

// ── Handler arrière-plan FCM ─────────────────────────────
// @pragma nécessaire pour que Flutter conserve cette fonction
// en mode release (tree-shaking)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase doit être réinitialisé dans l'isolate d'arrière-plan
  await Firebase.initializeApp();
  debugPrint('📩 Message arrière-plan: ${message.notification?.title}');
  // FCM affiche automatiquement la notification en arrière-plan
}

// ============================================================
// MAIN
// ============================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 1. Timezones ─────────────────────────────────────────
  tz.initializeTimeZones();
  debugPrint('✅ Timezones initialisées');

  // ── 2. Supabase ───────────────────────────────────────────
  await Supabase.initialize(
    url    : _supabaseUrl,
    anonKey: _supabaseAnonKey,
  );
  debugPrint('✅ Supabase initialisé');

  // ── 3. Firebase ───────────────────────────────────────────
  await Firebase.initializeApp();
  debugPrint('✅ Firebase initialisé');

  // ── 4. Handler arrière-plan FCM ───────────────────────────
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ── 5. Permissions notifications ──────────────────────────
  await FirebaseMessaging.instance.requestPermission(
    alert : true,
    badge : true,
    sound : true,
  );

  // ── 6. ✅ NOUVEAU — NotificationIdManager persistant ──────
  // Doit être initialisé AVANT NotificationService pour que
  // les rappels déjà programmés (agnelage J-30/J-7/J-1) soient
  // retrouvés correctement au redémarrage.
  try {
    await NotificationIdManager().initialize();
    debugPrint('✅ NotificationIdManager initialisé '
        '(${NotificationIdManager().count} IDs restaurés)');
  } catch (e) {
    debugPrint('⚠️ NotificationIdManager — erreur init: $e');
    // Non bloquant : l'app fonctionne, mais les IDs repartent de 1000
  }

  // ── 7. Notifications locales ──────────────────────────────
  try {
    await NotificationService().initialize();
    debugPrint('✅ NotificationService initialisé');
  } catch (e, stack) {
    debugPrint('❌ Erreur NotificationService: $e');
    debugPrint('Stack: $stack');
  }

  // ── 8. Auth listener → sauvegarder token FCM au login ─────
  Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
    final session = data.session;
    final event   = data.event;

    if (event == AuthChangeEvent.signedIn && session != null) {
      debugPrint('🔑 Connecté: ${session.user.email}');
      try {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await NotificationService().saveFcmToken(fcmToken);
          debugPrint(
            '✅ Token FCM enregistré: ${fcmToken.substring(0, 20)}...',
          );
        }
      } catch (e) {
        debugPrint('❌ Erreur token FCM: $e');
      }
    }

    if (event == AuthChangeEvent.signedOut) {
      debugPrint('🚪 Déconnexion');
      // ✅ Vider le registre des IDs à la déconnexion
      // pour repartir proprement au prochain login
      await NotificationIdManager().clear();
      debugPrint('🗑️ Registre notifications vidé après déconnexion');
    }
  });

  // ── 9. Messages foreground (app ouverte) ──────────────────
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    debugPrint('📩 Message foreground: ${message.notification?.title}');

    // Afficher la notification locale même quand l'app est ouverte
    // car FCM ne l'affiche pas automatiquement en foreground
    await NotificationService().afficherNotificationImmediateLocal(
      titre: message.notification?.title ?? 'Jur-Gui',
      corps: message.notification?.body  ?? '',
      type : message.data['type']        ?? 'general',
    );
  });

  // ── 10. Clic sur notification → navigation ─────────────────
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('📲 Notification cliquée: ${message.data}');
    _naviguerDepuisNotification(message.data);
  });

  // ── 11. App ouverte depuis notification (app était fermée) ─
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    debugPrint('📲 App ouverte depuis notification: ${initialMessage.data}');
    // Délai pour laisser le temps à MaterialApp de s'initialiser
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _naviguerDepuisNotification(initialMessage.data);
    });
  }

  runApp(const MyApp());
}

// ── Fonction de navigation centralisée ────────────────────
// Centralisée ici pour éviter la duplication entre
// onMessageOpenedApp et getInitialMessage
void _naviguerDepuisNotification(Map<String, dynamic> data) {
  final type = data['type'] ?? '';

  if (type.contains('chaleur') || type.contains('fenetre')) {
    NotificationService().navigatorKey.currentState?.pushNamed('/chaleur');
  } else if (type.contains('agnelage')) {
    NotificationService().navigatorKey.currentState?.pushNamed(
      '/accouplements',
      arguments: {
        'source'          : data['source'],
        'brebis_id'       : data['brebis_id'],
        'accouplement_id' : data['accouplement_id'],
      },
    );
  } else if (type.contains('consultation') || type.contains('alerte')) {
    NotificationService().navigatorKey.currentState?.pushNamed('/sante');
  }
}

// ============================================================
// APP
// ============================================================

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // NavigatorKey pour navigation depuis notifications
      navigatorKey: NotificationService().navigatorKey,
      color       : Colors.white,
      title       : 'Jur-Gui',
      home        : const Acceuil(),
      debugShowCheckedModeBanner: false,

      // Routes pour navigation depuis notifications
      routes: {
        '/chaleur': (context) => const ChaleurModule(),

        '/accouplements': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          if (args != null) {
            debugPrint('📲 Navigation accouplements: ${args['brebis_id']}');
          }
          return EnregistrerAccouplement(
            // Pré-sélectionner la brebis si l'ID est passé en argument
            // (navigation depuis notification agnelage)
          );
        },

        '/sante': (context) {
          // TODO: remplacer par votre vraie page santé
          return const Acceuil();
        },
      },
    );
  }
}