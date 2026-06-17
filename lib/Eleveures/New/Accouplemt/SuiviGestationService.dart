// ============================================================
// SERVICE SUIVI GESTATION — Étape 6
// Fichier: lib/Eleveures/New/Accouplemt/SuiviGestationService.dart
//
// Rôle :
//   • Calculer la semaine de gestation courante
//   • Charger / sauvegarder la checklist hebdomadaire
//   • Calculer et mettre à jour le score de probabilité
//   • Gérer la confirmation formelle à J+45
//
// Algorithme du score :
//   Score = moyenne pondérée de 5 indicateurs cliniques
//   + bonus visite vétérinaire + progression temporelle
//   Poids : mammaire(30%) + poids(20%) + appétit(15%)
//           + comportement(15%) + pas_retour_chaleur(20%)
// ============================================================
 
import 'package:depart/Eleveures/New/Reproduction/ReproductionConfig.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
 
class SuiviGestationService {
  static final SuiviGestationService _instance =
      SuiviGestationService._internal();
  factory SuiviGestationService() => _instance;
  SuiviGestationService._internal();
 
  final _supabase = Supabase.instance.client;
 
  // ============================================================
  // CALCUL SEMAINE DE GESTATION
  // ============================================================
 
  /// Retourne la semaine de gestation (1 à 20) depuis la date d'accouplement.
  /// Retourne null si la date est invalide ou gestation terminée.
  int? calculerSemaine(DateTime dateAccouplement) {
    final joursEcoules = DateTime.now().difference(dateAccouplement).inDays;
    if (joursEcoules < 0) return null;
    final semaine = (joursEcoules / 7).floor() + 1;
    // Gestation max 5 mois ≈ 21 semaines
    if (semaine > 21) return 21;
    return semaine;
  }
 
  /// Calcule le pourcentage de progression de la gestation (0 à 100).
  double calculerProgression(DateTime dateAccouplement) {
    final joursEcoules = DateTime.now().difference(dateAccouplement).inDays;
    final progression =
        (joursEcoules / ReproductionConfig.gestationMoyenneJours * 100)
            .clamp(0.0, 100.0);
    return progression;
  }
 
  /// Retourne le mois de gestation (1 à 5).
  int calculerMois(DateTime dateAccouplement) {
    final semaine = calculerSemaine(dateAccouplement) ?? 1;
    return ((semaine - 1) / 4).floor() + 1;
  }
 
  // ============================================================
  // CHARGER LA CHECKLIST D'UNE SEMAINE
  // ============================================================
 
  Future<ChecklistGestation?> chargerChecklist({
    required String accouplementId,
    required int semaine,
  }) async {
    try {
      final row = await _supabase
          .from('checklist_gestation')
          .select('*')
          .eq('accouplement_id', accouplementId)
          .eq('semaine', semaine)
          .maybeSingle();
 
      if (row == null) return null;
      return ChecklistGestation.fromMap(row);
    } catch (e) {
      debugPrint('❌ chargerChecklist: $e');
      return null;
    }
  }
 
  /// Charge toutes les checklists d'un accouplement (historique complet).
  Future<List<ChecklistGestation>> chargerHistoriqueChecklists(
      String accouplementId) async {
    try {
      final rows = await _supabase
          .from('checklist_gestation')
          .select('*')
          .eq('accouplement_id', accouplementId)
          .order('semaine', ascending: true);
 
      return rows.map((r) => ChecklistGestation.fromMap(r)).toList();
    } catch (e) {
      debugPrint('❌ chargerHistoriqueChecklists: $e');
      return [];
    }
  }
 
  // ============================================================
  // SAUVEGARDER LA CHECKLIST ET RECALCULER LE SCORE
  // ============================================================
 
  Future<double> sauvegarderChecklist({
    required String accouplementId,
    required int semaine,
    required ChecklistGestation checklist,
    required DateTime dateAccouplement,
  }) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
 
      // Calculer le score de cette semaine
      final scoresSemaine = _calculerScoreSemaine(checklist);
 
      // Calculer le score global cumulé (toutes semaines)
      final historique = await chargerHistoriqueChecklists(accouplementId);
      final scoreGlobal = _calculerScoreGlobal(
        historique    : historique,
        nouvelleSemaine: semaine,
        nouveauScore  : scoresSemaine,
        dateAccouplement: dateAccouplement,
      );
 
