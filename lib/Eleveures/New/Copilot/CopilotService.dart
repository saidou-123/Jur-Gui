// ============================================================
// LADOUM COPILOT SERVICE — v2 (colonnes réelles Supabase)
// Chemin : lib/Eleveures/New/Copilot/CopilotService.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// MODÈLE MESSAGE
// ============================================================

enum RoleMessage { user, assistant }

class CopilotMessage {
  final RoleMessage role;
  final String contenu;
  final DateTime horodatage;

  const CopilotMessage({
    required this.role,
    required this.contenu,
    required this.horodatage,
  });

  Map<String, String> toApiMap() => {
        'role': role == RoleMessage.user ? 'user' : 'assistant',
        'content': contenu,
      };
}

// ============================================================
// CONTEXTE BUILDER — utilise les vraies colonnes Supabase
// ============================================================

class CopilotContextBuilder {
  final _supabase = Supabase.instance.client;

  Future<String> construire() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return "Utilisateur non connecté.";

    try {
      // ── Toutes les requêtes en parallèle ─────────────────
      final resultats = await Future.wait([
        _chargerBrebis(userId),
        _chargerBeliers(userId),
        _chargerChaleurs(userId),
        _chargerAccouplements(userId),
        _chargerAlertesActives(userId),
        _chargerRappelsReproduction(userId),
        _chargerVaccinations(userId),
        _chargerAlertesSante(userId),
        _chargerAgneaux(userId),
      ]);

      final brebis        = resultats[0] as List<Map<String, dynamic>>;
      final beliers       = resultats[1] as List<Map<String, dynamic>>;
      final chaleurs      = resultats[2] as List<Map<String, dynamic>>;
      final accouplements = resultats[3] as List<Map<String, dynamic>>;
      final alertes       = resultats[4] as List<Map<String, dynamic>>;
      final rappels       = resultats[5] as List<Map<String, dynamic>>;
      final vaccinations  = resultats[6] as List<Map<String, dynamic>>;
      final alertesSante  = resultats[7] as List<Map<String, dynamic>>;
      final agneaux       = resultats[8] as List<Map<String, dynamic>>;

      final now    = DateTime.now();
      final buffer = StringBuffer();

      // ── En-tête ──────────────────────────────────────────
      buffer.writeln("DATE : ${_fmt(now)} | SAISON : ${_saison(now.month)}");
      buffer.writeln("TROUPEAU : ${brebis.length} brebis | ${beliers.length} béliers");
      buffer.writeln();

      // ── Statistiques rapides ──────────────────────────────
      final nbGestantes = brebis.where((b) =>
          _estGestante(accouplements, b['id'], b['source']) != null).length;
      final nbChaleursCeMois = chaleurs.where((c) {
        final d = DateTime.tryParse(c['date_chaleur'] ?? '');
        return d != null && d.month == now.month && d.year == now.year;
      }).length;
      final nbAgnelages30j = accouplements.where((a) {
        if (a['date_mise_bas'] != null) return false;
        final d = DateTime.tryParse(a['date_prevue_agnelage'] ?? '');
        if (d == null) return false;
        return d.isAfter(now) && d.isBefore(now.add(const Duration(days: 30)));
      }).length;

      buffer.writeln("=== STATISTIQUES ===");
      buffer.writeln("Brebis gestantes : $nbGestantes");
      buffer.writeln("Chaleurs ce mois : $nbChaleursCeMois");
      buffer.writeln("Agnelages prévus 30j : $nbAgnelages30j");
      buffer.writeln();

      // ── Détail brebis ─────────────────────────────────────
      buffer.writeln("=== BREBIS ===");
      for (final b in brebis) {
        final nom = b['nom'] ?? 'Sans nom';
        final id  = b['id'];
        final src = b['source'] as String;

        final gestante   = _estGestante(accouplements, id, src);
        final enChaleur  = _enChaleurRecente(chaleurs, id, src, now);
        final dernChdr   = _derniereChaleur(chaleurs, id, src);
        final prochChdr  = dernChdr?.add(const Duration(days: 17));
        final nbAcc      = _nbAccouplements(accouplements, id, src);
        final nbAgn      = _nbAgnelages(accouplements, id, src);
        final taux       = _tauxFertilite(accouplements, id, src);
        final couleur    = b['couleur'] ?? '';
        final gabarit    = b['gabarit'] ?? '';
        final scoreSante = b['score_sante'] != null
            ? '${(b['score_sante'] * 100).round()}%'
            : 'N/A';
        final ageTexte   = _calculerAge(b['date_naissance'], now);

        buffer.write("• $nom");
        if (ageTexte != null) buffer.write(" ($ageTexte)");
        if (gestante != null) {
          final j = gestante.difference(now).inDays;
          buffer.write(" [GESTANTE — agnelage dans ${j}j le ${_fmt(gestante)}]");
        } else if (enChaleur) {
          buffer.write(" [EN CHALEUR MAINTENANT ⚡]");
        } else if (prochChdr != null) {
          final dans = prochChdr.difference(now).inDays;
          buffer.write(dans >= 0
              ? " [prochaine chaleur ~dans ${dans}j]"
              : " [chaleur attendue, retard ${-dans}j]");
        } else {
          buffer.write(" [aucune chaleur enregistrée]");
        }

        buffer.write(" | accouplements:$nbAcc agnelages:$nbAgn");
        buffer.write(" fertilité:${taux.toStringAsFixed(0)}%");
        if (couleur.isNotEmpty) buffer.write(" couleur:$couleur");
        if (gabarit.isNotEmpty) buffer.write(" gabarit:$gabarit");
        buffer.write(" santé:$scoreSante");
        buffer.writeln();
      }
      buffer.writeln();

      // ── Béliers ──────────────────────────────────────────
      buffer.writeln("=== BÉLIERS ===");
      for (final b in beliers) {
        final couleur = b['couleur'] ?? '';
        final gabarit = b['gabarit'] ?? '';
        buffer.write("• ${b['nom'] ?? 'Sans nom'} (${b['source']})");
        if (couleur.isNotEmpty) buffer.write(" couleur:$couleur");
        if (gabarit.isNotEmpty) buffer.write(" gabarit:$gabarit");
        buffer.writeln();
      }
      buffer.writeln();

      // ── Alertes actives (cycle) ───────────────────────────
      if (alertes.isNotEmpty) {
        buffer.writeln("=== ALERTES CYCLE ACTIVES ===");
        for (final a in alertes) {
          buffer.writeln(
              "⚠️ ${a['nom_animal']} — ${a['type_alerte']} : ${a['message']}");
        }
        buffer.writeln();
      }

      // ── Alertes santé actives ──────────────────────────────
      if (alertesSante.isNotEmpty) {
        buffer.writeln("=== ALERTES SANTÉ ACTIVES ===");
        for (final a in alertesSante) {
          final priorite = a['priorite'] ?? 'normale';
          buffer.writeln(
              "🏥 [${priorite.toString().toUpperCase()}] ${a['type_alerte']} : ${a['message']}");
        }
        buffer.writeln();
      }

      // ── Rappels de reproduction à venir ────────────────────
      final rappelsAVenir = rappels.where((r) {
        final d = DateTime.tryParse(r['date_rappel'] ?? '');
        return d != null &&
            r['statut'] == 'planifie' &&
            d.isAfter(now.subtract(const Duration(days: 1)));
      }).toList()
        ..sort((a, b) => (a['date_rappel'] as String)
            .compareTo(b['date_rappel'] as String));

      if (rappelsAVenir.isNotEmpty) {
        buffer.writeln("=== RAPPELS DE REPRODUCTION (à venir) ===");
        for (final r in rappelsAVenir.take(15)) {
          final d = DateTime.tryParse(r['date_rappel']);
          final dStr = d != null ? _fmt(d) : '?';
          buffer.writeln("📅 $dStr — ${r['type']} : ${r['message']}");
        }
        buffer.writeln();
      }

      // ── Vaccinations ────────────────────────────────────────
      if (vaccinations.isNotEmpty) {
        buffer.writeln("=== VACCINATIONS ===");
        for (final v in vaccinations) {
          final dVac = DateTime.tryParse(v['date_vaccination'] ?? '');
          final dRap = DateTime.tryParse(v['date_rappel'] ?? '');
          buffer.write("💉 ${v['nom_vaccin']}");
          if (dVac != null) buffer.write(" — fait le ${_fmt(dVac)}");
          if (dRap != null) {
            final j = dRap.difference(now).inDays;
            if (j < 0) {
              buffer.write(" [RAPPEL EN RETARD de ${-j}j]");
            } else if (j <= 30) {
              buffer.write(" [rappel dans ${j}j le ${_fmt(dRap)}]");
            } else {
              buffer.write(" [prochain rappel : ${_fmt(dRap)}]");
            }
          }
          buffer.writeln();
        }
        buffer.writeln();
      }

      // ── Agneaux nés ──────────────────────────────────────────
      if (agneaux.isNotEmpty) {
        buffer.writeln("=== AGNEAUX NÉS ===");
        for (final a in agneaux) {
          final d = DateTime.tryParse(a['date_naissance'] ?? '');
          final nom = a['nom'] ?? 'Sans nom';
          final sexe = a['sexe'] ?? '';
          final etat = a['etat_naissance'] ?? 'vivant';
          final poids = a['poids_naissance'];
          buffer.write("🐑 $nom ($sexe)");
          if (d != null) buffer.write(" né le ${_fmt(d)}");
          if (poids != null) buffer.write(" — ${poids}kg");
          if (etat != 'vivant') buffer.write(" [$etat]");
          buffer.writeln();
        }
        buffer.writeln();
      }

      return buffer.toString();
    } catch (e) {
      debugPrint('❌ CopilotContextBuilder: $e');
      return "Erreur chargement données troupeau: $e";
    }
  }

  // ── Requêtes Supabase avec vraies colonnes ────────────────

  Future<List<Map<String, dynamic>>> _chargerBrebis(String userId) async {
    // animal_acheter n'a PAS date_naissance — on prend les colonnes disponibles
    final achetes = await _supabase
        .from('animal_acheter')
        .select('id, nom, sexe, race, couleur, gabarit, score_sante, statut')
        .eq('user_id', userId)
        .eq('sexe', 'Femelle')
        .eq('statut', 'actif');

    // nouveaux_nee HAS date_naissance
    final nees = await _supabase
        .from('nouveaux_nee')
        .select('id, nom, sexe, race, date_naissance, couleur, gabarit, score_sante, statut')
        .eq('user_id', userId)
        .eq('sexe', 'Femelle')
        .eq('statut', 'actif');

    return [
      ...List<Map<String, dynamic>>.from(achetes)
          .map((b) => {...b, 'source': 'achete'}),
      ...List<Map<String, dynamic>>.from(nees)
          .map((b) => {...b, 'source': 'nee'}),
    ];
  }

  Future<List<Map<String, dynamic>>> _chargerBeliers(String userId) async {
    final achetes = await _supabase
        .from('animal_acheter')
        .select('id, nom, couleur, gabarit')
        .eq('user_id', userId)
        .eq('sexe', 'Mâle')
        .eq('statut', 'actif');

    final nees = await _supabase
        .from('nouveaux_nee')
        .select('id, nom, couleur, gabarit')
        .eq('user_id', userId)
        .eq('sexe', 'Mâle')
        .eq('statut', 'actif');

    return [
      ...List<Map<String, dynamic>>.from(achetes)
          .map((b) => {...b, 'source': 'achete'}),
      ...List<Map<String, dynamic>>.from(nees)
          .map((b) => {...b, 'source': 'nee'}),
    ];
  }

  Future<List<Map<String, dynamic>>> _chargerChaleurs(String userId) async {
    final r = await _supabase
        .from('chaleurs')
        .select('animal_id, source, date_chaleur, intensite')
        .eq('user_id', userId)
        .order('date_chaleur', ascending: false)
        .limit(200);
    return List<Map<String, dynamic>>.from(r);
  }

  Future<List<Map<String, dynamic>>> _chargerAccouplements(String userId) async {
    final r = await _supabase
        .from('accouplements')
        .select('brebis_id, source_brebis, date_accouplement, '
            'date_prevue_agnelage, date_mise_bas, nombre_agneaux, '
            'resultat_ia, f_pourcent_ia')
        .eq('user_id', userId)
        .order('date_accouplement', ascending: false);
    return List<Map<String, dynamic>>.from(r);
  }

  Future<List<Map<String, dynamic>>> _chargerAlertesActives(String userId) async {
    final r = await _supabase
        .from('alertes_cycle')
        .select('nom_animal, type_alerte, message, suggestion')
        .eq('user_id', userId)
        .eq('statut', 'active')
        .limit(10);
    return List<Map<String, dynamic>>.from(r);
  }

  /// Rappels de reproduction planifiés (chaleurs, agnelages, sevrages, etc.)
  Future<List<Map<String, dynamic>>> _chargerRappelsReproduction(String userId) async {
    try {
      final r = await _supabase
          .from('rappels_reproduction')
          .select('type, animal_id, source, date_rappel, message, statut')
          .eq('user_id', userId)
          .eq('statut', 'planifie')
          .order('date_rappel', ascending: true)
          .limit(30);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      debugPrint('⚠️ _chargerRappelsReproduction: $e');
      return [];
    }
  }

  /// Vaccinations enregistrées (table peut être vide si non utilisée encore)
  Future<List<Map<String, dynamic>>> _chargerVaccinations(String userId) async {
    try {
      final r = await _supabase
          .from('vaccinations')
          .select('animal_id, source, nom_vaccin, date_vaccination, date_rappel, observations')
          .order('date_vaccination', ascending: false)
          .limit(50);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      debugPrint('⚠️ _chargerVaccinations: $e');
      return [];
    }
  }

  /// Alertes santé non résolues (vaccin expiré, suivi requis, etc.)
  Future<List<Map<String, dynamic>>> _chargerAlertesSante(String userId) async {
    try {
      final r = await _supabase
          .from('alertes_sante')
          .select('animal_id, source, type_alerte, message, priorite, date_echeance')
          .eq('resolue', false)
          .order('priorite', ascending: false)
          .limit(20);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      debugPrint('⚠️ _chargerAlertesSante: $e');
      return [];
    }
  }

  /// Agneaux nés récemment (table peut être vide si non utilisée encore)
  Future<List<Map<String, dynamic>>> _chargerAgneaux(String userId) async {
    try {
      final r = await _supabase
          .from('agneaux')
          .select('nom, sexe, poids_naissance, date_naissance, etat_naissance, race')
          .eq('user_id', userId)
          .order('date_naissance', ascending: false)
          .limit(20);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      debugPrint('⚠️ _chargerAgneaux: $e');
      return [];
    }
  }

  // ── Helpers ───────────────────────────────────────────────

  DateTime? _estGestante(List accouplements, dynamic id, String src) {
    final acc = accouplements.firstWhere(
      (a) => a['brebis_id'].toString() == id.toString() &&
          a['source_brebis'] == src &&
          a['date_mise_bas'] == null &&
          a['date_prevue_agnelage'] != null,
      orElse: () => <String, dynamic>{},
    );
    if ((acc as Map).isEmpty) return null;
    return DateTime.tryParse(acc['date_prevue_agnelage']);
  }

  bool _enChaleurRecente(List chaleurs, dynamic id, String src, DateTime now) {
    final il48h = now.subtract(const Duration(hours: 48));
    return chaleurs.any((c) =>
        c['animal_id'].toString() == id.toString() &&
        c['source'] == src &&
        DateTime.tryParse(c['date_chaleur'] ?? '')?.isAfter(il48h) == true);
  }

  DateTime? _derniereChaleur(List chaleurs, dynamic id, String src) {
    final liste = chaleurs
        .where((c) =>
            c['animal_id'].toString() == id.toString() && c['source'] == src)
        .toList();
    if (liste.isEmpty) return null;
    return DateTime.tryParse(liste.first['date_chaleur'] ?? '');
  }

  double _tauxFertilite(List accouplements, dynamic id, String src) {
    final mine = accouplements
        .where((a) =>
            a['brebis_id'].toString() == id.toString() &&
            a['source_brebis'] == src)
        .toList();
    if (mine.isEmpty) return 0;
    final reussis = mine.where((a) => a['date_mise_bas'] != null).length;
    return reussis / mine.length * 100;
  }

  int _nbAccouplements(List accouplements, dynamic id, String src) =>
      accouplements
          .where((a) =>
              a['brebis_id'].toString() == id.toString() &&
              a['source_brebis'] == src)
          .length;

  int _nbAgnelages(List accouplements, dynamic id, String src) =>
      accouplements
          .where((a) =>
              a['brebis_id'].toString() == id.toString() &&
              a['source_brebis'] == src &&
              a['date_mise_bas'] != null)
          .length;

  /// Calcule l'âge d'un animal à partir de sa date de naissance (si connue).
  /// Retourne null si la date est absente (ex: animal_acheter sans date_naissance).
  String? _calculerAge(dynamic dateNaissance, DateTime now) {
    if (dateNaissance == null) return null;
    final d = DateTime.tryParse(dateNaissance.toString());
    if (d == null) return null;

    final joursTotal = now.difference(d).inDays;
    if (joursTotal < 0) return null;

    if (joursTotal < 30) return '${joursTotal}j';
    if (joursTotal < 365) {
      final mois = (joursTotal / 30).floor();
      return '${mois} mois';
    }
    final ans = (joursTotal / 365).floor();
    final moisRestants = ((joursTotal % 365) / 30).floor();
    return moisRestants > 0 ? '${ans}an ${moisRestants}m' : '${ans}an';
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _saison(int m) {
    if (m >= 9 || m <= 2) return 'saison active (chaleurs normales)';
    if (m >= 6 && m <= 8) return 'anœstrus saisonnier (chaleurs rares)';
    return 'saison de transition';
  }
}

