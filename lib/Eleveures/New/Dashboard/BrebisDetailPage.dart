// ============================================================
// PROFIL DÉTAILLÉ D'UNE BREBIS - GRAPHIQUES FL_CHART
// Fichier: lib/Eleveures/New/Dashboard/BrebisDetailPage.dart
// Affiche: Historique chaleurs, accouplements, agnelages
// ============================================================

import 'package:depart/Eleveures/New/Accouplemt/ChecklistGestationPage.dart';
import 'package:depart/Eleveures/New/Accouplemt/DeclarationMiseBasPage.dart';
import 'package:depart/Eleveures/New/Accouplemt/PreparationMiseBasPage.dart';
import 'package:depart/Eleveures/New/Accouplemt/SuiviGestationService.dart';
import 'package:depart/Eleveures/New/Reproduction/ReproductionConfig.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BrebisDetailPage extends StatefulWidget {
  final Map<String, dynamic> brebis;
  final String source; // 'achete' ou 'nee'

  const BrebisDetailPage({
    super.key,
    required this.brebis,
    required this.source,
  });

  @override
  State<BrebisDetailPage> createState() => _BrebisDetailPageState();
}

class _BrebisDetailPageState extends State<BrebisDetailPage>
    with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  // ===== ANIMATIONS =====
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late TabController _tabController;

  // ===== ÉTAT =====
  bool _isLoading = true;
  String _periodeSelectionnee = '6 mois';

  // ===== DONNÉES BRUTES =====
  List<Map<String, dynamic>> _chaleurs = [];
  List<Map<String, dynamic>> _accouplements = [];
  List<Map<String, dynamic>> _agnelages = [];

  // ===== DONNÉES MENSUELLES POUR GRAPHIQUES =====
  List<_BrebisMonthData> _donneesMensuelles = [];

  // ===== STATISTIQUES BREBIS =====
  int _totalChaleurs = 0;
  int _totalAccouplements = 0;
  int _totalAgnelages = 0;
  double _tauxFertilite = 0.0;
  int _cycleMoyenJours = 0;
  String _statutActuel = 'Disponible';
  Color _couleurStatut = const Color(0xFF2E7D32);
  DateTime? _derniereChaleur;
  DateTime? _prochaineeChaleurEstimee;
  DateTime? _dateAgnelagePrevu;

  // ★ ÉTAPE 6+7 — Suivi gestation
  Map<String, dynamic>? _gestationCourante;
  double _scoreGestation    = 0.65;
  int    _semaineGestation  = 1;
  bool   _gestationConfirmee = false;

  // ===== TOUCHE GRAPHIQUES =====
  int _touchedBarIndex = -1;
  int _touchedPieIndex = -1;

  // ===== COULEURS =====
  static const Color _couleurPrimaire = Color(0xFF1B5E20);
  static const Color _couleurChaleur = Color(0xFFE53935);
  static const Color _couleurAccouplement = Color(0xFF8E24AA);
  static const Color _couleurAgnelage = Color(0xFF00ACC1);
  static const Color _couleurFond = Color(0xFFF1F8E9);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _chargerDonnees();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ============================================================
  // CHARGEMENT DES DONNÉES
  // ============================================================

  Future<void> _chargerDonnees() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final brebisId = widget.brebis['id'];
      final nbMois = _periodeSelectionnee == '3 mois'
          ? 3
          : _periodeSelectionnee == '6 mois'
              ? 6
              : 12;

      await Future.wait([
        _chargerChaleurs(brebisId),
        _chargerAccouplements(brebisId),
      ]);

      await _calculerStatistiques();
      await _construireDonneesMensuelles(brebisId, nbMois);

      if (mounted) {
        setState(() => _isLoading = false);
        _fadeController.forward(from: 0);
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement détail brebis: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _chargerChaleurs(dynamic brebisId) async {
    final result = await supabase
        .from('chaleurs')
        .select('*')
        .eq('animal_id', brebisId)
        .eq('source', widget.source)
        .order('date_chaleur', ascending: false);

    _chaleurs = List<Map<String, dynamic>>.from(result);
    _totalChaleurs = _chaleurs.length;

    if (_chaleurs.isNotEmpty) {
      _derniereChaleur = DateTime.parse(_chaleurs.first['date_chaleur']);

      // Calculer cycle moyen si assez de données
      if (_chaleurs.length >= 2) {
        int totalJours = 0;
        for (int i = 0; i < _chaleurs.length - 1; i++) {
          final d1 = DateTime.parse(_chaleurs[i]['date_chaleur']);
          final d2 = DateTime.parse(_chaleurs[i + 1]['date_chaleur']);
          totalJours += d1.difference(d2).inDays.abs();
        }
        _cycleMoyenJours = (totalJours / (_chaleurs.length - 1)).round();
        _prochaineeChaleurEstimee =
            _derniereChaleur!.add(Duration(days: _cycleMoyenJours));
      } else {
        _cycleMoyenJours = ReproductionConfig.cycleMoyenJours; // valeur par défaut
        _prochaineeChaleurEstimee = _derniereChaleur!
            .add(const Duration(days: ReproductionConfig.cycleMoyenJours));
      }
    }
  }

  Future<void> _chargerAccouplements(dynamic brebisId) async {
    final result = await supabase
        .from('accouplements')
        .select('*')
        .eq('brebis_id', brebisId)
        .eq('source_brebis', widget.source)
        .order('date_accouplement', ascending: false);

    _accouplements = List<Map<String, dynamic>>.from(result);
    _totalAccouplements = _accouplements.length;

    // Séparer agnelages (mise_bas renseignée) des gestations en cours
    _agnelages = _accouplements
        .where((a) => a['date_mise_bas'] != null)
        .toList();
    _totalAgnelages = _agnelages.length;
  }

  Future<void> _calculerStatistiques() async {
    // Taux de fertilité
    if (_totalAccouplements > 0) {
      _tauxFertilite = _totalAgnelages / _totalAccouplements;
    }

    // Statut actuel
    final enGestation = _accouplements.any((a) => a['date_mise_bas'] == null);
    final il48h = DateTime.now().subtract(const Duration(hours: 48));
    final enChaleur = _chaleurs.isNotEmpty &&
        DateTime.parse(_chaleurs.first['date_chaleur']).isAfter(il48h);

    if (enGestation) {
      _statutActuel = 'Gestante 🤰';
      _couleurStatut = const Color(0xFF8E24AA);
      // Chercher date agnelage prévu
      final gestationCourante =
          _accouplements.firstWhere((a) => a['date_mise_bas'] == null);
      _gestationCourante = gestationCourante; // ★ CORRECTIF : oubli d'assignation
      if (gestationCourante['date_prevue_agnelage'] != null) {
        _dateAgnelagePrevu =
            DateTime.parse(gestationCourante['date_prevue_agnelage']);
      }
    } else if (enChaleur) {
      _statutActuel = 'En chaleur 🔥';
      _couleurStatut = const Color(0xFFE53935);
    } else {
      _statutActuel = 'Disponible ✅';
      _couleurStatut = const Color(0xFF2E7D32);
    }
  }

  Future<void> _construireDonneesMensuelles(dynamic brebisId, int nbMois) async {
    final maintenant = DateTime.now();
    List<_BrebisMonthData> donnees = [];

    for (int i = nbMois - 1; i >= 0; i--) {
      final debut = DateTime(maintenant.year, maintenant.month - i, 1);
      final fin = DateTime(maintenant.year, maintenant.month - i + 1, 1);

      final chaleursM = _chaleurs.where((c) {
        final d = DateTime.parse(c['date_chaleur']);
        return d.isAfter(debut) && d.isBefore(fin);
      }).length;

      final accouplM = _accouplements.where((a) {
        final d = DateTime.parse(a['date_accouplement']);
        return d.isAfter(debut) && d.isBefore(fin);
      }).length;

      final agnelM = _agnelages.where((a) {
        final d = DateTime.parse(a['date_mise_bas']);
        return d.isAfter(debut) && d.isBefore(fin);
      }).length;

      donnees.add(_BrebisMonthData(
        mois: debut,
        chaleurs: chaleursM.toDouble(),
        accouplements: accouplM.toDouble(),
        agnelages: agnelM.toDouble(),
      ));
    }

    _donneesMensuelles = donnees;
  }

  // ============================================================
  // BUILD PRINCIPAL
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final nom = widget.brebis['nom'] ?? 'Brebis';
    final race = widget.brebis['race'] ?? 'N/A';
    final imageUrl = widget.brebis['image_url'];

    return Scaffold(
      backgroundColor: _couleurFond,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(nom, race, imageUrl),
        ],
        body: _isLoading ? _buildLoading() : _buildContenu(),
      ),
    );
  }

  // ============================================================
  // SLIVER APP BAR AVEC PHOTO
  // ============================================================

  Widget _buildSliverAppBar(String nom, String race, String? imageUrl) {
    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: _couleurPrimaire,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _chargerDonnees,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Photo ou dégradé
            imageUrl != null
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildGradientFond(),
                  )
                : _buildGradientFond(),

            // Overlay sombre pour lisibilité
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),

            // Infos dans le bas de l'image
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            nom,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        // Badge statut
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _couleurStatut,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: _couleurStatut.withOpacity(0.4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Text(
                            _statutActuel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.agriculture_rounded,
                            color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          race,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.tag_rounded,
                            color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          widget.brebis['tag_rfid'] ?? 'N/A',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Résumé', icon: Icon(Icons.dashboard_rounded, size: 18)),
          Tab(text: 'Chaleurs', icon: Icon(Icons.local_fire_department_rounded, size: 18)),
          Tab(text: 'Accouplements', icon: Icon(Icons.favorite_rounded, size: 18)),
          Tab(text: 'Agnelages', icon: Icon(Icons.child_care_rounded, size: 18)),
        ],
      ),
    );
  }

  Widget _buildGradientFond() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _couleurPrimaire,
            const Color(0xFF4CAF50),
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.pets_rounded, size: 100, color: Colors.white24),
      ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _couleurPrimaire),
          SizedBox(height: 16),
          Text('Chargement du profil...',
              style: TextStyle(color: _couleurPrimaire, fontSize: 15)),
        ],
      ),
    );
  }

  // ============================================================
  // CONTENU AVEC TABS
  // ============================================================

  Widget _buildContenu() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          // Sélecteur de période
          _buildSelectorPeriode(),

          // Tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTabResume(),
                _buildTabChaleurs(),
                _buildTabAccouplements(),
                _buildTabAgnelages(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== SÉLECTEUR PÉRIODE =====

  Widget _buildSelectorPeriode() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: ['3 mois', '6 mois', '1 an'].map((p) {
          final isSelected = _periodeSelectionnee == p;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _periodeSelectionnee = p);
                _chargerDonnees();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? _couleurPrimaire : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  p,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[600],
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ============================================================
  // TAB 1 : RÉSUMÉ
  // ============================================================

  Widget _buildTabResume() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPIs
          _buildKPIGrid(),
          const SizedBox(height: 20),

          // Alerte agnelage prévu
          if (_dateAgnelagePrevu != null) _buildAlerteAgnelage(),

          // Prochaine chaleur estimée
          if (_prochaineeChaleurEstimee != null) _buildProchaineChaleur(),

          const SizedBox(height: 20),

          // Graphique radar / vue globale mensuelle (barres groupées)
          _buildTitre('📊 Vue globale mensuelle',
              'Chaleurs · Accouplements · Agnelages'),
          const SizedBox(height: 12),
          _buildGraphiqueBarresGroupees(),

          const SizedBox(height: 20),

          // Graphique circulaire bilan
          _buildTitre('🎯 Bilan de reproduction', 'Taux de succès global'),
          const SizedBox(height: 12),
          _buildGraphiqueBilanCirculaire(),
        ],
      ),
    );
  }

  Widget _buildKPIGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.8,
      children: [
        _buildKPI('Chaleurs', _totalChaleurs.toString(),
            Icons.local_fire_department_rounded, _couleurChaleur,
            sous: 'total enregistrées'),
        _buildKPI('Accouplements', _totalAccouplements.toString(),
            Icons.favorite_rounded, _couleurAccouplement,
            sous: 'total réalisés'),
        _buildKPI('Agnelages', _totalAgnelages.toString(),
            Icons.child_care_rounded, _couleurAgnelage,
            sous: 'naissances réussies'),
        _buildKPI(
          'Fertilité',
          '${(_tauxFertilite * 100).toStringAsFixed(0)}%',
          Icons.trending_up_rounded,
          _tauxFertilite >= 0.75
              ? _couleurPrimaire
              : _tauxFertilite >= 0.5
                  ? Colors.orange
                  : _couleurChaleur,
          sous: _cycleMoyenJours > 0 ? 'cycle ~$_cycleMoyenJours j' : 'cycle moyen',
        ),
      ],
    );
  }

  Widget _buildKPI(String titre, String valeur, IconData icone, Color couleur,
      {required String sous}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: couleur.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
        border: Border.all(color: couleur.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: couleur.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icone, color: couleur, size: 18),
              ),
              Text(
                valeur,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: couleur,
                  height: 1,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titre,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2D2D2D))),
              Text(sous,
                  style:
                      TextStyle(fontSize: 10, color: Colors.grey[500])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlerteAgnelage() {
    final jours   = _dateAgnelagePrevu!.difference(DateTime.now()).inDays;
    final urgent  = jours <= 7;
    final depasse = jours < 0;
    final couleur = urgent ? _couleurChaleur : _couleurAccouplement;

    // Score couleur
    Color couleurScore;
    if (_scoreGestation >= 0.80)      couleurScore = const Color(0xFF2E7D32);
    else if (_scoreGestation >= 0.60) couleurScore = Colors.orange;
    else                              couleurScore = const Color(0xFFE53935);

    // Label compte à rebours pour le bouton (pas const car variable)
    final labelJours = depasse ? 'J0+' : 'J-$jours';

    return Container(
      margin    : const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color       : urgent ? Colors.red.shade50 : Colors.purple.shade50,
        borderRadius: BorderRadius.circular(14),
        border      : Border.all(color: couleur, width: 1.5),
      ),
      child: Column(
        children: [
          // En-tête
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                Icon(
                  depasse
                      ? Icons.baby_changing_station_rounded
                      : urgent ? Icons.warning_amber_rounded
                               : Icons.pregnant_woman_rounded,
                  color: couleur, size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        depasse
                            ? '🚨 Mise bas imminente !'
                            : urgent
                                ? '⚠️ Agnelage dans $jours jour${jours > 1 ? 's' : ''}'
                                : '🤰 Gestation — $jours jours restants',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14, color: couleur),
                      ),
                      Text(
                        'Date prévue : ${_formatDate(_dateAgnelagePrevu!)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Barre score gestation (étape 6)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Probabilité gestation — S$_semaineGestation',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: couleurScore.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${(_scoreGestation * 100).round()}%'
                        '${_gestationConfirmee ? ' ✅' : ''}',
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold,
                          color: couleurScore),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _scoreGestation,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(couleurScore),
                    minHeight: 7,
                  ),
                ),
              ],
            ),
          ),

          // 3 boutons (étapes 6, 7, 8)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Checklist gestation (étape 6)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _ouvrirChecklistGestation,
                    icon : const Icon(Icons.checklist_rounded, size: 14),
                    label: Text('S$_semaineGestation',
                        style: const TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _couleurAccouplement,
                      side: BorderSide(color: _couleurAccouplement),
                      padding: const EdgeInsets.symmetric(vertical: 7),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Compte à rebours (étape 7) — labelJours n'est PAS const
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _ouvrirPreparationMiseBas,
                    icon : const Icon(Icons.timer_rounded, size: 14),
                    label: Text(labelJours,
                        style: const TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: couleur,
                      side: BorderSide(color: couleur),
                      padding: const EdgeInsets.symmetric(vertical: 7),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Déclaration mise bas (étape 8)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _ouvrirDeclarationMiseBas,
                    icon : const Icon(Icons.baby_changing_station_rounded, size: 14),
                    label: const Text('Mise bas',
                        style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ★ ÉTAPE 6 : Checklist gestation
  Future<void> _ouvrirChecklistGestation() async {
    if (_gestationCourante == null) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ChecklistGestationPage(
          accouplement: _gestationCourante!,
          brebis      : widget.brebis,
        ),
      ),
    );
    if (result == true && mounted) _chargerDonnees();
  }

  // ★ ÉTAPE 7 : Préparation mise bas
  Future<void> _ouvrirPreparationMiseBas() async {
    final accouplement = _accouplements
        .where((a) => a['date_mise_bas'] == null)
        .firstOrNull;
    if (accouplement == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PreparationMiseBasPage(
          accouplement: accouplement,
          brebis      : widget.brebis,
        ),
      ),
    );
  }

  // ★ ÉTAPE 8 : Déclaration mise bas
  Future<void> _ouvrirDeclarationMiseBas() async {
    final accouplement = _accouplements
        .where((a) => a['date_mise_bas'] == null)
        .firstOrNull;
    if (accouplement == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun accouplement en cours trouvé'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DeclarationMiseBasPage(
          accouplement: accouplement,
          brebis      : widget.brebis,
        ),
      ),
    );
    if (result == true && mounted) _chargerDonnees();
  }

  Widget _buildProchaineChaleur() {
    if (_prochaineeChaleurEstimee == null) return const SizedBox.shrink();
    final jours =
        _prochaineeChaleurEstimee!.difference(DateTime.now()).inDays;
    final estPasse = jours < 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _couleurChaleur.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department_rounded,
              color: _couleurChaleur, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🔥 Prochaine chaleur estimée',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: _couleurChaleur)),
                Text(
                  estPasse
                      ? 'Dépassée · ${_formatDate(_prochaineeChaleurEstimee!)}'
                      : 'Dans $jours jour${jours > 1 ? 's' : ''} · ${_formatDate(_prochaineeChaleurEstimee!)}',
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
                if (_cycleMoyenJours > 0)
                  Text(
                    'Basé sur un cycle moyen de $_cycleMoyenJours jours',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== GRAPHIQUE BARRES GROUPÉES (RÉSUMÉ) =====

  Widget _buildGraphiqueBarresGroupees() {
    if (_donneesMensuelles.isEmpty) return _buildVide();

    final maxY = _donneesMensuelles
        .map((d) => [d.chaleurs, d.accouplements, d.agnelages])
        .expand((e) => e)
        .fold(0.0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 20, 16, 12),
      decoration: _cardDeco(),
      child: Column(
        children: [
          _buildLegende(),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (maxY + 1.5).clamp(3, double.infinity),
                minY: 0,
                groupsSpace: 8,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.grey.shade800,
                    tooltipBorderRadius: BorderRadius.circular(8),
                    getTooltipItem: (group, gi, rod, ri) {
                      final labels = ['Chaleurs', 'Accouplements', 'Agnelages'];
                      if (rod.toY == 0) return null;
                      return BarTooltipItem(
                        '${labels[ri]}: ${rod.toY.toInt()}',
                        const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                  touchCallback: (event, response) {
                    setState(() {
                      _touchedBarIndex =
                          response?.spot?.touchedBarGroupIndex ?? -1;
                    });
                  },
                ),
                titlesData: _buildTitlesData(maxY),
                gridData: _buildGridData(maxY),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(_donneesMensuelles.length, (i) {
                  final d = _donneesMensuelles[i];
                  final sel = i == _touchedBarIndex;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      _rod(d.chaleurs, _couleurChaleur, sel),
                      _rod(d.accouplements, _couleurAccouplement, sel),
                      _rod(d.agnelages, _couleurAgnelage, sel),
                    ],
                  );
                }),
              ),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOutCubic,
            ),
          ),
        ],
      ),
    );
  }

  BarChartRodData _rod(double value, Color color, bool selected) {
    return BarChartRodData(
      toY: value,
      color: selected ? color : color.withOpacity(0.72),
      width: 7,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
    );
  }

  // ===== GRAPHIQUE BILAN CIRCULAIRE (RÉSUMÉ) =====

  Widget _buildGraphiqueBilanCirculaire() {
    if (_totalAccouplements == 0) {
      return _buildVide(message: 'Aucun accouplement enregistré');
    }

    final echoues = _totalAccouplements - _totalAgnelages;
    final sections = [
      if (_totalAgnelages > 0)
        _PieData('Agnelages réussis', _totalAgnelages.toDouble(),
            _couleurAgnelage),
      if (echoues > 0)
        _PieData('Accouplements sans agnelage', echoues.toDouble(),
            Colors.grey.shade300),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      setState(() {
                        _touchedPieIndex = (!event.isInterestedForInteractions ||
                                response?.touchedSection == null)
                            ? -1
                            : response!.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  sections: sections.asMap().entries.map((e) {
                    final idx = e.key;
                    final s = e.value;
                    final sel = idx == _touchedPieIndex;
                    final pct =
                        (s.valeur / _totalAccouplements * 100).toStringAsFixed(0);
                    return PieChartSectionData(
                      value: s.valeur,
                      color: s.couleur,
                      radius: sel ? 80 : 65,
                      title: '$pct%',
                      titleStyle: TextStyle(
                        fontSize: sel ? 14 : 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: const [
                          Shadow(color: Colors.black26, blurRadius: 3)
                        ],
                      ),
                    );
                  }).toList(),
                  sectionsSpace: 3,
                  centerSpaceRadius: 38,
                  startDegreeOffset: -90,
                ),
                duration: const Duration(milliseconds: 500),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...sections.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: s.couleur,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.label,
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.grey[700])),
                                Text('${s.valeur.toInt()} fois',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: s.couleur)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _couleurPrimaire.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Fertilité: ${(_tauxFertilite * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _couleurPrimaire,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 2 : CHALEURS
  // ============================================================

  Widget _buildTabChaleurs() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Graphique ligne — historique chaleurs
          _buildTitre('🔥 Historique des chaleurs',
              'Nombre de chaleurs détectées par mois'),
          const SizedBox(height: 12),
          _buildGraphiqueLigneChaleurs(),
          const SizedBox(height: 20),

          // Graphique intensité
          _buildTitre('📊 Intensité des chaleurs', 'Répartition par niveau'),
          const SizedBox(height: 12),
          _buildGraphiqueIntensiteChaleurs(),
          const SizedBox(height: 20),

          // Liste chronologique
          _buildTitre(
              '📋 Historique détaillé', '${_totalChaleurs} chaleur(s) enregistrée(s)'),
          const SizedBox(height: 12),
          _buildListeChaleurs(),
        ],
      ),
    );
  }

  Widget _buildGraphiqueLigneChaleurs() {
    if (_donneesMensuelles.isEmpty) return _buildVide();

    final spots = _donneesMensuelles
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.chaleurs))
        .toList();

    final maxY = spots.map((s) => s.y).fold(0.0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 20, 16, 12),
      decoration: _cardDeco(),
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: (maxY + 1.5).clamp(3, double.infinity),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => Colors.grey.shade800,
                tooltipBorderRadius: BorderRadius.circular(8),
                getTooltipItems: (spots) => spots
                    .map((s) => LineTooltipItem(
                          '${s.y.toInt()} chaleur${s.y > 1 ? 's' : ''}',
                          const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12),
                        ))
                    .toList(),
              ),
              handleBuiltInTouches: true,
            ),
            titlesData: _buildTitlesData(maxY),
            gridData: _buildGridData(maxY),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.4,
                color: _couleurChaleur,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                    radius: 4.5,
                    color: Colors.white,
                    strokeWidth: 2.5,
                    strokeColor: _couleurChaleur,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _couleurChaleur.withOpacity(0.22),
                      _couleurChaleur.withOpacity(0.02),
                    ],
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        ),
      ),
    );
  }

  Widget _buildGraphiqueIntensiteChaleurs() {
    final compteur = <String, int>{
      'Faible': 0,
      'Moyenne': 0,
      'Forte': 0,
      'N/A': 0,
    };
    for (var c in _chaleurs) {
      final intensite = c['intensite'] as String? ?? 'N/A';
      compteur[intensite] = (compteur[intensite] ?? 0) + 1;
    }

    final sections = [
      _PieData('Faible', compteur['Faible']!.toDouble(), Colors.yellow.shade700),
      _PieData('Moyenne', compteur['Moyenne']!.toDouble(), Colors.orange),
      _PieData('Forte', compteur['Forte']!.toDouble(), _couleurChaleur),
      _PieData('N/A', compteur['N/A']!.toDouble(), Colors.grey.shade300),
    ].where((s) => s.valeur > 0).toList();

    if (sections.isEmpty || _totalChaleurs == 0) {
      return _buildVide(message: 'Aucune chaleur enregistrée');
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: SizedBox(
              height: 160,
              child: PieChart(
                PieChartData(
                  sections: sections
                      .map((s) => PieChartSectionData(
                            value: s.valeur,
                            color: s.couleur,
                            radius: 55,
                            title:
                                '${(s.valeur / _totalChaleurs * 100).toStringAsFixed(0)}%',
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ))
                      .toList(),
                  sectionsSpace: 3,
                  centerSpaceRadius: 32,
                  startDegreeOffset: -90,
                ),
                duration: const Duration(milliseconds: 500),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sections
                  .map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                  color: s.couleur, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(s.label,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[700])),
                            ),
                            Text('${s.valeur.toInt()}',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: s.couleur)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListeChaleurs() {
    if (_chaleurs.isEmpty) return _buildVide(message: 'Aucune chaleur enregistrée');

    return Column(
      children: _chaleurs.take(10).map((c) {
        final date = DateTime.parse(c['date_chaleur']);
        final intensite = c['intensite'] as String? ?? 'N/A';
        final signes = c['signes'] as String?;

        Color couleurIntensite;
        switch (intensite) {
          case 'Forte':
            couleurIntensite = _couleurChaleur;
            break;
          case 'Moyenne':
            couleurIntensite = Colors.orange;
            break;
          case 'Faible':
            couleurIntensite = Colors.yellow.shade700;
            break;
          default:
            couleurIntensite = Colors.grey;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: couleurIntensite.withOpacity(0.3), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: couleurIntensite.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.local_fire_department_rounded,
                    color: couleurIntensite, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDateComplete(date),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    if (signes != null && signes.isNotEmpty)
                      Text(signes,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: couleurIntensite.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  intensite,
                  style: TextStyle(
                      color: couleurIntensite,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ============================================================
  // TAB 3 : ACCOUPLEMENTS
  // ============================================================

  Widget _buildTabAccouplements() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitre('❤️ Évolution des accouplements', 'Par mois sur la période'),
          const SizedBox(height: 12),
          _buildGraphiqueBarresSimple(
            donnees: _donneesMensuelles.map((d) => d.accouplements).toList(),
            couleur: _couleurAccouplement,
            labelTooltip: 'accouplement(s)',
          ),
          const SizedBox(height: 20),
          _buildTitre('📋 Historique détaillé',
              '${_totalAccouplements} accouplement(s)'),
          const SizedBox(height: 12),
          _buildListeAccouplements(),
        ],
      ),
    );
  }

  Widget _buildGraphiqueBarresSimple({
    required List<double> donnees,
    required Color couleur,
    required String labelTooltip,
  }) {
    if (donnees.isEmpty) return _buildVide();
    final maxY = donnees.fold(0.0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 20, 16, 12),
      decoration: _cardDeco(),
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: (maxY + 1.5).clamp(3, double.infinity),
            minY: 0,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => Colors.grey.shade800,
                tooltipBorderRadius: BorderRadius.circular(8),
                getTooltipItem: (group, gi, rod, ri) {
                  if (rod.toY == 0) return null;
                  return BarTooltipItem(
                    '${rod.toY.toInt()} $labelTooltip',
                    const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  );
                },
              ),
            ),
            titlesData: _buildTitlesData(maxY),
            gridData: _buildGridData(maxY),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(donnees.length, (i) {
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: donnees[i],
                    color: couleur,
                    width: 14,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(5)),
                  ),
                ],
              );
            }),
          ),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        ),
      ),
    );
  }

  Widget _buildListeAccouplements() {
    if (_accouplements.isEmpty) {
      return _buildVide(message: 'Aucun accouplement enregistré');
    }

    return Column(
      children: _accouplements.take(10).map((a) {
        final date = DateTime.parse(a['date_accouplement']);
        final dateAgnelage = a['date_prevue_agnelage'] != null
            ? DateTime.parse(a['date_prevue_agnelage'])
            : null;
        final miseBas = a['date_mise_bas'];
        final reussi = miseBas != null;
        final methode = a['methode'] as String? ?? 'Naturel';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: reussi
                  ? _couleurAgnelage.withOpacity(0.3)
                  : _couleurAccouplement.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.favorite_rounded,
                      color: _couleurAccouplement, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _formatDateComplete(date),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: reussi
                          ? _couleurAgnelage.withOpacity(0.12)
                          : Colors.orange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      reussi ? '✅ Agnelé' : '⏳ En cours',
                      style: TextStyle(
                        color: reussi ? _couleurAgnelage : Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // ✅ FIX overflow : Wrap évite le débordement sur textes longs
              Wrap(
                spacing   : 8,
                runSpacing: 4,
                children  : [
                  _chip(Icons.sync_rounded, methode, Colors.grey.shade400),
                  if (dateAgnelage != null)
                    _chip(
                      Icons.calendar_today_rounded,
                      'Agnelage: ${_formatDate(dateAgnelage)}',
                      reussi ? _couleurAgnelage : _couleurAccouplement,
                    ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ============================================================
  // TAB 4 : AGNELAGES
  // ============================================================

  Widget _buildTabAgnelages() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitre('🍼 Évolution des agnelages', 'Naissances par mois'),
          const SizedBox(height: 12),
          _buildGraphiqueBarresSimple(
            donnees: _donneesMensuelles.map((d) => d.agnelages).toList(),
            couleur: _couleurAgnelage,
            labelTooltip: 'agnelage(s)',
          ),
          const SizedBox(height: 20),

          // Courbe cumulative
          _buildTitre('📈 Agnelages cumulés', 'Progression totale'),
          const SizedBox(height: 12),
          _buildGraphiqueAgnelagesCumules(),
          const SizedBox(height: 20),

          _buildTitre(
              '📋 Historique détaillé', '${_totalAgnelages} agnelage(s)'),
          const SizedBox(height: 12),
          _buildListeAgnelages(),
        ],
      ),
    );
  }

  Widget _buildGraphiqueAgnelagesCumules() {
    if (_donneesMensuelles.isEmpty) return _buildVide();

    double cumul = 0;
    final spots = _donneesMensuelles.asMap().entries.map((e) {
      cumul += e.value.agnelages;
      return FlSpot(e.key.toDouble(), cumul);
    }).toList();

    final maxY = cumul.clamp(3.0, double.infinity);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 20, 16, 12),
      decoration: _cardDeco(),
      child: SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: maxY + 1,
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => Colors.grey.shade800,
                tooltipBorderRadius: BorderRadius.circular(8),
                getTooltipItems: (spots) => spots
                    .map((s) => LineTooltipItem(
                          'Total: ${s.y.toInt()} agnelage${s.y > 1 ? 's' : ''}',
                          const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12),
                        ))
                    .toList(),
              ),
              handleBuiltInTouches: true,
            ),
            titlesData: _buildTitlesData(maxY),
            gridData: _buildGridData(maxY),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.3,
                color: _couleurAgnelage,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                    radius: 4,
                    color: Colors.white,
                    strokeWidth: 2.5,
                    strokeColor: _couleurAgnelage,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _couleurAgnelage.withOpacity(0.2),
                      _couleurAgnelage.withOpacity(0.01),
                    ],
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        ),
      ),
    );
  }

  Widget _buildListeAgnelages() {
    if (_agnelages.isEmpty) {
      return _buildVide(message: 'Aucun agnelage enregistré');
    }

    return Column(
      children: _agnelages.take(10).map((a) {
        final dateMiseBas = DateTime.parse(a['date_mise_bas']);
        final dateAccouplement = DateTime.parse(a['date_accouplement']);
        final gestationJours =
            dateMiseBas.difference(dateAccouplement).inDays;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _couleurAgnelage.withOpacity(0.3), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.child_care_rounded,
                      color: _couleurAgnelage, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _formatDateComplete(dateMiseBas),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _couleurAgnelage.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '✅ Réussi',
                      style: TextStyle(
                        color: _couleurAgnelage,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _chip(
                Icons.timeline_rounded,
                'Gestation: $gestationJours jours',
                _couleurAgnelage,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ============================================================
  // WIDGETS UTILITAIRES
  // ============================================================

  Widget _buildTitre(String titre, String sous) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titre,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
        const SizedBox(height: 2),
        Text(sous,
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildLegende() {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        _legendeItem(_couleurChaleur, 'Chaleurs'),
        _legendeItem(_couleurAccouplement, 'Accouplements'),
        _legendeItem(_couleurAgnelage, 'Agnelages'),
      ],
    );
  }

  Widget _legendeItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    // ✅ FIX overflow : Flexible + ellipsis pour textes longs
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            overflow  : TextOverflow.ellipsis,
            maxLines  : 1,
            style     : TextStyle(
              fontSize    : 11,
              color       : color,
              fontWeight  : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVide({String message = 'Aucune donnée sur cette période'}) {
    return Container(
      height: 120,
      decoration: _cardDeco(),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded, size: 40, color: Colors.grey[300]),
            const SizedBox(height: 6),
            Text(message,
                style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDeco() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3)),
      ],
    );
  }

  // ===== TITRES DES AXES (réutilisable) =====

  FlTitlesData _buildTitlesData(double maxY) {
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 26,
          interval: (maxY / 3).ceilToDouble().clamp(1, double.infinity),
          getTitlesWidget: (v, _) => Text(
            v.toInt().toString(),
            style: TextStyle(color: Colors.grey[500], fontSize: 10),
          ),
        ),
      ),
      rightTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          getTitlesWidget: (v, _) {
            final i = v.toInt();
            if (i < 0 || i >= _donneesMensuelles.length) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _nomMoisCourt(_donneesMensuelles[i].mois.month),
                style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            );
          },
        ),
      ),
    );
  }

  FlGridData _buildGridData(double maxY) {
    return FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: (maxY / 3).ceilToDouble().clamp(1, double.infinity),
      getDrawingHorizontalLine: (_) => FlLine(
        color: Colors.grey[200]!,
        strokeWidth: 1,
        dashArray: [4, 4],
      ),
    );
  }

  // ===== FORMATAGE DATES =====

  String _nomMoisCourt(int mois) {
    const noms = [
      '', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
      'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc',
    ];
    return noms[mois];
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatDateComplete(DateTime d) {
    const mois = [
      '', 'jan', 'fév', 'mar', 'avr', 'mai', 'jun',
      'jul', 'aoû', 'sep', 'oct', 'nov', 'déc',
    ];
    return '${d.day} ${mois[d.month]} ${d.year}';
  }
}

// ============================================================
// MODÈLES INTERNES
// ============================================================

class _BrebisMonthData {
  final DateTime mois;
  final double chaleurs;
  final double accouplements;
  final double agnelages;

  _BrebisMonthData({
    required this.mois,
    required this.chaleurs,
    required this.accouplements,
    required this.agnelages,
  });
}

class _PieData {
  final String label;
  final double valeur;
  final Color couleur;

  _PieData(this.label, this.valeur, this.couleur);
}