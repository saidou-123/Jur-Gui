import 'package:depart/Veterinaires/FichesSante.dart';
import 'package:depart/Veterinaires/HistoriqueMedical.dart';
import 'package:depart/Veterinaires/Scanveterinaire/ScanRFIDVeterinaireB.dart';
import 'package:depart/Veterinaires/Vaccinations.dart';
import 'package:depart/Veterinaires/constantes/models/note_eleveur_model.dart';
import 'package:depart/Veterinaires/constantes/services/vaccination_service.dart';
import 'package:depart/Veterinaires/features/collaboration/notes_eleveur_page.dart';
import 'package:depart/widgets/couleur.dart';
import 'package:depart/widgets/optioncardVeterinaire.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:depart/securite/ErrorHandler.dart';
import 'package:depart/securite/CachedData.dart';
import 'package:depart/pages/Bienvenue/connexion.dart';

class InterfaceVeterinaire extends StatefulWidget {
  const InterfaceVeterinaire({super.key});

  @override
  State<InterfaceVeterinaire> createState() => _InterfaceVeterinaireState();
}

class _InterfaceVeterinaireState extends State<InterfaceVeterinaire>
    with SingleTickerProviderStateMixin {
  final _db       = Supabase.instance.client;
  final _cache    = CacheManager();
  final _vaccSvc  = VaccinationService();
  final _noteSvc  = NoteService();

  late AnimationController _animCtrl;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;

  // État
  int    _totalAnimaux         = 0;
  int    _totalConsultations   = 0;
  int    _rappelsUrgents       = 0;
  int    _alertesOuvertes      = 0;
  bool   _isLoading            = true;
  String _userName             = '';
  String _userEmail            = '';

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initializeData();
  }

  @override
  void dispose() { _animCtrl.dispose(); super.dispose(); }

  // ── Animations ────────────────────────────────────────────
  void _initAnimations() {
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade  = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn));
    _slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  // ── Initialisation ────────────────────────────────────────
  Future<void> _initializeData() async {
    await Future.wait([
      _chargerUtilisateur(),
      _chargerStatistiques(),
    ]);
  }

  Future<void> _chargerUtilisateur() async {
    try {
      final user = _db.auth.currentUser;
      if (user == null) return;

      final data = await _db
          .from('users')
          .select('nom, prenom, nom_complet')
          .eq('id', user.id)
          .maybeSingle();

      String name = data?['nom_complet']
          ?? data?['prenom']
          ?? user.email?.split('@').first.toUpperCase()
          ?? 'Vétérinaire';

      if (mounted) setState(() {
        _userName  = name;
        _userEmail = user.email ?? '';
      });
    } catch (e) {
      if (mounted) setState(() { _userName = 'Vétérinaire'; });
    }
  }

  Future<void> _chargerStatistiques() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final userId = _db.auth.currentUser?.id;
      if (userId == null) throw Exception('Non connecté');

      final stats = await _cache.getOrFetch<Map<String, int>>(
        key: 'vet_stats_$userId',
        fetcher: _fetchStats,
        ttl: const Duration(minutes: 2),
      );

      // Rappels et alertes (pas mis en cache — temps réel)
      final rappels = await _vaccSvc.chargerRappels();
      final alertes = await _noteSvc.alertesActives();

      final urgents = rappels.where((v) {
        final d = DateTime.tryParse(v['date_rappel']?.toString() ?? '');
        return d != null && d.difference(DateTime.now()).inDays <= 7;
      }).length;

      if (mounted) setState(() {
        _totalAnimaux       = stats['total'] ?? 0;
        _totalConsultations = stats['consultations'] ?? 0;
        _rappelsUrgents     = urgents;
        _alertesOuvertes    = alertes.length;
        _isLoading          = false;
      });
    } catch (e, st) {
      ErrorHandler.log(e, st, context: 'Stats vétérinaire');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Map<String, int>> _fetchStats() async {
    final r = await Future.wait([
      _db.from('nouveaux_nee').select('id').count(),
      _db.from('animal_acheter').select('id').count(),
      _db.from('consultations').select('id')
          .eq('veterinaire_id', _db.auth.currentUser!.id).count(),
    ]);
    return {
      'total':          r[0].count + r[1].count,
      'consultations':  r[2].count,
    };
  }

  Future<void> _handleRefresh() async {
    final userId = _db.auth.currentUser?.id;
    if (userId != null) _cache.invalidate('vet_stats_$userId');
    await _initializeData();
    if (mounted) ErrorHandler.showSuccess(context, 'Données actualisées');
  }

  Future<void> _handleLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.logout, color: Colors.red),
          SizedBox(width: 12),
          Text('Déconnexion'),
        ]),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      _cache.clear();
      await _db.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const Connexion()),
        );
      }
    } catch (e, st) {
      ErrorHandler.log(e, st, context: 'Déconnexion');
      if (mounted) ErrorHandler.show(context, e);
    }
  }

  // ── BUILD ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: _isLoading
          ? _buildLoading()
          : RefreshIndicator(
              onRefresh: _handleRefresh,
              color: Couleur.premierColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildWelcomeCard(),
                        const SizedBox(height: 20),
                        _buildStats(),
                        const SizedBox(height: 24),
                        _buildScanCard(),
                        const SizedBox(height: 24),
                        _buildSectionTitle('🩺 Gestion médicale'),
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

  // ── AppBar ────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() => AppBar(
    title: const Text('JUR GUI — Vétérinaire',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
    centerTitle: true,
    backgroundColor: Colors.white,
    foregroundColor: Couleur.premierColor,
    elevation: 2,
    iconTheme: IconThemeData(color: Couleur.premierColor),
    actions: [
      Stack(
        alignment: Alignment.topRight,
        children: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: Couleur.premierColor),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NotesEleveurPage())),
          ),
          if (_alertesOuvertes > 0)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: Text('$_alertesOuvertes',
                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
      const SizedBox(width: 4),
    ],
  );

  // ── Loading ───────────────────────────────────────────────
  Widget _buildLoading() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      CircularProgressIndicator(color: Couleur.premierColor),
      const SizedBox(height: 16),
      Text('Chargement...', style: TextStyle(color: Couleur.premierColor, fontSize: 16)),
    ]),
  );

  // ── Welcome card ──────────────────────────────────────────
  Widget _buildWelcomeCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Couleur.premierColor, Couleur.deuxiemeColor],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(color: Couleur.premierColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
    ),
    child: Row(children: [
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bonjour, Dr. $_userName 👨‍⚕️',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Bienvenue sur votre espace médical',
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
        ],
      )),
      const Icon(Icons.medical_services, color: Colors.amber, size: 42),
    ]),
  );

  // ── Statistiques (4 cartes) ───────────────────────────────
  Widget _buildStats() => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
    childAspectRatio: 1.55,
    children: [
      _statCard(Icons.pets, 'Animaux', '$_totalAnimaux', Colors.blue),
      _statCard(Icons.medical_services, 'Consultations', '$_totalConsultations', Colors.green),
      _statCard(Icons.notifications_active, 'Rappels urgents', '$_rappelsUrgents',
          _rappelsUrgents > 0 ? Colors.red : Colors.grey),
      _statCard(Icons.warning_amber, 'Alertes', '$_alertesOuvertes',
          _alertesOuvertes > 0 ? Colors.orange : Colors.grey),
    ],
  );

  Widget _statCard(IconData icon, String label, String val, MaterialColor color) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [color[50]!, color[100]!],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color[200]!, width: 1.5),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: Icon(icon, size: 26, color: color[700]),
        ),
        Text(val, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color[900])),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color[700])),
      ],
    ),
  );

  // ── Scan RFID card ────────────────────────────────────────
  Widget _buildScanCard() => Container(
    height: 190,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.blue[800]!, Colors.blue[500]!],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 6))],
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Scan RFID Rapide',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Accédez aux dossiers médicaux via tag',
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
              ]),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ScanRFIDVeterinaireBluetooth())),
                icon: const Icon(Icons.nfc, size: 18),
                label: const Text('Scanner', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue[800],
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Icon(Icons.qr_code_scanner, size: 90, color: Colors.white.withOpacity(0.25)),
      ]),
    ),
  );

  // ── Options Grid ──────────────────────────────────────────
  Widget _buildSectionTitle(String t) =>
      Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));

  Widget _buildOptionsGrid() => Column(children: [
    Row(children: [
      Expanded(child: OptionCardVeterinaire(
        label: 'Fiches de Santé',
        icon: Icons.folder_shared,
        iconColor: Couleur.premierColor,
        backgroundColor: const Color(0xFFE8F5E9),
        borderColor: Colors.green[300],
        route: const FichesSante(),
      )),
      const SizedBox(width: 12),
      Expanded(child: OptionCardVeterinaire(
        label: 'Historique\nMédical',
        icon: Icons.history,
        iconColor: Colors.orange[700],
        backgroundColor: const Color(0xFFFFF3E0),
        borderColor: Colors.orange[300],
        route: const HistoriqueMedical(),
      )),
    ]),
    const SizedBox(height: 12),
    Row(children: [
      Expanded(child: OptionCardVeterinaire(
        label: 'Vaccinations',
        icon: Icons.vaccines,
        iconColor: Colors.purple[700],
        backgroundColor: const Color(0xFFFCE4EC),
        borderColor: Colors.purple[300],
        badgeCount: _rappelsUrgents,
        route: const Vaccinations(),
      )),
      const SizedBox(width: 12),
      Expanded(child: OptionCardVeterinaire(
        label: 'Notes\nÉleveur',
        icon: Icons.message,
        iconColor: Couleur.collaboration,
        backgroundColor: const Color(0xFFE0F7FA),
        borderColor: const Color(0xFF80DEEA),
        badgeCount: _alertesOuvertes,
        route: const NotesEleveurPage(),
      )),
    ]),
  ]);

  // ── Drawer ────────────────────────────────────────────────
  Widget _buildDrawer() => Drawer(
    child: ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Couleur.premierColor, Couleur.deuxiemeColor],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                child: Icon(Icons.medical_services, size: 32, color: Couleur.premierColor),
              ),
              const SizedBox(height: 10),
              Text('Dr. $_userName',
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              Text(_userEmail,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),

        // Stats résumé dans le drawer
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            _drawerStat('$_totalAnimaux', 'Animaux', Colors.green),
            const SizedBox(width: 8),
            _drawerStat('$_totalConsultations', 'Consultations', Colors.blue),
          ]),
        ),
        const Divider(),

        _drawerItem(Icons.dashboard, 'Tableau de bord', () => Navigator.pop(context)),
        _drawerItem(Icons.nfc, 'Scan RFID', () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanRFIDVeterinaireBluetooth()));
        }),
        _drawerItem(Icons.folder_shared, 'Fiches Santé', () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const FichesSante()));
        }),
        _drawerItem(Icons.vaccines, 'Vaccinations', () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const Vaccinations()));
        }),
        _drawerItem(Icons.history, 'Historique', () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoriqueMedical()));
        }),
        _drawerItem(Icons.message, 'Notes Éleveur', () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const NotesEleveurPage()));
        }),
        const Divider(),
        _drawerItem(Icons.refresh, 'Actualiser', () {
          Navigator.pop(context);
          _handleRefresh();
        }),
        _drawerItem(Icons.logout, 'Déconnexion', _handleLogout,
            color: Colors.red),
      ],
    ),
  );

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap, {Color? color}) =>
      ListTile(
        leading: Icon(icon, color: color ?? Couleur.premierColor, size: 22),
        title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        horizontalTitleGap: 8,
      );

  Widget _drawerStat(String val, String label, MaterialColor c) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: c[50], borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Text(val, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c[800])),
        Text(label, style: TextStyle(fontSize: 11, color: c[700])),
      ]),
    ),
  );
}