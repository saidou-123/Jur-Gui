// ============================================================
// MAIN.DART — VERSION ÉTAPE 5 (corrigée)
// ★ Routes retour_chaleur_j17 / j21 / non_fecondee / gestation_suspectee
//   ajoutées dans _naviguerDepuisNotification()
// ★ CORRECTIF : runApp() lancé dès que possible pour éviter les
//   "Skipped N frames" au démarrage. Supabase.initialize() et
//   Firebase.initializeApp() sont maintenant asynchrones, exécutés
//   pendant que le splash screen (Acceuil) s'affiche.
//   Acceuil attend le signal `supabasePret` (voir plus bas) avant
//   d'accéder à Supabase.instance.client — plus besoin de supposer
//   qu'un délai fixe suffit.
// ============================================================

import 'dart:async';

import 'package:depart/AlertesPage.dart';
import 'package:depart/Eleveures/New/Accouplemt/Accouplement..dart';
import 'package:depart/Eleveures/New/Notification/NotificationIdManager.dart';
import 'package:depart/Eleveures/New/Notification/NotificationService.dart';
import 'package:depart/Eleveures/New/chaleur/ChaleurModule.dart';
import 'package:depart/pages/Bienvenue/acceuil.dart';
import 'package:depart/pages/Bienvenue/descriptionPages/homePage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// ★ Signal global : se complète une fois Supabase.initialize() terminé.
/// Tout code qui a besoin de Supabase.instance.client de façon fiable
/// au tout début de l'app (ex: Acceuil) doit attendre ce futur avant
/// d'y accéder, plutôt que de supposer qu'un délai fixe suffit.
final Completer<void> supabasePret = Completer<void>();

// ============================================================
// HANDLER ARRIÈRE-PLAN FCM
// Doit rester au top-level (exigence Firebase)
// ============================================================
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Message arrière-plan: ${message.notification?.title}');
}

// ============================================================
// MAIN — runApp() dès que possible pour ne pas bloquer la 1ère frame
// ============================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Seul .env est bloquant : nécessaire pour les clés Supabase
  //    utilisées dès l'init, et c'est très rapide (lecture d'un fichier).
  await dotenv.load(fileName: '.env');
  debugPrint('✅ .env chargé');

  // ── L'app s'affiche IMMÉDIATEMENT (plus de jank au 1er frame) ──
  runApp(const MyApp());

  // ── Tout le reste (Supabase, Firebase, notifications, etc.)
  //    se fait en arrière-plan pendant que le splash (Acceuil) tourne.
  unawaited(_initApp());
}

/// Initialisations lourdes, non bloquantes pour l'affichage.
Future<void> _initApp() async {
  try {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    );
    debugPrint('✅ Supabase initialisé');
  } catch (e) {
    debugPrint('❌ Supabase init échoué: $e');
  } finally {
    // ★ On complète le signal dans tous les cas (succès ou échec) pour
    //   qu'Acceuil ne reste jamais bloqué à attendre indéfiniment.
    if (!supabasePret.isCompleted) supabasePret.complete();
  }

  try {
    await Firebase.initializeApp();
    debugPrint('✅ Firebase initialisé');
  } catch (e) {
    debugPrint('❌ Firebase init échoué: $e');
  }

  await _initSecondaire();
}

/// Toutes les initialisations secondaires (timezone, notifications, FCM).
Future<void> _initSecondaire() async {
  // Timezones — extraction robuste sur tous les appareils Android
  // flutter_timezone peut retourner :
  //   • Une String  : "Africa/Dakar"  (appareils normaux)
  //   • Un objet    : "TimezoneInfo(Africa/Dakar, (locale: fr_FR, ...))"
  // On extrait uniquement le nom IANA dans les deux cas.
  try {
    tz.initializeTimeZones(); // synchrone, garanti avant getLocation()
    final dynamic tzInfo = await FlutterTimezone.getLocalTimezone();
    String tzName = tzInfo.toString();
    final regexTzInfo = RegExp(r'TimezoneInfo\(([^,)]+)');
    final match = regexTzInfo.firstMatch(tzName);
    if (match != null) tzName = match.group(1)!.trim();
    if (tzName.isEmpty) tzName = 'UTC';
    tz.setLocalLocation(tz.getLocation(tzName));
    debugPrint('✅ Timezone: $tzName');
  } catch (e) {
    tz.setLocalLocation(tz.UTC);
    debugPrint('⚠️ Timezone fallback UTC: $e');
  }

  // Handler FCM arrière-plan
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Permission notifications
  try {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('✅ Permissions notifications accordées');
  } catch (e) {
    debugPrint('⚠️ Permissions notifications: $e');
  }

  // NotificationIdManager
  try {
    await NotificationIdManager().initialize();
    debugPrint('✅ NotificationIdManager: ${NotificationIdManager().count} IDs');
  } catch (e) {
    debugPrint('⚠️ NotificationIdManager: $e');
  }

  // NotificationService (local notifications)
  try {
    await NotificationService().initialize();
    debugPrint('✅ NotificationService initialisé');
  } catch (e, stack) {
    debugPrint('⚠️ NotificationService: $e\n$stack');
  }

  // Listeners FCM
  _initFCMListeners();

  debugPrint('✅ Toutes initialisations secondaires terminées');
}

