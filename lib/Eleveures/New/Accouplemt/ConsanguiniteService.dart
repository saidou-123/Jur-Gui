// ============================================================
// SERVICE IA CONSANGUINITÉ — v2 (Pedigree Automatique)
// Fichier: lib/Eleveures/New/Accouplemt/ConsanguiniteService.dart
// ============================================================

import 'dart:convert';
import 'package:depart/Eleveures/New/Accouplemt/ResultatConsanguinite.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ConsanguiniteService {
 static const String _baseUrl = 'https://web-production-9298.up.railway.app';
  final supabase = Supabase.instance.client;

  Future<ResultatConsanguinite> analyserCouple({
    required Map<String, dynamic> brebis,
    required Map<String, dynamic> belier,
  }) async {
    try {
      final actif = await _verifierServeur();
      if (!actif) {
        return ResultatConsanguinite.erreur(
          'Serveur IA non disponible.\n.',
        );
      }
      final corps = {
        'brebis_id'    : brebis['id'],
        'source_brebis': brebis['source'] ?? 'achete',
        'belier_id'    : belier['id'],
        'source_belier': belier['source'] ?? 'achete',
      };
      debugPrint('🤖 Analyse: ${brebis['nom']} × ${belier['nom']}');
      final reponse = await http
          .post(
            Uri.parse('$_baseUrl/analyser-pedigree'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(corps),
          )
          .timeout(const Duration(seconds: 15));
      if (reponse.statusCode == 200) {
        final json = jsonDecode(reponse.body) as Map<String, dynamic>;
        final r = ResultatConsanguinite.fromJson(json);
        debugPrint('✅ F=${r.fPourcent}% | ${r.relation} | ${r.resultat}');
        return r;
      }
      return ResultatConsanguinite.erreur('Erreur serveur: ${reponse.statusCode}');
    } on Exception catch (e) {
      debugPrint('❌ $e');
      return ResultatConsanguinite.erreur(
        'Impossible de contacter le serveur IA.\nVérifiez votre connexion Wi-Fi.',
      );
    }
  }

  Future<bool> _verifierServeur() async {
    try {
      final r = await http
          .get(Uri.parse('$_baseUrl/sante'))
          .timeout(const Duration(seconds: 5));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}