      // Upsert la checklist
      await _supabase.from('checklist_gestation').upsert(
        {
          'accouplement_id' : accouplementId,
          'user_id'         : userId,
          'semaine'         : semaine,
          'mammaire'        : checklist.mammaire,
          'prise_poids'     : checklist.prisePoids,
          'appetit_normal'  : checklist.appetitNormal,
          'comportement_ok' : checklist.comportementOk,
          'signe_chaleur'   : checklist.pasSigneChaleur,
          'visite_veto'     : checklist.visiteVeto,
          'notes_veto'      : checklist.notesVeto,
          'score_semaine'   : scoresSemaine,
          'date_saisie'     : DateTime.now().toIso8601String(),
        },
        onConflict: 'accouplement_id,semaine',
      );
 
      // Mettre à jour le score global et la semaine dans accouplements
      await _supabase.from('accouplements').update({
        'score_gestation'   : scoreGlobal,
        'semaine_gestation' : semaine,
        'probabilite_gestation': scoreGlobal, // synchroniser avec étape 5
      }).eq('id', accouplementId);
 
      debugPrint(
        '✅ Checklist S$semaine sauvegardée — '
        'score semaine: ${(scoresSemaine * 100).round()}% | '
        'score global: ${(scoreGlobal * 100).round()}%',
      );
 
      return scoreGlobal;
    } catch (e) {
      debugPrint('❌ sauvegarderChecklist: $e');
      rethrow;
    }
  }
 
  // ============================================================
  // CONFIRMER LA GESTATION À J+45
  // ============================================================
 
  Future<void> confirmerGestationJ45({
    required String accouplementId,
    required String typeConfirmation, // 'echographie'|'rapport_veto'|'observation'
    required String resultat,         // 'confirmee'|'infirmee'
    String? notes,
  }) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
 
      // Insérer la confirmation
      await _supabase.from('confirmations_gestation').upsert(
        {
          'accouplement_id'  : accouplementId,
          'user_id'          : userId,
          'type_confirmation': typeConfirmation,
          'resultat'         : resultat,
          'notes'            : notes,
          'date_confirmation': DateTime.now().toIso8601String(),
        },
        onConflict: 'accouplement_id',
      );
 
      // Mettre à jour le statut de l'accouplement
      final nouveauStatut = resultat == 'confirmee'
          ? 'gestation_confirmee'
          : 'non_fecondee';
 
      await _supabase.from('accouplements').update({
        'statut_gestation'       : nouveauStatut,
        'date_confirmation_j45'  : DateTime.now().toIso8601String(),
        'probabilite_gestation'  : resultat == 'confirmee' ? 0.99 : 0.01,
      }).eq('id', accouplementId);
 
      debugPrint('✅ Gestation confirmée: $resultat ($typeConfirmation)');
    } catch (e) {
      debugPrint('❌ confirmerGestationJ45: $e');
      rethrow;
    }
  }
 
  // ============================================================
  // ALGORITHME — Score d'une semaine (0.0 à 1.0)
  // ============================================================
 
  double _calculerScoreSemaine(ChecklistGestation c) {
    // Chaque indicateur est null (non répondu), true (positif) ou false (négatif)
    // On ne pénalise pas les non-réponses — on calcule sur les réponses disponibles
    double total = 0;
    double poidsTotalDisponible = 0;
 
    // Développement mammaire — poids 30%
    if (c.mammaire != null) {
      total += (c.mammaire! ? 1.0 : 0.0) * 0.30;
      poidsTotalDisponible += 0.30;
    }
    // Prise de poids — poids 20%
    if (c.prisePoids != null) {
      total += (c.prisePoids! ? 1.0 : 0.0) * 0.20;
      poidsTotalDisponible += 0.20;
    }
    // Appétit normal — poids 15%
    if (c.appetitNormal != null) {
      total += (c.appetitNormal! ? 1.0 : 0.0) * 0.15;
      poidsTotalDisponible += 0.15;
    }
    // Comportement calme — poids 15%
    if (c.comportementOk != null) {
      total += (c.comportementOk! ? 1.0 : 0.0) * 0.15;
      poidsTotalDisponible += 0.15;
    }
    // Pas de signe de chaleur — poids 20%
    if (c.pasSigneChaleur != null) {
      total += (c.pasSigneChaleur! ? 1.0 : 0.0) * 0.20;
      poidsTotalDisponible += 0.20;
    }
 
    // Bonus visite vétérinaire (+5% si effectuée)
    if (c.visiteVeto == true) total += 0.05;
 
    // Normaliser sur les poids disponibles
    if (poidsTotalDisponible == 0) return ReproductionConfig.probabiliteGestationBase;
    final scoreNormalise = (total / poidsTotalDisponible).clamp(0.0, 1.0);
 
    // Pondérer avec la base population (60% score clinique + 40% base)
    return (scoreNormalise * 0.60) +
        (ReproductionConfig.probabiliteGestationBase * 0.40);
  }
 
  // ============================================================
  // ALGORITHME — Score global cumulé (0.0 à 1.0)
  // ============================================================
 
  double _calculerScoreGlobal({
    required List<ChecklistGestation> historique,
    required int nouvelleSemaine,
    required double nouveauScore,
    required DateTime dateAccouplement,
  }) {
    // Construire la liste complète avec la nouvelle semaine
    final Map<int, double> scoresSemaines = {
      for (var c in historique) c.semaine: c.scoreSemaine,
      nouvelleSemaine: nouveauScore,
    };
 
    if (scoresSemaines.isEmpty) {
      return ReproductionConfig.probabiliteGestationBase;
    }
 
    // Moyenne pondérée — semaines récentes ont plus de poids
    double somme = 0;
    double poids = 0;
    scoresSemaines.forEach((semaine, score) {
      final p = semaine.toDouble(); // semaine 5 pèse 5x plus que semaine 1
      somme += score * p;
      poids += p;
    });
 
    final scoreMoyen = poids > 0 ? somme / poids : nouveauScore;
 
    // Bonus progression temporelle : plus on avance sans problème, plus c'est probable
    final progression = calculerProgression(dateAccouplement);
    final bonusTemporel = progression / 100 * 0.10; // max +10%
 
    return (scoreMoyen + bonusTemporel).clamp(0.20, 0.99);
  }
}
 
