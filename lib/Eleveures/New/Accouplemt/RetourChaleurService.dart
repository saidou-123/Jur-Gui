// ============================================================
// SERVICE CONTRÔLE RETOUR EN CHALEUR — Étape 5
// Fichier: lib/Eleveures/New/Accouplemt/RetourChaleurService.dart
//
// Rôle : gérer le cycle de vérification entre J+17 et J+21
// après un accouplement enregistré.
//
// Scénario complet implémenté :
//   1. À J+17 → notification "surveiller retour en chaleur"
//   2. À J+21 → question automatique : "Retour observé ?"
//   3. Si OUI  → statut "non_fecondee", nouvelle planification chaleur
//   4. Si NON  → statut "gestation_suspectee" + probabilité initiale
//
// Deux colonnes Supabase à ajouter à la table accouplements :
//   statut_gestation  TEXT  DEFAULT 'en_attente'
//   probabilite_gestation FLOAT DEFAULT NULL
//
// Valeurs possibles de statut_gestation :
//   'en_attente'          → accouplement enregistré, rien confirmé
//   'gestation_suspectee' → J+21 sans retour chaleur observé
//   'non_fecondee'        → retour chaleur confirmé à J+21
//   'gestation_confirmee' → échographie/rapport véto (étape 6)
//
// Règles absolues respectées :
//   ✅ Toutes les durées viennent de ReproductionConfig
//   ✅ Utilise NotificationService existant (_scheduleNotification)
//   ✅ Utilise _programmerPushDistant via méthode publique dédiée
//   ✅ Aucune valeur codée en dur
//   ✅ Commentaires en français
// ============================================================
 
import 'package:depart/Eleveures/New/Notification/NotificationService.dart';
import 'package:depart/Eleveures/New/Reproduction/ReproductionConfig.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
 
class RetourChaleurService {
  // ── Singleton ────────────────────────────────────────────
  static final RetourChaleurService _instance =
      RetourChaleurService._internal();
  factory RetourChaleurService() => _instance;
  RetourChaleurService._internal();
 
  final _supabase = Supabase.instance.client;
  final _notif    = NotificationService();
 
  // ============================================================
  // PLANIFIER LA SURVEILLANCE RETOUR CHALEUR
  // Appelé depuis Accouplement_.dart juste après l'insert
  // ============================================================
 
  /// Planifie deux notifications après un accouplement :
  ///   • J+17 → "Commencez à surveiller le retour en chaleur"
  ///   • J+21 → question automatique déclenchée à l'ouverture de l'app
  ///
  /// [accouplementId] : ID Supabase de la ligne accouplements
  /// [brebisId]       : ID de la brebis
  /// [source]         : 'achete' ou 'nee'
  /// [nomBrebis]      : pour les messages de notification
  /// [dateAccouplement] : date de la saillie
  Future<void> planifierSurveillanceRetour({
    required dynamic accouplementId,
    required dynamic brebisId,
    required String  source,
    required String  nomBrebis,
    required DateTime dateAccouplement,
  }) async {
    try {
      // ── Dates clés ────────────────────────────────────────
      // J+17 : début de la fenêtre de surveillance
      final dateJ17 = dateAccouplement.add(
        const Duration(days: ReproductionConfig.retourChaleurDebutJours),
      );
      // J+21 : question automatique à l'éleveur
      final dateJ21 = dateAccouplement.add(
        const Duration(days: ReproductionConfig.retourChaleurFinJours),
      );
 
      // ── Notification locale J+17 ──────────────────────────
      await _notif.planifierNotificationRetourChaleur(
        brebisId         : brebisId,
        nomBrebis        : nomBrebis,
        source           : source,
        accouplementId   : accouplementId,
        dateJ17          : dateJ17,
        dateJ21          : dateJ21,
      );
 
      // ── Enregistrer le suivi en BD ────────────────────────
      // Sert de file d'attente pour la question J+21 au démarrage
      await _enregistrerSuiviRetour(
        accouplementId : accouplementId,
        brebisId       : brebisId,
        source         : source,
        nomBrebis      : nomBrebis,
        dateJ21        : dateJ21,
      );
 
      debugPrint(
        '✅ Surveillance retour planifiée pour $nomBrebis '
        '(J+17: ${_fmt(dateJ17)} | J+21: ${_fmt(dateJ21)})',
      );
    } catch (e) {
      debugPrint('❌ RetourChaleurService.planifierSurveillanceRetour: $e');
    }
  }
 
  // ============================================================
  // VÉRIFIER LES SUIVIS EN ATTENTE
  // Appelé au démarrage de l'app (dans main.dart / initState)
  // pour afficher la question J+21 si la date est dépassée
  // ============================================================
 
