// ============================================================
// INTERFACE ÉLEVEUR - VERSION OPTIMISÉE
// Fichier: lib/pages/Interface/interfaceEleveur.dart
// ============================================================

import 'package:depart/Eleveures/Accouplemaent/ANI/AnimalAchateBluetooth.dart';
import 'package:depart/Eleveures/Accouplemaent/ANI/NouveauNeeBluetooth.dart';
import 'package:depart/Eleveures/AnimalInfoRFID/AnimalInfoRFIDBluetooth.dart';
import 'package:depart/Eleveures/AnimalInfoRFID/AnimalInfoRFIDPage.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:depart/Eleveures/Accouplemaent/EnregistrerAccouplement.dart';
import 'package:depart/Eleveures/Chaleur/Chaleur.dart';
import 'package:depart/Eleveures/Mon%20Troupeau/Mon_Troupeau.dart';
import 'package:depart/widgets/optioncardEleveur.dart';
import 'package:depart/securite/ErrorHandler.dart';
import 'package:depart/securite/CachedData.dart';
import 'package:depart/widgets/couleur.dart';
import 'package:depart/pages/connexion.dart';

class interfaceElevaur extends StatefulWidget {
  const interfaceElevaur({super.key});

  @override
  State<interfaceElevaur> createState() => _interfaceElevaureState();
}

