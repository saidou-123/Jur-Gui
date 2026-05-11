import 'package:depart/Veterinaires/constantes/models/consultation_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class ConsultationService {
  final _db = Supabase.instance.client;

  /// Consultations d'un animal précis
  Future<List<ConsultationModel>> charger(String animalId, String source) async {
    final r = await _db
        .from('consultations')
        .select('*')
        .eq('animal_id', animalId)
        .eq('source', source)
        .order('date_consultation', ascending: false);
    return r.map((m) => ConsultationModel.fromMap(m)).toList();
  }

  /// Version raw Map (compatibilité pages existantes)
  Future<List<Map<String, dynamic>>> chargerRaw(String animalId, String source) async {
    final r = await _db
        .from('consultations')
        .select('*')
        .eq('animal_id', animalId)
        .eq('source', source)
        .order('date_consultation', ascending: false);
    return List<Map<String, dynamic>>.from(r);
  }

  /// Historique complet du vétérinaire connecté
  Future<List<Map<String, dynamic>>> chargerHistorique() async {
    final vet = _db.auth.currentUser;
    if (vet == null) return [];
    final r = await _db
        .from('consultations')
        .select('*')
        .eq('veterinaire_id', vet.id)
        .order('date_consultation', ascending: false);
    return List<Map<String, dynamic>>.from(r);
  }

  /// Enregistre une consultation complète
  Future<void> enregistrer({
    required String animalId,
    required String source,
    required DateTime date,
    required String motif,
    required String examen,
    required String diagnostic,
    required String traitement,
    String? observations,
    double? poidsKg,
    double? temperatureC,
    int? frequenceCardiaque,
  }) async {
    final vet = _db.auth.currentUser;
    if (vet == null) throw Exception('Vétérinaire non connecté');

    await _db.from('consultations').insert({
      'animal_id': animalId,
      'source': source,
      'veterinaire_id': vet.id,
      'date_consultation': date.toIso8601String(),
      'motif': motif,
      'examen_clinique': examen,
      'diagnostic': diagnostic,
      'traitement': traitement,
      if (observations != null && observations.isNotEmpty) 'observations': observations,
      if (poidsKg != null) 'poids_kg': poidsKg,
      if (temperatureC != null) 'temperature_c': temperatureC,
      if (frequenceCardiaque != null) 'frequence_cardiaque': frequenceCardiaque,
    });
  }

  /// Dernière consultation d'un animal
  Future<ConsultationModel?> derniereConsultation(String animalId, String source) async {
    final r = await _db
        .from('consultations')
        .select('*')
        .eq('animal_id', animalId)
        .eq('source', source)
        .order('date_consultation', ascending: false)
        .limit(1)
        .maybeSingle();
    return r != null ? ConsultationModel.fromMap(r) : null;
  }

  /// Nombre total de consultations du vétérinaire
  Future<int> compter() async {
    final vet = _db.auth.currentUser;
    if (vet == null) return 0;
    final r = await _db.from('consultations').select('id').eq('veterinaire_id', vet.id);
    return r.length;
  }
}