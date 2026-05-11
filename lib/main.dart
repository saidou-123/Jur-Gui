import 'package:depart/Eleveures/New/Accouplemt/Accouplement..dart';
import 'package:depart/Eleveures/New/Notification/NotificationService.dart';
import 'package:depart/Eleveures/New/chaleur/ChaleurModule.dart';
import 'package:depart/pages/Bienvenue/acceuil.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ 1. INITIALISATION TIMEZONES EN PREMIER
  // CRITIQUE: Doit être appelé AVANT toute opération de notification
  tz.initializeTimeZones();
  debugPrint("✅ Timezones initialisées");
  
  // ✅ 2. INITIALISATION SUPABASE
  await Supabase.initialize(
    url: "https://oyudfyxlyxggforfxdin.supabase.co",
    anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95dWRmeXhseXhnZ2ZvcmZ4ZGluIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE3NDg1NzAsImV4cCI6MjA3NzMyNDU3MH0.ccVliXQ82DOBGowLMOuzUClekXb9zXUZSUfPGwGPQoA"
  );
  debugPrint("✅ Supabase initialisé");
  
  // ✅ 3. INITIALISATION SERVICE NOTIFICATIONS
  try {
    await NotificationService().initialize();
    debugPrint("✅ NotificationService initialisé avec succès");
  } catch (e, stackTrace) {
    debugPrint("❌ Erreur initialisation NotificationService: $e");
    debugPrint("Stack: $stackTrace");
    // L'app continue même si les notifications échouent
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget { 
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // ✅ CORRECTION CRITIQUE: NavigatorKey pour navigation depuis notifications
      // Sans ceci, taper sur une notification ne fait rien
      navigatorKey: NotificationService().navigatorKey,
      
      color: Colors.white,
      title: "Jur-Gui",
      home: const Acceuil(),
      debugShowCheckedModeBanner: false,
      
      // ✅ ROUTES POUR NAVIGATION DEPUIS NOTIFICATIONS
      routes: {
        // Navigation depuis notification de chaleur
        '/chaleur': (context) => const ChaleurModule(),
         
        // Navigation depuis notification d'agnelage
        '/accouplements': (context) {
          // Récupérer les arguments passés par la notification
          final args = ModalRoute.of(context)?.settings.arguments 
              as Map<String, dynamic>?;
          
          // Si des arguments sont fournis avec l'ID de la brebis
          if (args != null && args.containsKey('brebis_id')) {
            debugPrint("📲 Navigation vers accouplements avec brebis_id: ${args['brebis_id']}");
            // TODO OPTIONNEL: Charger les données de la brebis et les passer en argument
            // Pour l'instant, ouvre la page sans pré-sélection
          }
          return  EnregistrerAccouplement();
        },
      },
    );
  }
}