import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// MODÈLE — résultat de génération d'un partage
// ============================================================
class PartageResult {
  final String token;
  final String lien;
  final int dureeHeures;
  final DateTime expireAt;

  const PartageResult({
    required this.token,
    required this.lien,
    required this.dureeHeures,
    required this.expireAt,
  });
}

// ============================================================
// SERVICE DE PARTAGE ANIMAL
// Compatible avec les tables : nouveaux_nee et animal_acheter
// ============================================================
class PartageAnimalService {
  final _supabase = Supabase.instance.client;

  // Deep link de l'app — préfixe du lien partagé
  static const String _baseUrl = 'jurgui://partage?token=';

  // ── Génère un token aléatoire sécurisé (256 bits) ────────
  String _genererToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  // ── Hash SHA-256 du token pour stockage sécurisé ─────────
  String hashToken(String token) {
    final bytes = utf8.encode(token);
    return sha256.convert(bytes).toString();
  }

  // ── Génère un lien de partage pour un animal ─────────────
  Future<PartageResult> genererLien({
    required String animalId,
    required String tableSource,
    int dureeHeures = 48,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Non connecté');

    // Charger les données de l'animal selon la bonne table
    Map<String, dynamic> animal;
    if (tableSource == 'nouveaux_nee') {
      animal = await _supabase
          .from('nouveaux_nee')
          .select(
            'id, nom, race, sexe, date_naissance, tag_rfid, image_url, '
            'couleur, gabarit, type_cornes, taille_categorie, est_fondateur',
          )
          .eq('id', animalId)
          .eq('user_id', user.id)
          .single();
    } else {
      animal = await _supabase
          .from('animal_acheter')
          .select(
            'id, nom, race, sexe, tag_rfid, image_url, '
            'couleur, gabarit, type_cornes, taille_categorie, est_fondateur',
          )
          .eq('id', animalId)
          .eq('user_id', user.id)
          .single();
    }

    // Générer token + hash
    final token    = _genererToken();
    final hash     = hashToken(token);
    final expireAt = DateTime.now().add(Duration(hours: dureeHeures));

    // Insérer en base avec snapshot des données actuelles
    await _supabase.from('partages_animaux').insert({
      'animal_id'               : animalId,
      'table_source'            : tableSource,
      'owner_id'                : user.id,
      'token_hash'              : hash,
      'expire_at'               : expireAt.toIso8601String(),
      'duree_heures'            : dureeHeures,
      'snapshot_nom'            : animal['nom'],
      'snapshot_race'           : animal['race'],
      'snapshot_sexe'           : animal['sexe'],
      'snapshot_date_naissance' : animal['date_naissance'],
      'snapshot_tag_rfid'       : animal['tag_rfid'],
      'snapshot_image_url'      : animal['image_url'],
      'snapshot_couleur'        : animal['couleur'],
      'snapshot_gabarit'        : animal['gabarit'],
      'snapshot_type_cornes'    : animal['type_cornes'],
      'snapshot_taille_categorie': animal['taille_categorie'],
      'snapshot_est_fondateur'  : animal['est_fondateur'] ?? false,
    });

    return PartageResult(
      token       : token,
      lien        : '$_baseUrl$token',
      dureeHeures : dureeHeures,
      expireAt    : expireAt,
    );
  }

  // ── Charge un profil depuis un token brut ────────────────
  Future<Map<String, dynamic>> chargerProfilPartage(String token) async {
    final hash = hashToken(token);

    final partage = await _supabase
        .from('partages_animaux')
        .select('*')
        .eq('token_hash', hash)
        .eq('revoque', false)
        .gt('expire_at', DateTime.now().toIso8601String())
        .maybeSingle();

    if (partage == null) throw Exception('Lien invalide ou expiré');

    // Incrémenter le compteur de vues
    await _supabase
        .from('partages_animaux')
        .update({'nb_vues': (partage['nb_vues'] as int) + 1})
        .eq('token_hash', hash);

    return partage;
  }

  // ── Révoque un partage à partir du token brut ────────────
  // Accepte le token brut — le hash est calculé en interne
  Future<void> revoquer(String token) async {
    final hash = hashToken(token);
    await _supabase.from('partages_animaux').update({
      'revoque'   : true,
      'revoque_at': DateTime.now().toIso8601String(),
    }).eq('token_hash', hash);
  }

  // ── Liste les partages actifs de l'éleveur connecté ──────
  Future<List<Map<String, dynamic>>> mesPartagesActifs() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    return await _supabase
        .from('partages_animaux')
        .select('*')
        .eq('owner_id', user.id)
        .eq('revoque', false)
        .gt('expire_at', DateTime.now().toIso8601String())
        .order('created_at', ascending: false);
  }
}