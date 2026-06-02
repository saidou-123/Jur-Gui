// ============================================================
// ENREGISTRER ACCOUPLEMENT — SCÉNARIO COMPLET
// Fichier: lib/Eleveures/New/Accouplemt/Accouplement.dart
//
// Scénario implémenté :
//   1. Chargement brebis disponibles + béliers depuis Supabase
//   2. Sélection brebis → vérification chaleur (48h)
//   3. Sélection bélier → analyse IA consanguinité disponible
//   4. Analyse IA : POST /analyser-pedigree → F%, relation, ancêtres
//   5. Résultat vert/orange/rouge avec possibilité d'annuler
//   6. Saisie date, heure, méthode, notes
//   7. Vérification métier finale
//   8. Insertion Supabase avec colonnes IA complètes
//   9. Notifications agnelage (J-30, J-7, J-1)
//  10. Dialog de succès + retour liste
//
// ✅ CORRECTION BUG N+1 (v2) :
//   AVANT : pour N brebis → N+2 requêtes HTTP (1 par brebis pour gestation)
//   APRÈS : exactement 3 requêtes fixes quel que soit le nombre de brebis
//     - Requête 1 : toutes les femelles achetées
//     - Requête 2 : toutes les femelles nées
//     - Requête 3 : tous les accouplements sans mise_bas (une seule fois)
//   Le filtrage des gestantes se fait ensuite en mémoire avec un Set O(1).
// ============================================================

import 'package:depart/Eleveures/New/Accouplemt/ConsanguiniteService.dart';
import 'package:depart/Eleveures/New/Accouplemt/ResultatConsanguinite.dart';
import 'package:depart/Eleveures/New/Accouplemt/ResultatConsanguiniteWidget.dart' hide ResultatConsanguinite;
import 'package:depart/Eleveures/New/Notification/NotificationService.dart';
import 'package:depart/Eleveures/New/Reproduction/ReproductionBusinessService.dart';
import 'package:depart/Eleveures/New/Reproduction/ReproductionConfig.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EnregistrerAccouplement extends StatefulWidget {
  final Map<String, dynamic>? brebisPreSelectionnee;
  final String? sourcePreSelectionnee;

  const EnregistrerAccouplement({
    super.key,
    this.brebisPreSelectionnee,
    this.sourcePreSelectionnee,
  });

  @override
  State<EnregistrerAccouplement> createState() =>
      _EnregistrerAccouplementState();
}

class _EnregistrerAccouplementState extends State<EnregistrerAccouplement> {
  // ── Services ──────────────────────────────────────────────
  final supabase             = Supabase.instance.client;
  final _formKey             = GlobalKey<FormState>();
  final _businessService     = ReproductionBusinessService();
  final _notificationService = NotificationService();
  final _consanguiniteService = ConsanguiniteService();
  final _notesController     = TextEditingController();

  // ── Listes animaux ────────────────────────────────────────
  List<Map<String, dynamic>> _brebisDisponibles = [];
  List<Map<String, dynamic>> _beliersDisponibles = [];

  // ── Sélections ───────────────────────────────────────────
  Map<String, dynamic>? _brebisSelectionnee;
  Map<String, dynamic>? _belierSelectionne;

  // ── Détails accouplement ──────────────────────────────────
  DateTime  _dateAccouplement  = DateTime.now();
  TimeOfDay _heureAccouplement = TimeOfDay.now();
  String    _methodeAccouplement = 'Naturel';

  // ── Chaleur brebis ────────────────────────────────────────
  DateTime? _derniereChaleur;
  bool      _chaleurRecente = false;

  // ── Analyse IA ────────────────────────────────────────────
  bool                  _analyseIaEnCours = false;
  ResultatConsanguinite? _resultatIa;
  bool                  _analyseEffectuee = false;

  // ── États de chargement ───────────────────────────────────
  bool _isLoadingAnimaux = true;
  bool _isLoading        = false;

  // ─────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _brebisSelectionnee = widget.brebisPreSelectionnee;
    _chargerAnimaux();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────
  // 1. CHARGEMENT DES ANIMAUX
  // ──────────────────────────────────────────────────────────
  Future<void> _chargerAnimaux() async {
    if (!mounted) return;
    setState(() => _isLoadingAnimaux = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Non connecté');

      final results = await Future.wait([
        _chargerBrebisDisponibles(userId),
        _chargerBeliers(userId),
      ]);

      if (mounted) {
        setState(() {
          _brebisDisponibles  = results[0];
          _beliersDisponibles = results[1];
          _isLoadingAnimaux   = false;
        });
        if (_brebisSelectionnee != null) await _chargerInfosBrebis();
      }
    } catch (e) {
      debugPrint('❌ Chargement animaux: $e');
      if (mounted) {
        _showSnackBar('Erreur de chargement', Colors.red);
        setState(() => _isLoadingAnimaux = false);
      }
    }
  }

