import 'package:depart/Veterinaires/constantes/models/vaccination_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class VaccinationService {
  final _db = Supabase.instance.client;

  /// Vaccinations d'un animal précis
  Future<List<VaccinationModel>> charger(String animalId, String source) async {
    final r = await _db
        .from('vaccinations')
        .select('*')
        .eq('animal_id', animalId)
        .eq('source', source)
        .order('date_vaccination', ascending: false);
    return r.map((m) => VaccinationModel.fromMap(m)).toList();
  }

  /// Version raw Map (compatibilité)
  Future<List<Map<String, dynamic>>> chargerRaw(String animalId, String source) async {
    final r = await _db
        .from('vaccinations')
        .select('*')
        .eq('animal_id', animalId)
        .eq('source', source)
        .order('date_vaccination', ascending: false);
    return List<Map<String, dynamic>>.from(r);
  }

  /// Toutes les vaccinations du vétérinaire connecté
  Future<List<Map<String, dynamic>>> chargerToutes() async {
    final vet = _db.auth.currentUser;
    if (vet == null) return [];
    final r = await _db
        .from('vaccinations')
        .select('*')
        .eq('veterinaire_id', vet.id)
        .order('date_vaccination', ascending: false);
    return List<Map<String, dynamic>>.from(r);
  }

  /// Rappels dans les 30 prochains jours (ou en retard)
  Future<List<Map<String, dynamic>>> chargerRappels() async {
    final vet = _db.auth.currentUser;
    if (vet == null) return [];
    final limite = DateTime.now().add(const Duration(days: 30));
    final r = await _db
        .from('vaccinations')
        .select('*')
        .eq('veterinaire_id', vet.id)
        .not('date_rappel', 'is', null)
        .lte('date_rappel', limite.toIso8601String().substring(0, 10))
        .order('date_rappel');
    return List<Map<String, dynamic>>.from(r);
  }

  /// Enregistre une vaccination
  Future<void> enregistrer({
    required String animalId,
    required String source,
    required String nomVaccin,
    required DateTime dateVaccination,
    DateTime? dateRappel,
    String? lot,
    String? observations,
  }) async {
    final vet = _db.auth.currentUser;
    if (vet == null) throw Exception('Vétérinaire non connecté');

    await _db.from('vaccinations').insert({
      'animal_id': animalId,
      'source': source,
      'veterinaire_id': vet.id,
      'nom_vaccin': nomVaccin,
      'date_vaccination': dateVaccination.toIso8601String().substring(0, 10),
      if (dateRappel != null) 'date_rappel': dateRappel.toIso8601String().substring(0, 10),
      if (lot != null && lot.isNotEmpty) 'lot': lot,
      if (observations != null && observations.isNotEmpty) 'observations': observations,
    });
  }

  /// Nombre de rappels urgents (≤ 7 jours)
  Future<int> compterRappelsUrgents() async {
    final rappels = await chargerRappels();
    return rappels.where((v) {
      final d = DateTime.tryParse(v['date_rappel']?.toString() ?? '');
      return d != null && d.difference(DateTime.now()).inDays <= 7;
    }).length;
  }
}