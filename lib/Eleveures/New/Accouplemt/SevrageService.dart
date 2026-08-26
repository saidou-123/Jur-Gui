// ============================================================
// SERVICE SEVRAGE & RELANCE DU CYCLE — Étape 10
// Fichier: lib/Eleveures/New/Accouplemt/SevrageService.dart
//
// Rôle :
//   • Détecter quand le sevrage est dû (3-4 mois après naissance)
//   • Identifier les agneaux candidats reproducteurs (> 8 mois)
//   • Enregistrer le sevrage en BD
//   • Relancer automatiquement la surveillance du cycle de la mère
//   • Planifier les notifications de sevrage
//
// Constantes utilisées :
//   ReproductionConfig.dureeLactationJours    = 90  (3 mois)
//   ReproductionConfig.periodeSevrageJours    = 30  (fenêtre 3→4 mois)
//   ReproductionConfig.ageMinimumReproductionMois = 8
//   ReproductionConfig.retourChaleurPostSevrageJours = 21 (~3 semaines)
// ============================================================
 
import 'package:depart/Eleveures/New/Notification/NotificationService.dart';
import 'package:depart/Eleveures/New/Reproduction/ReproductionConfig.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
 
class SevrageService {
  static final SevrageService _instance = SevrageService._internal();
  factory SevrageService() => _instance;
  SevrageService._internal();
 
  final _supabase = Supabase.instance.client;
  final _notif    = NotificationService();
 
  // ============================================================
  // VÉRIFIER LES SEVRAGES EN ATTENTE
  // Appelé depuis ChaleurModule/initState
  // ============================================================
 
  /// Retourne la liste des brebis dont le sevrage est dû
  /// (entre 90 et 120 jours après la mise bas).
  Future<List<SevrageEnAttente>> getSevragesEnAttente() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];
 
      // Fenêtre de sevrage : entre J+90 et J+120 après mise bas
      final dateMin = DateTime.now()
          .subtract(Duration(
              days: ReproductionConfig.dureeLactationJours +
                    ReproductionConfig.periodeSevrageJours));
      final dateMax = DateTime.now()
          .subtract(
              Duration(days: ReproductionConfig.dureeLactationJours));
 
      final rows = await _supabase
          .from('accouplements')
          .select(
            'id, brebis_id, source_brebis, date_mise_bas, '
            'nombre_agneaux, sevrage_effectue, nom_brebis',
          )
          .eq('user_id', userId)
          .not('date_mise_bas', 'is', null)
          .isFilter('sevrage_effectue', null) // pas encore sevré
          .gte('date_mise_bas', dateMin.toIso8601String())
          .lte('date_mise_bas', dateMax.toIso8601String())
          .order('date_mise_bas', ascending: true);
 
      return rows.map((r) => SevrageEnAttente.fromMap(r)).toList();
    } catch (e) {
      debugPrint('❌ getSevragesEnAttente: $e');
      return [];
    }
  }
 
  // ============================================================
  // ENREGISTRER LE SEVRAGE
  // ============================================================
 
  Future<void> enregistrerSevrage({
    required String accouplementId,
    required String brebisId,
    required String sourceBrebis,
    required String nomBrebis,
    String? notes,
  }) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
 
      // 1. Marquer le sevrage dans l'accouplement
      await _supabase.from('accouplements').update({
        'sevrage_effectue' : DateTime.now().toIso8601String(),
        'notes_sevrage'    : notes,
      }).eq('id', accouplementId);
 
      // 2. Relancer la surveillance chaleur pour la mère
      //    → simplement réactiver dans ChaleurModule au prochain rafraîchissement
      //    → et planifier une notification de retour en chaleur
 
      final dateRetourChaleur = DateTime.now().add(
        const Duration(days: ReproductionConfig.retourChaleurPostSevrageJours),
      );
 
      await _notif.afficherNotificationImmediateLocal(
        titre : '✅ Sevrage enregistré — $nomBrebis',
        corps : 'Le sevrage de $nomBrebis est enregistré. '
                'Surveillez le retour en chaleur dans ~3 semaines.',
        type  : 'sevrage',
      );
 
      // Planifier rappel retour en chaleur post-sevrage
      await _supabase.from('notifications_programmees').insert({
        'user_id'   : userId,
        'animal_id' : brebisId,
        'source'    : sourceBrebis,
        'nom_animal': nomBrebis,
        'type'      : 'retour_chaleur_post_sevrage',
        'titre'     : '🔥 Retour en chaleur attendu — $nomBrebis',
        'corps'     : '$nomBrebis peut entrer en chaleur. '
                      'C\'est le bon moment pour planifier le prochain accouplement.',
        'date_envoi': dateRetourChaleur.toIso8601String(),
        'statut'    : 'planifie',
        'metadata'  : {
          'brebis_id'     : brebisId,
          'source'        : sourceBrebis,
          'type_relance'  : 'post_sevrage',
        },
      });
 
      debugPrint('✅ Sevrage enregistré pour $nomBrebis');
    } catch (e) {
      debugPrint('❌ enregistrerSevrage: $e');
      rethrow;
    }
  }
 
  // ============================================================
  // CHARGER LES AGNEAUX D'UN ACCOUPLEMENT (pour sélection reproducteurs)
  // ============================================================
 
  Future<List<Map<String, dynamic>>> getAgneauxAccouplement(
      String accouplementId) async {
    try {
      final rows = await _supabase
          .from('agneaux')
          .select('*')
          .eq('accouplement_id', accouplementId)
          .order('date_naissance', ascending: true);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('❌ getAgneauxAccouplement: $e');
      return [];
    }
  }
 
  // ============================================================
  // MARQUER UN AGNEAU COMME FUTUR REPRODUCTEUR
  // ============================================================
 
  Future<void> marquerFutureReproducteur({
    required String agneauId,
    required String tableSource, // 'nouveaux_nee'
    required bool   estReproducteur,
  }) async {
    try {
      await _supabase.from(tableSource).update({
        'futur_reproducteur': estReproducteur,
      }).eq('id', agneauId);
 
      debugPrint('✅ Agneau $agneauId marqué reproducteur: $estReproducteur');
    } catch (e) {
      debugPrint('❌ marquerFutureReproducteur: $e');
    }
  }
 
  // ============================================================
  // ANALYSER LES PERFORMANCES GÉNÉTIQUES DES AGNEAUX
  // ============================================================
 
  Future<PerformancesGenetiques> analyserPerformances(
      String accouplementId) async {
    try {
      // Charger l'accouplement avec les données IA
      final acc = await _supabase
          .from('accouplements')
          .select('*, agneaux(*)')
          .eq('id', accouplementId)
          .single();
 
      final agneaux = List<Map<String, dynamic>>.from(
          acc['agneaux'] as List? ?? []);
 
      final nbTotal   = agneaux.length;
      final nbVivants = agneaux.where((a) =>
          a['etat_naissance'] != 'mort_ne').length;
      final nbFemelles = agneaux.where((a) => a['sexe'] == 'Femelle').length;
      final nbMales    = agneaux.where((a) => a['sexe'] == 'Mâle').length;
 
      // Poids moyen à la naissance
      final poids = agneaux
          .where((a) => a['poids_naissance'] != null)
          .map((a) => (a['poids_naissance'] as num).toDouble())
          .toList();
      final poidsMoyen = poids.isNotEmpty
          ? poids.reduce((a, b) => a + b) / poids.length
          : null;
 
      // Score consanguinité de l'accouplement
      final fPourcent = (acc['f_pourcent_ia'] as num?)?.toDouble();
      final relation  = acc['relation_ia'] as String?;
 
      return PerformancesGenetiques(
        accouplementId : accouplementId,
        nbAgneauxTotal : nbTotal,
        nbVivants      : nbVivants,
        nbFemelles     : nbFemelles,
        nbMales        : nbMales,
        poidsMoyenKg   : poidsMoyen,
        fPourcent      : fPourcent,
        relation       : relation,
        tauxSurvie     : nbTotal > 0 ? nbVivants / nbTotal : 0,
      );
    } catch (e) {
      debugPrint('❌ analyserPerformances: $e');
      return PerformancesGenetiques.vide(accouplementId);
    }
  }
}
 
