// ============================================================
// SERVICE CONSANGUINITÉ — v5 (Wright seul décisionnel)
// Fichier: lib/Eleveures/New/Accouplemt/ConsanguiniteService.dart
// ============================================================

import 'dart:convert';
import 'package:depart/Eleveures/New/Accouplemt/ResultatConsanguinite.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ConsanguiniteService {
  // URL de l'API déployée sur Render
  static const String _baseUrl = 'https://api-consanguinite.onrender.com';

  // ----------------------------------------------------------
  // MÉTHODE PRINCIPALE
  // ----------------------------------------------------------
  Future<ResultatConsanguinite> analyserCouple({
    required Map<String, dynamic> brebis,
    required Map<String, dynamic> belier,
  }) async {
    try {
      // 1. Vérifier disponibilité du serveur
      final actif = await _verifierServeur();
      if (!actif) {
        return ResultatConsanguinite.erreur(
          'Serveur IA non disponible.\n'
          'Vérifiez votre connexion Internet.',
        );
      }

      // 2. Construire la requête
      final corps = {
        'brebis_id'    : brebis['id'],
        'source_brebis': brebis['source'] ?? 'achete',
        'belier_id'    : belier['id'],
        'source_belier': belier['source'] ?? 'achete',
      };

      debugPrint('🧬 Wright: ${brebis['nom']} × ${belier['nom']}');

      // 3. Appel HTTP POST
      final reponse = await http
          .post(
            Uri.parse('$_baseUrl/analyser-pedigree'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(corps),
          )
          .timeout(const Duration(seconds: 45));

      if (reponse.statusCode == 200) {
        final json = jsonDecode(reponse.body) as Map<String, dynamic>;
        final r = ResultatConsanguinite.fromJson(json);
        debugPrint('✅ F=${r.fFormate} | ${r.relation} | ${r.resultat} | ${r.methode}');
        return r;
      }

      debugPrint('❌ HTTP ${reponse.statusCode}: ${reponse.body}');
      return ResultatConsanguinite.erreur(
          'Erreur serveur: ${reponse.statusCode}');

    } on Exception catch (e) {
      debugPrint('❌ ConsanguiniteService: $e');
      return ResultatConsanguinite.erreur(
        'Impossible de contacter le serveur.\n'
        'Vérifiez votre connexion Wi-Fi.',
      );
    }
  }

  // ----------------------------------------------------------
  // HEALTHCHECK
  // ----------------------------------------------------------
  Future<bool> _verifierServeur() async {
    try {
      final r = await http
          .get(Uri.parse('$_baseUrl/sante'))
          .timeout(const Duration(seconds: 15));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}