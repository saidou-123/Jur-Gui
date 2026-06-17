// ============================================================
// MODULE CHALEUR — ÉTAPE 5 INTÉGRÉE
// Fichier: lib/Eleveures/New/chaleur/ChaleurModule.dart
//
// Modifications étape 5 :
//   ★ Import RetourChaleurDialog + RetourChaleurService
//   ★ _retourService + _suivisEnAttente dans le State
//   ★ _verifierSuivisJ21() appelé depuis initState via addPostFrameCallback
//   ★ _buildBannieresSuivisJ21() — bannière jaune tapable
//   ★ _enrichirStatuts() enrichi avec statut_gestation + probabilite_gestation
//   ★ _buildBrebisCard() : badge statut gestation affiché
// ============================================================
 
import 'package:depart/Eleveures/New/Accouplemt/RetourChaleurDialog.dart';
import 'package:depart/Eleveures/New/Accouplemt/SevrageService.dart';
import 'package:depart/Eleveures/New/Accouplemt/SevragePage.dart';
import 'package:depart/Eleveures/New/Accouplemt/RetourChaleurService.dart';
import 'package:depart/Eleveures/New/Dashboard/BrebisDetailPage.dart';
import 'package:depart/Eleveures/New/Reproduction/ReproductionConfig.dart';
import 'package:depart/Eleveures/New/chaleur/EnrChaleurPageAmelioree.dart';
import 'package:depart/Eleveures/New/Reproduction/ReproductionBusinessService.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
 
class ChaleurModule extends StatefulWidget {
  const ChaleurModule({super.key});
 
  @override
  State<ChaleurModule> createState() => _ChaleurModuleState();
}
 
