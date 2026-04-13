// ============================================================
// MODULE CHALEUR - AVEC INTÉGRATION BREBISCARD CLIQUABLE
// Fichier: lib/Eleveures/New/chaleur/ChaleurModule.dart
// Modifications:
//   ✅ Chaque carte brebis est cliquable → BrebisDetailPage
//   ✅ _buildBrebisCard() remplacé par BrebisCard widget
//   ✅ Navigation vers profil détaillé avec graphiques fl_chart
// ============================================================

import 'package:depart/Eleveures/New/Dashboard/BrebisDetailPage.dart';
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
  final supabase = Supabase.instance.client;
  final _reproService = ReproductionBusinessService();

  // ===== ÉTAT =====
  bool _isLoading = true;
  String _recherche = '';
  final TextEditingController _searchController = TextEditingController();

  // ===== DONNÉES =====
  List<Map<String, dynamic>> _toutesLesBrebis = [];
  List<Map<String, dynamic>> _brebisEnChaleur = [];
  List<Map<String, dynamic>> _brebisGestantes = [];

  // ===== TAB =====
  late TabController _tabController;

  // ===== COULEURS =====
  static const Color _couleurPrimaire = Color(0xFF1B5E20);
  static const Color _couleurChaleur = Color(0xFFE53935);
  static const Color _couleurGestante = Color(0xFF8E24AA);
  static const Color _couleurFond = Color(0xFFF1F8E9);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _chargerBrebis();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
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

      // Charger brebis achetées (UUID)
      final acheteesRaw = await supabase
          .from('animal_acheter')
          .select('*')
          .eq('sexe', 'Femelle')
          .eq('user_id', userId)
          .order('nom');

      // Charger brebis nées (int)
      final neesRaw = await supabase
          .from('nouveaux_nee')
          .select('*')
          .eq('sexe', 'Femelle')
          .eq('user_id', userId)
          .order('nom');

      // Fusionner avec source
      final List<Map<String, dynamic>> toutes = [
        ...List<Map<String, dynamic>>.from(acheteesRaw)
            .map((b) => {...b, 'source': 'achete'}),
        ...List<Map<String, dynamic>>.from(neesRaw)
            .map((b) => {...b, 'source': 'nee'}),
      ];

      // Enrichir avec statut reproduction
      final enrichies = await _enrichirStatuts(toutes, userId);

      if (!mounted) return;
      setState(() {
        _toutesLesBrebis = enrichies;
        _brebisEnChaleur =
            enrichies.where((b) => b['enChaleur'] == true).toList();
        _brebisGestantes =
            enrichies.where((b) => b['estGestante'] == true).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Erreur chargement brebis: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Enrichit chaque brebis avec son statut reproductif
  /// Optimisé : 1 requête groupée par table au lieu de N requêtes
  Future<List<Map<String, dynamic>>> _enrichirStatuts(
    List<Map<String, dynamic>> brebis,
    String userId,
  ) async {
    if (brebis.isEmpty) return brebis;

    // ── Toutes les chaleurs récentes (48h) ──
    final il48h =
        DateTime.now().subtract(const Duration(hours: 48)).toIso8601String();
    final chaleurs = await supabase
        .from('chaleurs')
        .select('animal_id, date_chaleur, source')
        .eq('user_id', userId)
        .gte('date_chaleur', il48h);

    // ── Toutes les gestations en cours ──
    final gestations = await supabase
        .from('accouplements')
        .select('brebis_id, source_brebis, date_prevue_agnelage')
        .eq('user_id', userId)
        .isFilter('date_mise_bas', null);

    // Construire des maps pour lookup O(1)
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

      // ── Calcul âge (uniquement pour les nouveau-nés — source 'nee') ──
      // Les brebis achetées sont supposées adultes (âge non contrôlé ici)
      int? ageMois;
      bool tropJeune = false;
      if (b['source'] == 'nee') {
        final dateNaissanceRaw = b['date_naissance'] as String?;
        if (dateNaissanceRaw != null) {
          final dateNaissance = DateTime.tryParse(dateNaissanceRaw);
          if (dateNaissance != null) {
            final maintenant = DateTime.now();
            ageMois = (maintenant.difference(dateNaissance).inDays / 30.44)
                .floor();
            tropJeune = ageMois < 8; // ✅ Règle métier : minimum 8 mois
          }
        }
      }

      return {
        ...b,
        'enChaleur': enChaleurSet.contains(key),
        'estGestante': gestation.contains(key),
        'dateAgnelagePrevu': dateAgnelage[key],
        'derniereChaleur': derniereChaleurMap[key],
        'ageMois': ageMois,
        'tropJeune': tropJeune, // ✅ Flag bloquant pour les < 8 mois
      };
    }).toList();
  }

  // ============================================================
  // FILTRAGE PAR RECHERCHE
  // ============================================================

  List<Map<String, dynamic>> _filtrer(List<Map<String, dynamic>> liste) {
    if (_recherche.isEmpty) return liste;
    final q = _recherche.toLowerCase();
    return liste.where((b) {
      final nom = (b['nom'] ?? '').toLowerCase();
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
  // ✅ SÉLECTION BREBIS AVANT ENREGISTREMENT CHALEUR
  // ============================================================

  /// Ouvre une bottom sheet pour choisir la brebis avant d'ouvrir
  /// EnregistrerChaleurPageAmelioree avec le bon paramètre `brebis`
  Future<void> _ouvrirSelectionBrebis() async {
    if (_toutesLesBrebis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune brebis disponible dans le troupeau'),
          backgroundColor: Color(0xFFE53935),
        ),
      );
      return;
    }

    final brebisSelectionnee = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BottomSheetSelectionBrebis(
        brebis: _toutesLesBrebis,
      ),
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
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _chargerBrebis,
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        labelStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: [
          Tab(
            text: 'Toutes (${_toutesLesBrebis.length})',
            icon: const Icon(Icons.pets_rounded, size: 18),
          ),
          Tab(
            text: 'Chaleur (${_brebisEnChaleur.length})',
            icon: const Icon(Icons.local_fire_department_rounded, size: 18),
          ),
          Tab(
            text: 'Gestantes (${_brebisGestantes.length})',
            icon: const Icon(Icons.pregnant_woman_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  // ===== BARRE DE RECHERCHE =====

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _recherche = v),
        decoration: InputDecoration(
          hintText: 'Rechercher par nom, race ou RFID...',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded,
              color: Color(0xFF1B5E20), size: 22),
          suffixIcon: _recherche.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      size: 18, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _recherche = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        ),
      ),
    );
  }

  // ===== BANNIÈRE STATS RAPIDES =====

  Widget _buildStatBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('Total', _toutesLesBrebis.length, _couleurPrimaire,
              Icons.pets_rounded),
          _divider(),
          _statItem('En chaleur', _brebisEnChaleur.length, _couleurChaleur,
              Icons.local_fire_department_rounded),
          _divider(),
          _statItem('Gestantes', _brebisGestantes.length, _couleurGestante,
              Icons.pregnant_woman_rounded),
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
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 36, color: Colors.grey[200]);
  }

  // ============================================================
  // ONGLET LISTE BREBIS
  // ============================================================

  Widget _buildOnglet(List<Map<String, dynamic>> brebis, String type) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _couleurPrimaire),
      );
    }

    if (brebis.isEmpty) {
      return _buildVide(type);
    }

    return RefreshIndicator(
      onRefresh: _chargerBrebis,
      color: _couleurPrimaire,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: brebis.length,
        itemBuilder: (context, index) {
          return _buildBrebisCard(brebis[index]);
        },
      ),
    );
  }

  // ============================================================
  // ✅ CARTE BREBIS CLIQUABLE → BrebisDetailPage
  // ============================================================

  Widget _buildBrebisCard(Map<String, dynamic> brebis) {
    final estGestante = brebis['estGestante'] == true;
    final enChaleur = brebis['enChaleur'] == true;
    final tropJeune = brebis['tropJeune'] == true;
    final ageMois = brebis['ageMois'] as int?;
    final derniereChaleur = brebis['derniereChaleur'] as String?;
    final dateAgnelage = brebis['dateAgnelagePrevu'] as String?;
    final source = brebis['source'] as String;

    // Couleur de la bordure selon statut
    Color couleurBord;
    Color couleurBadge;
    String? labelBadge;
    IconData iconeBadge;

    if (tropJeune) {
      couleurBord = Colors.orange.shade300;
      couleurBadge = Colors.orange.shade700;
      labelBadge = ageMois != null ? '$ageMois mois — trop jeune' : 'Trop jeune';
      iconeBadge = Icons.child_care_rounded;
    } else if (estGestante) {
      couleurBord = _couleurGestante;
      couleurBadge = _couleurGestante;
      labelBadge = 'Gestante';
      iconeBadge = Icons.pregnant_woman_rounded;
    } else if (enChaleur) {
      couleurBord = _couleurChaleur;
      couleurBadge = _couleurChaleur;
      labelBadge = 'En chaleur';
      iconeBadge = Icons.local_fire_department_rounded;
    } else {
      couleurBord = Colors.grey.shade200;
      couleurBadge = _couleurPrimaire;
      labelBadge = null;
      iconeBadge = Icons.check_circle_rounded;
    }

    return GestureDetector(
      onTap: () {
        // Navigation vers le profil détaillé (accessible même si trop jeune)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BrebisDetailPage(
              brebis: brebis,
              source: source,
            ),
          ),
        ).then((_) => _chargerBrebis());
      },
      child: Opacity(
        opacity: tropJeune ? 0.75 : 1.0,
        child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: couleurBord, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: couleurBord.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Ligne principale ──
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Photo / Avatar
                  _buildAvatar(brebis, couleurBadge),
                  const SizedBox(width: 14),

                  // Infos
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
                                  fontSize: 16,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                            ),
                            // Badge statut
                            if (labelBadge != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: couleurBadge.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: couleurBadge.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(iconeBadge,
                                        size: 11, color: couleurBadge),
                                    const SizedBox(width: 3),
                                    Text(
                                      labelBadge,
                                      style: TextStyle(
                                        color: couleurBadge,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.agriculture_rounded,
                                size: 12, color: Colors.grey[500]),
                            const SizedBox(width: 3),
                            Text(
                              brebis['race'] ?? 'Race inconnue',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                            if (brebis['tag_rfid'] != null) ...[
                              const SizedBox(width: 10),
                              Icon(Icons.tag_rounded,
                                  size: 12, color: Colors.grey[400]),
                              const SizedBox(width: 3),
                              Text(
                                brebis['tag_rfid'],
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[500]),
                              ),
                            ],
                          ],
                        ),
                        if (derniereChaleur != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.schedule_rounded,
                                  size: 11, color: Colors.grey[400]),
                              const SizedBox(width: 3),
                              Text(
                                'Dernière chaleur: ${_formatDateCourte(DateTime.parse(derniereChaleur))}',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Flèche cliquable
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _couleurPrimaire.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: _couleurPrimaire,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            // ── Bande info agnelage prévu (si gestante) ──
            if (estGestante && dateAgnelage != null)
              _buildBandeAgnelage(dateAgnelage),

            // ── Bande avertissement trop jeune ──
            if (tropJeune) _buildBandeTropJeune(ageMois),
          ],
        ),
        ),
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
        // Indicateur source (petit badge)
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: couleur,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Icon(
              brebis['source'] == 'achete'
                  ? Icons.shopping_bag_rounded
                  : Icons.child_care_rounded,
              size: 9,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _avatarFallback(Color couleur) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: couleur.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.pets_rounded, size: 28, color: couleur),
    );
  }

  Widget _buildBandeAgnelage(String dateAgnelage) {
    final date = DateTime.parse(dateAgnelage);
    final jours = date.difference(DateTime.now()).inDays;
    final urgent = jours <= 7;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: urgent
            ? _couleurChaleur.withOpacity(0.08)
            : _couleurGestante.withOpacity(0.06),
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(14)),
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
            size: 14,
            color: urgent ? _couleurChaleur : _couleurGestante,
          ),
          const SizedBox(width: 6),
          Text(
            urgent
                ? 'Agnelage dans $jours jour${jours > 1 ? 's' : ''} !'
                : 'Agnelage prévu: ${_formatDate(date)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: urgent ? _couleurChaleur : _couleurGestante,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBandeTropJeune(int? ageMois) {
    final moisRestants = ageMois != null ? (8 - ageMois) : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(14)),
        border: Border(
          top: BorderSide(color: Colors.orange.withOpacity(0.25)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_clock_rounded,
              size: 14, color: Colors.orange.shade700),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              moisRestants != null
                  ? '⚠️ Trop jeune — $moisRestants mois avant la reproduction (min. 8 mois)'
                  : '⚠️ Trop jeune pour la reproduction (min. 8 mois)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== VUE VIDE =====

  Widget _buildVide(String type) {
    String message;
    IconData icone;

    switch (type) {
      case 'chaleur':
        message = 'Aucune brebis en chaleur\ndans les 48 dernières heures';
        icone = Icons.local_fire_department_rounded;
        break;
      case 'gestante':
        message = 'Aucune brebis en gestation';
        icone = Icons.pregnant_woman_rounded;
        break;
      default:
        message = 'Aucune brebis trouvée\ndans le troupeau';
        icone = Icons.pets_rounded;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icone, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 15,
              height: 1.5,
            ),
          ),
          if (type == 'toutes') ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _chargerBrebis,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Actualiser'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _couleurPrimaire,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===== FORMATAGE =====

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
  static const Color _couleurChaleur = Color(0xFFE53935);
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
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Poignée
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Titre
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _couleurChaleur.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.local_fire_department_rounded,
                        color: _couleurChaleur, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sélectionner une brebis',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700)),
                        Text('Pour enregistrer sa chaleur',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon:
                        const Icon(Icons.close_rounded, color: Colors.grey),
                  ),
                ],
              ),
            ),
            // Recherche
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _ctrl,
                  onChanged: (v) => setState(() => _recherche = v),
                  decoration: InputDecoration(
                    hintText: 'Rechercher...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: _couleurPrimaire, size: 20),
                    suffixIcon: _recherche.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded,
                                size: 16, color: Colors.grey),
                            onPressed: () {
                              _ctrl.clear();
                              setState(() => _recherche = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            // Liste
            Expanded(
              child: _filtrees.isEmpty
                  ? Center(
                      child: Text('Aucune brebis trouvée',
                          style: TextStyle(color: Colors.grey[400])),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      itemCount: _filtrees.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, index) =>
                          _buildItem(_filtrees[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> b) {
    final estGestante = b['estGestante'] == true;
    final enChaleur = b['enChaleur'] == true;
    final tropJeune = b['tropJeune'] == true;
    final ageMois = b['ageMois'] as int?;

    Color couleur;
    String? avertissement;
    bool bloquee = false; // ✅ true = désactiver la sélection

    if (tropJeune) {
      // ✅ RÈGLE MÉTIER : nouveau-né < 8 mois → sélection BLOQUÉE
      bloquee = true;
      couleur = Colors.orange.shade700;
      final moisRestants = ageMois != null ? (8 - ageMois) : null;
      avertissement = moisRestants != null
          ? 'Trop jeune — encore $moisRestants mois (min. 8 mois)'
          : 'Trop jeune pour la reproduction (min. 8 mois)';
    } else if (estGestante) {
      couleur = _couleurGestante;
      avertissement = 'Gestante — vérifiez avant de saisir';
    } else if (enChaleur) {
      couleur = _couleurChaleur;
      avertissement = 'Déjà enregistrée en chaleur (48h)';
    } else {
      couleur = _couleurPrimaire;
      avertissement = null;
    }

    return Opacity(
      opacity: bloquee ? 0.55 : 1.0,
      child: InkWell(
      onTap: bloquee
          ? () {
              // Affiche un message d'erreur si l'éleveur essaie quand même
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ageMois != null
                        ? '${b['nom'] ?? 'Cette brebis'} a seulement $ageMois mois. Minimum requis : 8 mois.'
                        : 'Cette brebis est trop jeune (minimum 8 mois).',
                  ),
                  backgroundColor: Colors.orange.shade700,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
          : () => Navigator.pop(context, b),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: couleur.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: couleur.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: couleur.withOpacity(0.12),
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
            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b['nom'] ?? 'Sans nom',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(b['race'] ?? 'Race inconnue',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[600])),
                  if (avertissement != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 11, color: couleur),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(avertissement,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: couleur,
                                  fontWeight: FontWeight.w500)),
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
              size: 22,
            ),
          ],
        ),
      ),
      ),
    );
  }
}