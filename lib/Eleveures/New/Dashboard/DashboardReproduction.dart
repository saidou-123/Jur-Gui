// ============================================================
// DASHBOARD REPRODUCTION - ÉVOLUTION DES BREBIS
// Fichier: lib/Eleveures/New/Dashboard/DashboardReproduction.dart
// Dépendance: fl_chart: ^0.68.0 (à ajouter dans pubspec.yaml)
// ============================================================

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardReproduction extends StatefulWidget {
  const DashboardReproduction({super.key});

  @override
  State<DashboardReproduction> createState() => _DashboardReproductionState();
}

class _DashboardReproductionState extends State<DashboardReproduction>
    with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  // ===== ANIMATIONS =====
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // ===== DONNÉES =====
  bool _isLoading = true;
  String _periodeSelectionnee = '6 mois'; // '3 mois', '6 mois', '1 an'

  // Données mensuelles pour les graphiques
  List<_MoisData> _donnesMensuelles = [];

  // Statistiques globales
  int _totalBrebis = 0;
  int _brebisEnChaleur = 0;
  int _brebisGestantes = 0;
  int _agnelauxCeMois = 0;
  double _tauxFertilite = 0.0;

  // Données pour graphique en barres groupées
  int _touchedGroupIndex = -1;

  // Données pour graphique circulaire
  int _touchedPieIndex = -1;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _chargerDonnees();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // ===== CHARGEMENT DES DONNÉES =====

  Future<void> _chargerDonnees() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final nbMois = _periodeSelectionnee == '3 mois'
          ? 3
          : _periodeSelectionnee == '6 mois'
              ? 6
              : 12;

      await Future.wait([
        _chargerStatistiquesGlobales(userId),
        _chargerDonnesMensuelles(userId, nbMois),
      ]);

      if (mounted) {
        setState(() => _isLoading = false);
        _fadeController.forward(from: 0);
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement dashboard: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _chargerStatistiquesGlobales(String userId) async {
    // Total brebis (achetées + nées)
    final achetes = await supabase
        .from('animal_acheter')
        .select('id')
        .eq('sexe', 'Femelle')
        .eq('user_id', userId);

    final nees = await supabase
        .from('nouveaux_nee')
        .select('id')
        .eq('sexe', 'Femelle')
        .eq('user_id', userId);

    _totalBrebis = achetes.length + nees.length;

    // Brebis gestantes
    final gestantes = await supabase
        .from('accouplements')
        .select('id')
        .eq('user_id', userId)
        .isFilter('date_mise_bas', null);

    _brebisGestantes = gestantes.length;

    // Brebis en chaleur (dernières 48h)
    final il48h =
        DateTime.now().subtract(const Duration(hours: 48)).toIso8601String();
    final enChaleur = await supabase
        .from('chaleurs')
        .select('animal_id')
        .eq('user_id', userId)
        .gte('date_chaleur', il48h);

    _brebisEnChaleur = enChaleur.length;

    // Agneaux ce mois
    final debutMois =
        DateTime(DateTime.now().year, DateTime.now().month, 1).toIso8601String();
    final agnelages = await supabase
        .from('accouplements')
        .select('id')
        .eq('user_id', userId)
        .not('date_mise_bas', 'is', null)
        .gte('date_mise_bas', debutMois);

    _agnelauxCeMois = agnelages.length;

    // Taux de fertilité global
    final totalAccouplements = await supabase
        .from('accouplements')
        .select('id, date_mise_bas')
        .eq('user_id', userId);

    if (totalAccouplements.isNotEmpty) {
      final reussis =
          totalAccouplements.where((a) => a['date_mise_bas'] != null).length;
      _tauxFertilite = reussis / totalAccouplements.length;
    }
  }

  Future<void> _chargerDonnesMensuelles(String userId, int nbMois) async {
    final maintenant = DateTime.now();
    List<_MoisData> donnees = [];

    for (int i = nbMois - 1; i >= 0; i--) {
      final mois = DateTime(maintenant.year, maintenant.month - i, 1);
      final moisSuivant = DateTime(maintenant.year, maintenant.month - i + 1, 1);

      // Chaleurs du mois
      final chaleurs = await supabase
          .from('chaleurs')
          .select('id')
          .eq('user_id', userId)
          .gte('date_chaleur', mois.toIso8601String())
          .lt('date_chaleur', moisSuivant.toIso8601String());

      // Accouplements du mois
      final accouplements = await supabase
          .from('accouplements')
          .select('id')
          .eq('user_id', userId)
          .gte('date_accouplement', mois.toIso8601String())
          .lt('date_accouplement', moisSuivant.toIso8601String());

      // Agnelages du mois
      final agnelages = await supabase
          .from('accouplements')
          .select('id')
          .eq('user_id', userId)
          .not('date_mise_bas', 'is', null)
          .gte('date_mise_bas', mois.toIso8601String())
          .lt('date_mise_bas', moisSuivant.toIso8601String());

      donnees.add(_MoisData(
        mois: mois,
        chaleurs: chaleurs.length.toDouble(),
        accouplements: accouplements.length.toDouble(),
        agnelages: agnelages.length.toDouble(),
      ));
    }

    _donnesMensuelles = donnees;
  }

  // ===== COULEURS DU THÈME =====
  static const Color _couleurPrimaire = Color(0xFF1B5E20);
  static const Color _couleurSecondaire = Color(0xFF2E7D32);
  static const Color _couleurChaleur = Color(0xFFE53935);
  static const Color _couleurAccouplement = Color(0xFF8E24AA);
  static const Color _couleurAgnelage = Color(0xFF00ACC1);
  static const Color _couleurFond = Color(0xFFF1F8E9);
  static const Color _couleurCarte = Colors.white;

  // ===== CONSTRUCTION UI =====

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _couleurFond,
      appBar: _buildAppBar(),
      body: _isLoading ? _buildLoading() : _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Évolution du Troupeau',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 20,
          letterSpacing: 0.3,
        ),
      ),
      backgroundColor: _couleurPrimaire,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _chargerDonnees,
          tooltip: 'Actualiser',
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _couleurPrimaire),
          SizedBox(height: 16),
          Text(
            'Chargement des données...',
            style: TextStyle(color: _couleurPrimaire, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: RefreshIndicator(
        onRefresh: _chargerDonnees,
        color: _couleurPrimaire,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bandeau de période
              _buildSelectorPeriode(),
              const SizedBox(height: 20),

              // Cartes KPI
              _buildKPICards(),
              const SizedBox(height: 24),

              // Graphique évolution (barres groupées)
              _buildTitreSection(
                  '📊 Évolution mensuelle', 'Chaleurs · Accouplements · Agnelages'),
              const SizedBox(height: 12),
              _buildGraphiqueEvolution(),
              const SizedBox(height: 24),

              // Graphique ligne — tendance chaleurs
              _buildTitreSection(
                  '🔥 Tendance des chaleurs', 'Nombre de chaleurs détectées par mois'),
              const SizedBox(height: 12),
              _buildGraphiqueLigneChaleurs(),
              const SizedBox(height: 24),

              // Graphique circulaire — état du troupeau
              _buildTitreSection(
                  '🐑 État actuel du troupeau', 'Répartition par statut reproductif'),
              const SizedBox(height: 12),
              _buildGraphiqueCirculaire(),
              const SizedBox(height: 24),

              // Graphique ligne — agnelages cumulés
              _buildTitreSection(
                  '🍼 Agnelages cumulés', 'Progression sur la période'),
              const SizedBox(height: 12),
              _buildGraphiqueAgnelagesCumules(),
            ],
          ),
        ),
      ),
    );
  }

  // ===== SÉLECTEUR DE PÉRIODE =====

  Widget _buildSelectorPeriode() {
    return Container(
      padding: const EdgeInsets.all(4),
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
      child: Row(
        children: ['3 mois', '6 mois', '1 an'].map((periode) {
          final isSelected = _periodeSelectionnee == periode;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _periodeSelectionnee = periode);
                _chargerDonnees();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? _couleurPrimaire : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  periode,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[600],
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ===== CARTES KPI =====

  Widget _buildKPICards() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      children: [
        _buildKPICard(
          titre: 'Total Brebis',
          valeur: _totalBrebis.toString(),
          icone: Icons.pets_rounded,
          couleur: _couleurSecondaire,
          sousTitre: 'dans le troupeau',
        ),
        _buildKPICard(
          titre: 'En Chaleur',
          valeur: _brebisEnChaleur.toString(),
          icone: Icons.local_fire_department_rounded,
          couleur: _couleurChaleur,
          sousTitre: 'dernières 48h',
        ),
        _buildKPICard(
          titre: 'Gestantes',
          valeur: _brebisGestantes.toString(),
          icone: Icons.pregnant_woman_rounded,
          couleur: _couleurAccouplement,
          sousTitre: 'en gestation',
        ),
        _buildKPICard(
          titre: 'Agnelages',
          valeur: _agnelauxCeMois.toString(),
          icone: Icons.child_care_rounded,
          couleur: _couleurAgnelage,
          sousTitre: 'ce mois-ci',
        ),
      ],
    );
  }

  Widget _buildKPICard({
    required String titre,
    required String valeur,
    required IconData icone,
    required Color couleur,
    required String sousTitre,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _couleurCarte,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: couleur.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: couleur.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: couleur.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icone, color: couleur, size: 20),
              ),
              Text(
                valeur,
                style: TextStyle(
                  fontSize: 28,
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
              Text(
                titre,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D2D2D),
                ),
              ),
              Text(
                sousTitre,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===== TITRE DE SECTION =====

  Widget _buildTitreSection(String titre, String sousTitre) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titre,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          sousTitre,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // ===== GRAPHIQUE 1 : BARRES GROUPÉES — ÉVOLUTION =====

  Widget _buildGraphiqueEvolution() {
    if (_donnesMensuelles.isEmpty) return _buildEmptyChart();

    final maxY = _donnesMensuelles
        .map((d) => [d.chaleurs, d.accouplements, d.agnelages])
        .expand((e) => e)
        .reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 16, 12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLegende(),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (maxY + 2).clamp(5, double.infinity),
                minY: 0,
                groupsSpace: 10,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.grey[850]!,
                    tooltipBorderRadius: BorderRadius.circular(10),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final labels = ['Chaleurs', 'Accouplements', 'Agnelages'];
                      return BarTooltipItem(
                        '${labels[rodIndex]}: ${rod.toY.toInt()}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                  touchCallback: (event, response) {
                    setState(() {
                      if (response == null || response.spot == null) {
                        _touchedGroupIndex = -1;
                      } else {
                        _touchedGroupIndex = response.spot!.touchedBarGroupIndex;
                      }
                    });
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: (maxY / 4).ceilToDouble().clamp(1, double.infinity),
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= _donnesMensuelles.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _nomMoisCourt(_donnesMensuelles[index].mois.month),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval:
                      (maxY / 4).ceilToDouble().clamp(1, double.infinity),
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.grey[200]!,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(_donnesMensuelles.length, (index) {
                  final d = _donnesMensuelles[index];
                  final isSelected = index == _touchedGroupIndex;
                  return BarChartGroupData(
                    x: index,
                    groupVertically: false,
                    barRods: [
                      _buildBar(d.chaleurs, _couleurChaleur, isSelected),
                      _buildBar(d.accouplements, _couleurAccouplement, isSelected),
                      _buildBar(d.agnelages, _couleurAgnelage, isSelected),
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

  BarChartRodData _buildBar(double value, Color color, bool isSelected) {
    return BarChartRodData(
      toY: value,
      color: isSelected ? color : color.withOpacity(0.75),
      width: 8,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
    );
  }

  Widget _buildLegende() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
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
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ===== GRAPHIQUE 2 : LIGNE — TENDANCE CHALEURS =====

  Widget _buildGraphiqueLigneChaleurs() {
    if (_donnesMensuelles.isEmpty) return _buildEmptyChart();

    final spots = _donnesMensuelles
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.chaleurs))
        .toList();

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 16, 12),
      decoration: _cardDecoration(),
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: (maxY + 2).clamp(5, double.infinity),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => Colors.grey[850]!,
                tooltipBorderRadius: BorderRadius.circular(10),
                getTooltipItems: (touchedSpots) => touchedSpots
                    .map((s) => LineTooltipItem(
                          '${s.y.toInt()} chaleur${s.y > 1 ? 's' : ''}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ))
                    .toList(),
              ),
              handleBuiltInTouches: true,
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: (maxY / 4).ceilToDouble().clamp(1, double.infinity),
                  getTitlesWidget: (value, meta) => Text(
                    value.toInt().toString(),
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ),
              ),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= _donnesMensuelles.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _nomMoisCourt(_donnesMensuelles[index].mois.month),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval:
                  (maxY / 4).ceilToDouble().clamp(1, double.infinity),
              getDrawingHorizontalLine: (_) => FlLine(
                color: Colors.grey[200]!,
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.35,
                color: _couleurChaleur,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(
                    radius: 4,
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
                      _couleurChaleur.withOpacity(0.25),
                      _couleurChaleur.withOpacity(0.02),
                    ],
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic,
        ),
      ),
    );
  }

  // ===== GRAPHIQUE 3 : CIRCULAIRE — ÉTAT DU TROUPEAU =====

  Widget _buildGraphiqueCirculaire() {
    final brebisLibres =
        (_totalBrebis - _brebisGestantes - _brebisEnChaleur).clamp(0, _totalBrebis);

    final sections = [
      _PieSection('Libres', brebisLibres.toDouble(), _couleurSecondaire),
      _PieSection('Gestantes', _brebisGestantes.toDouble(), _couleurAccouplement),
      _PieSection('En chaleur', _brebisEnChaleur.toDouble(), _couleurChaleur),
    ].where((s) => s.valeur > 0).toList();

    if (sections.isEmpty || _totalBrebis == 0) {
      return _buildEmptyChart(message: 'Aucune brebis enregistrée');
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          _touchedPieIndex = -1;
                          return;
                        }
                        _touchedPieIndex = pieTouchResponse
                            .touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  sections: sections.asMap().entries.map((entry) {
                    final index = entry.key;
                    final section = entry.value;
                    final isSelected = index == _touchedPieIndex;
                    final pct = (section.valeur / _totalBrebis * 100).toStringAsFixed(0);

                    return PieChartSectionData(
                      value: section.valeur,
                      color: section.couleur,
                      radius: isSelected ? 85 : 70,
                      titleStyle: TextStyle(
                        fontSize: isSelected ? 14 : 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: const [
                          Shadow(color: Colors.black26, blurRadius: 3)
                        ],
                      ),
                      title: '$pct%',
                      badgeWidget: isSelected
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: section.couleur,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: section.couleur.withOpacity(0.4),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Text(
                                '${section.valeur.toInt()}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            )
                          : null,
                      badgePositionPercentageOffset: 1.3,
                    );
                  }).toList(),
                  sectionsSpace: 3,
                  centerSpaceRadius: 40,
                  startDegreeOffset: -90,
                ),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOutCubic,
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
                _buildPieLegendItem(
                    _couleurSecondaire, 'Libres', brebisLibres),
                const SizedBox(height: 10),
                _buildPieLegendItem(
                    _couleurAccouplement, 'Gestantes', _brebisGestantes),
                const SizedBox(height: 10),
                _buildPieLegendItem(
                    _couleurChaleur, 'En chaleur', _brebisEnChaleur),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _couleurPrimaire.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pets_rounded,
                          size: 14, color: _couleurPrimaire),
                      const SizedBox(width: 6),
                      Text(
                        'Total: $_totalBrebis',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _couleurPrimaire,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Taux de fertilité
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fertilité: ${(_tauxFertilite * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _tauxFertilite,
                        minHeight: 6,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _tauxFertilite >= 0.75
                              ? _couleurSecondaire
                              : _tauxFertilite >= 0.6
                                  ? Colors.orange
                                  : _couleurChaleur,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieLegendItem(Color color, String label, int count) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  // ===== GRAPHIQUE 4 : LIGNE — AGNELAGES CUMULÉS =====

  Widget _buildGraphiqueAgnelagesCumules() {
    if (_donnesMensuelles.isEmpty) return _buildEmptyChart();

    double cumul = 0;
    final spotsCumul = _donnesMensuelles.asMap().entries.map((e) {
      cumul += e.value.agnelages;
      return FlSpot(e.key.toDouble(), cumul);
    }).toList();

    final spotsAgnelages = _donnesMensuelles
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.agnelages))
        .toList();

    final maxY = cumul.clamp(5, double.infinity);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 16, 12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _legendeItem(_couleurAgnelage, 'Mensuel'),
              const SizedBox(width: 16),
              _legendeItem(_couleurPrimaire, 'Cumulé'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY + 1,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => Colors.grey[850]!,
                    tooltipBorderRadius: BorderRadius.circular(10),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((s) {
                        final label = s.barIndex == 0 ? 'Mensuel' : 'Cumulé';
                        return LineTooltipItem(
                          '$label: ${s.y.toInt()}',
                          TextStyle(
                            color: s.barIndex == 0
                                ? _couleurAgnelage
                                : _couleurPrimaire,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                  handleBuiltInTouches: true,
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: (maxY / 4).ceilToDouble().clamp(1, double.infinity),
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                    ),
                  ),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= _donnesMensuelles.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _nomMoisCourt(_donnesMensuelles[index].mois.month),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval:
                      (maxY / 4).ceilToDouble().clamp(1, double.infinity),
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.grey[200]!,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Ligne mensuelle
                  LineChartBarData(
                    spots: spotsAgnelages,
                    isCurved: false,
                    color: _couleurAgnelage,
                    barWidth: 2,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                        radius: 3.5,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: _couleurAgnelage,
                      ),
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                  // Ligne cumulée
                  LineChartBarData(
                    spots: spotsCumul,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: _couleurPrimaire,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeWidth: 2.5,
                        strokeColor: _couleurPrimaire,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _couleurPrimaire.withOpacity(0.15),
                          _couleurPrimaire.withOpacity(0.01),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeInOutCubic,
            ),
          ),
        ],
      ),
    );
  }

  // ===== ÉTAT VIDE =====

  Widget _buildEmptyChart({String message = 'Aucune donnée disponible'}) {
    return Container(
      height: 160,
      decoration: _cardDecoration(),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // ===== UTILITAIRES =====

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: _couleurCarte,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  String _nomMoisCourt(int mois) {
    const noms = [
      '', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
      'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc',
    ];
    return noms[mois];
  }
}

// ===== MODÈLES DE DONNÉES =====

class _MoisData {
  final DateTime mois;
  final double chaleurs;
  final double accouplements;
  final double agnelages;

  _MoisData({
    required this.mois,
    required this.chaleurs,
    required this.accouplements,
    required this.agnelages,
  });
}

class _PieSection {
  final String label;
  final double valeur;
  final Color couleur;

  _PieSection(this.label, this.valeur, this.couleur);
}