/// Listeners FCM — toujours enregistrés après Firebase.initializeApp()
void _initFCMListeners() {
  Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
    final session = data.session;
    final event = data.event;

    if (event == AuthChangeEvent.signedIn && session != null) {
      debugPrint('🔐 Connecté: ${session.user.email}');
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await NotificationService().saveFcmToken(token);
          debugPrint('✅ Token FCM enregistré');
        }
      } catch (e) {
        debugPrint('⚠️ Token FCM: $e');
      }
    }

    if (event == AuthChangeEvent.signedOut) {
      await NotificationIdManager().clear();
      debugPrint('🔓 Déconnexion — registre notifications vidé');
    }
  });

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    try {
      await NotificationService().saveFcmToken(newToken);
      debugPrint('🔄 Token FCM renouvelé');
    } catch (e) {
      debugPrint('⚠️ Refresh token FCM: $e');
    }
  });

  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    debugPrint('📩 Message foreground: ${message.notification?.title}');
    final type = message.data['type'] ?? 'general';
    final urgente = type.contains('alerte') ||
        type.contains('cycle') ||
        type.contains('consultation') ||
        type == 'retour_chaleur_j21';
    await NotificationService().afficherNotificationImmediateLocal(
      titre: message.notification?.title ?? 'Jur-Gui',
      corps: message.notification?.body ?? '',
      type: type,
      urgente: urgente,
    );
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('👆 Notification cliquée: ${message.data}');
    _naviguerDepuisNotification(message.data);
  });

  FirebaseMessaging.instance.getInitialMessage().then((message) {
    if (message != null) {
      debugPrint('🚀 App ouverte depuis notification: ${message.data}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _naviguerDepuisNotification(message.data);
      });
    }
  });
}

// ============================================================
// NAVIGATION DEPUIS NOTIFICATION
// ============================================================
void _naviguerDepuisNotification(Map<String, dynamic> data) {
  final type = data['type'] ?? '';
  final nav = NotificationService().navigatorKey.currentState;

  if (type.contains('chaleur') ||
      type.contains('fenetre') ||
      type.contains('preparation_accouplement') ||
      type.contains('derniere_chance') ||
      type.contains('j15_sans_gestation') ||
      type == 'retour_chaleur_j17' ||
      type == 'retour_chaleur_j21' ||
      type == 'non_fecondee' ||
      type == 'gestation_suspectee') {
    nav?.pushNamed('/chaleur');
  } else if (type.contains('agnelage')) {
    nav?.pushNamed(
      '/accouplements',
      arguments: {
        'source': data['source'],
        'brebis_id': data['brebis_id'],
        'accouplement_id': data['accouplement_id'],
      },
    );
  } else if (type.contains('cycle') ||
      type.contains('alerte') ||
      type.contains('consultation')) {
    nav?.pushNamed('/sante');
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
      navigatorKey: NotificationService().navigatorKey,
      color: Colors.white,
      title: 'Jur-Gui',
      home: const Acceuil(),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1B5E20),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1B5E20),
          elevation: 2,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFF1B5E20),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1B5E20),
            foregroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFF1B5E20), width: 2),
          ),
        ),
      ),
      routes: {
        '/chaleur': (context) => const ChaleurModule(),
        '/accouplements': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          if (args != null) {
            debugPrint('Navigation accouplements: ${args['brebis_id']}');
          }
          return EnregistrerAccouplement();
        },
        '/sante': (context) => const AlertesPage(),
      },
    );
  }
}