class _interfaceElevaureState extends State<interfaceElevaur>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _cache = CacheManager();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // État
  int _totalAnimaux = 0;
  int _nombreMales = 0;
  int _nombreFemelles = 0;
  bool _isLoading = true;
  String _userEmail = "";
  String _userName = "";

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initializeData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ===== ANIMATIONS =====
  void _initAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  // ===== INITIALISATION =====
  Future<void> _initializeData() async {
    await Future.wait([
      _chargerInfoUtilisateur(),
      _chargerStatistiques(),
    ]);
  }

  // ===== CHARGER INFO UTILISATEUR =====
  Future<void> _chargerInfoUtilisateur() async {
    try {
      final user = _supabase.auth.currentUser;
      
      if (user != null && mounted) {
        // Essayer de récupérer depuis la table users
        final userData = await _supabase
            .from('users')
            .select('nom, prenom, nom_complet')
            .eq('id', user.id)
            .maybeSingle();
        
        String name;
        if (userData != null && userData['nom_complet'] != null) {
          name = userData['nom_complet'];
        } else if (userData != null && userData['prenom'] != null) {
          name = userData['prenom'];
        } else {
          name = user.email?.split('@').first.toUpperCase() ?? "Éleveur";
        }
        
        setState(() {
          _userEmail = user.email ?? "Non disponible";
          _userName = name;
        });
        
        debugPrint("✅ Utilisateur chargé: $name");
      }
    } catch (e) {
      debugPrint("⚠️ Erreur chargement utilisateur: $e");
      // Utiliser valeurs par défaut
      setState(() {
        _userName = "Éleveur";
        _userEmail = _supabase.auth.currentUser?.email ?? "";
      });
    }
  }

  // ===== CHARGER STATISTIQUES AVEC CACHE =====
  Future<void> _chargerStatistiques() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception("Utilisateur non connecté");

      // ✅ Utiliser le cache
      final stats = await _cache.getOrFetch<Map<String, int>>(
        key: CacheKeys.stats(userId),
        fetcher: () => _fetchStatistics(userId),
        ttl: const Duration(minutes: 2),
      );

      if (mounted) {
        setState(() {
          _totalAnimaux = stats['total'] ?? 0;
          _nombreMales = stats['males'] ?? 0;
          _nombreFemelles = stats['femelles'] ?? 0;
          _isLoading = false;
        });
      }
    } catch (error, stackTrace) {
      ErrorHandler.log(
        error,
        stackTrace,
        context: 'Chargement statistiques',
      );
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ===== RÉCUPÉRER STATISTIQUES =====
  Future<Map<String, int>> _fetchStatistics(String userId) async {
    debugPrint("📊 Chargement statistiques pour: $userId");

    // ✅ Requêtes parallèles
    final results = await Future.wait([
      _supabase
          .from('nouveaux_nee')
          .select('sexe')
          .eq('user_id', userId),
      _supabase
          .from('animal_acheter')
          .select('sexe')
          .eq('user_id', userId),
    ]);

    int males = 0;
    int femelles = 0;

    // Compter nouveaux-nés
    for (var animal in results[0]) {
      final sexe = animal['sexe']?.toString().toLowerCase() ?? '';
      if (sexe == 'male' || sexe == 'mâle') {
        males++;
      } else if (sexe == 'femelle') {
        femelles++;
      }
    }

    // Compter achetés
    for (var animal in results[1]) {
      final sexe = animal['sexe']?.toString().toLowerCase() ?? '';
      if (sexe == 'male' || sexe == 'mâle') {
        males++;
      } else if (sexe == 'femelle') {
        femelles++;
      }
    }

    final total = males + femelles;

    debugPrint("✅ Stats: Total=$total, Mâles=$males, Femelles=$femelles");

    return {
      'total': total,
      'males': males,
      'femelles': femelles,
    };
  }

  // ===== DÉCONNEXION SÉCURISÉE =====
  Future<void> _handleLogout() async {
    final navigator = Navigator.of(context);
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout, color: Colors.red),
            ),
            const SizedBox(width: 12),
            const Text("Déconnexion"),
          ],
        ),
        content: const Text(
          "Êtes-vous sûr de vouloir vous déconnecter ?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text("Annuler", style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Déconnexion"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Vider le cache
      _cache.clear();
      
      // Déconnexion
      await _supabase.auth.signOut();
      
      debugPrint("✅ Déconnexion réussie");

      // Navigation
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const Connexion()),
      );
    } catch (error, stackTrace) {
      ErrorHandler.log(error, stackTrace, context: 'Déconnexion');
      if (mounted) {
        ErrorHandler.show(context, error);
      }
    }
  }

  // ===== RAFRAÎCHISSEMENT =====
  Future<void> _handleRefresh() async {
    // Invalider le cache des stats
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      _cache.invalidate(CacheKeys.stats(userId));
    }
    
    await _initializeData();
    
    if (mounted) {
      ErrorHandler.showSuccess(context, "Données actualisées");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: _isLoading
          ? _buildLoadingState()
          : RefreshIndicator(
              onRefresh: _handleRefresh,
              color: Couleur.PremierColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildWelcomeCard(),
                        const SizedBox(height: 20),
                        _buildStatistiques(),
                        const SizedBox(height: 24),
                        _buildScanRFIDCard(),
                        const SizedBox(height: 24),
                        _buildSectionHeader(),
                        const SizedBox(height: 12),
                        _buildOptionsGrid(),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        "JUR GUI - Éleveur",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
      ),
      centerTitle: true,
      backgroundColor: Colors.white,
      foregroundColor: Couleur.PremierColor,
      elevation: 2,
      iconTheme: IconThemeData(color: Couleur.PremierColor),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Couleur.PremierColor),
          const SizedBox(height: 16),
          Text(
            "Chargement...",
            style: TextStyle(color: Couleur.PremierColor, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Couleur.PremierColor,
            Couleur.PremierColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Couleur.PremierColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Bonjour, $_userName! 👋",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Bienvenue sur votre tableau de bord",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.wb_sunny_outlined, color: Colors.amber[300], size: 40),
        ],
      ),
    );
  }

  Widget _buildStatistiques() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.pets,
            label: "Total",
            value: "$_totalAnimaux",
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.male,
            label: "Mâles",
            value: "$_nombreMales",
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.female,
            label: "Femelles",
            value: "$_nombreFemelles",
            color: Colors.pink,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required MaterialColor color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color[50]!, color[100]!],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color[200]!, width: 2),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: color[700]),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color[900],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanRFIDCard() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Couleur.PremierColor,
            Couleur.PremierColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Couleur.PremierColor.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Infos Animal RFID",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Scannez facilement",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AnimalInfoRFIDPageBluetooth (),
                        ),
                      );
                    },
                    icon: const Icon(Icons.nfc, size: 20),
                    label: const Text(
                      "Scanner",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Couleur.PremierColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              flex: 1,
              child: Image.asset(
                "assets/image/img10.png",
                width: 100,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.pets,
                  size: 100,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Gestion du troupeau',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        TextButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MonTroupeau()),
            );
          },
          icon: const Icon(Icons.arrow_forward, size: 16),
          label: const Text("Voir tout"),
          style: TextButton.styleFrom(foregroundColor: Couleur.PremierColor),
        ),
      ],
    );
  }

  Widget _buildOptionsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: optioncardEleveur(
                image: 'assets/image/img6.png',
                label: "Mon Troupeau",
                route: const MonTroupeau(),
                backgroundColor: const Color(0xFFE8F5E9),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: optioncardEleveur(
                image: 'assets/image/img10.png',
                label: 'Période Chaleur',
                route: const Chaleur(),
                backgroundColor: const Color(0xFFFFF3E0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: optioncardEleveur(
                image: 'assets/image/img5.png',
                label: "Accouplement",
                route: const EnregistrerAccouplementPage(),
                backgroundColor: const Color(0xFFFCE4EC),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: optioncardEleveur(
                image: 'assets/image/img14.png',
                label: 'Ajouter Animal',
                route: const  NouveauNeeBluetooth (),
                backgroundColor: const Color(0xFFFFF9C4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: optioncardEleveur(
                image: 'assets/image/img5.png',
                label: "Historique Médical",
                route: const AnimalAchateBluetooth (),
                backgroundColor: const Color(0xFFE3F2FD),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Couleur.PremierColor,
                  Couleur.PremierColor.withOpacity(0.8),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 40, color: Colors.green),
                ),
                const SizedBox(height: 12),
                Text(
                  _userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _userEmail,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text("Actualiser"),
            onTap: () {
              Navigator.pop(context);
              _handleRefresh();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Déconnexion", style: TextStyle(color: Colors.red)),
            onTap: _handleLogout,
          ),
        ],
      ),
    );
  }
}