// ============================================================
// MODÈLES
// ============================================================
 
class SevrageEnAttente {
  final String   accouplementId;
  final String   brebisId;
  final String   sourceBrebis;
  final DateTime dateMiseBas;
  final int      nombreAgneaux;
  final String   nomBrebis;
 
  SevrageEnAttente({
    required this.accouplementId,
    required this.brebisId,
    required this.sourceBrebis,
    required this.dateMiseBas,
    required this.nombreAgneaux,
    required this.nomBrebis,
  });
 
  factory SevrageEnAttente.fromMap(Map<String, dynamic> m) {
    return SevrageEnAttente(
      accouplementId : m['id']?.toString() ?? '',
      brebisId       : m['brebis_id']?.toString() ?? '',
      sourceBrebis   : m['source_brebis'] ?? '',
      dateMiseBas    : DateTime.parse(m['date_mise_bas']),
      nombreAgneaux  : (m['nombre_agneaux'] as num?)?.toInt() ?? 0,
      nomBrebis      : m['nom_brebis'] ?? 'Brebis inconnue',
    );
  }
 
  /// Âge des agneaux en jours
  int get ageAgneauxJours =>
      DateTime.now().difference(dateMiseBas).inDays;
 
  /// Âge des agneaux en semaines
  int get ageAgneauxSemaines => (ageAgneauxJours / 7).floor();
 
  /// Label court pour l'affichage
  String get labelAge => '$ageAgneauxSemaines semaines';
 
  /// Urgence du sevrage
  bool get estUrgent => ageAgneauxJours >=
      ReproductionConfig.dureeLactationJours +
      ReproductionConfig.periodeSevrageJours - 7;
}
 
class PerformancesGenetiques {
  final String  accouplementId;
  final int     nbAgneauxTotal;
  final int     nbVivants;
  final int     nbFemelles;
  final int     nbMales;
  final double? poidsMoyenKg;
  final double? fPourcent;
  final String? relation;
  final double  tauxSurvie;
 
  const PerformancesGenetiques({
    required this.accouplementId,
    required this.nbAgneauxTotal,
    required this.nbVivants,
    required this.nbFemelles,
    required this.nbMales,
    this.poidsMoyenKg,
    this.fPourcent,
    this.relation,
    required this.tauxSurvie,
  });
 
  factory PerformancesGenetiques.vide(String id) =>
      PerformancesGenetiques(
        accouplementId : id,
        nbAgneauxTotal : 0,
        nbVivants      : 0,
        nbFemelles     : 0,
        nbMales        : 0,
        tauxSurvie     : 0,
      );
 
  String get tauxSurvieLabel => '${(tauxSurvie * 100).round()}%';
 
  Color get couleurTauxSurvie {
    if (tauxSurvie >= 0.9)  return const Color(0xFF2E7D32);
    if (tauxSurvie >= 0.7)  return Colors.orange;
    return const Color(0xFFE53935);
  }
}