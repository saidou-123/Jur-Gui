import 'package:depart/Eleveures/Mon%20Troupeau/SupprimerAnimal/Animalmodel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class AnimalService {
  final _db = Supabase.instance.client;

  /// Charge tous les animaux actifs des deux tables
  Future<List<Map<String, dynamic>>> chargerTousLesAnimaux() async {
    final nees   = await _db.from('nouveaux_nee').select('*').eq('statut', 'actif').order('nom');
    final achetes = await _db.from('animal_acheter').select('*').eq('statut', 'actif').order('nom');
    return [
      ...nees.map((a)   => {...a, 'source': 'nee'}),
      ...achetes.map((a) => {...a, 'source': 'achete'}),
    ];
  }

  /// Version typée
  Future<List<AnimalModel>> chargerAnimaux() async {
    final raw = await chargerTousLesAnimaux();
    return raw.map((m) => AnimalModel.fromMap(m, m['source'] as String)).toList().cast<AnimalModel>();
  }

  /// Recherche un animal par tag RFID dans les deux tables
  Future<({Map<String, dynamic>? animal, String? source})> rechercherParRfid(
    String uid,
  ) async {
    final clean = uid.trim().toUpperCase();

    var res = await _db
        .from('nouveaux_nee')
        .select('*')
        .ilike('tag_rfid', clean)
        .maybeSingle();
    if (res != null) return (animal: {...res, 'source': 'nee'}, source: 'nee');

    res = await _db
        .from('animal_acheter')
        .select('*')
        .ilike('tag_rfid', clean)
        .maybeSingle();
    if (res != null) return (animal: {...res, 'source': 'achete'}, source: 'achete');

    return (animal: null, source: null);
  }

  /// Récupère un animal par son ID et sa source
  Future<Map<String, dynamic>?> chargerParId(String id, String source) async {
    final table = source == 'nee' ? 'nouveaux_nee' : 'animal_acheter';
    final res = await _db.from(table).select('*').eq('id', id).maybeSingle();
    if (res == null) return null;
    return {...res, 'source': source};
  }

  /// Nombre total d'animaux actifs
  Future<int> compterAnimaux() async {
    final r1 = await _db.from('nouveaux_nee').select('id').eq('statut', 'actif');
    final r2 = await _db.from('animal_acheter').select('id').eq('statut', 'actif');
    return r1.length + r2.length;
  }
}