class _ChaleurModuleState extends State<ChaleurModule>
    with SingleTickerProviderStateMixin {
  final supabase      = Supabase.instance.client;
  final _reproService = ReproductionBusinessService();
 
  // ★ ÉTAPE 5 : service retour chaleur
  final _retourService = RetourChaleurService();
 
  // ===== ÉTAT =====
  bool _isLoading = true;
  String _recherche = '';
  final TextEditingController _searchController = TextEditingController();
 
  // ★ ÉTAPE 5 : suivis J+21 en attente de réponse
  List<SuiviRetourChaleur> _suivisEnAttente = [];
 
  // ★ ÉTAPE 10 : sevrages en attente (3-4 mois après mise bas)
  List<SevrageEnAttente> _sevragesEnAttente = [];
  final _sevrageService = SevrageService();
 
  // ===== DONNÉES =====
  List<Map<String, dynamic>> _toutesLesBrebis = [];
  List<Map<String, dynamic>> _brebisEnChaleur = [];
  List<Map<String, dynamic>> _brebisGestantes = [];
 
  // ===== TAB =====
  late TabController _tabController;
 
  // ===== COULEURS =====
  static const Color _couleurPrimaire  = Color(0xFF1B5E20);
  static const Color _couleurChaleur   = Color(0xFFE53935);
  static const Color _couleurGestante  = Color(0xFF8E24AA);
  static const Color _couleurSuspectee = Color(0xFF5C6BC0); // ★ ÉTAPE 5
  static const Color _couleurFond      = Color(0xFFF1F8E9);
 
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _chargerBrebis();
    // ★ ÉTAPE 5 : vérifier J+21 après le premier frame
    // addPostFrameCallback évite d'ouvrir un dialog avant le build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verifierSuivisJ21();
      _verifierSevrages(); // ★ ÉTAPE 10
    });
  }
 
  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
 
  // ============================================================
  // ★ ÉTAPE 5 — VÉRIFICATION SUIVIS J+21 EN ATTENTE
  // ============================================================
 
  Future<void> _verifierSuivisJ21() async {
    try {
      final suivis = await _retourService.getSuivisEnAttente();
      if (!mounted || suivis.isEmpty) return;
 
      setState(() => _suivisEnAttente = suivis);
 
      // Afficher le premier suivi seulement — les autres au prochain lancement
      // (évite de submerger l'éleveur avec plusieurs dialogs)
      await _afficherDialogJ21(suivis.first);
    } catch (e) {
      debugPrint('⚠️ _verifierSuivisJ21: $e');
    }
  }
 
  /// Affiche le dialog J+21 et traite la réponse
  Future<void> _afficherDialogJ21(SuiviRetourChaleur suivi) async {
    final reponse = await showRetourChaleurDialog(context, suivi);
    if (!mounted) return;
 
    if (reponse == null) {
      // L'éleveur reporte — le suivi reste en_attente pour le prochain lancement
      debugPrint('ℹ️ J+21 reporté pour ${suivi.nomBrebis}');
      return;
    }
 
    if (reponse == ReponseRetourChaleur.retourObserve) {
      await _traiterRetourObserve(suivi);
    } else {
      await _traiterAbsenceRetour(suivi);
    }
 
    // Rafraîchir les listes et retirer ce suivi de la bannière
    await _chargerBrebis();
    if (mounted) {
      setState(() {
        _suivisEnAttente.removeWhere(
          (s) => s.accouplementId == suivi.accouplementId,
        );
      });
    }
  }
 
  /// OUI : retour en chaleur observé → non fécondée
  Future<void> _traiterRetourObserve(SuiviRetourChaleur suivi) async {
    try {
      await _retourService.confirmerRetourChaleur(
        accouplementId : suivi.accouplementId,
        brebisId       : suivi.brebisId,
        source         : suivi.source,
        nomBrebis      : suivi.nomBrebis,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${suivi.nomBrebis} — non fécondée. '
                  'Planifiez un accouplement lors de sa prochaine chaleur.',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor : const Color(0xFFE53935),
          behavior        : SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (mounted) _afficherErreur('Erreur enregistrement : $e');
    }
  }
 
  /// NON : pas de retour → gestation suspectée
  Future<void> _traiterAbsenceRetour(SuiviRetourChaleur suivi) async {
    try {
      // Date accouplement approximative (J21 - 21 jours)
      final dateAccouplement = suivi.dateQuestionJ21.subtract(
        const Duration(days: ReproductionConfig.retourChaleurFinJours),
      );
 
      final resultat = await _retourService.confirmerAbsenceRetour(
        accouplementId   : suivi.accouplementId,
        brebisId         : suivi.brebisId,
        source           : suivi.source,
        nomBrebis        : suivi.nomBrebis,
        dateAccouplement : dateAccouplement,
      );
 
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.pregnant_woman_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${suivi.nomBrebis} — gestation suspectée '
                  '(${resultat.probabilitePourcent}). '
                  'Confirmation recommandée à J+45.',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor : const Color(0xFF2E7D32),
          behavior        : SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (mounted) _afficherErreur('Erreur enregistrement : $e');
    }
  }
 
  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content         : Text(message),
        backgroundColor : Colors.red.shade700,
        behavior        : SnackBarBehavior.floating,
      ),
    );
  }
 
  // ============================================================
  // CHARGEMENT DES DONNÉES
  // ============================================================
 
  Future<void> _chargerBrebis() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
 
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
 
      final acheteesRaw = await supabase
          .from('animal_acheter')
          .select('*')
          .eq('sexe', 'Femelle')
          .eq('user_id', userId)
          .order('nom');
 
      final neesRaw = await supabase
          .from('nouveaux_nee')
          .select('*')
          .eq('sexe', 'Femelle')
          .eq('user_id', userId)
          .order('nom');
 
      final List<Map<String, dynamic>> toutes = [
        ...List<Map<String, dynamic>>.from(acheteesRaw)
            .map((b) => {...b, 'source': 'achete'}),
        ...List<Map<String, dynamic>>.from(neesRaw)
            .map((b) => {...b, 'source': 'nee'}),
      ];
 
      final enrichies = await _enrichirStatuts(toutes, userId);
 
      if (!mounted) return;
      setState(() {
        _toutesLesBrebis = enrichies;
        _brebisEnChaleur = enrichies.where((b) => b['enChaleur'] == true).toList();
        _brebisGestantes = enrichies.where((b) => b['estGestante'] == true).toList();
        _isLoading       = false;
      });
    } catch (e) {
      debugPrint('❌ Erreur chargement brebis: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }
 
  /// Enrichit chaque brebis avec son statut reproductif
  /// ★ ÉTAPE 5 : statut_gestation + probabilite_gestation ajoutés
  Future<List<Map<String, dynamic>>> _enrichirStatuts(
    List<Map<String, dynamic>> brebis,
    String userId,
  ) async {
    if (brebis.isEmpty) return brebis;
 
    // ── Chaleurs récentes (48h) ──
    final il48h = DateTime.now().subtract(const Duration(hours: 48)).toIso8601String();
    final chaleurs = await supabase
        .from('chaleurs')
        .select('animal_id, date_chaleur, source')
        .eq('user_id', userId)
        .gte('date_chaleur', il48h);
 
    // ── Gestations en cours — ENRICHI étape 5 ──
    final gestations = await supabase
        .from('accouplements')
        .select(
          'brebis_id, source_brebis, date_prevue_agnelage, '
          'statut_gestation, probabilite_gestation', // ★ ÉTAPE 5
        )
        .eq('user_id', userId)
        .isFilter('date_mise_bas', null);
 
    // Maps pour lookup O(1)
    final Set<String> enChaleurSet = {
      for (var c in chaleurs) '${c['source']}_${c['animal_id']}'
    };
    final Set<String> gestation = {
      for (var g in gestations) '${g['source_brebis']}_${g['brebis_id']}'
    };
    final Map<String, String?> dateAgnelage = {
      for (var g in gestations)
        '${g['source_brebis']}_${g['brebis_id']}': g['date_prevue_agnelage'],
    };
    // ★ ÉTAPE 5 : maps statut et probabilité
    final Map<String, String?> statutGestation = {
      for (var g in gestations)
        '${g['source_brebis']}_${g['brebis_id']}': g['statut_gestation'],
    };
    final Map<String, double?> probabiliteGestation = {
      for (var g in gestations)
        '${g['source_brebis']}_${g['brebis_id']}':
            (g['probabilite_gestation'] as num?)?.toDouble(),
    };
 
    // Dernière chaleur par animal
    final derniereChaleurs = await supabase
        .from('chaleurs')
        .select('animal_id, source, date_chaleur')
        .eq('user_id', userId)
        .order('date_chaleur', ascending: false);
 
    final Map<String, String> derniereChaleurMap = {};
    for (var c in derniereChaleurs) {
      final key = '${c['source']}_${c['animal_id']}';
      if (!derniereChaleurMap.containsKey(key)) {
        derniereChaleurMap[key] = c['date_chaleur'];
      }
    }
 
    return brebis.map((b) {
      final key = '${b['source']}_${b['id']}';
 
      int? ageMois;
      bool tropJeune = false;
      if (b['source'] == 'nee') {
        final dateNaissanceRaw = b['date_naissance'] as String?;
        if (dateNaissanceRaw != null) {
          final dateNaissance = DateTime.tryParse(dateNaissanceRaw);
          if (dateNaissance != null) {
            final maintenant = DateTime.now();
            ageMois = (maintenant.difference(dateNaissance).inDays / 30.44).floor();
            tropJeune = ageMois < 8;
          }
        }
      }
 
      return {
        ...b,
        'enChaleur'           : enChaleurSet.contains(key),
        'estGestante'         : gestation.contains(key),
        'dateAgnelagePrevu'   : dateAgnelage[key],
        'derniereChaleur'     : derniereChaleurMap[key],
        'ageMois'             : ageMois,
        'tropJeune'           : tropJeune,
        'statutGestation'     : statutGestation[key],     // ★ ÉTAPE 5
        'probabiliteGestation': probabiliteGestation[key], // ★ ÉTAPE 5
      };
    }).toList();
  }
 
  // ============================================================
  // FILTRAGE
  // ============================================================
 
  List<Map<String, dynamic>> _filtrer(List<Map<String, dynamic>> liste) {
    if (_recherche.isEmpty) return liste;
    final q = _recherche.toLowerCase();
    return liste.where((b) {
      final nom  = (b['nom']  ?? '').toLowerCase();
      final race = (b['race'] ?? '').toLowerCase();
      final rfid = (b['tag_rfid'] ?? '').toLowerCase();
      return nom.contains(q) || race.contains(q) || rfid.contains(q);
    }).toList();
  }
 
  // ============================================================
  // BUILD
  // ============================================================
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _couleurFond,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          // ★ ÉTAPE 5 : bannière J+21
          if (_suivisEnAttente.isNotEmpty) _buildBannieresSuivisJ21(),
          // ★ ÉTAPE 10 : bannière sevrage
          if (_sevragesEnAttente.isNotEmpty) _buildBannieresSevrage(),
          _buildStatBanner(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOnglet(_filtrer(_toutesLesBrebis), 'toutes'),
                _buildOnglet(_filtrer(_brebisEnChaleur), 'chaleur'),
                _buildOnglet(_filtrer(_brebisGestantes), 'gestante'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _ouvrirSelectionBrebis(),
        backgroundColor: _couleurChaleur,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Enregistrer chaleur',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }
 
  // ============================================================
  // ★ ÉTAPE 5 — BANNIÈRE SUIVIS J+21 EN ATTENTE
  // ============================================================
 
 
  // ============================================================
  // ★ ÉTAPE 10 — VÉRIFICATION ET AFFICHAGE DES SEVRAGES
  // ============================================================
 
  Future<void> _verifierSevrages() async {
    try {
      final sevrages = await _sevrageService.getSevragesEnAttente();
      if (!mounted) return;
      setState(() => _sevragesEnAttente = sevrages);
      debugPrint('✅ ${sevrages.length} sevrage(s) en attente');
    } catch (e) {
      debugPrint('⚠️ _verifierSevrages: $e');
    }
  }
 
  Widget _buildBannieresSevrage() {
    final n      = _sevragesEnAttente.length;
    final sv     = _sevragesEnAttente.first;
    final urgent = sv.estUrgent;
    final couleur = urgent
        ? const Color(0xFFE65100)
        : const Color(0xFF2E7D32);
 
    return GestureDetector(
      onTap: () => _ouvrirSevrage(sv),
      child: Container(
        margin  : const EdgeInsets.fromLTRB(16, 4, 16, 0),
        padding : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color       : const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(12),
          border      : Border.all(color: couleur, width: 1.5),
          boxShadow   : [
            BoxShadow(color: couleur.withOpacity(0.12),
                blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding   : const EdgeInsets.all(6),
              decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
              child     : const Icon(Icons.child_care_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n == 1
                        ? 'Sevrage en attente — ${sv.nomBrebis}'
                        : '$n sevrages en attente',
                    style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13,
                      color: urgent
                          ? const Color(0xFFBF360C)
                          : const Color(0xFF1B5E20),
                    ),
                  ),
                  Text(
                    'Agneaux de ${sv.labelAge} — Appuyez pour traiter',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF388E3C)),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: couleur, size: 20),
          ],
        ),
      ),
    );
  }
 
  Future<void> _ouvrirSevrage(SevrageEnAttente sv) async {
    Map<String, dynamic> brebis = {};
    try {
      final table = sv.sourceBrebis == 'achete'
          ? 'animal_acheter' : 'nouveaux_nee';
      final row = await supabase
          .from(table).select('*').eq('id', sv.brebisId).maybeSingle();
      brebis = row ?? {'nom': sv.nomBrebis, 'source': sv.sourceBrebis};
    } catch (_) {
      brebis = {'nom': sv.nomBrebis, 'source': sv.sourceBrebis};
    }
    if (!mounted) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => SevragePage(sevrage: sv, brebis: brebis)),
    );
    if (result == true && mounted) {
      setState(() => _sevragesEnAttente
          .removeWhere((s) => s.accouplementId == sv.accouplementId));
      _chargerBrebis();
    }
  }
 
  Widget _buildBannieresSuivisJ21() {
    final n = _suivisEnAttente.length;
 
    return GestureDetector(
      onTap: () => _afficherDialogJ21(_suivisEnAttente.first),
      child: Container(
        margin  : const EdgeInsets.fromLTRB(16, 4, 16, 0),
        padding : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color       : const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(12),
          border      : Border.all(color: const Color(0xFFFFB300), width: 1.5),
          boxShadow: [
            BoxShadow(
              color     : const Color(0xFFFFB300).withOpacity(0.15),
              blurRadius: 8,
              offset    : const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding   : const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color : Color(0xFFFFB300),
                shape : BoxShape.circle,
              ),
              child: const Icon(Icons.query_stats_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children          : [
                  Text(
                    n == 1 ? 'Contrôle J+21 en attente' : '$n contrôles J+21 en attente',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize  : 13,
                      color     : Color(0xFF5D4037),
                    ),
                  ),
                  Text(
                    n == 1 ? _suivisEnAttente.first.nomBrebis : 'Appuyez pour répondre',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF795548)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFFFB300), size: 20),
          ],
        ),
      ),
    );
  }
 
  // ============================================================
  // SÉLECTION BREBIS POUR CHALEUR
  // ============================================================
 
  Future<void> _ouvrirSelectionBrebis() async {
    if (_toutesLesBrebis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content        : Text('Aucune brebis disponible dans le troupeau'),
          backgroundColor: Color(0xFFE53935),
        ),
      );
      return;
    }
 
    final brebisSelectionnee = await showModalBottomSheet<Map<String, dynamic>>(
      context            : context,
      isScrollControlled : true,
      backgroundColor    : Colors.transparent,
      builder: (ctx) => _BottomSheetSelectionBrebis(brebis: _toutesLesBrebis),
    );
 
    if (brebisSelectionnee == null || !mounted) return;
 
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EnregistrerChaleurPageAmelioree(
          brebis: brebisSelectionnee,
          source: brebisSelectionnee['source'] as String,
        ),
      ),
    );
    _chargerBrebis();
  }
 
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Module Chaleur',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
      ),
      backgroundColor: _couleurPrimaire,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        IconButton(
          icon     : const Icon(Icons.refresh_rounded),
          onPressed: _chargerBrebis,
        ),
      ],
      bottom: TabBar(
        controller          : _tabController,
        indicatorColor      : Colors.white,
        indicatorWeight     : 3,
        labelColor          : Colors.white,
        unselectedLabelColor: Colors.white60,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: [
          Tab(text: 'Toutes (${_toutesLesBrebis.length})',  icon: const Icon(Icons.pets_rounded, size: 18)),
          Tab(text: 'Chaleur (${_brebisEnChaleur.length})', icon: const Icon(Icons.local_fire_department_rounded, size: 18)),
          Tab(text: 'Gestantes (${_brebisGestantes.length})', icon: const Icon(Icons.pregnant_woman_rounded, size: 18)),
        ],
      ),
    );
  }
 
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color       : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged : (v) => setState(() => _recherche = v),
        decoration: InputDecoration(
          hintText  : 'Rechercher par nom, race ou RFID...',
          hintStyle : TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF1B5E20), size: 22),
          suffixIcon: _recherche.isNotEmpty
              ? IconButton(
                  icon     : const Icon(Icons.clear_rounded, size: 18, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _recherche = '');
                  },
                )
              : null,
          border        : InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        ),
      ),
    );
  }
 
  Widget _buildStatBanner() {
    return Container(
      margin  : const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color       : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow   : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('Total',     _toutesLesBrebis.length, _couleurPrimaire, Icons.pets_rounded),
          _divider(),
          _statItem('En chaleur', _brebisEnChaleur.length, _couleurChaleur,  Icons.local_fire_department_rounded),
          _divider(),
          _statItem('Gestantes', _brebisGestantes.length, _couleurGestante, Icons.pregnant_woman_rounded),
        ],
      ),
    );
  }
 
  Widget _statItem(String label, int count, Color color, IconData icon) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(count.toString(),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }
 
  Widget _divider() =>
      Container(width: 1, height: 36, color: Colors.grey[200]);
 
  // ============================================================
  // ONGLET LISTE BREBIS
  // ============================================================
 
  Widget _buildOnglet(List<Map<String, dynamic>> brebis, String type) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _couleurPrimaire));
    }
    if (brebis.isEmpty) return _buildVide(type);
 
    return RefreshIndicator(
      onRefresh: _chargerBrebis,
      color    : _couleurPrimaire,
      child: ListView.builder(
        padding    : const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount  : brebis.length,
        itemBuilder: (context, index) => _buildBrebisCard(brebis[index]),
      ),
    );
  }
 
  // ============================================================
  // CARTE BREBIS — ★ ÉTAPE 5 : badge statut gestation
  // ============================================================
 
  Widget _buildBrebisCard(Map<String, dynamic> brebis) {
    final estGestante   = brebis['estGestante'] == true;
    final enChaleur     = brebis['enChaleur'] == true;
    final tropJeune     = brebis['tropJeune'] == true;
    final ageMois       = brebis['ageMois'] as int?;
    final derniereChaleur = brebis['derniereChaleur'] as String?;
    final dateAgnelage  = brebis['dateAgnelagePrevu'] as String?;
    final source        = brebis['source'] as String;
 
    // ★ ÉTAPE 5 : statut gestation
    final statutGestStr = brebis['statutGestation'] as String?;
    final statutGest    = StatutGestation.fromString(statutGestStr);
    final probabilite   = brebis['probabiliteGestation'] as double?;
 
    Color couleurBord;
    Color couleurBadge;
    String? labelBadge;
    IconData iconeBadge;
 
    if (tropJeune) {
      couleurBord  = Colors.orange.shade300;
      couleurBadge = Colors.orange.shade700;
      labelBadge   = ageMois != null ? '$ageMois mois — trop jeune' : 'Trop jeune';
      iconeBadge   = Icons.child_care_rounded;
    } else if (estGestante) {
      // ★ ÉTAPE 5 : distinguer gestation suspectée vs confirmée
      if (statutGest == StatutGestation.gestationSuspectee) {
        couleurBord  = _couleurSuspectee;
        couleurBadge = _couleurSuspectee;
        labelBadge   = probabilite != null
            ? 'Suspectée ${(probabilite * 100).round()}%'
            : 'Gestation suspectée';
        iconeBadge   = Icons.pregnant_woman_rounded;
      } else {
        couleurBord  = _couleurGestante;
        couleurBadge = _couleurGestante;
        labelBadge   = 'Gestante';
        iconeBadge   = Icons.pregnant_woman_rounded;
      }
    } else if (enChaleur) {
      couleurBord  = _couleurChaleur;
      couleurBadge = _couleurChaleur;
      labelBadge   = 'En chaleur';
      iconeBadge   = Icons.local_fire_department_rounded;
    } else if (statutGest == StatutGestation.nonFecondee) {
      // ★ ÉTAPE 5 : badge "non fécondée" pour les brebis récemment confirmées
      couleurBord  = Colors.red.shade200;
      couleurBadge = Colors.red.shade400;
      labelBadge   = 'Non fécondée';
      iconeBadge   = Icons.replay_rounded;
    } else {
      couleurBord  = Colors.grey.shade200;
      couleurBadge = _couleurPrimaire;
      labelBadge   = null;
      iconeBadge   = Icons.check_circle_rounded;
    }
 
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BrebisDetailPage(brebis: brebis, source: source),
          ),
        ).then((_) => _chargerBrebis());
      },
      child: Opacity(
        opacity: tropJeune ? 0.75 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color       : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border      : Border.all(color: couleurBord, width: 1.5),
            boxShadow: [
              BoxShadow(
                color     : couleurBord.withOpacity(0.12),
                blurRadius: 10,
                offset    : const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    _buildAvatar(brebis, couleurBadge),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  brebis['nom'] ?? 'Sans nom',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize  : 16,
                                    color     : Color(0xFF1A1A1A),
                                  ),
                                ),
                              ),
                              if (labelBadge != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color       : couleurBadge.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border      : Border.all(color: couleurBadge.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(iconeBadge, size: 11, color: couleurBadge),
                                      const SizedBox(width: 3),
                                      Text(labelBadge,
                                          style: TextStyle(
                                            color     : couleurBadge,
                                            fontSize  : 10,
                                            fontWeight: FontWeight.w700,
                                          )),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.agriculture_rounded, size: 12, color: Colors.grey[500]),
                              const SizedBox(width: 3),
                              Text(brebis['race'] ?? 'Race inconnue',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              if (brebis['tag_rfid'] != null) ...[
                                const SizedBox(width: 10),
                                Icon(Icons.tag_rounded, size: 12, color: Colors.grey[400]),
                                const SizedBox(width: 3),
                                Text(brebis['tag_rfid'],
                                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                              ],
                            ],
                          ),
                          if (derniereChaleur != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.schedule_rounded, size: 11, color: Colors.grey[400]),
                                const SizedBox(width: 3),
                                Text(
                                  'Dernière chaleur: ${_formatDateCourte(DateTime.parse(derniereChaleur))}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding  : const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color : _couleurPrimaire.withOpacity(0.08),
                        shape : BoxShape.circle,
                      ),
                      child: const Icon(Icons.chevron_right_rounded, color: _couleurPrimaire, size: 20),
                    ),
                  ],
                ),
              ),
 
              // ── Bande info agnelage (si gestante confirmée) ──
              if (estGestante && dateAgnelage != null &&
                  statutGest != StatutGestation.gestationSuspectee)
                _buildBandeAgnelage(dateAgnelage),
 
              // ★ ÉTAPE 5 : Bande probabilité (si gestation suspectée)
              if (estGestante &&
                  statutGest == StatutGestation.gestationSuspectee &&
                  probabilite != null)
                _buildBandeGestationSuspectee(probabilite, dateAgnelage),
 
              // ── Bande avertissement trop jeune ──
              if (tropJeune) _buildBandeTropJeune(ageMois),
            ],
          ),
        ),
      ),
    );
  }
 
  // ★ ÉTAPE 5 — Bande gestation suspectée avec probabilité
  Widget _buildBandeGestationSuspectee(double probabilite, String? dateAgnelage) {
    final pct = (probabilite * 100).round();
    Color couleurBarre;
    if (probabilite >= ReproductionConfig.probabiliteGestationElevee) {
      couleurBarre = const Color(0xFF2E7D32);
    } else if (probabilite >= ReproductionConfig.probabiliteGestationModeree) {
      couleurBarre = Colors.orange;
    } else {
      couleurBarre = Colors.red;
    }
 
    return Container(
      width  : double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      decoration: BoxDecoration(
        color: _couleurSuspectee.withOpacity(0.06),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
        border: Border(
          top: BorderSide(color: _couleurSuspectee.withOpacity(0.2)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.query_stats_rounded, size: 13, color: _couleurSuspectee),
                  const SizedBox(width: 5),
                  Text(
                    'Gestation suspectée',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _couleurSuspectee),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color       : couleurBarre.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$pct%',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: couleurBarre),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value          : probabilite,
              backgroundColor: Colors.grey.shade200,
              valueColor     : AlwaysStoppedAnimation<Color>(couleurBarre),
              minHeight      : 6,
            ),
          ),
          if (dateAgnelage != null) ...[
            const SizedBox(height: 4),
            Text(
              'Agnelage estimé : ${_formatDate(DateTime.parse(dateAgnelage))}',
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ],
        ],
      ),
    );
  }
 
  Widget _buildAvatar(Map<String, dynamic> brebis, Color couleur) {
    final imageUrl = brebis['image_url'] as String?;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: imageUrl != null
              ? Image.network(
                  imageUrl,
                  width: 58,
                  height: 58,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _avatarFallback(couleur),
                )
              : _avatarFallback(couleur),
        ),
        Positioned(
          bottom: 0,
          right : 0,
          child : Container(
            padding  : const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color : couleur,
              shape : BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Icon(
              brebis['source'] == 'achete'
                  ? Icons.shopping_bag_rounded
                  : Icons.child_care_rounded,
              size : 9,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
 
  Widget _avatarFallback(Color couleur) {
    return Container(
      width : 58,
      height: 58,
      decoration: BoxDecoration(
        color       : couleur.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.pets_rounded, size: 28, color: couleur),
    );
  }
 
  Widget _buildBandeAgnelage(String dateAgnelage) {
    final date  = DateTime.parse(dateAgnelage);
    final jours = date.difference(DateTime.now()).inDays;
    final urgent = jours <= 7;
 
    return Container(
      width  : double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: urgent
            ? _couleurChaleur.withOpacity(0.08)
            : _couleurGestante.withOpacity(0.06),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
        border: Border(
          top: BorderSide(
            color: urgent
                ? _couleurChaleur.withOpacity(0.2)
                : _couleurGestante.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            urgent ? Icons.warning_amber_rounded : Icons.event_rounded,
            size : 14,
            color: urgent ? _couleurChaleur : _couleurGestante,
          ),
          const SizedBox(width: 6),
          Text(
            urgent
                ? 'Agnelage dans $jours jour${jours > 1 ? 's' : ''} !'
                : 'Agnelage prévu: ${_formatDate(date)}',
            style: TextStyle(
              fontSize  : 12,
              fontWeight: FontWeight.w600,
              color     : urgent ? _couleurChaleur : _couleurGestante,
            ),
          ),
        ],
      ),
    );
  }
 
  Widget _buildBandeTropJeune(int? ageMois) {
    final moisRestants = ageMois != null ? (8 - ageMois) : null;
    return Container(
      width  : double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
        border: Border(top: BorderSide(color: Colors.orange.withOpacity(0.25))),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_clock_rounded, size: 14, color: Colors.orange.shade700),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              moisRestants != null
                  ? '⚠️ Trop jeune — $moisRestants mois avant la reproduction (min. 8 mois)'
                  : '⚠️ Trop jeune pour la reproduction (min. 8 mois)',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.orange.shade800),
            ),
          ),
        ],
      ),
    );
  }
 
  Widget _buildVide(String type) {
    String message;
    IconData icone;
    switch (type) {
      case 'chaleur':
        message = 'Aucune brebis en chaleur\ndans les 48 dernières heures';
        icone   = Icons.local_fire_department_rounded;
        break;
      case 'gestante':
        message = 'Aucune brebis en gestation';
        icone   = Icons.pregnant_woman_rounded;
        break;
      default:
        message = 'Aucune brebis trouvée\ndans le troupeau';
        icone   = Icons.pets_rounded;
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icone, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 15, height: 1.5)),
          if (type == 'toutes') ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _chargerBrebis,
              icon     : const Icon(Icons.refresh_rounded, size: 18),
              label    : const Text('Actualiser'),
              style    : ElevatedButton.styleFrom(
                backgroundColor: _couleurPrimaire,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }
 
  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
 
  String _formatDateCourte(DateTime d) {
    final diff = DateTime.now().difference(d).inDays;
    if (diff == 0) return "Aujourd'hui";
    if (diff == 1) return "Hier";
    if (diff < 7) return "Il y a $diff jours";
    return _formatDate(d);
  }
}
 