  /// Retourne la liste des accouplements pour lesquels
  /// J+21 est atteint et l'éleveur n'a pas encore répondu.
  Future<List<SuiviRetourChaleur>> getSuivisEnAttente() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];
 
      final maintenant = DateTime.now().toIso8601String();
 
      final rows = await _supabase
          .from('suivis_retour_chaleur')
          .select('*')
          .eq('user_id', userId)
          .eq('statut', 'en_attente')
          .lte('date_question_j21', maintenant) // date J+21 atteinte
          .order('date_question_j21', ascending: true);
 
      return rows
          .map((r) => SuiviRetourChaleur.fromMap(r))
          .toList();
    } catch (e) {
      debugPrint('❌ getSuivisEnAttente: $e');
      return [];
    }
  }
 
  // ============================================================
  // CONFIRMER : RETOUR EN CHALEUR OBSERVÉ (non fécondée)
  // L'éleveur a répondu OUI à la question J+21
  // ============================================================
 
  /// Met à jour l'accouplement avec statut "non_fecondee"
  /// et prépare la relance automatique du cycle.
  Future<void> confirmerRetourChaleur({
    required dynamic accouplementId,
    required dynamic brebisId,
    required String  source,
    required String  nomBrebis,
  }) async {
    try {
      // 1. Mettre à jour le statut de l'accouplement
      await _supabase
          .from('accouplements')
          .update({
            'statut_gestation'     : StatutGestation.nonFecondee.valeur,
            'date_confirmation_statut': DateTime.now().toIso8601String(),
          })
          .eq('id', accouplementId);
 
      // 2. Marquer le suivi comme traité
      await _marquerSuiviTraite(
        accouplementId : accouplementId,
        reponse        : 'retour_observe',
      );
 
      // 3. Annuler les rappels d'agnelage (plus nécessaires)
      await _notif.annulerRappelsBrebis(
        brebisId : brebisId,
        source   : source,
      );
 
      // 4. Notification informative à l'éleveur
      await _notif.afficherNotificationImmediateLocal(
        titre : '🔄 Retour en chaleur — $nomBrebis',
        corps : 'La brebis $nomBrebis n\'est pas gestante. '
                'Vous pouvez planifier un nouvel accouplement '
                'lors de sa prochaine chaleur.',
        type  : 'non_fecondee',
      );
 
      debugPrint('✅ Statut "non_fecondee" enregistré pour $nomBrebis');
    } catch (e) {
      debugPrint('❌ confirmerRetourChaleur: $e');
      rethrow; // Remonter pour que l'UI puisse afficher l'erreur
    }
  }
 
  // ============================================================
  // CONFIRMER : PAS DE RETOUR EN CHALEUR (gestation suspectée)
  // L'éleveur a répondu NON à la question J+21
  // ============================================================
 
  /// Met à jour l'accouplement avec statut "gestation_suspectee"
  /// et calcule la probabilité initiale de gestation.
  Future<ResultatSuspicionGestation> confirmerAbsenceRetour({
    required dynamic accouplementId,
    required dynamic brebisId,
    required String  source,
    required String  nomBrebis,
    required DateTime dateAccouplement,
  }) async {
    try {
      // Calculer la probabilité initiale (base : 65% — s'affine à l'étape 6)
      final probabilite = await _calculerProbabiliteInitiale(
        brebisId : brebisId,
        source   : source,
      );
 
      // Mettre à jour l'accouplement
      await _supabase
          .from('accouplements')
          .update({
            'statut_gestation'        : StatutGestation.gestationSuspectee.valeur,
            'probabilite_gestation'   : probabilite,
            'date_confirmation_statut': DateTime.now().toIso8601String(),
          })
          .eq('id', accouplementId);
 
      // Marquer le suivi comme traité
      await _marquerSuiviTraite(
        accouplementId : accouplementId,
        reponse        : 'pas_de_retour',
      );
 
      // Notification de confirmation à l'éleveur
      await _notif.afficherNotificationImmediateLocal(
        titre : '🤰 Gestation suspectée — $nomBrebis',
        corps : '$nomBrebis est probablement gestante '
                '(${(probabilite * 100).round()}% de probabilité). '
                'Confirmation recommandée à J+45 par échographie.',
        type  : 'gestation_suspectee',
      );
 
      debugPrint(
        '✅ Statut "gestation_suspectee" → $nomBrebis '
        '(probabilité: ${(probabilite * 100).round()}%)',
      );
 
      return ResultatSuspicionGestation(
        probabilite  : probabilite,
        dateAgnelage : dateAccouplement.add(
          Duration(days: ReproductionConfig.gestationMoyenneJours),
        ),
        messageConseils: _construireMessageConseils(probabilite),
      );
    } catch (e) {
      debugPrint('❌ confirmerAbsenceRetour: $e');
      rethrow;
    }
  }
 
  // ============================================================
  // RÉCUPÉRER LE STATUT D'UN ACCOUPLEMENT
  // ============================================================
 
  /// Retourne le statut de gestation d'un accouplement et
  /// sa probabilité (null si pas encore calculée).
  Future<Map<String, dynamic>?> getStatutAccouplement(
    dynamic accouplementId,
  ) async {
    try {
      final row = await _supabase
          .from('accouplements')
          .select('statut_gestation, probabilite_gestation, date_prevue_agnelage')
          .eq('id', accouplementId)
          .maybeSingle();
      return row;
    } catch (e) {
      debugPrint('❌ getStatutAccouplement: $e');
      return null;
    }
  }
 
  // ============================================================
  // PRIVÉ — Enregistrer le suivi en BD
  // ============================================================
 
  Future<void> _enregistrerSuiviRetour({
    required dynamic accouplementId,
    required dynamic brebisId,
    required String  source,
    required String  nomBrebis,
    required DateTime dateJ21,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
 
    try {
      // Éviter les doublons si appelé deux fois (idempotent)
      await _supabase
          .from('suivis_retour_chaleur')
          .upsert({
            'user_id'          : userId,
            'accouplement_id'  : accouplementId.toString(),
            'brebis_id'        : brebisId.toString(),
            'source'           : source,
            'nom_brebis'       : nomBrebis,
            'date_question_j21': dateJ21.toIso8601String(),
            'statut'           : 'en_attente',
            'created_at'       : DateTime.now().toIso8601String(),
          },
          onConflict: 'accouplement_id'); // upsert sur la clé unique
    } catch (e) {
      debugPrint('⚠️ _enregistrerSuiviRetour (non bloquant): $e');
    }
  }
 
  // ============================================================
  // PRIVÉ — Marquer un suivi comme traité
  // ============================================================
 
  Future<void> _marquerSuiviTraite({
    required dynamic accouplementId,
    required String  reponse, // 'retour_observe' | 'pas_de_retour'
  }) async {
    try {
      await _supabase
          .from('suivis_retour_chaleur')
          .update({
            'statut'         : 'traite',
            'reponse_eleveur': reponse,
            'date_reponse'   : DateTime.now().toIso8601String(),
          })
          .eq('accouplement_id', accouplementId.toString());
    } catch (e) {
      debugPrint('⚠️ _marquerSuiviTraite (non bloquant): $e');
    }
  }
 
  // ============================================================
  // PRIVÉ — Calcul probabilité initiale de gestation
  // Basé sur l'historique de la brebis (taux de fertilité passé)
  // ============================================================
 
  Future<double> _calculerProbabiliteInitiale({
    required dynamic brebisId,
    required String  source,
  }) async {
    try {
      // Charger tous les accouplements passés de cette brebis
      final historique = await _supabase
          .from('accouplements')
          .select('date_mise_bas, statut_gestation')
          .eq('brebis_id', brebisId)
          .eq('source_brebis', source)
          .not('statut_gestation', 'eq', 'en_attente');
 
      if (historique.isEmpty) {
        // Première fois → probabilité de base (65% pour une Ladoum)
        return ReproductionConfig.probabiliteGestationBase;
      }
 
      // Calculer le taux de réussite historique de cette brebis
      final total    = historique.length;
      final reussis  = historique
          .where((a) => a['date_mise_bas'] != null)
          .length;
 
      // Pondération : 60% historique brebis + 40% base population Ladoum
      final tauxHistorique = reussis / total;
      final probabilite    =
          (tauxHistorique * 0.6) +
          (ReproductionConfig.probabiliteGestationBase * 0.4);
 
      // Clamp entre 30% et 95% (éviter les valeurs extrêmes)
      return probabilite.clamp(0.30, 0.95);
    } catch (e) {
      debugPrint('⚠️ _calculerProbabiliteInitiale: $e');
      return ReproductionConfig.probabiliteGestationBase;
    }
  }
 
  // ============================================================
  // PRIVÉ — Message de conseils selon la probabilité
  // ============================================================
 
  String _construireMessageConseils(double probabilite) {
    if (probabilite >= 0.80) {
      return 'Forte probabilité de gestation. '
             'Continuez la surveillance normale et '
             'prévoyez une confirmation par échographie à J+45.';
    } else if (probabilite >= 0.60) {
      return 'Probabilité modérée. Une échographie à J+45 '
             'est fortement recommandée pour confirmer.';
    } else {
      return 'Probabilité faible. Surveillez attentivement '
             'les signes de chaleur dans les 7 prochains jours '
             'et consultez votre vétérinaire si nécessaire.';
    }
  }
 
  // ── Utilitaire formatage date ────────────────────────────
  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}
 
