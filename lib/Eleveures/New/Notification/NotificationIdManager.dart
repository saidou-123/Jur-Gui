// ============================================================
// GESTIONNAIRE D'IDS DE NOTIFICATIONS — v3 (Persistance)
// Fichier: lib/Eleveures/New/Notification/NotificationIdManager.dart
//
// ✅ CORRECTION ÉTAPE 2 : persistance avec SharedPreferences
//
// PROBLÈME ORIGINAL :
//   Le registre (_registry) et le compteur (_nextId) vivaient
//   uniquement en mémoire RAM. À chaque redémarrage de l'app :
//     • _registry = {}        → tous les IDs oubliés
//     • _nextId   = 1000      → les nouveaux IDs recommen cent à 1000
//   Conséquence : les notifications déjà programmées (J-30, J-7, J-1
//   pour l'agnelage) ne pouvaient plus être annulées car l'app ne
//   connaissait plus leur ID. Elles s'accumulaient sans contrôle.
//
// SOLUTION :
//   1. SharedPreferences stocke le registre (JSON) et _nextId sur disque.
//   2. initialize() charge le registre au démarrage — à appeler une
//      seule fois dans main.dart ou dans NotificationService.initialize().
//   3. getOrCreate() et remove() sont désormais async pour écrire sur
//      disque après chaque modification.
//   4. clear() efface aussi SharedPreferences (déconnexion utilisateur).
//
// DÉPENDANCE À AJOUTER dans pubspec.yaml :
//   shared_preferences: ^2.2.3
//
// UTILISATION dans main.dart :
//   await NotificationIdManager().initialize();
//
// UTILISATION dans le code (inchangée côté appelant sauf await) :
//   final id = await _idManager.getOrCreate('agnelage', brebisId);
//   await _idManager.remove('agnelage', brebisId);
// ============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationIdManager {
  // ── Singleton ────────────────────────────────────────────
  static final NotificationIdManager _instance =
      NotificationIdManager._internal();
  factory NotificationIdManager() => _instance;
  NotificationIdManager._internal();

  // ── Clés SharedPreferences ───────────────────────────────
  static const String _keyRegistry = 'notif_id_registry';
  static const String _keyNextId   = 'notif_id_next';

  // ── État interne ─────────────────────────────────────────
  // Registre en mémoire : "prefix__animalId" → notificationId
  // Miroir exact de ce qui est persisté sur disque.
  final Map<String, int> _registry = {};
  int _nextId = 1000;

  // Indique si initialize() a été appelé — évite les appels avant init.
  bool _isInitialized = false;

  // ============================================================
  // INITIALISATION — appeler une seule fois au démarrage
  // ============================================================

  /// Charge le registre depuis SharedPreferences.
  /// À appeler dans main.dart avant runApp() :
  ///   await NotificationIdManager().initialize();
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Restaurer _nextId
      _nextId = prefs.getInt(_keyNextId) ?? 1000;

      // Restaurer le registre depuis JSON
      final registryJson = prefs.getString(_keyRegistry);
      if (registryJson != null) {
        final decoded = jsonDecode(registryJson) as Map<String, dynamic>;
        _registry.addAll(
          decoded.map((key, value) => MapEntry(key, value as int)),
        );
      }

      _isInitialized = true;
      debugPrint(
        '✅ NotificationIdManager chargé: '
        '${_registry.length} entrées, prochain ID: $_nextId',
      );
    } catch (e) {
      // En cas d'erreur lecture, on repart de zéro proprement.
      debugPrint('⚠️ NotificationIdManager — erreur chargement: $e');
      _registry.clear();
      _nextId = 1000;
      _isInitialized = true;
    }
  }

  // ============================================================
  // GETORCREATE — retourne un ID stable et unique
  // ============================================================

  /// Retourne un ID stable et UNIQUE pour (prefix, animalId).
  /// Crée un nouvel ID si la clé n'existe pas encore, et le persiste.
  ///
  /// Convention de clé : "prefix__animalId" avec double underscore
  /// pour éviter toute collision (un ID Supabase ne contient jamais "__").
  Future<int> getOrCreate(String prefix, dynamic animalId) async {
    _assertInitialized();
    final key = '${prefix}__$animalId';

    // ID déjà connu → retourner directement depuis la mémoire (O(1))
    if (_registry.containsKey(key)) {
      debugPrint('🔑 ID existant: ${_registry[key]} pour "$key"');
      return _registry[key]!;
    }

    // Nouvel ID unique garanti
    final newId = _nextId++;
    _registry[key] = newId;

    // Persister immédiatement sur disque
    await _sauvegarder();

    debugPrint('🔑 Nouvel ID créé: $newId pour "$key"');
    return newId;
  }

  // ============================================================
  // REMOVE — supprimer une entrée (brebis vendue / décédée)
  // ============================================================

  /// Supprime l'entrée du registre ET de SharedPreferences.
  /// Appeler quand une brebis est vendue ou décédée pour libérer
  /// les IDs de ses notifications programmées.
  Future<void> remove(String prefix, dynamic animalId) async {
    _assertInitialized();
    final key = '${prefix}__$animalId';

    if (!_registry.containsKey(key)) {
      debugPrint('ℹ️ Clé "$key" absente du registre — rien à supprimer');
      return;
    }

    _registry.remove(key);
    await _sauvegarder();
    debugPrint('🗑️ ID notification supprimé pour "$key"');
  }

  // ============================================================
  // REMOVE ALL — supprimer toutes les notifs d'un animal
  // ============================================================

  /// Supprime toutes les entrées liées à un animalId,
  /// quel que soit le prefix (agnelage, chaleur, alerte…).
  /// Utile lors de la suppression complète d'un animal.
  Future<void> removeAllForAnimal(dynamic animalId) async {
    _assertInitialized();
    final suffix = '__$animalId';

    final keysToRemove = _registry.keys
        .where((k) => k.endsWith(suffix))
        .toList();

    if (keysToRemove.isEmpty) return;

    for (final key in keysToRemove) {
      _registry.remove(key);
    }

    await _sauvegarder();
    debugPrint(
      '🗑️ ${keysToRemove.length} IDs supprimés pour animal $animalId',
    );
  }

  // ============================================================
  // CLEAR — réinitialiser tout (déconnexion utilisateur)
  // ============================================================

  /// Vide le registre en mémoire ET sur disque.
  /// À appeler lors de la déconnexion de l'utilisateur pour
  /// repartir de zéro proprement au prochain login.
  Future<void> clear() async {
    _registry.clear();
    _nextId = 1000;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyRegistry);
      await prefs.remove(_keyNextId);
    } catch (e) {
      debugPrint('⚠️ Erreur clear NotificationIdManager: $e');
    }

    debugPrint('🗑️ Registre IDs notifications entièrement vidé');
  }

  // ============================================================
  // UTILITAIRES
  // ============================================================

  /// Nombre d'IDs actuellement en registre (utile pour debug/tests).
  int get count => _registry.length;

  /// Vérifie si un ID existe déjà pour (prefix, animalId).
  bool contains(String prefix, dynamic animalId) {
    _assertInitialized();
    return _registry.containsKey('${prefix}__$animalId');
  }

  // ============================================================
  // PRIVÉ
  // ============================================================

  /// Persiste le registre et _nextId sur disque.
  /// Appelé après chaque modification (getOrCreate, remove).
  Future<void> _sauvegarder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setString(_keyRegistry, jsonEncode(_registry)),
        prefs.setInt(_keyNextId, _nextId),
      ]);
    } catch (e) {
      // La persistance a échoué — l'ID est quand même en mémoire
      // pour cette session, mais sera oublié au redémarrage.
      debugPrint('⚠️ NotificationIdManager — erreur sauvegarde: $e');
    }
  }

  /// Lève une erreur explicite si initialize() n'a pas été appelé.
  void _assertInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'NotificationIdManager non initialisé. '
        'Appelez await NotificationIdManager().initialize() dans main.dart.',
      );
    }
  }
}