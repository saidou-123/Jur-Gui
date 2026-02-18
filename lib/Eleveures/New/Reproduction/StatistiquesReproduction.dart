// ============================================================
// MODULE STATISTIQUES REPRODUCTION - VERSION PROFESSIONNELLE
// Dashboard complet avec graphiques et indicateurs
// ============================================================

import 'package:depart/Eleveures/New/Reproduction/ReproductionBusinessService.dart';
import 'package:depart/Eleveures/New/Reproduction/ReproductionConfig.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class StatistiquesReproductionPage extends StatefulWidget {
  const StatistiquesReproductionPage({super.key});

  @override
  State<StatistiquesReproductionPage> createState() => 
      _StatistiquesReproductionPageState();
}

class _StatistiquesReproductionPageState 
    extends State<StatistiquesReproductionPage> {
  final supabase = Supabase.instance.client;
  final _businessService = ReproductionBusinessService();
  
  bool _isLoading = true;
  StatistiquesReproduction? _statsGlobales;
  List<Map<String, dynamic>> _topBrebis = [];
  Map<String, int> _chaleursMois = {};
  Map<String, int> _accouplementsMois = {};

  @override
  void initState() {
    super.initState();
    _chargerStatistiques();
  }

  Future<void> _chargerStatistiques() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception("Non connecté");

      // Charger statistiques globales
      final stats = await _businessService.calculerStatistiquesGlobales(userId);
      
      // Charger top brebis par fertilité
      final topBrebis = await _chargerTopBrebis(userId);
      
      // Charger répartition mensuelle
      final chaleursMois = await _chargerChaleursMois(userId);
      final accouplementsMois = await _chargerAccouplementsMois(userId);

      if (mounted) {
        setState(() {
          _statsGlobales = stats;
          _topBrebis = topBrebis;
          _chaleursMois = chaleursMois;
          _accouplementsMois = accouplementsMois;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint("❌ Erreur chargement statistiques: $e\n$stackTrace");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _chargerTopBrebis(String userId) async {
    final stats = await supabase
        .from('statistiques_reproduction')
        .select('animal_id, source, nombre_accouplements, nombre_mises_bas, taux_fertilite')
        .eq('user_id', userId)
        .gte('nombre_accouplements', 1)
        .order('taux_fertilite', ascending: false)
        .limit(10);

    // Enrichir avec les noms
    List<Map<String, dynamic>> enrichies = [];
    for (var stat in stats) {
      try {
        dynamic animal;
        if (stat['source'] == 'achete') {
          animal = await supabase
              .from('animal_acheter')
              .select('nom, race')
              .eq('id', stat['animal_id'])
              .single();
        } else {
          animal = await supabase
              .from('nouveaux_nee')
              .select('nom, race')
              .eq('id', stat['animal_id'])
              .single();
        }
        
        enrichies.add({
          ...stat,
          'nom': animal['nom'],
          'race': animal['race'],
        });
      } catch (e) {
        debugPrint("⚠️ Erreur enrichissement: $e");
      }
    }

    return enrichies;
  }

  Future<Map<String, int>> _chargerChaleursMois(String userId) async {
    final maintenant = DateTime.now();
    Map<String, int> repartition = {};

    for (int i = 5; i >= 0; i--) {
      final mois = DateTime(maintenant.year, maintenant.month - i, 1);
      final moisSuivant = DateTime(maintenant.year, maintenant.month - i + 1, 1);
      
      final chaleurs = await supabase
          .from('chaleurs')
          .select('id')
          .eq('user_id', userId)
          .gte('date_chaleur', mois.toIso8601String())
          .lt('date_chaleur', moisSuivant.toIso8601String());
      
      final nomMois = _getNomMois(mois.month);
      repartition[nomMois] = chaleurs.length;
    }

    return repartition;
  }

  Future<Map<String, int>> _chargerAccouplementsMois(String userId) async {
    final maintenant = DateTime.now();
    Map<String, int> repartition = {};

    for (int i = 5; i >= 0; i--) {
      final mois = DateTime(maintenant.year, maintenant.month - i, 1);
      final moisSuivant = DateTime(maintenant.year, maintenant.month - i + 1, 1);
      
      final accouplements = await supabase
          .from('accouplements')
          .select('id')
          .eq('user_id', userId)
          .gte('date_accouplement', mois.toIso8601String())
          .lt('date_accouplement', moisSuivant.toIso8601String());
      
      final nomMois = _getNomMois(mois.month);
      repartition[nomMois] = accouplements.length;
    }

    return repartition;
  }

  String _getNomMois(int mois) {
    const noms = [
      '', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
      'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'
    ];
    return noms[mois];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Statistiques Reproduction"),
        backgroundColor: Color(ReproductionConfig.colorInfo),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerStatistiques,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCartesGlobales(),
                  const SizedBox(height: 24),
                  _buildGraphiqueMensuel(),
                  const SizedBox(height: 24),
                  _buildTopBrebis(),
                  const SizedBox(height: 24),
                  _buildIndicateursPerformance(),
                ],
              ),
            ),
    );
  }

  Widget _buildCartesGlobales() {
    if (_statsGlobales == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Vue d'ensemble",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildCarteStats(
                Icons.favorite,
                "${_statsGlobales!.totalAccouplements}",
                "Accouplements",
                Color(ReproductionConfig.colorPrimary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCarteStats(
                Icons.check_circle,
                "${_statsGlobales!.accouplementsReussis}",
                "Réussis",
                Color(ReproductionConfig.colorSuccess),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildCarteStats(
                Icons.local_fire_department,
                "${_statsGlobales!.chaleursCeMois}",
                "Chaleurs ce mois",
                Color(ReproductionConfig.colorWarning),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCarteStats(
                Icons.pregnant_woman,
                "${_statsGlobales!.agnelagesAttendus30j}",
                "Agnelages à venir",
                Color(ReproductionConfig.colorSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildCarteTauxFertilite(),
      ],
    );
  }

  Widget _buildCarteStats(
    IconData icon,
    String valeur,
    String label,
    Color couleur,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: couleur.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: couleur, width: 2),
      ),
      child: Column(
        children: [
          Icon(icon, color: couleur, size: 32),
          const SizedBox(height: 8),
          Text(
            valeur,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: couleur,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCarteTauxFertilite() {
    if (_statsGlobales == null) return const SizedBox.shrink();

    final taux = _statsGlobales!.tauxFertilite;
    Color couleur;
    String evaluation;

    if (taux >= ReproductionConfig.tauxFertiliteNormalMin) {
      couleur = Color(ReproductionConfig.colorSuccess);
      evaluation = "Excellent";
    } else if (taux >= 0.60) {
      couleur = Color(ReproductionConfig.colorWarning);
      evaluation = "Acceptable";
    } else {
      couleur = Color(ReproductionConfig.colorDanger);
      evaluation = "Faible";
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: couleur.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: couleur, width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Taux de fertilité global",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                evaluation,
                style: TextStyle(
                  fontSize: 14,
                  color: couleur,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: taux,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(couleur),
            minHeight: 20,
          ),
          const SizedBox(height: 8),
          Text(
            "${(taux * 100).toStringAsFixed(1)}%",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: couleur,
            ),
          ),
          Text(
            "Objectif : ${(ReproductionConfig.tauxFertiliteNormalMin * 100).toInt()}% minimum",
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildGraphiqueMensuel() {
    if (_chaleursMois.isEmpty) return const SizedBox.shrink();

    final maxChaleurs = _chaleursMois.values.reduce((a, b) => a > b ? a : b);
    final maxAccouplements = _accouplementsMois.values.reduce((a, b) => a > b ? a : b);
    final maxValue = maxChaleurs > maxAccouplements ? maxChaleurs : maxAccouplements;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Évolution sur 6 mois",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  color: Color(ReproductionConfig.colorWarning),
                ),
                const SizedBox(width: 8),
                const Text("Chaleurs", style: TextStyle(fontSize: 12)),
                const SizedBox(width: 16),
                Container(
                  width: 12,
                  height: 12,
                  color: Color(ReproductionConfig.colorPrimary),
                ),
                const SizedBox(width: 8),
                const Text("Accouplements", style: TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _chaleursMois.keys.map((mois) {
                  final chaleurs = _chaleursMois[mois] ?? 0;
                  final accouplements = _accouplementsMois[mois] ?? 0;
                  
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Container(
                                  height: maxValue > 0 ? (chaleurs / maxValue) * 180 : 0,
                                  decoration: BoxDecoration(
                                    color: Color(ReproductionConfig.colorWarning),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Container(
                                  height: maxValue > 0 ? (accouplements / maxValue) * 180 : 0,
                                  decoration: BoxDecoration(
                                    color: Color(ReproductionConfig.colorPrimary),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            mois,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBrebis() {
    if (_topBrebis.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.info, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                "Aucune statistique disponible",
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "🏆 Top brebis par fertilité",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._topBrebis.take(5).map((brebis) => _buildBrebisItem(brebis)),
          ],
        ),
      ),
    );
  }

  Widget _buildBrebisItem(Map<String, dynamic> brebis) {
    final taux = (brebis['taux_fertilite'] as num).toDouble() / 100;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  brebis['nom'] ?? 'Sans nom',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                "${brebis['nombre_mises_bas']}/${brebis['nombre_accouplements']}",
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: taux,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              _getColorForTaux(taux),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            "${(taux * 100).toStringAsFixed(0)}% - ${brebis['race']}",
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicateursPerformance() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "📊 Indicateurs de performance",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildIndicateur(
              "Saison actuelle",
              _getSaisonActuelle(),
              _getCouleurSaison(),
            ),
            const Divider(),
            _buildIndicateur(
              "Moyenne accouplements/brebis",
              _calculerMoyenneAccouplements(),
              Colors.blue,
            ),
            const Divider(),
            _buildIndicateur(
              "Taux de suivi",
              _calculerTauxSuivi(),
              Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicateur(String label, String valeur, Color couleur) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            valeur,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: couleur,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForTaux(double taux) {
    if (taux >= 0.75) return Color(ReproductionConfig.colorSuccess);
    if (taux >= 0.60) return Color(ReproductionConfig.colorWarning);
    return Color(ReproductionConfig.colorDanger);
  }

  String _getSaisonActuelle() {
    final mois = DateTime.now().month;
    if (mois >= 9 || mois <= 2) return "Saison active";
    if (mois >= 3 && mois <= 5) return "Transition";
    return "Anœstrus";
  }

  Color _getCouleurSaison() {
    final mois = DateTime.now().month;
    if (mois >= 9 || mois <= 2) return Colors.green;
    if (mois >= 3 && mois <= 5) return Colors.orange;
    return Colors.red;
  }

  String _calculerMoyenneAccouplements() {
    if (_statsGlobales == null || _topBrebis.isEmpty) return "N/A";
    
    final total = _topBrebis.fold<int>(
      0,
      (sum, b) => sum + (b['nombre_accouplements'] as int),
    );
    
    final moyenne = total / _topBrebis.length;
    return moyenne.toStringAsFixed(1);
  }

  String _calculerTauxSuivi() {
    if (_statsGlobales == null) return "N/A";
    
    // Calcul simplifié : chaleurs / accouplements
    if (_statsGlobales!.totalAccouplements == 0) return "0%";
    
    final ratio = _statsGlobales!.chaleursCeMois / 
                  _statsGlobales!.totalAccouplements;
    
    return "${(ratio * 100).toStringAsFixed(0)}%";
  }
}