// ============================================================
// MODÈLE CHECKLIST
// ============================================================
 
class ChecklistGestation {
  final String  id;
  final String  accouplementId;
  final int     semaine;
  final bool?   mammaire;
  final bool?   prisePoids;
  final bool?   appetitNormal;
  final bool?   comportementOk;
  final bool?   pasSigneChaleur;
  final bool    visiteVeto;
  final String? notesVeto;
  final double  scoreSemaine;
  final DateTime dateSaisie;
 
  const ChecklistGestation({
    required this.id,
    required this.accouplementId,
    required this.semaine,
    this.mammaire,
    this.prisePoids,
    this.appetitNormal,
    this.comportementOk,
    this.pasSigneChaleur,
    this.visiteVeto = false,
    this.notesVeto,
    required this.scoreSemaine,
    required this.dateSaisie,
  });
 
  factory ChecklistGestation.fromMap(Map<String, dynamic> m) {
    return ChecklistGestation(
      id              : m['id']?.toString() ?? '',
      accouplementId  : m['accouplement_id']?.toString() ?? '',
      semaine         : (m['semaine'] as num?)?.toInt() ?? 1,
      mammaire        : m['mammaire'] as bool?,
      prisePoids      : m['prise_poids'] as bool?,
      appetitNormal   : m['appetit_normal'] as bool?,
      comportementOk  : m['comportement_ok'] as bool?,
      pasSigneChaleur : m['signe_chaleur'] as bool?,
      visiteVeto      : m['visite_veto'] as bool? ?? false,
      notesVeto       : m['notes_veto'] as String?,
      scoreSemaine    : (m['score_semaine'] as num?)?.toDouble() ?? 0.0,
      dateSaisie      : DateTime.tryParse(m['date_saisie'] ?? '') ?? DateTime.now(),
    );
  }
 
  /// Retourne une copie vierge (pour nouvelle saisie)
  factory ChecklistGestation.vierge({
    required String accouplementId,
    required int semaine,
  }) {
    return ChecklistGestation(
      id             : '',
      accouplementId : accouplementId,
      semaine        : semaine,
      scoreSemaine   : 0,
      dateSaisie     : DateTime.now(),
    );
  }
 