// ============================================================
// BOTTOM SHEET — SÉLECTION BREBIS POUR ENREGISTREMENT CHALEUR
// ============================================================
 
class _BottomSheetSelectionBrebis extends StatefulWidget {
  final List<Map<String, dynamic>> brebis;
  const _BottomSheetSelectionBrebis({required this.brebis});
 
  @override
  State<_BottomSheetSelectionBrebis> createState() =>
      _BottomSheetSelectionBrebisState();
}
 
class _BottomSheetSelectionBrebisState
    extends State<_BottomSheetSelectionBrebis> {
  String _recherche = '';
  final TextEditingController _ctrl = TextEditingController();
 
  static const Color _couleurPrimaire = Color(0xFF1B5E20);
  static const Color _couleurChaleur  = Color(0xFFE53935);
  static const Color _couleurGestante = Color(0xFF8E24AA);
 
  List<Map<String, dynamic>> get _filtrees {
    if (_recherche.isEmpty) return widget.brebis;
    final q = _recherche.toLowerCase();
    return widget.brebis.where((b) {
      return (b['nom'] ?? '').toLowerCase().contains(q) ||
          (b['race'] ?? '').toLowerCase().contains(q);
    }).toList();
  }
 
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
 
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize    : 0.5,
      maxChildSize    : 0.95,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color       : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width : 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Container(
                    padding   : const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color       : _couleurChaleur.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.local_fire_department_rounded, color: _couleurChaleur, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sélectionner une brebis',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        Text('Pour enregistrer sa chaleur',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon     : const Icon(Icons.close_rounded, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color       : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _ctrl,
                  onChanged : (v) => setState(() => _recherche = v),
                  decoration: InputDecoration(
                    hintText  : 'Rechercher...',
                    hintStyle : TextStyle(color: Colors.grey[400], fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded, color: _couleurPrimaire, size: 20),
                    suffixIcon: _recherche.isNotEmpty
                        ? IconButton(
                            icon     : const Icon(Icons.clear_rounded, size: 16, color: Colors.grey),
                            onPressed: () {
                              _ctrl.clear();
                              setState(() => _recherche = '');
                            },
                          )
                        : null,
                    border        : InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _filtrees.isEmpty
                  ? Center(
                      child: Text('Aucune brebis trouvée',
                          style: TextStyle(color: Colors.grey[400])),
                    )
                  : ListView.separated(
                      controller     : scrollController,
                      padding        : const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      itemCount      : _filtrees.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder    : (_, index) => _buildItem(_filtrees[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
 
  Widget _buildItem(Map<String, dynamic> b) {
    final estGestante = b['estGestante'] == true;
    final enChaleur   = b['enChaleur'] == true;
    final tropJeune   = b['tropJeune'] == true;
    final ageMois     = b['ageMois'] as int?;
 
    Color couleur;
    String? avertissement;
    bool bloquee = false;
 
    if (tropJeune) {
      bloquee = true;
      couleur = Colors.orange.shade700;
      final moisRestants = ageMois != null ? (8 - ageMois) : null;
      avertissement = moisRestants != null
          ? 'Trop jeune — encore $moisRestants mois (min. 8 mois)'
          : 'Trop jeune pour la reproduction (min. 8 mois)';
    } else if (estGestante) {
      couleur       = _couleurGestante;
      avertissement = 'Gestante — vérifiez avant de saisir';
    } else if (enChaleur) {
      couleur       = _couleurChaleur;
      avertissement = 'Déjà enregistrée en chaleur (48h)';
    } else {
      couleur       = _couleurPrimaire;
      avertissement = null;
    }
 
    return Opacity(
      opacity: bloquee ? 0.55 : 1.0,
      child: InkWell(
        onTap: bloquee
            ? () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ageMois != null
                          ? '${b['nom'] ?? 'Cette brebis'} a seulement $ageMois mois. Minimum requis : 8 mois.'
                          : 'Cette brebis est trop jeune (minimum 8 mois).',
                    ),
                    backgroundColor: Colors.orange.shade700,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            : () => Navigator.pop(context, b),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding   : const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color       : couleur.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border      : Border.all(color: couleur.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Container(
                width : 46,
                height: 46,
                decoration: BoxDecoration(
                  color       : couleur.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: b['image_url'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(b['image_url'], fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Icon(Icons.pets_rounded, color: couleur, size: 24)),
                      )
                    : Icon(Icons.pets_rounded, color: couleur, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b['nom'] ?? 'Sans nom',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(b['race'] ?? 'Race inconnue',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    if (avertissement != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 11, color: couleur),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(avertissement,
                                style: TextStyle(
                                    fontSize: 11, color: couleur, fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                bloquee ? Icons.lock_rounded : Icons.chevron_right_rounded,
                color: couleur,
                size : 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}