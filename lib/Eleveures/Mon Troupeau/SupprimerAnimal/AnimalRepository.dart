// ============================================================
// 🗄️ REPOSITORY — Couche données, toutes les requêtes Supabase
// ============================================================

import 'package:depart/Eleveures/Mon%20Troupeau/SupprimerAnimal/Animalmodel.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class AnimalRepository {
  final _client = Supabase.instance.client;

  String? get _currentUserId => _client.auth.currentUser?.id;

  // ----------------------------------------------------------
  // 📥 CHARGER LES ANIMAUX ACTIFS
  // ----------------------------------------------------------
  Future<List<AnimalModel>> fetchAnimauxActifs({String filtre = 'Tout'}) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception("Utilisateur non connecté");

    final List<AnimalModel> result = [];

    if (filtre == 'Tout' || filtre == 'Nouveau_nee') {
      final rows = await _client
          .from('nouveaux_nee')
          .select('*')
          .eq('user_id', userId)
          .or('statut.eq.actif,statut.is.null') // compatibilité si pas encore migré
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);

      result.addAll(rows.map((r) => AnimalModel.fromMap(r, 'nouveaux_nee')));
    }

    if (filtre == 'Tout' || filtre == 'Animal_acheter') {
      final rows = await _client
          .from('animal_acheter')
          .select('*')
          .eq('user_id', userId)
          .or('statut.eq.actif,statut.is.null')
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);

      result.addAll(rows.map((r) => AnimalModel.fromMap(r, 'animal_acheter')));
    }

    return result;
  }

  // ----------------------------------------------------------
  // 🔇 SOFT DELETE — Marquer l'animal sans le supprimer
  // ----------------------------------------------------------
  Future<void> softDeleteAnimal({
    required AnimalModel animal,
    required AnimalStatut statut,
    String? transfertVersUserId,
  }) async {
    final updateData = {
      'statut': statut.dbValue,
      'motif_suppression': statut.label,
      'deleted_at': DateTime.now().toIso8601String(),
      if (transfertVersUserId != null)
        'transfert_vers_user_id': transfertVersUserId,
    };

    await _client
        .from(animal.tableSource)
        .update(updateData)
        .eq('id', animal.id);

    // Insérer dans l'historique
    await _insertHistorique(animal: animal, statut: statut);

    debugPrint("✅ Soft delete effectué: ${animal.nom} → ${statut.label}");
  }

  // ----------------------------------------------------------
  // 📜 HISTORIQUE
  // ----------------------------------------------------------
  Future<void> _insertHistorique({
    required AnimalModel animal,
    required AnimalStatut statut,
  }) async {
    try {
      await _client.from('animal_historique').insert({
        'animal_id': animal.id,
        'animal_nom': animal.nom,
        'animal_race': animal.race,
        'table_source': animal.tableSource,
        'owner_id': animal.userId,
        'action': 'suppression',
        'motif': statut.label,
        'statut': statut.dbValue,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // L'historique est optionnel, ne pas bloquer la suppression
      debugPrint("⚠️ Erreur historique (non bloquant): $e");
    }
  }

  // ----------------------------------------------------------
  // 📊 STATISTIQUES TABLEAU DE BORD
  // ----------------------------------------------------------
  Future<Map<String, int>> fetchStatistiques() async {
    final userId = _currentUserId;
    if (userId == null) return {};

    final stats = <String, int>{
      'actif': 0,
      'mort': 0,
      'vendu': 0,
      'tue': 0,
    };

    for (final table in ['nouveaux_nee', 'animal_acheter']) {
      for (final statut in ['actif', 'mort', 'vendu', 'tue']) {
        try {
          final response = await _client
              .from(table)
              .select('id')
              .eq('user_id', userId)
              .eq('statut', statut);
          stats[statut] = (stats[statut] ?? 0) + (response as List).length;
        } catch (_) {}
      }
    }

    return stats;
  }

  // ----------------------------------------------------------
  // 🔍 CHERCHER UN ÉLEVEUR PAR EMAIL (pour le transfert)
  // Utilise la table 'users' avec les colonnes réelles :
  //   id, email, nom, prenom, nom_complet, role
  // ----------------------------------------------------------
  Future<Map<String, dynamic>?> findEleveurByEmail(String email) async {
    final currentUserId = _currentUserId;
    final emailNormalise = email.trim().toLowerCase();

    try {
      // ilike = insensible à la casse côté Supabase
      // Pas de filtre dur sur 'role' (évite bugs casse/accent)
      // On exclut l'utilisateur connecté lui-même
      final results = await _client
          .from('users')
          .select('id, email, nom, prenom, nom_complet, role')
          .ilike('email', emailNormalise)
          .neq('id', currentUserId ?? '');

      if ((results as List).isEmpty) return null;

      final user = Map<String, dynamic>.from(results.first);

      // Vérification côté client : accepte 'Eleveur', 'eleveur', 'Éleveur'
      final role = (user['role'] ?? '').toString().toLowerCase();
      if (!role.contains('leveur')) {
        debugPrint("⚠️ Rôle non éleveur : \$role");
        return null;
      }

      return user;
    } catch (e) {
      debugPrint("❌ Erreur recherche éleveur: \$e");
      return null;
    }
  }
}