// ============================================================
// COPILOT SERVICE
// ============================================================

class CopilotService {
  static final CopilotService _instance = CopilotService._internal();
  factory CopilotService() => _instance;
  CopilotService._internal() {
    // 🔒 Écouter les changements d'authentification
    // Si un éleveur se déconnecte ou un autre se connecte → cache vidé immédiatement
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedOut ||
          event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.userUpdated) {
        reinitialiser();
        debugPrint('🔒 CopilotService: cache vidé (événement: $event)');
      }
    });
  }

  final _supabase       = Supabase.instance.client;
  final _contextBuilder = CopilotContextBuilder();

  final List<CopilotMessage> _historique = [];
  String?   _contexteCache;
  DateTime? _dernierChargement;
  String?   _userIdCache; // 🔒 Mémorise l'utilisateur propriétaire du cache

  List<CopilotMessage> get historique => List.unmodifiable(_historique);

  Future<String> envoyerMessage(String question) async {
    _historique.add(CopilotMessage(
      role: RoleMessage.user,
      contenu: question,
      horodatage: DateTime.now(),
    ));

    try {
      final contexte     = await _obtenirContexte();
      final messagesApi  = _historique.takeLast(10).map((m) => m.toApiMap()).toList();

      final response = await _supabase.functions.invoke(
        'copilot',
        body: {
          'messages'          : messagesApi,
          'contexte_troupeau' : contexte,
        },
      );

      if (response.status != 200) {
        throw Exception('Erreur Edge Function: ${response.status}');
      }

      final reponse = (response.data as Map<String, dynamic>)['reponse'] as String? ??
          'Je n\'ai pas pu générer de réponse.';

      _historique.add(CopilotMessage(
        role: RoleMessage.assistant,
        contenu: reponse,
        horodatage: DateTime.now(),
      ));

      return reponse;
    } catch (e) {
      debugPrint('❌ CopilotService: $e');
      const erreur = 'Désolé, une erreur est survenue. Vérifiez votre connexion.';
      _historique.add(CopilotMessage(
        role: RoleMessage.assistant,
        contenu: erreur,
        horodatage: DateTime.now(),
      ));
      return erreur;
    }
  }

  Future<String> _obtenirContexte() async {
    final now           = DateTime.now();
    final currentUserId = _supabase.auth.currentUser?.id;

    // 🔒 Si l'utilisateur connecté a changé → vider le cache immédiatement
    if (currentUserId != _userIdCache) {
      debugPrint('🔒 CopilotService: nouvel utilisateur détecté, cache invalidé');
      invaliderContexte();
    }

    if (_contexteCache != null &&
        _dernierChargement != null &&
        now.difference(_dernierChargement!).inMinutes < 5) {
      return _contexteCache!;
    }

    _contexteCache     = await _contextBuilder.construire();
    _dernierChargement = now;
    _userIdCache       = currentUserId; // 🔒 Mémoriser le propriétaire du cache
    return _contexteCache!;
  }

  void invaliderContexte() {
    _contexteCache     = null;
    _dernierChargement = null;
    _userIdCache       = null;
  }

  void reinitialiser() {
    _historique.clear();
    invaliderContexte();
  }
}

extension ListTakeLast<T> on List<T> {
  List<T> takeLast(int n) => length <= n ? this : sublist(length - n);
}