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