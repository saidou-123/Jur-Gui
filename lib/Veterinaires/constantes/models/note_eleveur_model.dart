import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service de collaboration vétérinaire ↔ éleveur
class NoteService {
  final _db = Supabase.instance.client;

  /// Envoie une note/recommandation à l'éleveur propriétaire de l'animal
  Future<void> envoyerNote({
    required String animalId,
    required String source,
    required String eleveurId,
    required String titre,
    required String message,
    String type = 'recommandation', // recommandation | alerte | information | urgence
  }) async {
    final vet = _db.auth.currentUser;
    if (vet == null) throw Exception('Non connecté');

    await _db.from('notes_eleveur').insert({
      'animal_id': animalId,
      'source': source,
      'veterinaire_id': vet.id,
      'eleveur_id': eleveurId,
      'titre': titre,
      'message': message,
      'type': type,
    });
  }

  /// Notes envoyées par ce vétérinaire
  Future<List<Map<String, dynamic>>> mesNotes() async {
    final vet = _db.auth.currentUser;
    if (vet == null) return [];
    return _db
        .from('notes_eleveur')
        .select('*')
        .eq('veterinaire_id', vet.id)
        .order('created_at', ascending: false)
        .then((r) => List<Map<String, dynamic>>.from(r));
  }

  /// Crée une alerte sanitaire sur un animal
  Future<void> creerAlerte({
    required String animalId,
    required String source,
    required String typeAlerte, // vaccin_expire | rappel_vaccin | suivi_requis | maladie_suspectee
    required String message,
    String priorite = 'normale',
    DateTime? dateEcheance,
  }) async {
    final vet = _db.auth.currentUser;
    if (vet == null) throw Exception('Non connecté');

    await _db.from('alertes_sante').insert({
      'animal_id': animalId,
      'source': source,
      'veterinaire_id': vet.id,
      'type_alerte': typeAlerte,
      'message': message,
      'priorite': priorite,
      if (dateEcheance != null) 'date_echeance': dateEcheance.toIso8601String().substring(0, 10),
    });
  }

  /// Alertes actives du vétérinaire
  Future<List<Map<String, dynamic>>> alertesActives() async {
    final vet = _db.auth.currentUser;
    if (vet == null) return [];
    return _db
        .from('alertes_sante')
        .select('*')
        .eq('veterinaire_id', vet.id)
        .eq('resolue', false)
        .order('created_at', ascending: false)
        .then((r) => List<Map<String, dynamic>>.from(r));
  }

  /// Résoudre une alerte
  Future<void> resoudreAlerte(String alerteId) async {
    await _db.from('alertes_sante').update({'resolue': true}).eq('id', alerteId);
  }
}


enum TypeNote { recommandation, alerte, information, urgence }

class NoteEleveurModel {
  final String id;
  final String animalId;
  final String source;
  final String veterinaireId;
  final String eleveurId;
  final String titre;
  final String message;
  final TypeNote type;
  final bool lu;
  final DateTime createdAt;

  const NoteEleveurModel({
    required this.id,
    required this.animalId,
    required this.source,
    required this.veterinaireId,
    required this.eleveurId,
    required this.titre,
    required this.message,
    required this.type,
    required this.lu,
    required this.createdAt,
  });

  factory NoteEleveurModel.fromMap(Map<String, dynamic> m) => NoteEleveurModel(
    id: m['id'] ?? '',
    animalId: m['animal_id'] ?? '',
    source: m['source'] ?? '',
    veterinaireId: m['veterinaire_id'] ?? '',
    eleveurId: m['eleveur_id'] ?? '',
    titre: m['titre'] ?? '',
    message: m['message'] ?? '',
    type: TypeNote.values.firstWhere(
      (t) => t.name == (m['type'] ?? 'information'),
      orElse: () => TypeNote.information,
    ),
    lu: m['lu'] == true,
    createdAt: DateTime.tryParse(m['created_at']?.toString() ?? '') ?? DateTime.now(),
  );

  Color get couleur => switch (type) {
    TypeNote.recommandation => Colors.green,
    TypeNote.alerte         => Colors.orange,
    TypeNote.information    => Colors.blue,
    TypeNote.urgence        => Colors.red,
  };

  IconData get icone => switch (type) {
    TypeNote.recommandation => Icons.tips_and_updates,
    TypeNote.alerte         => Icons.warning_amber,
    TypeNote.information    => Icons.info,
    TypeNote.urgence        => Icons.emergency,
  };

  String get typeLabel => switch (type) {
    TypeNote.recommandation => 'Recommandation',
    TypeNote.alerte         => 'Alerte',
    TypeNote.information    => 'Information',
    TypeNote.urgence        => 'URGENCE',
  };

  String get dateFormatee {
    final d = createdAt;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}