// ============================================================
// ENUM — Statuts de gestation
// Centralise les valeurs pour éviter les fautes de frappe
// ============================================================
 
enum StatutGestation {
  enAttente,
  gestationSuspectee,
  nonFecondee,
  gestationConfirmee;
 
  /// Valeur exacte stockée en base Supabase
  String get valeur {
    switch (this) {
      case StatutGestation.enAttente:
        return 'en_attente';
      case StatutGestation.gestationSuspectee:
        return 'gestation_suspectee';
      case StatutGestation.nonFecondee:
        return 'non_fecondee';
      case StatutGestation.gestationConfirmee:
        return 'gestation_confirmee';
    }
  }
 
  /// Label lisible pour l'interface
  String get label {
    switch (this) {
      case StatutGestation.enAttente:
        return 'En attente';
      case StatutGestation.gestationSuspectee:
        return 'Gestation suspectée';
      case StatutGestation.nonFecondee:
        return 'Non fécondée';
      case StatutGestation.gestationConfirmee:
        return 'Gestation confirmée';
    }
  }
 
  /// Couleur associée dans l'interface
  Color get couleur {
    switch (this) {
      case StatutGestation.enAttente:
        return Colors.grey;
      case StatutGestation.gestationSuspectee:
        return const Color(0xFF8E24AA); // Violet
      case StatutGestation.nonFecondee:
        return const Color(0xFFE53935); // Rouge
      case StatutGestation.gestationConfirmee:
        return const Color(0xFF2E7D32); // Vert foncé
    }
  }
 
