import 'package:depart/widgets/optioncardVeterinaire.dart';
import 'package:flutter/material.dart';
import 'package:depart/Veterinaires/FichesSante.dart';
import 'package:depart/Veterinaires/HistoriqueMedical.dart';
import 'package:depart/Veterinaires/Scanveterinaire/ScanRFIDVeterinaire.dart';
import 'package:depart/Veterinaires/Vaccinations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// INTERFACE VÉTÉRINAIRE - DASHBOARD PRINCIPAL
// ============================================================
class interfaceVeterinaire extends StatefulWidget {
  const interfaceVeterinaire({super.key});

  @override
  State<interfaceVeterinaire> createState() => _interfaceVeterinaireState();
}

class _interfaceVeterinaireState extends State<interfaceVeterinaire> {
  final supabase = Supabase.instance.client;
  int _totalAnimaux = 0;
  int _consultationsEnCours = 0;
  bool _isLoading = true;
  String _userEmail = "";
  String _userName = "";

  @override
  void initState() {
    super.initState();
    _chargerStatistiques();
    _chargerInfoUtilisateur();
  }

  Future<void> _chargerInfoUtilisateur() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        setState(() {
          _userEmail = user.email ?? "Non disponible";
          // Extraire le nom de l'email (partie avant @)
          _userName = user.email?.split('@').first.toUpperCase() ?? "Vétérinaire";
        });
      }
    } catch (e) {
      debugPrint("Erreur chargement utilisateur: $e");
    }
  }

  Future<void> _chargerStatistiques() async {
    setState(() => _isLoading = true);
    try {
      // Compter tous les animaux (toutes sources confondues)
      final nouveauxNes = await supabase.from('nouveaux_nee').select('id').count();
      final achetes = await supabase.from('animal_acheter').select('id').count();
      
      setState(() {
        _totalAnimaux = nouveauxNes.count + achetes.count;
        _consultationsEnCours = 0; // À implémenter selon vos besoins
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Erreur chargement stats: $e");
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Erreur lors du chargement des données"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "JUR GUI - Vétérinaire",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blue[700],
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.blue[700]),
        actions: [
          // Badge de notifications
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: Stack(
                children: [
                  Icon(Icons.notifications_outlined, color: Colors.blue[700]),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      child: const Text(
                        '2',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Notifications à venir")),
                );
              },
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.blue[700]),
                  const SizedBox(height: 16),
                  Text(
                    "Chargement des données...",
                    style: TextStyle(color: Colors.blue[700]),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _chargerStatistiques,
              color: Colors.blue[700],
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Message de bienvenue
                  _buildWelcomeCard(),
                  const SizedBox(height: 20),

                  // Statistiques
                  _buildStatistiques(),
                  const SizedBox(height: 24),

                  // Carte Scan RFID
                  _buildScanCard(),

                  const SizedBox(height: 24),

                  // Section Grille Options
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Gestion médicale',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          // TODO: Voir tout
                        },
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text("Voir tout"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildOptionsGrid(),
                  const SizedBox(height: 80), // Espace pour le FAB
                ],
              ),
            ),
     
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[700]!, Colors.blue[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
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
                  "Bonjour, Dr. $_userName! 👨‍⚕️",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Bienvenue sur votre espace médical",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.medical_services, color: Colors.amber[300], size: 40),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue[50]!,
              Colors.white,
            ],
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // En-tête du Drawer
            Container(
              height: 240,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue[700]!,
                    Colors.blue[500]!,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar vétérinaire
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.medical_services,
                          size: 50,
                          color: Colors.blue[700],
                        ),
                      ),      
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _userEmail,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Section Mon Compte
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                "MON COMPTE",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                  letterSpacing: 1.2,
                ),
              ),
            ),

            _buildDrawerTile(
              icon: Icons.person_outline,
              title: "Mon Profil",
              subtitle: "Informations personnelles",
              onTap: () {
                Navigator.pop(context);
                // TODO: Naviguer vers profil
              },
            ),

            _buildDrawerTile(
              icon: Icons.settings_outlined,
              title: "Paramètres",
              subtitle: "Préférences et configuration",
              onTap: () {
                Navigator.pop(context);
                // TODO: Naviguer vers paramètres
              },
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 32),
            ),

            // Section Médical
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                "MÉDICAL",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                  letterSpacing: 1.2,
                ),
              ),
            ),

            _buildDrawerTile(
              icon: Icons.assignment_outlined,
              title: "Mes Consultations",
              subtitle: "Historique des consultations",
              onTap: () {
                Navigator.pop(context);
                // TODO: Naviguer vers consultations
              },
            ),

            _buildDrawerTile(
              icon: Icons.schedule,
              title: "Rendez-vous",
              subtitle: "Gérer mon agenda",
              onTap: () {
                Navigator.pop(context);
                // TODO: Naviguer vers agenda
              },
            ),

            _buildDrawerTile(
              icon: Icons.local_pharmacy_outlined,
              title: "Prescriptions",
              subtitle: "Ordonnances et traitements",
              onTap: () {
                Navigator.pop(context);
                // TODO: Naviguer vers prescriptions
              },
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 32),
            ),

            // Section Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                "ACTIONS",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                  letterSpacing: 1.2,
                ),
              ),
            ),

            _buildDrawerTile(
              icon: Icons.refresh,
              title: "Actualiser",
              subtitle: "Recharger les données",
              onTap: () {
                Navigator.pop(context);
                _chargerStatistiques();
                _chargerInfoUtilisateur();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 12),
                        Text("Données actualisées avec succès"),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),

            _buildDrawerTile(
              icon: Icons.help_outline,
              title: "Aide & Support",
              subtitle: "Besoin d'assistance ?",
              onTap: () {
                Navigator.pop(context);
                // TODO: Ouvrir page d'aide
              },
            ),

            _buildDrawerTile(
              icon: Icons.info_outline,
              title: "À propos",
              subtitle: "Version 4.0.0",
              onTap: () {
                Navigator.pop(context);
                _showAboutDialog();
              },
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 32),
            ),

            // Déconnexion
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.logout, color: Colors.red, size: 20),
                  ),
                  title: const Text(
                    "Déconnexion",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: const Text(
                    "Se déconnecter de l'application",
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  onTap: () => _showLogoutDialog(),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue[700], size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onTap: onTap,
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
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
        content: const Text(
          "Êtes-vous sûr de vouloir vous déconnecter de votre compte ?",
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Annuler",
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              Navigator.pop(context); // Fermer le drawer
              
              // Afficher un indicateur de chargement
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              await supabase.auth.signOut();
              
              if (mounted) {
                Navigator.of(context).pop(); // Fermer le loading
                Navigator.of(context).pushReplacementNamed('/connexion');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("Déconnexion"),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.medical_services, color: Colors.blue[700], size: 40),
            const SizedBox(width: 12),
            const Text("À propos"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "JUR GUI - Espace Vétérinaire",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text("Version 4.0.0"),
            const SizedBox(height: 16),
            Text(
              "Plateforme de gestion médicale complète pour le suivi vétérinaire.",
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            const Text("© 2026 JUR GUI. Tous droits réservés."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
          ),
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
            label: "Total Animaux",
            value: "$_totalAnimaux",
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.medical_services,
            label: "Consultations",
            value: "$_consultationsEnCours",
            color: Colors.green,
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
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
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
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }


Widget _buildScanCard() {
  return LayoutBuilder(
    builder: (context, constraints) {
      final isTinyScreen = constraints.maxWidth < 320;
      final isSmallScreen = constraints.maxWidth < 350;
      final isMediumScreen = constraints.maxWidth < 600;
      
      return Container(
        height: isTinyScreen ? 240 : (isSmallScreen ? 220 : 200),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue[700]!, 
              Colors.blue[500]!, 
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.4), 
              blurRadius: 12,
              offset: const Offset(0, 6), 
            ),
          ],
        ),
        
        child: Padding(
          padding: EdgeInsets.all(isTinyScreen ? 12 : (isSmallScreen ? 16 : 20)),
          
          child: Row(
            children: [
              Expanded(
                flex: isMediumScreen ? 2 : 3,
                
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        
                        children: [
                          SizedBox(height: isTinyScreen ? 6 : 8),
                          Text(
                            "Scan RFID Rapide",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isTinyScreen ? 16 : (isSmallScreen ? 18 : 20),
                              fontWeight: FontWeight.bold,
                              height: 1.2, 
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis, 
                          ),
                          
                          SizedBox(height: isTinyScreen ? 3 : 4),

                          Text(
                            "Accédez aux dossiers médicaux",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),

                              fontSize: isTinyScreen ? 11 : (isSmallScreen ? 12 : 14),
                            ),
                            maxLines: 2, 
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: isTinyScreen ? 6 : 8),

                    FittedBox(
                      fit: BoxFit.scaleDown, 
                      alignment: Alignment.centerLeft, 
                      
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ScanRFIDVeterinaire(),
                            ),
                          );
                        }, 
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white, 
                          foregroundColor: Colors.blue[700], 

                          padding: EdgeInsets.symmetric(
                            horizontal: isTinyScreen ? 14 : (isSmallScreen ? 16 : 20),
                            vertical: isTinyScreen ? 10 : (isSmallScreen ? 11 : 12),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 2, 
                        ),

                        icon: Icon(
                          Icons.nfc, 
                          size: isTinyScreen ? 16 : (isSmallScreen ? 18 : 20),
                        ),

                        label: Text(
                          "Scanner maintenant",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isTinyScreen ? 12 : (isSmallScreen ? 13 : 14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: isTinyScreen ? 6 : (isSmallScreen ? 8 : 12)),

              Flexible(
                flex: 1, 
                child: Image.asset(
                  "assets/image/img14.png",
                  width: isTinyScreen ? 70 : (isSmallScreen ? 85 : 110),
                  fit: BoxFit.contain, 
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

  Widget _buildOptionsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: optioncardVeterinaire(
                image: 'assets/image/img10.png',
                label: "Fiches de Santé",
                route: const FichesSante(),
                backgroundColor: const Color(0xFFE8F5E9),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: optioncardVeterinaire(
                image: 'assets/image/img6.png',
                label: 'Historique Médical',
                route: const HistoriqueMedical(),
                backgroundColor: const Color(0xFFFFF3E0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: optioncardVeterinaire(
                image: 'assets/image/img5.png',
                label: "Vaccinations",
                route: const Vaccinations(),
                backgroundColor: const Color(0xFFFCE4EC),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: optioncardVeterinaire(
                image: 'assets/image/img14.png',
                label: 'Scan RFID',
                route: const ScanRFIDVeterinaire(),
                backgroundColor: const Color(0xFFFFF9C4),
              ),
            ),
          ],
        ),
      ],
    );
  }
}