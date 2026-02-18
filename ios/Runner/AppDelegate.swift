// ============================================================
// ios/Runner/AppDelegate.swift
// REMPLACEZ ENTIÈREMENT votre fichier actuel par celui-ci
// ============================================================

import Flutter
import UIKit

// ✅ AJOUT CRITIQUE: Import du plugin de notifications
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // ✅ Enregistrer les plugins Flutter
    GeneratedPluginRegistrant.register(with: self)
    
    // ✅ AJOUT CRITIQUE: Configuration du delegate pour les notifications
    // Sans ceci, les notifications ne s'affichent PAS quand l'app est au premier plan
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
    
    // ✅ AJOUT CRITIQUE: Configuration pour les actions de notification en arrière-plan
    // Sans ceci, les actions de notification ne fonctionnent PAS quand l'app est fermée
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
        GeneratedPluginRegistrant.register(with: registry)
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // ✅ AJOUT: Méthode pour gérer les notifications en avant-plan
  // Cette méthode contrôle comment les notifications s'affichent quand l'app est ouverte
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // Afficher la notification même quand l'app est au premier plan
    // iOS 14+ utilise .banner, iOS 13 et moins utilisent .alert
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }
  
  // ✅ AJOUT: Méthode appelée quand l'utilisateur tape sur une notification
  // Cette méthode est optionnelle mais utile pour le debug
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    // Le plugin flutter_local_notifications gère déjà cette méthode
    // Mais on peut ajouter des logs ici si nécessaire
    print("📲 Notification tapped: \(response.notification.request.identifier)")
    
    // Appeler la méthode parent pour que le plugin gère le reste
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }
}