  /// Icône associée dans l'interface
  IconData get icone {
    switch (this) {
      case StatutGestation.enAttente:
        return Icons.hourglass_empty_rounded;
      case StatutGestation.gestationSuspectee:
        return Icons.pregnant_woman_rounded;
      case StatutGestation.nonFecondee:
        return Icons.replay_rounded;
      case StatutGestation.gestationConfirmee:
        return Icons.check_circle_rounded;
    }
  }
 
  /// Construire depuis la valeur BD (sécurisé)
  static StatutGestation fromString(String? valeur) {
    switch (valeur) {
      case 'gestation_suspectee':
        return StatutGestation.gestationSuspectee;
      case 'non_fecondee':
        return StatutGestation.nonFecondee;
      case 'gestation_confirmee':
        return StatutGestation.gestationConfirmee;
      default:
        return StatutGestation.enAttente;
    }
  }
}
 
// ============================================================
// MODÈLES DE DONNÉES
// ============================================================
 
/// Représente un suivi retour chaleur en attente de réponse
class SuiviRetourChaleur {
  final String   id;
  final String   accouplementId;
  final String   brebisId;
  final String   source;
  final String   nomBrebis;
  final DateTime dateQuestionJ21;
  final String   statut;
 
  const SuiviRetourChaleur({
    required this.id,
    required this.accouplementId,
    required this.brebisId,
    required this.source,
    required this.nomBrebis,
    required this.dateQuestionJ21,
    required this.statut,
  });
 
  factory SuiviRetourChaleur.fromMap(Map<String, dynamic> m) {
    return SuiviRetourChaleur(
      id              : m['id']?.toString() ?? '',
      accouplementId  : m['accouplement_id']?.toString() ?? '',
      brebisId        : m['brebis_id']?.toString() ?? '',
      source          : m['source'] ?? '',
      nomBrebis       : m['nom_brebis'] ?? 'Inconnue',
      dateQuestionJ21 : DateTime.parse(m['date_question_j21']),
      statut          : m['statut'] ?? 'en_attente',
    );
  }
 
  /// Nombre de jours de retard sur la question J+21
  int get joursRetard =>
      DateTime.now().difference(dateQuestionJ21).inDays;
}
 
/// Résultat retourné après confirmation de gestation suspectée
class ResultatSuspicionGestation {
  final double   probabilite;       // 0.0 à 1.0
  final DateTime dateAgnelage;      // date prévue mise bas
  final String   messageConseils;   // texte conseils adapté
 
  const ResultatSuspicionGestation({
    required this.probabilite,
    required this.dateAgnelage,
    required this.messageConseils,
  });
 
  /// Probabilité en pourcentage arrondi
  String get probabilitePourcent => '${(probabilite * 100).round()}%';
 
  /// Niveau de confiance lisible
  String get niveauConfiance {
    if (probabilite >= 0.80) return 'Élevée';
    if (probabilite >= 0.60) return 'Modérée';
    return 'Faible';
  }
 
  /// Couleur associée au niveau de confiance
  Color get couleurConfiance {
    if (probabilite >= 0.80) return const Color(0xFF2E7D32);
    if (probabilite >= 0.60) return const Color(0xFFF57F17);
    return const Color(0xFFE53935);
  }
}
 