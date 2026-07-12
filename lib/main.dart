// ============================================================
// MAIN.DART — VERSION ÉTAPE 5
// ★ Routes retour_chaleur_j17 / j21 / non_fecondee / gestation_suspectee
//   ajoutées dans _naviguerDepuisNotification()
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
// MAIN — optimisé pour éviter les frames sautées au démarrage
// ============================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
 
  // ── ÉTAPE 1 : bloquant strict (nécessaire avant runApp) ───
  await dotenv.load(fileName: '.env');
  debugPrint('✅ .env chargé');
 
  await Supabase.initialize(
    url    : dotenv.env['SUPABASE_URL']      ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );
  debugPrint('✅ Supabase initialisé');
 
  await Firebase.initializeApp();
  debugPrint('✅ Firebase initialisé');
 
  // ── ÉTAPE 2 : lancer l'app IMMÉDIATEMENT ─────────────────
  runApp(const MyApp());
 
  // ── ÉTAPE 3 : initialisations secondaires EN PARALLÈLE ───
  unawaited(_initSecondaire());
}
 
/// Toutes les initialisations non bloquantes pour l'affichage.
Future<void> _initSecondaire() async {
    // 3a. Timezones — extraction robuste sur tous les appareils Android
  // flutter_timezone peut retourner :
  //   • Une String  : "Africa/Dakar"  (appareils normaux)
  //   • Un objet    : "TimezoneInfo(Africa/Dakar, (locale: fr_FR, ...))"
  // On extrait uniquement le nom IANA dans les deux cas.
  try {
    tz.initializeTimeZones(); // synchrone, garanti avant getLocation()
    final dynamic tzInfo = await FlutterTimezone.getLocalTimezone();
    String tzName = tzInfo.toString();
    // Extraire le nom IANA si format "TimezoneInfo(Africa/Dakar, ...)"
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
 
  // 3b. Handler FCM arrière-plan
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
 
  // 3c. Permission notifications
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
 
  // 3d. NotificationIdManager
  try {
    await NotificationIdManager().initialize();
    debugPrint('✅ NotificationIdManager: ${NotificationIdManager().count} IDs');
  } catch (e) {
    debugPrint('⚠️ NotificationIdManager: $e');
  }
 
  // 3e. NotificationService (local notifications)
  try {
    await NotificationService().initialize();
    debugPrint('✅ NotificationService initialisé');
  } catch (e, stack) {
    debugPrint('⚠️ NotificationService: $e\n$stack');
  }
 
  // 3f. Listeners FCM
  _initFCMListeners();
 
  debugPrint('✅ Toutes initialisations secondaires terminées');
}
 
 
/// Listeners FCM — toujours enregistrés après Firebase.initializeApp()
void _initFCMListeners() {
  // Auth listener — token FCM + clear IDs au logout
  Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
    final session = data.session;
    final event   = data.event;
 
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
 
  // Renouvellement token FCM
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    try {
      await NotificationService().saveFcmToken(newToken);
      debugPrint('🔄 Token FCM renouvelé');
    } catch (e) {
      debugPrint('⚠️ Refresh token FCM: $e');
    }
  });
 
  // Messages foreground (app ouverte)
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    debugPrint('📩 Message foreground: ${message.notification?.title}');
    final type    = message.data['type'] ?? 'general';
    // ★ ÉTAPE 5 : types retour chaleur considérés comme urgents
    final urgente = type.contains('alerte') ||
                    type.contains('cycle')  ||
                    type.contains('consultation') ||
                    type == 'retour_chaleur_j21';
    await NotificationService().afficherNotificationImmediateLocal(
      titre  : message.notification?.title ?? 'Jur-Gui',
      corps  : message.notification?.body  ?? '',
      type   : type,
      urgente: urgente,
    );
  });
 
  // Clic sur notification (app en arrière-plan)
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('👆 Notification cliquée: ${message.data}');
    _naviguerDepuisNotification(message.data);
  });
 
  // App lancée depuis notification (app était fermée)
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
// ★ ÉTAPE 5 : routes retour_chaleur_j17/j21/non_fecondee/
//             gestation_suspectee ajoutées
// ============================================================
void _naviguerDepuisNotification(Map<String, dynamic> data) {
  final type = data['type'] ?? '';
  final nav  = NotificationService().navigatorKey.currentState;
 
  if (type.contains('chaleur')              ||
      type.contains('fenetre')              ||
      type.contains('preparation_accouplement') ||
      type.contains('derniere_chance')          ||
      type.contains('j15_sans_gestation')       ||
      type == 'retour_chaleur_j17'              || // ★ ÉTAPE 5
      type == 'retour_chaleur_j21'              || // ★ ÉTAPE 5
      type == 'non_fecondee'                    || // ★ ÉTAPE 5
      type == 'gestation_suspectee') {             // ★ ÉTAPE 5
    nav?.pushNamed('/chaleur');
 
  } else if (type.contains('agnelage')) {
    nav?.pushNamed(
      '/accouplements',
      arguments: {
        'source'          : data['source'],
        'brebis_id'       : data['brebis_id'],
        'accouplement_id' : data['accouplement_id'],
      },
    );
 
  } else if (type.contains('cycle')  ||
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
      navigatorKey              : NotificationService().navigatorKey,
      color                     : Colors.white,
      title                     : 'Jur-Gui',
      home                      :  Homepage(),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed         : const Color(0xFF1B5E20),
        useMaterial3            : true,
        scaffoldBackgroundColor : Colors.grey[50],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1B5E20),
          elevation      : 2,
          centerTitle    : true,
          titleTextStyle : TextStyle(
            color     : Color(0xFF1B5E20),
            fontSize  : 20,
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
            borderSide  : BorderSide(color: Color(0xFF1B5E20), width: 2),
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