  /// Nombre d'indicateurs renseignés
  int get nbIndicateursRenseignes => [
    mammaire, prisePoids, appetitNormal, comportementOk, pasSigneChaleur,
  ].where((b) => b != null).length;
 
  /// Checklist complète si les 5 indicateurs sont renseignés
  bool get estComplete => nbIndicateursRenseignes == 5;
 
  /// Score en pourcentage arrondi
  String get scorePourcent => '${(scoreSemaine * 100).round()}%';
 
  /// Couleur du score
  Color get couleurScore {
    if (scoreSemaine >= ReproductionConfig.probabiliteGestationElevee) {
      return const Color(0xFF2E7D32);
    }
    if (scoreSemaine >= ReproductionConfig.probabiliteGestationModeree) {
      return Colors.orange;
    }
    return const Color(0xFFE53935);
  }
 
  /// Niveau textuel du score
  String get niveauScore {
    if (scoreSemaine >= ReproductionConfig.probabiliteGestationElevee) return 'Élevée';
    if (scoreSemaine >= ReproductionConfig.probabiliteGestationModeree) return 'Modérée';
    return 'Faible';
  }
}
 
// ============================================================
// MODÈLE RÉSUMÉ SUIVI GESTATION (pour l'UI)
// ============================================================
 
class ResumeGestationSemaine {
  final int      semaine;
  final int      mois;
  final double   progression;    // 0.0 à 1.0
  final double   scoreGlobal;    // 0.0 à 1.0
  final bool     aChecklist;
  final bool     j45Atteint;
  final bool     confirmee;
  final String   conseilsSemaine;
  final String   rappelSuivant;
 
  const ResumeGestationSemaine({
    required this.semaine,
    required this.mois,
    required this.progression,
    required this.scoreGlobal,
    required this.aChecklist,
    required this.j45Atteint,
    required this.confirmee,
    required this.conseilsSemaine,
    required this.rappelSuivant,
  });
 
  /// Construire depuis les données disponibles
  factory ResumeGestationSemaine.calculer({
    required DateTime dateAccouplement,
    required double scoreGlobal,
    required bool aChecklist,
    required bool confirmee,
  }) {
    final svc = SuiviGestationService();
    final semaine   = svc.calculerSemaine(dateAccouplement) ?? 1;
    final mois      = svc.calculerMois(dateAccouplement);
    final progression = svc.calculerProgression(dateAccouplement) / 100;
    final joursDepuis = DateTime.now().difference(dateAccouplement).inDays;
    final j45Atteint  = joursDepuis >= 45;
 
    return ResumeGestationSemaine(
      semaine        : semaine,
      mois           : mois,
      progression    : progression,
      scoreGlobal    : scoreGlobal,
      aChecklist     : aChecklist,
      j45Atteint     : j45Atteint,
      confirmee      : confirmee,
      conseilsSemaine: _conseilsSemaine(semaine, mois),
      rappelSuivant  : _rappelSuivant(semaine, j45Atteint),
    );
  }
 
  static String _conseilsSemaine(int semaine, int mois) {
    if (mois == 1) return 'Surveillance discrète. Évitez le stress. '
        'Alimentation normale, eau fraîche en permanence.';
    if (mois == 2) return 'Augmentez légèrement la ration. '
        'Commencez à observer le développement mammaire.';
    if (mois == 3) return 'Vermifugation recommandée. '
        'Complément minéral (calcium/phosphore). Réduire les efforts physiques.';
    if (mois == 4) return 'Isolation progressive du reste du troupeau. '
        'Préparez la loge de mise bas. Vaccination clostridies.';
    return 'Surveillance quotidienne. Préparez matériel agnelage. '
        'Alimentation légère et facilement digestible.';
  }
 
  static String _rappelSuivant(int semaine, bool j45Atteint) {
    if (!j45Atteint) {
      final joursAvantJ45 = 45 - (semaine * 7);
      if (joursAvantJ45 > 0) {
        return 'Confirmation par échographie dans ~$joursAvantJ45 jours (J+45)';
      }
    }
    if (semaine < 8)  return 'Prochaine checklist dans 7 jours';
    if (semaine < 16) return 'Rappel vaccination clostridies bientôt';
    return 'Préparation mise bas — voir étape 7';
  }
}
