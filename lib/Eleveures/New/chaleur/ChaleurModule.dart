// ============================================================
// MODULE CHALEUR COMPLET - VERSION FINALE
// Gestion complète du suivi des chaleurs avec prédictions
// TOUTES LES NAVIGATIONS IMPLÉMENTÉES
// ============================================================

import 'package:depart/Eleveures/New/Accouplemt/Accouplement.dart';
import 'package:depart/Eleveures/New/Notification/NotificationService.dart';
import 'package:depart/Eleveures/New/Reproduction/ReproductionBusinessService.dart';
import 'package:depart/Eleveures/New/Reproduction/ReproductionConfig.dart';
import 'package:depart/Eleveures/New/chaleur/EnrChaleurPageAmelioree.dart';
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
  final _businessService = ReproductionBusinessService();
  final _notificationService = NotificationService();
  
  late TabController _tabController;
  
  List<Map<String, dynamic>> _brebis = [];
  List<Map<String, dynamic>> _brebisEnChaleur = [];
  List<Map<String, dynamic>> _prochainesChaleurs = [];
  
  bool _isLoading = true;
  String? _saisonActuelle;
  String? _indicateurSaison;
  Color? _couleurSaison;
  
  // Statistiques
  int _chaleursCeMois = 0;
  int _brebisDisponibles = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initModule();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initModule() async {
    await _notificationService.initialize();
    await _determinerSaison();
    await _chargerDonnees();
  }

  Future<void> _determinerSaison() async {
    final now = DateTime.now();
    final mois = now.month;

    if (mois >= 9 || mois <= 2) {
      _saisonActuelle = "Saison active de reproduction";
      _indicateurSaison = "🟢 Période favorable pour les chaleurs";
      _couleurSaison = Colors.green;
    } else if (mois >= 3 && mois <= 5) {
      _saisonActuelle = "Période de transition";
      _indicateurSaison = "🟡 Activité reproductive modérée";
      _couleurSaison = Colors.orange;
    } else {
      _saisonActuelle = "Anœstrus saisonnier";
      _indicateurSaison = "🔴 Période défavorable - Chaleurs rares";
      _couleurSaison = Colors.red;
    }
  }

  Future<void> _chargerDonnees() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception("Utilisateur non connecté");

      // Charger toutes les brebis
      final toutesLesBrebis = await _chargerToutesLesBrebis(userId);
      
      // Enrichir avec statut reproduction
      final brebisEnrichies = await _enrichirAvecStatutReproduction(toutesLesBrebis);
      
      // Filtrer brebis en chaleur (dernières 48h)
      final enChaleur = await _filtrerBrebisEnChaleur(brebisEnrichies);
      
      // Calculer prochaines chaleurs prévues
      final prochaines = await _calculerProchainesChaleurs(brebisEnrichies);
      
      // Calculer statistiques
      await _calculerStatistiques(userId, brebisEnrichies);

      if (mounted) {
        setState(() {
          _brebis = brebisEnrichies;
          _brebisEnChaleur = enChaleur;
          _prochainesChaleurs = prochaines;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint("❌ Erreur chargement: $e");
      debugPrint("Stack: $stackTrace");
      if (mounted) {
        _showSnackBar("Erreur de chargement", Colors.red);
        setState(() => _isLoading = false);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _chargerToutesLesBrebis(String userId) async {
    List<Map<String, dynamic>> toutes = [];

    // Brebis achetées
    try {
      final achetes = await supabase
          .from('animal_acheter')
          .select('id, nom, race, sexe, tag_rfid, image_url, provenance')
          .eq('sexe', 'Femelle')
          .eq('user_id', userId)
          .order('nom');

      for (var b in achetes) {
        b['source'] = 'achete';
        toutes.add(b);
      }
    } catch (e) {
      debugPrint("⚠️ Erreur brebis achetées: $e");
    }

    // Brebis nées
    try {
      final nees = await supabase
          .from('nouveaux_nee')
          .select('id, nom, race, sexe, tag_rfid, image_url, date_naissance')
          .eq('sexe', 'Femelle')
          .eq('user_id', userId)
          .order('nom');

      for (var b in nees) {
        b['source'] = 'nee';
        toutes.add(b);
      }
    } catch (e) {
      debugPrint("⚠️ Erreur brebis nées: $e");
    }

    return toutes;
  }

  Future<List<Map<String, dynamic>>> _enrichirAvecStatutReproduction(
    List<Map<String, dynamic>> brebis,
  ) async {
    for (var brebis in brebis) {
      try {
        // Vérifier gestation
        final accouplement = await supabase
            .from('accouplements')
            .select('date_accouplement, date_prevue_agnelage, date_mise_bas')
            .eq('brebis_id', brebis['id'])
            .eq('source_brebis', brebis['source'])
            .isFilter('date_mise_bas', null)
            .order('date_accouplement', ascending: false)
            .limit(1)
            .maybeSingle();

        brebis['estGestante'] = accouplement != null;
        brebis['dateAgnelage'] = accouplement?['date_prevue_agnelage'];

        // Vérifier lactation
        final derniereMiseBas = await supabase
            .from('accouplements')
            .select('date_mise_bas')
            .eq('brebis_id', brebis['id'])
            .eq('source_brebis', brebis['source'])
            .not('date_mise_bas', 'is', null)
            .order('date_mise_bas', ascending: false)
            .limit(1)
            .maybeSingle();

        if (derniereMiseBas != null) {
          final dateMiseBas = DateTime.parse(derniereMiseBas['date_mise_bas']);
          final joursDepuis = DateTime.now().difference(dateMiseBas).inDays;
          brebis['enLactation'] = joursDepuis < ReproductionConfig.dureeLactationJours;
        } else {
          brebis['enLactation'] = false;
        }

        // Récupérer dernière chaleur
        final derniereChaleur = await supabase
            .from('chaleurs')
            .select('date_chaleur, intensite')
            .eq('animal_id', brebis['id'])
            .eq('source', brebis['source'])
            .order('date_chaleur', ascending: false)
            .limit(1)
            .maybeSingle();

        brebis['derniereChaleur'] = derniereChaleur?['date_chaleur'];
        brebis['derniereChaleurIntensite'] = derniereChaleur?['intensite'];

        // Vérifier l'âge minimum pour reproduction (8 mois)
        if (brebis['source'] == 'nee' && brebis['date_naissance'] != null) {
          final dateNaissance = DateTime.parse(brebis['date_naissance']);
          final moisAge = DateTime.now().difference(dateNaissance).inDays ~/ 30;
          brebis['ageEnMois'] = moisAge;
          brebis['tropJeune'] = moisAge < ReproductionConfig.ageMinimumReproductionMois;
        } else {
          brebis['tropJeune'] = false;
          brebis['ageEnMois'] = null;
        }

      } catch (e) {
        debugPrint("⚠️ Erreur enrichissement brebis ${brebis['nom']}: $e");
      }
    }

    return brebis;
  }

  Future<List<Map<String, dynamic>>> _filtrerBrebisEnChaleur(
    List<Map<String, dynamic>> brebis,
  ) async {
    final maintenant = DateTime.now();
    final il48h = maintenant.subtract(const Duration(hours: 48));

    return brebis.where((b) {
      if (b['derniereChaleur'] == null) return false;
      
      final dateChaleur = DateTime.parse(b['derniereChaleur']);
      return dateChaleur.isAfter(il48h) && dateChaleur.isBefore(maintenant);
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _calculerProchainesChaleurs(
    List<Map<String, dynamic>> brebis,
  ) async {
    List<Map<String, dynamic>> prochaines = [];

    for (var b in brebis) {
      if (b['estGestante'] == true) continue;
      if (b['derniereChaleur'] == null) continue;

      try {
        final prediction = await _businessService.calculerProchaineChaleur(
          brebisId: b['id'],
          source: b['source'],
          derniereChaleur: DateTime.parse(b['derniereChaleur']),
        );

        if (prediction.dateMin.isAfter(DateTime.now())) {
          prochaines.add({
            ...b,
            'prochaineChaleurMin': prediction.dateMin,
            'prochaineChaleurMax': prediction.dateMax,
            'niveauConfiance': prediction.niveauConfiance,
            'joursRestants': prediction.dateMin.difference(DateTime.now()).inDays,
          });
        }
      } catch (e) {
        debugPrint("⚠️ Erreur prédiction ${b['nom']}: $e");
      }
    }

    // Trier par proximité
    prochaines.sort((a, b) => 
      a['joursRestants'].compareTo(b['joursRestants']));

    return prochaines.take(10).toList();
  }

  Future<void> _calculerStatistiques(
    String userId,
    List<Map<String, dynamic>> brebis,
  ) async {
    try {
      final stats = await _businessService.calculerStatistiquesGlobales(userId);
      
      setState(() {
        _chaleursCeMois = stats.chaleursCeMois;
        _brebisDisponibles = brebis
            .where((b) => b['estGestante'] != true)
            .length;
      });
    } catch (e) {
      debugPrint("⚠️ Erreur calcul stats: $e");
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ===== FONCTION: SÉLECTEUR DE BREBIS =====
  Future<void> _afficherSelecteurBrebis() async {
    // Filtrer brebis disponibles (non gestantes ET âge suffisant)
    final disponibles = _brebis.where((b) {
      if (b['estGestante'] == true) return false;
      if (b['tropJeune'] == true) return false;
      return true;
    }).toList();
    
    if (disponibles.isEmpty) {
      _showSnackBar(
        "Aucune brebis disponible pour la reproduction.\n"
        "Les brebis doivent avoir au moins 8 mois et ne pas être gestantes.",
        Colors.orange,
      );
      return;
    }
    
    // Afficher bottom sheet avec liste
    final brebisSelectionnee = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(ReproductionConfig.colorPrimary),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pets, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text(
                    "Sélectionner une brebis",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: disponibles.length,
                itemBuilder: (context, index) {
                  final brebis = disponibles[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: _buildAvatar(brebis),
                      title: Text(
                        brebis['nom'] ?? 'Sans nom',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text("Race: ${brebis['race'] ?? 'N/A'}"),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(context, brebis),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    
    // Si une brebis a été sélectionnée, naviguer vers la page d'enregistrement
    if (brebisSelectionnee != null && mounted) {
      await _naviguerVersEnregistrerChaleur(brebisSelectionnee);
    }
  }

  // ===== INTERFACE UTILISATEUR =====

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Suivi des Chaleurs"),
        backgroundColor: Color(ReproductionConfig.colorPrimary),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: "Toutes", icon: Icon(Icons.pets, size: 20)),
            Tab(text: "En chaleur", icon: Icon(Icons.local_fire_department, size: 20)),
            Tab(text: "Prédictions", icon: Icon(Icons.analytics, size: 20)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSaisonIndicateur(),
                _buildStatistiquesCards(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOngletToutes(),
                      _buildOngletEnChaleur(),
                      _buildOngletPredictions(),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _afficherSelecteurBrebis,
        backgroundColor: Color(ReproductionConfig.colorPrimary),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "Nouvelle chaleur",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildSaisonIndicateur() {
    if (_saisonActuelle == null || _indicateurSaison == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: _couleurSaison?.withOpacity(0.1),
      child: Row(
        children: [
          Icon(Icons.wb_sunny, color: _couleurSaison, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _saisonActuelle!,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _couleurSaison,
                  ),
                ),
                Text(
                  _indicateurSaison!,
                  style: TextStyle(
                    fontSize: 12,
                    color: _couleurSaison,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistiquesCards() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.blue),
                    const SizedBox(height: 4),
                    Text(
                      "$_chaleursCeMois",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const Text(
                      "Chaleurs ce mois",
                      style: TextStyle(fontSize: 11, color: Colors.blue),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(height: 4),
                    Text(
                      "$_brebisDisponibles",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const Text(
                      "Brebis disponibles",
                      style: TextStyle(fontSize: 11, color: Colors.green),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== ONGLET: TOUTES LES BREBIS =====

  Widget _buildOngletToutes() {
    if (_brebis.isEmpty) {
      return _buildEmptyState(
        Icons.pets,
        "Aucune brebis",
        "Ajoutez des brebis pour commencer le suivi",
      );
    }

    return RefreshIndicator(
      onRefresh: _chargerDonnees,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _brebis.length,
        itemBuilder: (context, index) {
          return _buildBrebisCard(_brebis[index]);
        },
      ),
    );
  }

  // ===== ONGLET: BREBIS EN CHALEUR =====

  Widget _buildOngletEnChaleur() {
    if (_brebisEnChaleur.isEmpty) {
      return _buildEmptyState(
        Icons.local_fire_department,
        "Aucune brebis en chaleur",
        "Les brebis en chaleur dans les dernières 48h apparaîtront ici",
      );
    }

    return RefreshIndicator(
      onRefresh: _chargerDonnees,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _brebisEnChaleur.length,
        itemBuilder: (context, index) {
          return _buildBrebisEnChaleurCard(_brebisEnChaleur[index]);
        },
      ),
    );
  }

  // ===== ONGLET: PRÉDICTIONS =====

  Widget _buildOngletPredictions() {
    if (_prochainesChaleurs.isEmpty) {
      return _buildEmptyState(
        Icons.analytics,
        "Aucune prédiction disponible",
        "Les prédictions apparaîtront après l'enregistrement de plusieurs chaleurs",
      );
    }

    return RefreshIndicator(
      onRefresh: _chargerDonnees,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _prochainesChaleurs.length,
        itemBuilder: (context, index) {
          return _buildPredictionCard(_prochainesChaleurs[index]);
        },
      ),
    );
  }

  // ===== WIDGETS DE CARTES =====

  Widget _buildBrebisCard(Map<String, dynamic> brebis) {
    final estGestante = brebis['estGestante'] == true;
    final enLactation = brebis['enLactation'] == true;
    final tropJeune = brebis['tropJeune'] == true;
    final ageEnMois = brebis['ageEnMois'];
    final derniereChaleur = brebis['derniereChaleur'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: _buildAvatar(brebis),
        title: Text(
          brebis['nom'] ?? 'Sans nom',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Race: ${brebis['race'] ?? 'N/A'}"),
            if (ageEnMois != null)
              Text(
                "Âge: $ageEnMois mois",
                style: TextStyle(
                  fontSize: 12,
                  color: tropJeune ? Colors.red : Colors.grey[600],
                ),
              ),
            if (derniereChaleur != null)
              Text(
                "Dernière chaleur: ${_formatDate(DateTime.parse(derniereChaleur))}",
                style: const TextStyle(fontSize: 12),
              ),
            if (tropJeune)
              const Text(
                "🚫 Trop jeune (minimum 8 mois)",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            if (estGestante)
              const Text(
                "🤰 Gestante",
                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
              ),
            if (enLactation && !estGestante)
              const Text(
                "🍼 En lactation",
                style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        trailing: Icon(
          (estGestante || tropJeune) ? Icons.block : Icons.chevron_right,
          color: (estGestante || tropJeune) ? Colors.red : Color(ReproductionConfig.colorPrimary),
        ),
        onTap: (estGestante || tropJeune)
            ? () {
                String message = '';
                if (estGestante) {
                  message = ReproductionConfig.messageGestante;
                } else if (tropJeune) {
                  message = ReproductionConfig.messageTropJeune;
                }
                
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    icon: const Icon(Icons.info_outline, color: Colors.orange, size: 64),
                    title: const Text("Non disponible"),
                    content: Text(message),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("OK"),
                      ),
                    ],
                  ),
                );
              }
            : () async {
                await _naviguerVersEnregistrerChaleur(brebis);
              },
      ),
    );
  }

  Widget _buildBrebisEnChaleurCard(Map<String, dynamic> brebis) {
    final dateChaleur = DateTime.parse(brebis['derniereChaleur']);
    final heuresDepuis = DateTime.now().difference(dateChaleur).inHours;
    final tropJeune = brebis['tropJeune'] == true;
    final ageEnMois = brebis['ageEnMois'];
    final debutFenetre = dateChaleur.add(
      Duration(hours: ReproductionConfig.debutFenetileHeures),
    );
    final finFenetre = dateChaleur.add(
      Duration(hours: ReproductionConfig.dureeChaleurHeures),
    );
    
    final estDansFenetre = DateTime.now().isAfter(debutFenetre) &&
        DateTime.now().isBefore(finFenetre);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: estDansFenetre ? Colors.green.shade50 : Colors.orange.shade50,
      child: ListTile(
        leading: Stack(
          children: [
            _buildAvatar(brebis),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_fire_department, size: 16, color: Colors.white),
              ),
            ),
          ],
        ),
        title: Text(
          brebis['nom'] ?? 'Sans nom',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Il y a ${heuresDepuis}h"),
            if (tropJeune && ageEnMois != null)
              Text(
                "⚠️ $ageEnMois mois (minimum 8 mois)",
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            if (estDansFenetre && !tropJeune)
              const Text(
                "🎯 FENÊTRE FERTILE ACTIVE",
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              )
            else if (!tropJeune)
              Text(
                "Fenêtre: ${_formatHeure(debutFenetre)} - ${_formatHeure(finFenetre)}",
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        trailing: tropJeune
            ? const Icon(Icons.block, color: Colors.red)
            : ElevatedButton.icon(
                onPressed: () async {
                  await _naviguerVersAccouplement(brebis);
                },
                icon: const Icon(Icons.favorite, size: 16),
                label: const Text("Accoupler"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: estDansFenetre ? Colors.green : Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildPredictionCard(Map<String, dynamic> brebis) {
    final joursRestants = brebis['joursRestants'] as int;
    final confiance = brebis['niveauConfiance'] as String;
    
    Color couleurConfiance;
    if (confiance == "Élevé") {
      couleurConfiance = Colors.green;
    } else if (confiance == "Modéré") {
      couleurConfiance = Colors.orange;
    } else {
      couleurConfiance = Colors.red;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _buildAvatar(brebis),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    brebis['nom'] ?? 'Sans nom',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text("Race: ${brebis['race'] ?? 'N/A'}"),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        "Dans $joursRestants jours",
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.analytics, size: 14, color: couleurConfiance),
                      const SizedBox(width: 4),
                      Text(
                        "Confiance: $confiance",
                        style: TextStyle(
                          fontSize: 13,
                          color: couleurConfiance,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: joursRestants <= 3 ? Colors.orange : Colors.blue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                joursRestants <= 3 ? "BIENTÔT" : "J-$joursRestants",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(Map<String, dynamic> brebis) {
    if (brebis['image_url'] != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          brebis['image_url'],
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 60,
              height: 60,
              color: Colors.grey[300],
              child: const Icon(Icons.pets, size: 30),
            );
          },
        ),
      );
    }

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Color(ReproductionConfig.colorPrimary).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.pets,
        size: 30,
        color: Color(ReproductionConfig.colorPrimary),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String titre, String sousTitre) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            titre,
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            sousTitre,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ===== UTILITAIRES DE FORMATAGE =====

  String _formatHeure(DateTime date) {
    return "${date.hour}h${date.minute.toString().padLeft(2, '0')}";
  }

  String _formatDate(DateTime date) {
    final maintenant = DateTime.now();
    final difference = maintenant.difference(date).inDays;

    if (difference == 0) return "Aujourd'hui";
    if (difference == 1) return "Hier";
    if (difference < 7) return "Il y a $difference jours";
    if (difference < 30) return "Il y a ${(difference / 7).floor()} semaines";
    return "${date.day}/${date.month}/${date.year}";
  }

  // ===== MÉTHODES DE NAVIGATION =====

  /// Navigation vers la page d'enregistrement de chaleur
  Future<void> _naviguerVersEnregistrerChaleur(Map<String, dynamic> brebis) async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EnregistrerChaleurPageAmelioree(
            brebis: brebis,
            source: brebis['source'],
          ),
        ),
      );
      
      // Recharger les données si l'enregistrement a réussi
      if (result == true && mounted) {
        await _chargerDonnees();
        _showSnackBar(
          "✅ Chaleur enregistrée avec succès", 
          Color(ReproductionConfig.colorSuccess),
        );
      }
    } catch (e) {
      debugPrint("❌ Erreur navigation enregistrement chaleur: $e");
      if (mounted) {
        _showSnackBar(
          "Erreur lors de l'ouverture de la page d'enregistrement",
          Color(ReproductionConfig.colorDanger),
        );
      }
    }
  }

  /// Navigation vers la page d'accouplement
  Future<void> _naviguerVersAccouplement(Map<String, dynamic> brebis) async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EnregistrerAccouplement(
            brebisPreSelectionnee: brebis,
            sourcePreSelectionnee: brebis['source'],
          ),
        ),
      );
      
      // Recharger les données si l'accouplement a réussi
      if (result == true && mounted) {
        await _chargerDonnees();
        _showSnackBar(
          "✅ Accouplement enregistré avec succès", 
          Color(ReproductionConfig.colorSuccess),
        );
      }
    } catch (e) {
      debugPrint("❌ Erreur navigation accouplement: $e");
      if (mounted) {
        _showSnackBar(
          "Erreur lors de l'ouverture de la page d'accouplement",
          Color(ReproductionConfig.colorDanger),
        );
      }
    }
  }
}