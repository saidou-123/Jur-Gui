// ============================================================
// SERVICE PARTAGE QR CODE — Profils génétiques entre coopératives
// Fichier: lib/Eleveures/New/PartageQR/PartageQRService.dart
//
// Responsabilités :
//   • Générer un token de partage sécurisé pour un bélier
//   • Valider un token scanné (expiry, révocation, disponibilité)
//   • Révoquer un partage
//   • Enregistrer tous les scans/accouplements dans Supabase
// ============================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Modèle résultat de validation ────────────────────────────
class ValidationQR {
  final bool valide;
  final String? motifEchec;      // raison si invalide
  final Map<String, dynamic>? belier;
  final Map<String, dynamic>? partage;

  const ValidationQR({
    required this.valide,
    this.motifEchec,
    this.belier,
    this.partage,
  });

  factory ValidationQR.echec(String motif) =>
      ValidationQR(valide: false, motifEchec: motif);
}

class PartageQRService {
  final _supabase = Supabase.instance.client;

  // ──────────────────────────────────────────────────────────
  // 1. GÉNÉRER UN PARTAGE QR
  //    Crée une entrée dans partages_qr et retourne le token
  // ──────────────────────────────────────────────────────────
  Future<String?> genererPartage({
    required int belierId,
    required String sourceBelier,
    int validiteJours = 30,
    int nbScansMax   = 10,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Non connecté');

      // Vérifier que le bélier appartient à cet éleveur et est disponible
      final disponible = await _verifierBelierdisponible(belierId, sourceBelier, userId);
      if (!disponible) {
        debugPrint('❌ Bélier non disponible pour le partage');
        return null;
      }

      // Supprimer l'ancien partage actif si existant (un seul à la fois)
      await _supabase
          .from('partages_qr')
          .update({'revoque': true})
          .eq('belier_id', belierId)
          .eq('source_belier', sourceBelier)
          .eq('proprietaire_id', userId)
          .eq('revoque', false);

      // Créer le nouveau partage
      final expireAt = DateTime.now().add(Duration(days: validiteJours));
      final result = await _supabase
          .from('partages_qr')
          .insert({
            'belier_id'      : belierId,
            'source_belier'  : sourceBelier,
            'proprietaire_id': userId,
            'nb_scans_max'   : nbScansMax,
            'expire_at'      : expireAt.toIso8601String(),
          })
          .select('token')
          .single();

      final token = result['token'] as String;
      debugPrint('✅ Partage QR généré: $token (expire: $expireAt)');
      return token;
    } catch (e) {
      debugPrint('❌ genererPartage: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────
  // 2. VALIDER UN TOKEN SCANNÉ
  //    Retourne le profil du bélier si tout est valide
  // ──────────────────────────────────────────────────────────
  Future<ValidationQR> validerToken(String token) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return ValidationQR.echec('Vous devez être connecté.');

      // Récupérer le partage
      final partage = await _supabase
          .from('partages_qr')
          .select('*')
          .eq('token', token)
          .maybeSingle();

      if (partage == null) {
        await _logScan(null, userId, 'scan_refuse', 'Token introuvable');
        return ValidationQR.echec('QR Code invalide ou inexistant.');
      }

      // ── Vérification 1 : expiry ──────────────────────────
      final expireAt = DateTime.parse(partage['expire_at'] as String);
      if (DateTime.now().isAfter(expireAt)) {
        await _logScan(partage['id'], userId, 'scan_refuse', 'QR Code expiré');
        return ValidationQR.echec(
          'Ce QR Code a expiré le ${_formaterDate(expireAt)}.\n'
          'Demandez un nouveau code au propriétaire.',
        );
      }

      // ── Vérification 2 : révocation ──────────────────────
      if (partage['revoque'] == true) {
        await _logScan(partage['id'], userId, 'scan_refuse', 'Partage révoqué');
        return ValidationQR.echec(
          'Ce partage a été révoqué par le propriétaire.',
        );
      }

      // ── Vérification 3 : quota accouplements ─────────────
      final nbScans    = partage['nb_scans'] as int;
      final nbScansMax = partage['nb_scans_max'] as int;
      if (nbScans >= nbScansMax) {
        await _logScan(partage['id'], userId, 'scan_refuse',
            'Quota atteint ($nbScans/$nbScansMax)');
        return ValidationQR.echec(
          'Le nombre maximal d\'accouplements autorisés ($nbScansMax) a été atteint.\n'
          'Ce reproducteur n\'est plus disponible via ce partage.',
        );
      }

      // ── Vérification 4 : disponibilité actuelle du bélier ─
      final belierId    = partage['belier_id'] as int;
      final sourceBelierStr = partage['source_belier'] as String;
      final proprietaireId  = partage['proprietaire_id'] as String;

      final disponible = await _verifierBelierdisponible(
          belierId, sourceBelierStr, proprietaireId);
      if (!disponible) {
        await _logScan(partage['id'], userId, 'scan_refuse', 'Bélier indisponible');
        return ValidationQR.echec(
          'Ce reproducteur est temporairement indisponible.\n'
          'Il a peut-être atteint sa limite de saillies ou n\'est plus actif.',
        );
      }

      // ── Charger le profil complet du bélier ──────────────
      final belier = await _chargerProfilBelier(belierId, sourceBelierStr);
      if (belier == null) {
        return ValidationQR.echec('Profil du bélier introuvable.');
      }

      // Enrichir avec les infos du propriétaire
      belier['_partage_id']          = partage['id'];
      belier['_partage_expire_at']   = partage['expire_at'];
      belier['_partage_nb_restants'] = nbScansMax - nbScans;
      belier['source']               = sourceBelierStr;

      // Logger le scan valide
      await _logScan(partage['id'], userId, 'scan_valide', null);

      debugPrint('✅ QR valide: bélier ${belier['nom']} — ${nbScansMax - nbScans} acc. restants');
      return ValidationQR(valide: true, belier: belier, partage: partage);
    } catch (e) {
      debugPrint('❌ validerToken: $e');
      return ValidationQR.echec('Erreur lors de la vérification du QR Code.');
    }
  }

  // ──────────────────────────────────────────────────────────
  // 3. INCRÉMENTER LE COMPTEUR après accouplement confirmé
  // ──────────────────────────────────────────────────────────
  Future<void> enregistrerAccouplement({
    required String partageId,
    required String scannerId,
    required Map<String, dynamic>? resultatIa,
  }) async {
    try {
      // Incrémenter nb_scans
      await _supabase.rpc('incrementer_scan_qr', params: {'p_partage_id': partageId});

      // Log traçabilité
      await _logScan(
        partageId,
        scannerId,
        'accouplement_lance',
        null,
        resultatIa: resultatIa,
      );
      debugPrint('✅ Accouplement via QR enregistré (partage: $partageId)');
    } catch (e) {
      // Fallback manuel si RPC non disponible
      debugPrint('⚠️ RPC incrementer_scan_qr indisponible, fallback: $e');
      try {
        final current = await _supabase
            .from('partages_qr')
            .select('nb_scans')
            .eq('id', partageId)
            .single();
        final newCount = (current['nb_scans'] as int) + 1;
        await _supabase
            .from('partages_qr')
            .update({'nb_scans': newCount})
            .eq('id', partageId);
        await _logScan(partageId, scannerId, 'accouplement_lance', null,
            resultatIa: resultatIa);
      } catch (e2) {
        debugPrint('❌ Fallback increment: $e2');
      }
    }
  }

  // ──────────────────────────────────────────────────────────
  // 4. RÉVOQUER UN PARTAGE
  // ──────────────────────────────────────────────────────────
  Future<bool> revoquerPartage(String partageId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      await _supabase
          .from('partages_qr')
          .update({'revoque': true})
          .eq('id', partageId)
          .eq('proprietaire_id', userId);

      debugPrint('🚫 Partage révoqué: $partageId');
      return true;
    } catch (e) {
      debugPrint('❌ revoquerPartage: $e');
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────
  // 5. LISTE DES PARTAGES ACTIFS pour un éleveur
  // ──────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> listerPartagesActifs() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final partages = await _supabase
          .from('partages_qr')
          .select('*')
          .eq('proprietaire_id', userId)
          .eq('revoque', false)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(partages);
    } catch (e) {
      debugPrint('❌ listerPartagesActifs: $e');
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────
  // HELPERS PRIVÉS
  // ──────────────────────────────────────────────────────────

  Future<bool> _verifierBelierdisponible(
      int belierId, String source, String userId) async {
    try {
      final table = source == 'nee' ? 'nouveaux_nee' : 'animal_acheter';
      final result = await _supabase
          .from(table)
          .select('id, sexe')
          .eq('id', belierId)
          .eq('user_id', userId)
          .eq('sexe', 'Mâle')
          .maybeSingle();
      return result != null;
    } catch (e) {
      debugPrint('⚠️ _verifierBelierdisponible: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> _chargerProfilBelier(
      int belierId, String source) async {
    try {
      final table = source == 'nee' ? 'nouveaux_nee' : 'animal_acheter';
      final result = await _supabase
          .from(table)
          .select('id, nom, race, sexe, tag_rfid, image_url, created_at')
          .eq('id', belierId)
          .maybeSingle();
      return result != null ? Map<String, dynamic>.from(result) : null;
    } catch (e) {
      debugPrint('❌ _chargerProfilBelier: $e');
      return null;
    }
  }

  Future<void> _logScan(
    String? partageId,
    String scannerId,
    String action,
    String? motifRefus, {
    Map<String, dynamic>? resultatIa,
  }) async {
    try {
      if (partageId == null) return;
      await _supabase.from('scans_qr').insert({
        'partage_id' : partageId,
        'scanner_id' : scannerId,
        'action'     : action,
        'motif_refus': motifRefus,
        'resultat_ia': resultatIa != null ? jsonEncode(resultatIa) : null,
      });
    } catch (e) {
      debugPrint('⚠️ _logScan: $e');
    }
  }

  String _formaterDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';
}
