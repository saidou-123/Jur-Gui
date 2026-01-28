// ============================================================
// GESTIONNAIRE DE CACHE & PERFORMANCE
// Fichier: lib/utils/cache_manager.dart
// ============================================================

import 'package:flutter/material.dart';

// ===== CLASSE DE DONNÉES CACHÉES =====
class CachedData<T> {
  final T data;
  final DateTime timestamp;
  final Duration ttl; // Time To Live
  
  CachedData({
    required this.data,
    required this.timestamp,
    this.ttl = const Duration(minutes: 5),
  });
  
  bool get isExpired {
    return DateTime.now().difference(timestamp) > ttl;
  }
  
  Duration get age {
    return DateTime.now().difference(timestamp);
  }
}

// ===== GESTIONNAIRE DE CACHE =====
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();
  
  final Map<String, CachedData> _cache = {};
  
  // ===== SAUVEGARDER EN CACHE =====
  void set<T>(
    String key,
    T data, {
    Duration ttl = const Duration(minutes: 5),
  }) {
    _cache[key] = CachedData<T>(
      data: data,
      timestamp: DateTime.now(),
      ttl: ttl,
    );
    
    debugPrint('📦 Cache SET: $key (TTL: ${ttl.inMinutes}min)');
    _cleanExpired(); // Nettoyage automatique
  }
  
  // ===== RÉCUPÉRER DU CACHE =====
  T? get<T>(String key) {
    final cached = _cache[key];
    
    if (cached == null) {
      debugPrint('❌ Cache MISS: $key');
      return null;
    }
    
    if (cached.isExpired) {
      debugPrint('⏰ Cache EXPIRED: $key (age: ${cached.age.inMinutes}min)');
      _cache.remove(key);
      return null;
    }
    
    debugPrint('✅ Cache HIT: $key (age: ${cached.age.inSeconds}s)');
    return cached.data as T;
  }
  
  // ===== RÉCUPÉRER OU CHARGER =====
  Future<T> getOrFetch<T>({
    required String key,
    required Future<T> Function() fetcher,
    Duration ttl = const Duration(minutes: 5),
    bool forceRefresh = false,
  }) async {
    // Vérifier cache si pas de forceRefresh
    if (!forceRefresh) {
      final cached = get<T>(key);
      if (cached != null) {
        return cached;
      }
    }
    
    // Charger depuis la source
    debugPrint('🔄 Fetching: $key');
    final data = await fetcher();
    
    // Sauvegarder en cache
    set(key, data, ttl: ttl);
    
    return data;
  }
  
  // ===== INVALIDER UNE CLÉ =====
  void invalidate(String key) {
    _cache.remove(key);
    debugPrint('🗑️ Cache invalidé: $key');
  }
  
  // ===== INVALIDER PAR PRÉFIXE =====
  void invalidateByPrefix(String prefix) {
    final keysToRemove = _cache.keys
        .where((key) => key.startsWith(prefix))
        .toList();
    
    for (final key in keysToRemove) {
      _cache.remove(key);
    }
    
    debugPrint('🗑️ Cache invalidé (préfixe: $prefix): ${keysToRemove.length} entrées');
  }
  
  // ===== TOUT VIDER =====
  void clear() {
    final count = _cache.length;
    _cache.clear();
    debugPrint('🗑️ Cache entièrement vidé ($count entrées)');
  }
  
  // ===== NETTOYER LES ENTRÉES EXPIRÉES =====
  void _cleanExpired() {
    final expiredKeys = _cache.entries
        .where((entry) => entry.value.isExpired)
        .map((entry) => entry.key)
        .toList();
    
    for (final key in expiredKeys) {
      _cache.remove(key);
    }
    
    if (expiredKeys.isNotEmpty) {
      debugPrint('🧹 Cache nettoyé: ${expiredKeys.length} entrées expirées supprimées');
    }
  }
  
  // ===== STATISTIQUES =====
  Map<String, dynamic> getStats() {
    _cleanExpired();
    
    return {
      'total_entries': _cache.length,
      'total_size_estimate': '${(_cache.length * 100).toStringAsFixed(0)} KB',
      'oldest_entry': _cache.values.isNotEmpty
          ? _cache.values
              .map((e) => e.timestamp)
              .reduce((a, b) => a.isBefore(b) ? a : b)
              .toIso8601String()
          : 'N/A',
      'keys': _cache.keys.toList(),
    };
  }
}

// ===== CLÉS DE CACHE STANDARDISÉES =====
class CacheKeys {
  // Animaux
  static String animals(String userId) => 'animals_$userId';
  static String animalById(String animalId) => 'animal_$animalId';
  static String animalsBySource(String userId, String source) => 
      'animals_${userId}_$source';
  
  // Statistiques
  static String stats(String userId) => 'stats_$userId';
  
  // Historique médical
  static String medicalHistory(String userId) => 'medical_history_$userId';
  
  // Vaccinations
  static String vaccinations(String userId) => 'vaccinations_$userId';
  static String vaccinationReminders(String userId) => 
      'vaccination_reminders_$userId';
  
  // Accouplements
  static String matings(String userId) => 'matings_$userId';
  
  // Chaleurs
  static String heats(String userId) => 'heats_$userId';
  
  // Utilisateur
  static String userProfile(String userId) => 'user_profile_$userId';
}

// ===== EXEMPLE D'UTILISATION =====
/*
// Dans un StatefulWidget:

final cache = CacheManager();

Future<void> _loadAnimals() async {
  setState(() => _isLoading = true);
  
  try {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    
    // ✅ Utiliser le cache
    final animals = await cache.getOrFetch<List<Map<String, dynamic>>>(
      key: CacheKeys.animals(userId),
      fetcher: () async {
        return await Supabase.instance.client
            .from('animal_acheter')
            .select()
            .eq('user_id', userId);
      },
      ttl: const Duration(minutes: 3),
    );
    
    setState(() {
      _animals = animals;
      _isLoading = false;
    });
  } catch (e) {
    // Gérer erreur
  }
}

// Forcer le rafraîchissement:
await cache.getOrFetch(
  key: CacheKeys.animals(userId),
  fetcher: _fetchAnimals,
  forceRefresh: true, // ✅ Ignore le cache
);

// Invalider après modification:
await _saveAnimal(animal);
cache.invalidate(CacheKeys.animals(userId));

// Invalider tout ce qui concerne les animaux:
cache.invalidateByPrefix('animals_');

// Voir les stats:
print(cache.getStats());
*/