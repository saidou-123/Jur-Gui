// ============================================================
// INTERFACE ÉLEVEUR - VERSION PRODUCTION AVEC BOTTOM NAV BAR
// ✅ ÉTAPE 3 : Notifications réelles connectées à Supabase
//    - Badge dynamique avec compteur des non lues
//    - Bouton cloche navigue vers NotificationsPage
//    - Bottom nav "Alertes" navigue aussi vers NotificationsPage
//    - Écoute temps réel : badge mis à jour automatiquement
// Fichier: lib/pages/Interface/interfaceEleveur.dart
// ============================================================

import 'package:depart/Eleveures/Ajouter%20Animal/AjouterAnimal.dart';
import 'package:depart/Eleveures/AnimalInfoRFID/AnimalInfoRFIDBluetooth.dart';
import 'package:depart/Eleveures/New/Accouplemt/Accouplement..dart';
import 'package:depart/Eleveures/New/Notification/NotificationBadge.dart';
import 'package:depart/Eleveures/New/Notification/NotificationsViewPage.dart';
import 'package:depart/Eleveures/New/chaleur/ChaleurModule.dart';
import 'package:depart/Eleveures/New/genealogique/ArbreGenealogique.dart';
import 'package:depart/Eleveures/New/Copilot/CopilotPage.dart';
// ✅ NOUVEAU — Import page notifications réelles

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:depart/Eleveures/Mon%20Troupeau/Mon_Troupeau.dart';
import 'package:depart/widgets/optioncardEleveur.dart';
import 'package:depart/securite/ErrorHandler.dart';
import 'package:depart/securite/CachedData.dart';
import 'package:depart/widgets/couleur.dart';
import 'package:depart/pages/Bienvenue/connexion.dart';

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

  // ✅ NOUVEAU — Compteur notifications non lues (badge dynamique)
  int _notifNonLues = 0;
  RealtimeChannel? _notifChannel;

  // BottomNav
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initializeData();
    // ✅ NOUVEAU — Charger le compteur et écouter en temps réel
    _chargerCompteurNotifs();
    _ecouterNotificationsTempsReel();
  }

  @override
  void dispose() {
    _animationController.dispose();
    // ✅ Nettoyer l'abonnement temps réel
    _notifChannel?.unsubscribe();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  // ✅ NOUVEAU : Charger le nombre de notifications non lues
  // ─────────────────────────────────────────────────────────
  Future<void> _chargerCompteurNotifs() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || !mounted) return;

    try {
      final result = await _supabase
          .from('notifications')
          .select('id')
          .eq('destinataire_id', userId)
          .eq('lu', false);

      if (mounted) {
        setState(() => _notifNonLues = (result as List).length);
      }
    } catch (e) {
      debugPrint('⚠️ Erreur compteur notifs: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // ✅ NOUVEAU : Écoute temps réel — badge mis à jour
  // automatiquement quand le vétérinaire envoie une notif
  // ─────────────────────────────────────────────────────────
  void _ecouterNotificationsTempsReel() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _notifChannel = _supabase
        .channel('notifications_eleveur_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'destinataire_id',
            value: userId,
          ),
          callback: (payload) {
            // Nouvelle notification reçue → incrémenter le badge
            if (mounted) {
              setState(() => _notifNonLues++);
              // Afficher un snackbar discret
              final titre = payload.newRecord['titre']?.toString() ?? 'Nouvelle notification';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.notifications, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          titre,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.green[700],
                  duration: const Duration(seconds: 4),
                  action: SnackBarAction(
                    label: 'Voir',
                    textColor: Colors.white,
                    onPressed: _ouvrirNotifications,
                  ),
                ),
              );
            }
          },
        )
        .subscribe();
  }

  // ─────────────────────────────────────────────────────────
  // ✅ NOUVEAU : Ouvrir la page notifications et rafraîchir le badge
  // ─────────────────────────────────────────────────────────
  // ✅ Dialog de choix entre les deux types de notifications
  Future<void> _ouvrirNotifications() async {
    await showModalBottomSheet(
      context   : context,
      shape     : const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder   : (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mes Notifications',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Option 1 : Notifications vétérinaire
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.medical_services, color: Colors.green[700]),
              ),
              title: const Text(
                'Notifications vétérinaire',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                _notifNonLues > 0
                    ? 'Consultations et vaccinations · $_notifNonLues non lue(s)'
                    : 'Consultations et vaccinations reçues',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: _notifNonLues > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_notifNonLues',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    )
                  : const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                Navigator.pop(ctx);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NotificationsPage()),
                );
                if (mounted) {
                  setState(() => _selectedIndex = 0);
                  _chargerCompteurNotifs();
                }
              },
            ),

            const Divider(),

            // Option 2 : Rappels élevage
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.alarm, color: Colors.orange[700]),
              ),
              title: const Text(
                'Rappels élevage',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Chaleurs, agnelages, reproduction',
                style: TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NotificationsViewPage()),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
      CurvedAnimation(
          parent: _animationController, curve: Curves.easeOutCubic),
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
      ErrorHandler.log(error, stackTrace, context: 'Chargement statistiques');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ===== RÉCUPÉRER STATISTIQUES =====
  Future<Map<String, int>> _fetchStatistics(String userId) async {
    debugPrint("📊 Chargement statistiques pour: $userId");

    final results = await Future.wait([
      _supabase.from('nouveaux_nee').select('sexe').eq('user_id', userId),
      _supabase.from('animal_acheter').select('sexe').eq('user_id', userId),
    ]);

    int males = 0;
    int femelles = 0;

    for (var animal in results[0]) {
      final sexe = animal['sexe']?.toString().toLowerCase() ?? '';
      if (sexe == 'male' || sexe == 'mâle') {
        males++;
      } else if (sexe == 'femelle') {
        femelles++;
      }
    }

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
    return {'total': total, 'males': males, 'femelles': femelles};
  }

  // ===== DÉCONNEXION SÉCURISÉE =====
  Future<void> _handleLogout() async {
    final navigator = Navigator.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
        content: const Text("Êtes-vous sûr de vouloir vous déconnecter ?"),
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
      _notifChannel?.unsubscribe();
      _cache.clear();
      await _supabase.auth.signOut();
      debugPrint("✅ Déconnexion réussie");
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const Connexion()),
      );
    } catch (error, stackTrace) {
      ErrorHandler.log(error, stackTrace, context: 'Déconnexion');
      if (mounted) ErrorHandler.show(context, error);
    }
  }

  // ===== RAFRAÎCHISSEMENT =====
  Future<void> _handleRefresh() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      _cache.invalidate(CacheKeys.stats(userId));
    }
    await Future.wait([
      _initializeData(),
      _chargerCompteurNotifs(), // ✅ Rafraîchir aussi le badge
    ]);
    if (mounted) {
      ErrorHandler.showSuccess(context, "Données actualisées");
    }
  }

  // ===== NAVIGATION BOTTOM BAR =====
  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);

    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MonTroupeau()),
        ).then((_) => setState(() => _selectedIndex = 0));
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AjouterAnimal()),
        ).then((_) => setState(() => _selectedIndex = 0));
        break;
      case 3:
        // ✅ MODIFIÉ — Navigue vers les vraies notifications
        _ouvrirNotifications();
        break;
    }
  }

  // ===== BUILD PRINCIPAL =====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      floatingActionButton: _buildCopilotFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  // ===== COPILOT IA FAB =====
  Widget _buildCopilotFAB() {
    return FloatingActionButton.extended(
      heroTag: 'copilot',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CopilotPage()),
      ),
      backgroundColor: const Color(0xFF1B5E20),
      icon: const Icon(Icons.smart_toy_outlined, color: Colors.white),
      label: const Text(
        'Copilot IA',
        style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
      ),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  // ===== APP BAR =====
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
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: IconButton(
            // ✅ MODIFIÉ — Badge dynamique réel (plus le '2' statique)
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.notifications_outlined, color: Colors.blue[700]),
                if (_notifNonLues > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        _notifNonLues > 99 ? '99+' : '$_notifNonLues',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            // ✅ MODIFIÉ — Ouvre la vraie page notifications
            onPressed: _ouvrirNotifications,
          ),
        ),
      ],
    );
  }

  // ===== BOTTOM NAVIGATION BAR =====
  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onNavTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: Couleur.PremierColor,
          unselectedItemColor: Colors.grey[400],
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w400, fontSize: 11),
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: _navIcon(Icons.home_outlined, 0),
              activeIcon: _navIconActive(Icons.home_rounded, 0),
              label: "Accueil",
            ),
            BottomNavigationBarItem(
              icon: _navIcon(Icons.scanner, 1),
              activeIcon: _navIconActive(Icons.scanner, 1),
              label: "Partage",
            ),
            BottomNavigationBarItem(
              icon: _navIcon(Icons.add_circle_outline, 2),
              activeIcon: _navIconActive(Icons.add_circle, 2),
              label: "Ajouter",
            ),
            BottomNavigationBarItem(
              // ✅ MODIFIÉ — Badge dynamique sur l'onglet Alertes
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  _navIcon(Icons.notifications_outlined, 3),
                  if (_notifNonLues > 0)
                    Positioned(
                      right: -6,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                            minWidth: 15, minHeight: 15),
                        child: Text(
                          _notifNonLues > 9 ? '9+' : '$_notifNonLues',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              activeIcon: _navIconActive(Icons.notifications, 3),
              label: "Alertes",
            ),
          ],
        ),
      ),
    );
  }

  Widget _navIcon(IconData icon, int index) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Icon(icon, size: 24),
    );
  }

  Widget _navIconActive(IconData icon, int index) {
    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Couleur.PremierColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(icon, size: 24, color: Couleur.PremierColor),
    );
  }

  // ===== LOADING =====
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Couleur.PremierColor),
          const SizedBox(height: 16),
          Text("Chargement...",
              style: TextStyle(color: Couleur.PremierColor, fontSize: 16)),
        ],
      ),
    );
  }

  // ===== WELCOME CARD =====
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
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  "Bienvenue sur votre tableau de bord",
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.9), fontSize: 14),
                ),
              ],
            ),
          ),
          Icon(Icons.wb_sunny_outlined, color: Colors.amber[300], size: 40),
        ],
      ),
    );
  }

  // ===== STATISTIQUES =====
  Widget _buildStatistiques() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
              icon: Icons.pets,
              label: "Total",
              value: "$_totalAnimaux",
              color: Colors.blue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
              icon: Icons.male,
              label: "Mâles",
              value: "$_nombreMales",
              color: Colors.green),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
              icon: Icons.female,
              label: "Femelles",
              value: "$_nombreFemelles",
              color: Colors.pink),
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
                color: Colors.white, shape: BoxShape.circle),
            child: Icon(icon, size: 32, color: color[700]),
          ),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color[900])),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color[700])),
        ],
      ),
    );
  }

  // ===== SCAN RFID =====
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
                      const Text("Infos Animal RFID",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text("Scannez facilement",
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14)),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              const AnimalInfoRFIDPageBluetooth()),
                    ),
                    icon: const Icon(Icons.nfc, size: 20),
                    label: const Text("Scanner",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Couleur.PremierColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
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
                errorBuilder: (_, __, ___) => Icon(Icons.pets,
                    size: 100, color: Colors.white.withOpacity(0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== SECTION HEADER =====
  Widget _buildSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Gestion du troupeau',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        TextButton.icon(
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (context) => const MonTroupeau())),
          icon: const Icon(Icons.arrow_forward, size: 16),
          label: const Text("Voir tout"),
          style: TextButton.styleFrom(foregroundColor: Couleur.PremierColor),
        ),
      ],
    );
  }

  // ===== OPTIONS GRID =====
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
                route: const ChaleurModule(),
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
                route: EnregistrerAccouplement(),
                backgroundColor: const Color(0xFFFCE4EC),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: optioncardEleveur(
                image: 'assets/image/img14.png',
                label: 'Ajouter Animal',
                route: const AjouterAnimal(),
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
                label: "Genealogique",
                route: const ArbreGenealogique(),
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

  // ===== DRAWER =====
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
                Text(_userName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                Text(_userEmail,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
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
          // ✅ NOUVEAU — Notifications dans le Drawer avec badge
          ListTile(
            leading: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.notifications_outlined, color: Colors.blue[700]),
                if (_notifNonLues > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                      child: Text(
                        '$_notifNonLues',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            title: Row(
              children: [
                const Text('Notifications'),
                if (_notifNonLues > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$_notifNonLues',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: _notifNonLues > 0
                ? Text('$_notifNonLues non lue${_notifNonLues > 1 ? 's' : ''}',
                    style: const TextStyle(color: Colors.red, fontSize: 12))
                : const Text('Aucune nouvelle notification'),
            onTap: () {
              Navigator.pop(context);
              _ouvrirNotifications();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.smart_toy_outlined,
                color: Color(0xFF1B5E20)),
            title: const Text("Copilot IA",
                style: TextStyle(
                    color: Color(0xFF1B5E20),
                    fontWeight: FontWeight.w600)),
            subtitle: const Text("Assistant élevage intelligent"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CopilotPage()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Déconnexion",
                style: TextStyle(color: Colors.red)),
            onTap: _handleLogout,
          ),
        ],
      ),
    );
  }
}