  // ──────────────────────────────────────────────────────────
  // ✅ VERSION CORRIGÉE — 3 requêtes fixes au lieu de N+2
  //
  // PROBLÈME ORIGINAL (bug N+1) :
  //   Pour chaque brebis dans la liste, une requête Supabase séparée
  //   était faite pour vérifier si elle est gestante.
  //   Exemple : 50 brebis = 52 requêtes HTTP → lent + consomme des données.
  //
  // SOLUTION :
  //   Étape 1 — Charger toutes les femelles (2 requêtes parallèles)
  //   Étape 2 — Charger TOUS les accouplements sans mise_bas (1 requête)
  //   Étape 3 — Construire un Set des clés "source_id" des gestantes
  //   Étape 4 — Filtrer en mémoire avec Set.contains() en O(1)
  //
  //   Résultat : toujours 3 requêtes, peu importe la taille du troupeau.
  // ──────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> _chargerBrebisDisponibles(
      String userId) async {

    // ── Étape 1 : charger toutes les femelles en parallèle ──
    List<Map<String, dynamic>> toutes = [];

    final results = await Future.wait([
      // Femelles achetées
      supabase
          .from('animal_acheter')
          .select('id, nom, race, image_url, tag_rfid')
          .eq('sexe', 'Femelle')
          .eq('user_id', userId)
          .order('nom')
          .then((r) {
            final liste = List<Map<String, dynamic>>.from(r);
            for (var b in liste) b['source'] = 'achete';
            return liste;
          })
          .catchError((e) {
            debugPrint('⚠️ Brebis achetées: $e');
            return <Map<String, dynamic>>[];
          }),

      // Femelles nées
      supabase
          .from('nouveaux_nee')
          .select('id, nom, race, image_url, tag_rfid')
          .eq('sexe', 'Femelle')
          .eq('user_id', userId)
          .order('nom')
          .then((r) {
            final liste = List<Map<String, dynamic>>.from(r);
            for (var b in liste) b['source'] = 'nee';
            return liste;
          })
          .catchError((e) {
            debugPrint('⚠️ Brebis nées: $e');
            return <Map<String, dynamic>>[];
          }),
    ]);

    toutes = [...results[0], ...results[1]];
    debugPrint('📋 Total femelles chargées: ${toutes.length}');

    if (toutes.isEmpty) return [];

    // ── Étape 2 : UNE seule requête pour toutes les gestantes ──
    // On récupère tous les accouplements sans date_mise_bas
    // appartenant à cet éleveur — une seule fois pour tout le troupeau.
    Set<String> gestantesKeys = {};
    try {
      final accouplements = await supabase
          .from('accouplements')
          .select('brebis_id, source_brebis')
          .eq('user_id', userId)
          .isFilter('date_mise_bas', null);

      // ── Étape 3 : construire un Set de clés uniques ──
      // Clé composite : "source__id" → exemple "achete__42" ou "nee__uuid"
      // Utiliser __ comme séparateur pour éviter toute collision
      // (un id ne peut pas contenir "__")
      gestantesKeys = {
        for (final acc in accouplements)
          '${acc['source_brebis']}__${acc['brebis_id']}'
      };

      debugPrint('🤰 Brebis gestantes détectées: ${gestantesKeys.length}');
    } catch (e) {
      // Si la requête échoue (table manquante, erreur réseau),
      // on retourne toutes les brebis sans filtrage plutôt que bloquer.
      debugPrint('⚠️ Impossible de charger les gestantes: $e — toutes incluses');
      return toutes;
    }

    // ── Étape 4 : filtrage en mémoire O(1) par brebis ──
    // Set.contains() est O(1) — aucune requête réseau supplémentaire.
    final disponibles = toutes
        .where((b) => !gestantesKeys.contains(
              '${b['source']}__${b['id']}',
            ))
        .toList();

    debugPrint(
      '✅ Brebis disponibles: ${disponibles.length} '
      '(${toutes.length - disponibles.length} gestantes exclues)',
    );

    return disponibles;
  }

  // ── Chargement béliers — parallèle avec Future.wait ──────
  Future<List<Map<String, dynamic>>> _chargerBeliers(String userId) async {
    final results = await Future.wait([
      supabase
          .from('animal_acheter')
          .select('id, nom, race, tag_rfid, image_url')
          .eq('sexe', 'Mâle')
          .eq('user_id', userId)
          .order('nom')
          .then((r) {
            final liste = List<Map<String, dynamic>>.from(r);
            for (var b in liste) b['source'] = 'achete';
            return liste;
          })
          .catchError((e) {
            debugPrint('⚠️ Béliers achetés: $e');
            return <Map<String, dynamic>>[];
          }),

      supabase
          .from('nouveaux_nee')
          .select('id, nom, race, tag_rfid, image_url')
          .eq('sexe', 'Mâle')
          .eq('user_id', userId)
          .order('nom')
          .then((r) {
            final liste = List<Map<String, dynamic>>.from(r);
            for (var b in liste) b['source'] = 'nee';
            return liste;
          })
          .catchError((e) {
            debugPrint('⚠️ Béliers nés: $e');
            return <Map<String, dynamic>>[];
          }),
    ]);

    final tous = [...results[0], ...results[1]];
    debugPrint('🐏 Total béliers chargés: ${tous.length}');
    return tous;
  }

  // ──────────────────────────────────────────────────────────
  // 2. VÉRIFICATION CHALEUR (48h)
  // ──────────────────────────────────────────────────────────
  Future<void> _chargerInfosBrebis() async {
    if (_brebisSelectionnee == null) return;
    try {
      final chaleur = await supabase
          .from('chaleurs')
          .select('date_chaleur')
          .eq('animal_id', _brebisSelectionnee!['id'])
          .eq('source', _brebisSelectionnee!['source'])
          .order('date_chaleur', ascending: false)
          .limit(1)
          .maybeSingle();

      if (chaleur != null) {
        _derniereChaleur = DateTime.parse(chaleur['date_chaleur']);
        _chaleurRecente  =
            DateTime.now().difference(_derniereChaleur!).inHours <= 48;
      } else {
        _derniereChaleur = null;
        _chaleurRecente  = false;
      }
      if (mounted) setState(() {});
    } catch (e) {
      // La table "chaleurs" n'existe peut-être pas encore dans Supabase.
      // Ce catch est intentionnellement silencieux pour ne pas bloquer le flux,
      // mais on log l'erreur complète pour diagnostic.
      debugPrint('⚠️ Table chaleurs — erreur ou table manquante: $e');
      _derniereChaleur = null;
      _chaleurRecente  = false;
      if (mounted) setState(() {});
    }
  }

  // ──────────────────────────────────────────────────────────
  // 3. RÉINITIALISER ANALYSE IA
  // ──────────────────────────────────────────────────────────
  void _reinitialiserAnalyse() {
    setState(() {
      _resultatIa      = null;
      _analyseEffectuee = false;
    });
  }

  // ──────────────────────────────────────────────────────────
  // 4. ANALYSE IA CONSANGUINITÉ
  // ──────────────────────────────────────────────────────────
  Future<void> _analyserConsanguinite() async {
    if (_brebisSelectionnee == null || _belierSelectionne == null) {
      _showSnackBar(
          'Sélectionnez d\'abord une brebis et un bélier', Colors.orange);
      return;
    }
    setState(() { _analyseIaEnCours = true; _resultatIa = null; });

    final resultat = await _consanguiniteService.analyserCouple(
      brebis: _brebisSelectionnee!,
      belier: _belierSelectionne!,
    );

    setState(() {
      _resultatIa       = resultat;
      _analyseIaEnCours  = false;
      _analyseEffectuee  = true;
    });
  }

  // ──────────────────────────────────────────────────────────
  // 5–10. VALIDER ET ENREGISTRER
  // ──────────────────────────────────────────────────────────
  Future<void> _validerEtEnregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    if (_brebisSelectionnee == null) {
      _showSnackBar('Veuillez sélectionner une brebis', Colors.orange);
      return;
    }
    if (_belierSelectionne == null) {
      _showSnackBar('Veuillez sélectionner un bélier', Colors.orange);
      return;
    }

    // Confirmation si risque élevé
    if (_resultatIa != null && _resultatIa!.estRisque) {
      final ok = await _showConfirmationDialog(
        '⚠️ Risque de consanguinité détecté',
        'L\'IA a détecté un risque génétique élevé (F=${_resultatIa!.fPourcent.toStringAsFixed(1)}%).\n\n'
        'Relation : ${_resultatIa!.relation}\n\n'
        'Voulez-vous quand même enregistrer cet accouplement ?',
      );
      if (ok != true) return;
    }

    setState(() => _isLoading = true);

    try {
      final dateComplete = DateTime(
        _dateAccouplement.year,
        _dateAccouplement.month,
        _dateAccouplement.day,
        _heureAccouplement.hour,
        _heureAccouplement.minute,
      );

      final brebisId = _brebisSelectionnee!['id'] is String
          ? int.parse(_brebisSelectionnee!['id'])
          : _brebisSelectionnee!['id'] as int;
      final belierId = _belierSelectionne!['id'] is String
          ? int.parse(_belierSelectionne!['id'])
          : _belierSelectionne!['id'] as int;

      // Vérification métier
      final validation = await _businessService.peutAccoupler(
        brebisId         : brebisId,
        sourceBrebis     : _brebisSelectionnee!['source'],
        belierId         : belierId,
        sourceBelier     : _belierSelectionne!['source'],
        dateAccouplement : dateComplete,
      );

      if (!validation.isValid) {
        if (validation.severity == 'warning') {
          final ok = await _showConfirmationDialog('Attention', validation.message);
          if (ok != true) return;
        } else {
          _showErrorDialog('Accouplement impossible', validation.message);
          return;
        }
      }

      // Calcul fourchette agnelage
      final fourchette = _businessService.calculerFourchetteAgnelage(dateComplete);

      // Insertion Supabase avec colonnes IA complètes
      final result = await supabase.from('accouplements').insert({
        'brebis_id'            : _brebisSelectionnee!['id'],
        'source_brebis'        : _brebisSelectionnee!['source'],
        'belier_id'            : _belierSelectionne!['id'],
        'source_belier'        : _belierSelectionne!['source'],
        'date_accouplement'    : dateComplete.toIso8601String(),
        'heure_accouplement'   :
            '${_heureAccouplement.hour}:${_heureAccouplement.minute}',
        'methode'              : _methodeAccouplement,
        'date_prevue_agnelage' : fourchette['prevue']!.toIso8601String(),
        'date_min_agnelage'    : fourchette['min']!.toIso8601String(),
        'date_max_agnelage'    : fourchette['max']!.toIso8601String(),
        'notes'                : _notesController.text.trim(),
        'user_id'              : supabase.auth.currentUser!.id,
        'created_at'           : DateTime.now().toIso8601String(),
        // ── Colonnes IA enrichies ───────────────────────────
        'resultat_ia'          : _resultatIa?.resultat,
        'f_pourcent_ia'        : _resultatIa?.fPourcent,
        'f_wright_ia'          : _resultatIa?.fWright,
        'relation_ia'          : _resultatIa?.relation,
        'ancetres_communs_ia'  : _resultatIa?.ancetresCommuns.join(', '),
        'confiance_ia'         : _resultatIa?.confiance,
        'methode_ia'           : _resultatIa?.methode,
        'confiance_risque'     : _resultatIa?.confianceRisque,
        'confiance_acceptable' : _resultatIa?.confianceAcceptable,
        'message_ia'           : _resultatIa?.message,
        'action_ia'            : _resultatIa?.action,
      }).select('id').single();

      debugPrint('✅ Accouplement enregistré: ${result['id']}');

      // ★ Annuler alerte dernière chance — accouplement enregistré !
      await _notificationService.annulerAlerteDerniereChance(
        brebisId: _brebisSelectionnee!['id'],
        source  : _brebisSelectionnee!['source'],
      );

      // ★ Annuler TOUS les anciens rappels (chaleur + ancien cycle agnelage)
      //   AVANT de planifier les nouveaux — sinon les IDs seraient supprimés
      //   du registre juste après avoir été créés (Bug #1 corrigé).
      await _notificationService.annulerRappelsBrebis(
        brebisId: _brebisSelectionnee!['id'],
        source  : _brebisSelectionnee!['source'],
      );

      // ★ Programmer les nouveaux rappels agnelage (J-30, J-7, J-1)
      await _notificationService.planifierRappelsAgnelage(
        brebisId          : _brebisSelectionnee!['id'],
        nomBrebis         : _brebisSelectionnee!['nom'],
        datePrevueAgnelage: fourchette['prevue']!,
        source            : _brebisSelectionnee!['source'],
        accouplementId    : result['id'],
      );

      if (mounted) {
        await _showSuccessDialog(
          dateAccouplement: dateComplete,
          fourchette      : fourchette,
        );
      }
    } catch (e, stack) {
      debugPrint('❌ Enregistrement: $e\n$stack');
      if (mounted) _showSnackBar('❌ Erreur: ${e.toString()}', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ──────────────────────────────────────────────────────────
  // DIALOGS
  // ──────────────────────────────────────────────────────────
  Future<void> _showSuccessDialog({
    required DateTime dateAccouplement,
    required Map<String, DateTime> fourchette,
  }) async {
    return showDialog(
      context          : context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon : const Icon(Icons.check_circle, color: Colors.green, size: 64),
        title: const Text(
          'Accouplement enregistré',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize        : MainAxisSize.min,
            crossAxisAlignment  : CrossAxisAlignment.start,
            children: [
              // Récapitulatif couple
              _buildInfoBox(
                '🐑 Accouplement',
                '${_brebisSelectionnee!['nom']} × ${_belierSelectionne!['nom']}\n'
                'Date : ${_formatDateTime(dateAccouplement)}\n'
                'Méthode : $_methodeAccouplement',
                Color(ReproductionConfig.colorPrimary),
              ),
              const SizedBox(height: 12),

              // Badge IA enrichi
              if (_resultatIa != null)
                Container(
                  padding   : const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color       : _resultatIa!.estAcceptable
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border      : Border.all(
                      color: _resultatIa!.estAcceptable
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _resultatIa!.estAcceptable
                                ? Icons.check_circle
                                : Icons.warning,
                            color: _resultatIa!.estAcceptable
                                ? Colors.green
                                : Colors.red,
                            size : 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'IA : ${_resultatIa!.resultat} '
                            '(F = ${_resultatIa!.fPourcent.toStringAsFixed(1)}%)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize  : 13,
                              color     : _resultatIa!.estAcceptable
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      if (_resultatIa!.relation != 'Inconnu') ...[
                        const SizedBox(height: 4),
                        Text(
                          'Relation : ${_resultatIa!.relation}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                      if (_resultatIa!.ancetresCommuns.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Ancêtres communs : ${_resultatIa!.ancetresCommuns.join(', ')}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        'Fiabilité : ${_resultatIa!.confiance}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),

              // Fourchette agnelage
              _buildInfoBox(
                '📅 Agnelage prévu',
                'Date prévue : ${_formatDate(fourchette['prevue']!)}\n'
                'Fourchette : ${_formatDate(fourchette['min']!)} – '
                '${_formatDate(fourchette['max']!)}\n'
                '(Gestation : ${ReproductionConfig.gestationMoyenneJours} jours)',
                Colors.purple,
              ),
              const SizedBox(height: 12),

              // Rappels programmés
              Container(
                padding   : const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color       : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🔔 Rappels programmés :',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('• 1 mois avant : '
                      '${_formatDate(fourchette['prevue']!.subtract(const Duration(days: 30)))}'),
                    Text('• 1 semaine avant : '
                      '${_formatDate(fourchette['prevue']!.subtract(const Duration(days: 7)))}'),
                    Text('• 24h avant : '
                      '${_formatDate(fourchette['prevue']!.subtract(const Duration(days: 1)))}'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
  }

  Future<void> _showErrorDialog(String titre, String message) async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon   : const Icon(Icons.error, color: Colors.red, size: 64),
        title  : Text(titre),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child    : const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showConfirmationDialog(
      String titre, String message) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon   : const Icon(Icons.warning, color: Colors.orange, size: 64),
        title  : Text(titre),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child    : const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style    : ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // UTILITAIRES
  // ──────────────────────────────────────────────────────────
  /// Avatar circulaire avec photo (si image_url dispo) ou icône fallback.
  Widget _buildAnimalAvatar({
    required String? imageUrl,
    required IconData fallbackIcon,
    required Color    color,
    double radius = 24,
  }) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CircleAvatar(
        radius          : radius,
        backgroundColor : color.withOpacity(0.1),
        child           : ClipOval(
          child: Image.network(
            imageUrl,
            width     : radius * 2,
            height    : radius * 2,
            fit       : BoxFit.cover,
            errorBuilder: (_, __, ___) => Icon(
              fallbackIcon,
              color : color,
              size  : radius,
            ),
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : SizedBox(
                    width : radius * 2,
                    height: radius * 2,
                    child : CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color      : color,
                    ),
                  ),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius         : radius,
      backgroundColor: color.withOpacity(0.1),
      child          : Icon(fallbackIcon, color: color, size: radius),
    );
  }

  Widget _buildInfoBox(String titre, String contenu, Color color) {
    return Container(
      padding   : const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color       : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border      : Border.all(color: color, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titre,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: 14)),
          const SizedBox(height: 6),
          Text(contenu, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content        : Text(message),
        backgroundColor: color,
        duration       : const Duration(seconds: 2),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatDateTime(DateTime d) =>
      '${_formatDate(d)} à ${d.hour}h${d.minute.toString().padLeft(2, '0')}';

  // ──────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title          : const Text('Enregistrer un accouplement'),
        backgroundColor: Color(ReproductionConfig.colorSecondary),
        foregroundColor: Colors.white,
      ),
      body: _isLoadingAnimaux
          ? const Center(child: CircularProgressIndicator())
          : _isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Enregistrement en cours...'),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child : Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Sélection brebis ──────────────
                        _buildSelectionBrebis(),
                        if (_brebisSelectionnee != null && !_chaleurRecente)
                          _buildAvertissementChaleur(),
                        const SizedBox(height: 16),

                        // ── Sélection bélier ──────────────
                        _buildSelectionBelier(),
                        const SizedBox(height: 16),

                        // ── Analyse IA ────────────────────
                        _buildSectionAnalyseIA(),
                        const SizedBox(height: 24),

                        // ── Détails accouplement ──────────
                        const Text(
                          'Détails de l\'accouplement',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _buildDatePicker(),
                        const SizedBox(height: 16),
                        _buildTimePicker(),
                        const SizedBox(height: 16),
                        _buildMethodeDropdown(),
                        const SizedBox(height: 16),
                        _buildNotesField(),
                        const SizedBox(height: 32),

                        // ── Bouton enregistrer ────────────
                        _buildSubmitButton(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // WIDGETS SECTION
  // ──────────────────────────────────────────────────────────

  Widget _buildSelectionBrebis() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child  : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.female,
                    color: Color(ReproductionConfig.colorPrimary)),
                const SizedBox(width: 8),
                const Text('Sélectionner la brebis',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),

            // ── Champ saisie + autocomplétion ─────────────────
            Autocomplete<Map<String, dynamic>>(
              displayStringForOption: (b) => '${b['nom']} (${b['race']})',

              initialValue: _brebisSelectionnee != null
                  ? TextEditingValue(
                      text:
                          '${_brebisSelectionnee!['nom']} (${_brebisSelectionnee!['race']})',
                    )
                  : null,

              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return _brebisDisponibles;
                }
                final query = textEditingValue.text.toLowerCase();
                return _brebisDisponibles.where((b) {
                  final nom  = (b['nom']  ?? '').toString().toLowerCase();
                  final race = (b['race'] ?? '').toString().toLowerCase();
                  final rfid = (b['tag_rfid'] ?? '').toString().toLowerCase();
                  return nom.contains(query) ||
                         race.contains(query) ||
                         rfid.contains(query);
                });
              },

              optionsViewBuilder: (context, onSelected, options) {
                final primaryColor = Color(ReproductionConfig.colorPrimary);
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation    : 6,
                    borderRadius : BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: 280,
                        maxWidth : MediaQuery.of(context).size.width - 64,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ListView.separated(
                          padding    : EdgeInsets.zero,
                          shrinkWrap : true,
                          itemCount  : options.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color : Colors.grey.shade200,
                          ),
                          itemBuilder: (ctx, index) {
                            final brebis = options.elementAt(index);
                            final estSelectionnee =
                                _brebisSelectionnee?['id']?.toString() ==
                                brebis['id']?.toString();
                            return InkWell(
                              onTap: () => onSelected(brebis),
                              child: Container(
                                color  : estSelectionnee
                                    ? primaryColor.withOpacity(0.07)
                                    : Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    // ── Photo ou icône ──────
                                    _buildAnimalAvatar(
                                      imageUrl    : brebis['image_url'],
                                      fallbackIcon: Icons.female,
                                      color       : primaryColor,
                                      radius      : 22,
                                    ),
                                    const SizedBox(width: 12),
                                    // ── Nom + race ──────────
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            brebis['nom'] ?? '—',
                                            style: TextStyle(
                                              fontSize  : 14,
                                              fontWeight: estSelectionnee
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                          if ((brebis['race'] ?? '')
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              brebis['race'],
                                              style: TextStyle(
                                                fontSize: 12,
                                                color   : Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    // ── Coche si sélectionnée ─
                                    if (estSelectionnee)
                                      Icon(Icons.check_circle,
                                          color: primaryColor, size: 20),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },

              fieldViewBuilder: (
                context,
                textEditingController,
                focusNode,
                onFieldSubmitted,
              ) {
                return TextFormField(
                  controller: textEditingController,
                  focusNode : focusNode,
                  decoration: InputDecoration(
                    border    : const OutlineInputBorder(),
                    hintText  : 'Chercher ou saisir le nom de la brebis...',
                    prefixIcon: Icon(Icons.search,
                        color: Color(ReproductionConfig.colorPrimary)),
                    suffixIcon: _brebisSelectionnee != null
                        ? IconButton(
                            icon    : const Icon(Icons.clear, size: 18),
                            tooltip : 'Effacer',
                            onPressed: () {
                              textEditingController.clear();
                              setState(() {
                                _brebisSelectionnee = null;
                                _derniereChaleur    = null;
                                _chaleurRecente     = false;
                                _reinitialiserAnalyse();
                              });
                            },
                          )
                        : null,
                  ),
                  onFieldSubmitted: (_) => onFieldSubmitted(),
                  validator: (_) =>
                      _brebisSelectionnee == null ? 'Champ requis' : null,
                );
              },

              onSelected: (brebis) async {
                setState(() {
                  _brebisSelectionnee = brebis;
                  _reinitialiserAnalyse();
                  _derniereChaleur = null;
                  _chaleurRecente  = false;
                });
                await _chargerInfosBrebis();
              },
            ),

            // Bandeau chaleur
            if (_derniereChaleur != null) ...[
              const SizedBox(height: 8),
              Container(
                padding   : const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color       : _chaleurRecente
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _chaleurRecente ? Icons.check_circle : Icons.info,
                      color: _chaleurRecente ? Colors.green : Colors.orange,
                      size : 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _chaleurRecente
                            ? '✅ Chaleur récente '
                              '(${DateTime.now().difference(_derniereChaleur!).inHours}h)'
                            : '⚠️ Dernière chaleur : ${_formatDate(_derniereChaleur!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color   : _chaleurRecente
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvertissementChaleur() {
    return Container(
      margin    : const EdgeInsets.only(top: 16),
      padding   : const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color       : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border      : Border.all(color: Colors.orange, width: 2),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning, color: Colors.orange, size: 30),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '⚠️ Aucune chaleur enregistrée dans les dernières 48h.\n'
              'Il est recommandé d\'accoupler pendant la chaleur.',
              style: TextStyle(
                  color: Colors.orange, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionBelier() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child  : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.male, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text('Sélectionner le bélier',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),

            // ── Champ saisie + autocomplétion ─────────────────
            Autocomplete<Map<String, dynamic>>(
              // Affiche le nom du bélier sélectionné dans le champ
              displayStringForOption: (b) => '${b['nom']} (${b['race']})',

              // Valeur initiale si un bélier est déjà sélectionné
              initialValue: _belierSelectionne != null
                  ? TextEditingValue(
                      text:
                          '${_belierSelectionne!['nom']} (${_belierSelectionne!['race']})',
                    )
                  : null,

              // Filtrage des suggestions selon la saisie
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return _beliersDisponibles; // affiche tout si vide
                }
                final query = textEditingValue.text.toLowerCase();
                return _beliersDisponibles.where((b) {
                  final nom   = (b['nom']  ?? '').toString().toLowerCase();
                  final race  = (b['race'] ?? '').toString().toLowerCase();
                  final rfid  = (b['tag_rfid'] ?? '').toString().toLowerCase();
                  return nom.contains(query) ||
                         race.contains(query) ||
                         rfid.contains(query);
                });
              },

              // Rendu de chaque suggestion dans la liste déroulante
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation    : 6,
                    borderRadius : BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: 280,
                        maxWidth : MediaQuery.of(context).size.width - 64,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ListView.separated(
                          padding    : EdgeInsets.zero,
                          shrinkWrap : true,
                          itemCount  : options.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color : Colors.grey.shade200,
                          ),
                          itemBuilder: (ctx, index) {
                            final belier = options.elementAt(index);
                            final estSelectionne =
                                _belierSelectionne?['id']?.toString() ==
                                belier['id']?.toString();
                            return InkWell(
                              onTap: () => onSelected(belier),
                              child: Container(
                                color  : estSelectionne
                                    ? Colors.blue.shade50
                                    : Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    // ── Photo ou icône ──────
                                    _buildAnimalAvatar(
                                      imageUrl    : belier['image_url'],
                                      fallbackIcon: Icons.male,
                                      color       : Colors.blue.shade700,
                                      radius      : 22,
                                    ),
                                    const SizedBox(width: 12),
                                    // ── Nom + race ──────────
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            belier['nom'] ?? '—',
                                            style: TextStyle(
                                              fontSize  : 14,
                                              fontWeight: estSelectionne
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                          if ((belier['race'] ?? '')
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              belier['race'],
                                              style: TextStyle(
                                                fontSize: 12,
                                                color   : Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    // ── Coche si sélectionné ─
                                    if (estSelectionne)
                                      Icon(Icons.check_circle,
                                          color: Colors.blue.shade700,
                                          size : 20),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },

              // Champ de saisie
              fieldViewBuilder: (
                context,
                textEditingController,
                focusNode,
                onFieldSubmitted,
              ) {
                return TextFormField(
                  controller: textEditingController,
                  focusNode : focusNode,
                  decoration: InputDecoration(
                    border     : const OutlineInputBorder(),
                    hintText   : 'Chercher ou saisir le nom du bélier...',
                    prefixIcon : Icon(Icons.search,
                        color: Colors.blue.shade700),
                    suffixIcon : _belierSelectionne != null
                        ? IconButton(
                            icon    : const Icon(Icons.clear, size: 18),
                            tooltip : 'Effacer',
                            onPressed: () {
                              textEditingController.clear();
                              setState(() {
                                _belierSelectionne = null;
                                _reinitialiserAnalyse();
                              });
                            },
                          )
                        : null,
                  ),
                  onFieldSubmitted: (_) => onFieldSubmitted(),
                  validator: (_) =>
                      _belierSelectionne == null ? 'Champ requis' : null,
                );
              },

              // Quand l'utilisateur sélectionne une suggestion
              onSelected: (belier) {
                setState(() {
                  _belierSelectionne = belier;
                  _reinitialiserAnalyse();
                });
              },
            ),

            // Bandeau récapitulatif du bélier sélectionné
            if (_belierSelectionne != null) ...[
              const SizedBox(height: 8),
              Container(
                padding   : const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color       : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border      : Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: Colors.blue.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_belierSelectionne!['nom']} · '
                        '${_belierSelectionne!['race'] ?? ''}'
                        '${_belierSelectionne!['tag_rfid'] != null ? ' · RFID: ${_belierSelectionne!['tag_rfid']}' : ''}',
                        style: TextStyle(
                          fontSize  : 12,
                          color     : Colors.blue.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionAnalyseIA() {
    final deuxSelectionnes =
        _brebisSelectionnee != null && _belierSelectionne != null;

    Color couleurBord;
    if (_resultatIa == null) {
      couleurBord = Colors.purple.shade200;
    } else if (_resultatIa!.estAcceptable) {
      couleurBord = Colors.green;
    } else if (_resultatIa!.estModere) {
      couleurBord = Colors.orange;
    } else {
      couleurBord = Colors.red;
    }

    return Card(
      elevation: 2,
      shape    : RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side        : BorderSide(color: couleurBord, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child  : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre
            Row(
              children: [
                Container(
                  padding   : const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color       : Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.psychology,
                      color: Colors.purple, size: 24),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Analyse IA — Consanguinité',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Détecte les risques génétiques avant accouplement',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Bouton analyser
            if (!_analyseEffectuee || _resultatIa?.estErreur == true)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: deuxSelectionnes && !_analyseIaEnCours
                      ? _analyserConsanguinite
                      : null,
                  icon : _analyseIaEnCours
                      ? const SizedBox(
                          width : 18,
                          height: 18,
                          child : CircularProgressIndicator(
                            color      : Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.biotech),
                  label: Text(
                    _analyseIaEnCours
                        ? 'Analyse en cours...'
                        : deuxSelectionnes
                            ? 'Analyser la consanguinité'
                            : 'Sélectionnez brebis et bélier d\'abord',
                    style: const TextStyle(fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding        : const EdgeInsets.symmetric(vertical: 12),
                    shape          : RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

            // Résultat IA
            if (_resultatIa != null && !_resultatIa!.estErreur) ...[
              const SizedBox(height: 12),
              ResultatConsanguiniteWidget(
                resultat   : _resultatIa!,
                onContinuer: null,
                onAnnuler  : _resultatIa!.estRisque
                    ? () => setState(() {
                          _resultatIa       = null;
                          _analyseEffectuee  = false;
                        })
                    : null,
              ),
              TextButton.icon(
                onPressed: _reinitialiserAnalyse,
                icon     : const Icon(Icons.refresh, size: 16),
                label    : const Text('Relancer l\'analyse'),
                style    : TextButton.styleFrom(
                  foregroundColor: Colors.grey,
                  padding        : EdgeInsets.zero,
                ),
              ),
            ],

            // Message erreur
            if (_resultatIa != null && _resultatIa!.estErreur) ...[
              const SizedBox(height: 8),
              Container(
                padding   : const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color       : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _resultatIa!.message,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return Card(
      child: ListTile(
        leading : Icon(Icons.calendar_today,
            color: Color(ReproductionConfig.colorSecondary)),
        title   : const Text('Date d\'accouplement'),
        subtitle: Text(_formatDate(_dateAccouplement)),
        trailing: const Icon(Icons.chevron_right),
        onTap   : () async {
          final d = await showDatePicker(
            context    : context,
            initialDate: _dateAccouplement,
            firstDate  : DateTime.now().subtract(const Duration(days: 7)),
            lastDate   : DateTime.now(),
          );
          if (d != null && mounted) setState(() => _dateAccouplement = d);
        },
      ),
    );
  }

  Widget _buildTimePicker() {
    return Card(
      child: ListTile(
        leading : Icon(Icons.access_time,
            color: Color(ReproductionConfig.colorSecondary)),
        title   : const Text('Heure'),
        subtitle: Text(
          '${_heureAccouplement.hour}h'
          '${_heureAccouplement.minute.toString().padLeft(2, '0')}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap   : () async {
          final t = await showTimePicker(
            context    : context,
            initialTime: _heureAccouplement,
          );
          if (t != null && mounted) setState(() => _heureAccouplement = t);
        },
      ),
    );
  }

  Widget _buildMethodeDropdown() {
    return DropdownButtonFormField<String>(
      value     : _methodeAccouplement,
      decoration: InputDecoration(
        labelText  : 'Méthode d\'accouplement',
        border     : const OutlineInputBorder(),
        prefixIcon : Icon(Icons.sync,
            color: Color(ReproductionConfig.colorSecondary)),
      ),
      items: const [
        DropdownMenuItem(value: 'Naturel', child: Text('Naturel')),
        DropdownMenuItem(
          value: 'Insémination artificielle',
          child: Text('Insémination artificielle'),
        ),
      ],
      onChanged: (v) => setState(() => _methodeAccouplement = v!),
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      maxLines  : 3,
      decoration: InputDecoration(
        labelText : 'Notes (optionnel)',
        hintText  : 'Observations...',
        border    : const OutlineInputBorder(),
        prefixIcon: Icon(Icons.notes,
            color: Color(ReproductionConfig.colorSecondary)),
      ),
    );
  }

  Widget _buildSubmitButton() {
    final estRisque   = _resultatIa != null && _resultatIa!.estRisque;
    final couleur     = estRisque
        ? Colors.orange
        : Color(ReproductionConfig.colorSecondary);
    final label       = estRisque
        ? 'Enregistrer malgré le risque'
        : 'Enregistrer l\'accouplement';

    return SizedBox(
      width : double.infinity,
      height: 52,
      child : ElevatedButton.icon(
        onPressed: _isLoading ? null : _validerEtEnregistrer,
        icon     : _isLoading
            ? const SizedBox(
                width : 20,
                height: 20,
                child : CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.check_circle),
        label: Text(
          _isLoading ? 'Enregistrement...' : label,
          style: const TextStyle(fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: couleur,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}