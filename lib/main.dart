import 'package:depart/AlertesPage.dart';
import 'package:depart/Eleveures/New/Accouplemt/Accouplement..dart';
import 'package:depart/Eleveures/New/Notification/NotificationIdManager.dart';
import 'package:depart/Eleveures/New/Notification/NotificationService.dart';
import 'package:depart/Eleveures/New/chaleur/ChaleurModule.dart';
import 'package:depart/pages/Bienvenue/acceuil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
 
// Handler arriere-plan FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Message arriere-plan: ${message.notification?.title}');
}
 
// ============================================================
// MAIN
// ============================================================
 
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
 
  // 1. Chargement .env — AVANT toute initialisation
  await dotenv.load(fileName: '.env');
  debugPrint('Variables environnement chargees');
 
  // 2. Timezones
  tz.initializeTimeZones();
  try {
    final dynamic tzInfo = await FlutterTimezone.getLocalTimezone();
    final String localTimezoneName =
        tzInfo is String ? tzInfo : (tzInfo.name as String);
    tz.setLocalLocation(tz.getLocation(localTimezoneName));
    debugPrint('Timezone locale: $localTimezoneName');
  } catch (e) {
    tz.setLocalLocation(tz.UTC);
    debugPrint('Timezone non detectee — fallback UTC: $e');
  }
 
  // 3. Supabase — cles depuis .env
  await Supabase.initialize(
    url    : dotenv.env['SUPABASE_URL']      ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );
  debugPrint('Supabase initialise');
 
  // 4. Firebase
  await Firebase.initializeApp();
  debugPrint('Firebase initialise');
 
  // 5. Handler arriere-plan FCM
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
 
  // 6. Permissions notifications
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
 
  // 7. NotificationIdManager persistant
  try {
    await NotificationIdManager().initialize();
    debugPrint('NotificationIdManager: ${NotificationIdManager().count} IDs restaures');
  } catch (e) {
    debugPrint('NotificationIdManager init: $e');
  }
 
  // 8. Notifications locales
  try {
    await NotificationService().initialize();
    debugPrint('NotificationService initialise');
  } catch (e, stack) {
    debugPrint('Erreur NotificationService: $e\n$stack');
  }
 
  // 9. Auth listener — token FCM + clear IDs au logout
  Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
    final session = data.session;
    final event   = data.event;
 
    if (event == AuthChangeEvent.signedIn && session != null) {
      debugPrint('Connecte: ${session.user.email}');
      try {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await NotificationService().saveFcmToken(fcmToken);
          debugPrint('Token FCM enregistre');
        }
      } catch (e) {
        debugPrint('Erreur token FCM: $e');
      }
    }
 
    if (event == AuthChangeEvent.signedOut) {
      debugPrint('Deconnexion');
      await NotificationIdManager().clear();
      debugPrint('Registre notifications vide');
    }
  });
 
  // 10. Token FCM refresh
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    debugPrint('Token FCM renouvele');
    try {
      await NotificationService().saveFcmToken(newToken);
    } catch (e) {
      debugPrint('Erreur refresh token FCM: $e');
    }
  });
 
  // 11. Messages foreground (app ouverte)
  // FCM n'affiche pas la notification automatiquement en foreground
  // on l'affiche manuellement via NotificationService
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    debugPrint('Message foreground: ${message.notification?.title}');
    final type = message.data['type'] ?? 'general';
    final urgente = type.contains('alerte') ||
                    type.contains('cycle')  ||
                    type.contains('consultation');
    await NotificationService().afficherNotificationImmediateLocal(
      titre  : message.notification?.title ?? 'Jur-Gui',
      corps  : message.notification?.body  ?? '',
      type   : type,
      urgente: urgente,
    );
  });
 
  // 12. Clic sur notification (app en arriere-plan)
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('Notification cliquee: ${message.data}');
    _naviguerDepuisNotification(message.data);
  });
 
  // 13. App lancee depuis notification (app etait fermee)
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    debugPrint('App ouverte depuis notification: ${initialMessage.data}');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _naviguerDepuisNotification(initialMessage.data);
    });
  }
 
  runApp(const MyApp());
}
 
// Navigation centralisee depuis notification
void _naviguerDepuisNotification(Map<String, dynamic> data) {
  final type = data['type'] ?? '';
 
  if (type.contains('chaleur')   ||
      type.contains('fenetre')   ||
      type.contains('preparation_accouplement') ||
      type.contains('derniere_chance')          ||
      type.contains('j15_sans_gestation')) {
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
 
  } else if (type.contains('cycle')  ||
             type.contains('alerte') ||
             type.contains('consultation')) {
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
      navigatorKey: NotificationService().navigatorKey,
      color       : Colors.white,
      title       : 'Jur-Gui',
      home        : const Acceuil(),
      debugShowCheckedModeBanner: false,
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
 
        // CORRECTION BUG 2 : vraie page sante (plus de TODO)
        '/sante': (context) => const AlertesPage(),
      },
    );
  }
}