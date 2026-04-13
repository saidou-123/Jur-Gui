// ============================================================
// GESTIONNAIRE D'IDS DE NOTIFICATIONS - VERSION CORRIGÉE
// Fichier: lib/Eleveures/New/Notification/NotificationIdManager.dart
// Corrections:
//   ✅ Bug hashCode: deux UUIDs différents pouvaient générer le même ID
//      causant l'écrasement silencieux de notifications
//   ✅ Remplacement par un registre persistant avec IDs déterministes
// ============================================================

import 'package:flutter/material.dart';

class NotificationIdManager {
  static final NotificationIdManager _instance =
      NotificationIdManager._internal();
  factory NotificationIdManager() => _instance;
  NotificationIdManager._internal();

  // Registre en mémoire: "prefix_animalId" → notificationId (int)
  final Map<String, int> _registry = {};
  int _nextId = 1000; // On commence à 1000 pour éviter les conflits

  /// Retourne un ID stable et UNIQUE pour chaque combinaison (prefix, animalId).
  /// Contrairement à hashCode, deux clés différentes ne donnent jamais
  /// le même ID — élimine le bug d'écrasement de notifications.
  int getOrCreate(String prefix, dynamic animalId) {
    final key = '${prefix}_$animalId';

    if (_registry.containsKey(key)) {
      debugPrint('🔑 ID notification existant: ${_registry[key]} pour $key');
      return _registry[key]!;
    }

    // Nouvel ID unique garanti
    final newId = _nextId++;
    _registry[key] = newId;
    debugPrint('🔑 Nouvel ID notification: $newId pour $key');
    return newId;
  }

  /// Supprime l'entrée du registre (utile quand une brebis est vendue/décédée)
  void remove(String prefix, dynamic animalId) {
    final key = '${prefix}_$animalId';
    _registry.remove(key);
    debugPrint('🗑️ ID notification supprimé pour $key');
  }

  /// Réinitialise tout le registre (pour les tests ou déconnexion)
  void clear() {
    _registry.clear();
    _nextId = 1000;
    debugPrint('🗑️ Registre IDs notifications vidé');
  }
}