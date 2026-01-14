import 'package:depart/Eleveures/Accouplemaent/EnregistrerAccouplement.dart';
import 'package:depart/Eleveures/Ajouter%20Animal/AjouterAnimal.dart';
import 'package:depart/Eleveures/AnimalInfoRFID/AnimalInfoRFIDPage.dart';
import 'package:depart/Eleveures/Chaleur/Chaleur.dart';
import 'package:depart/Eleveures/Mon%20Troupeau/HistoriqueMedicalEleveur.dart';
import 'package:depart/Eleveures/Mon%20Troupeau/Mon_Troupeau.dart';
import 'package:depart/Eleveures/Mon%20Troupeau/SupprimerAnimal/RappelsVaccinationEleveur.dart';
import 'package:depart/Eleveures/Mon%20Troupeau/ModfierAnimal/AnimalListPage.dart';
import 'package:depart/widgets/optioncardEleveur.dart';
import 'package:flutter/material.dart';
import 'package:depart/widgets/couleur.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// INTERFACE ÉLEVEUR - DASHBOARD PRINCIPAL
// ============================================================
class interfaceElevaur extends StatefulWidget {
  const interfaceElevaur({super.key});

  @override
  State<interfaceElevaur> createState() => _interfaceElevaureState();
}

class _interfaceElevaureState extends State<interfaceElevaur> {
  final supabase = Supabase.instance.client;
  int _totalAnimaux = 0;
  int _nombreMales = 0;
  int _nombreFemelles = 0;
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
          _userName = user.email?.split('@').first.toUpperCase() ?? "Éleveur";
        });
      }
    } catch (e) {
      debugPrint("Erreur chargement utilisateur: $e");
    }
  }

  Future<void> _chargerStatistiques() async {
    setState(() => _isLoading = true);
    try {
      // Compter tous les animaux
      final nouveauxNes = await supabase.from('nouveaux_nee').select('id, sexe').count();
      final achetes = await supabase.from('animal_acheter').select('id, sexe').count();
      
      // Récupérer les données pour compter par sexe
      final nouveauxNesData = await supabase.from('nouveaux_nee').select('sexe');
      final achetesData = await supabase.from('animal_acheter').select('sexe');
      
      int males = 0;
      int femelles = 0;
      
      // Compter les mâles et femelles dans nouveaux_nee
      for (var animal in nouveauxNesData) {
        if (animal['sexe']?.toString().toLowerCase() == 'male' || 
            animal['sexe']?.toString().toLowerCase() == 'mâle') {
          males++;
        } else if (animal['sexe']?.toString().toLowerCase() == 'femelle') {
          femelles++;
        }
      }
      
      // Compter les mâles et femelles dans animal_acheter
      for (var animal in achetesData) {
        if (animal['sexe']?.toString().toLowerCase() == 'male' || 
            animal['sexe']?.toString().toLowerCase() == 'mâle') {
          males++;
        } else if (animal['sexe']?.toString().toLowerCase() == 'femelle') {
          femelles++;
        }
      }
      
      setState(() {
        _totalAnimaux = nouveauxNes.count + achetes.count;
        _nombreMales = males;
        _nombreFemelles = femelles;
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
          "JUR GUI - Éleveur",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Couleur.PremierColor,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
        iconTheme: IconThemeData(color: Couleur.PremierColor),
        actions: [
          // Badge de notifications (optionnel)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: Stack(
                children: [
                  Icon(Icons.notifications_outlined, color: Couleur.PremierColor),
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
                        '3',
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
                // TODO: Naviguer vers les notifications
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
                  CircularProgressIndicator(color: Couleur.PremierColor),
                  const SizedBox(height: 16),
                  Text(
                    "Chargement des données...",
                    style: TextStyle(color: Couleur.PremierColor),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _chargerStatistiques,
              color: Couleur.PremierColor,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Message de bienvenue
                  _buildWelcomeCard(),
                  const SizedBox(height: 20),

                  // Statistiques du troupeau
                  _buildStatistiques(),
                  const SizedBox(height: 24),

                  // Carte Ajouter Animal
                  _buildAjouterAnimalCard(),
                  const SizedBox(height: 24),

                  // Section Gestion du troupeau
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Gestion du troupeau',
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
                        style: TextButton.styleFrom(
                          foregroundColor: Couleur.PremierColor
                        ),
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
          colors: [Couleur.PremierColor, Couleur.PremierColor.withOpacity(0.8)],
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

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Couleur.PremierColor.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // En-tête du Drawer amélioré
            Container(
              height: 240,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Couleur.PremierColor,
                    Couleur.PremierColor.withOpacity(0.8),
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo ou image de l'application
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
                          Icons.person,
                          size: 50,
                          color: Couleur.PremierColor,
                        ),
                      ),
                       const SizedBox(height: 24),
                      // Informations utilisateur
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
            color: Couleur.PremierColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Couleur.PremierColor, size: 20),
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
      builder: (dialogContext) => AlertDialog(
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
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              "Annuler",
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              // Capturer les navigators avant les opérations async
              final dialogNavigator = Navigator.of(dialogContext);
              final rootNavigator = Navigator.of(context, rootNavigator: true);
              
              // Fermer le dialog de confirmation
              dialogNavigator.pop();
              
              // Fermer le drawer
              Navigator.pop(context);
              
              try {
                // Afficher un indicateur de chargement
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (loadingContext) => WillPopScope(
                    onWillPop: () async => false,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                );

                // Déconnexion
                await supabase.auth.signOut();
                
                // Vérifier si le widget est encore monté
                if (mounted) {
                  // Fermer le loading dialog
                  rootNavigator.pop();
                  
                  // Naviguer vers la page de connexion
                  rootNavigator.pushReplacementNamed('/Connexion');
                }
              } catch (e) {
                debugPrint("Erreur lors de la déconnexion: $e");
                
                if (mounted) {
                  // Fermer le loading dialog en cas d'erreur
                  rootNavigator.pop();
                  
                  // Afficher un message d'erreur
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text("Erreur lors de la déconnexion: ${e.toString()}"),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
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
            Image.asset("assets/image/img10.png", width: 40, height: 40),
            const SizedBox(width: 12),
            const Text("À propos"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "JUR GUI - Gestion d'Élevage",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text("Version 4.0.0"),
            const SizedBox(height: 16),
            Text(
              "Application de gestion complète pour votre troupeau.",
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
            decoration: BoxDecoration(
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

 Widget _buildAjouterAnimalCard() {
  return LayoutBuilder(
    builder: (context, constraints) {
      // Déterminer si c'est un petit écran
      final isSmallScreen = constraints.maxWidth < 350;
      final isMediumScreen = constraints.maxWidth < 600;
      return Container(
        height: isSmallScreen ? 220 : 200,
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
          padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
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
                          Text(
                            "Afficher les information de l'animal",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 16 : 19,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isSmallScreen ? 6 : 8),
                          Text(
                            "Scannez facilement avec RFID",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: isSmallScreen ? 12 : 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AnimalInfoRFIDPage(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Couleur.PremierColor,
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 16 : 20,
                            vertical: isSmallScreen ? 12 : 15,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 2,
                        ),
                        label: Text(
                          "Scanner maintenant",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isSmallScreen ? 13 : 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: isSmallScreen ? 8 : 12),
              Flexible(
                flex: 1,
                child: Image.asset(
                  "assets/image/img10.png",
                  width: isSmallScreen ? 80 : 100,
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
              child: optioncardEleveur(
                image: 'assets/image/img6.png',
                label: "Mon Troupeau",
                route: const MonTroupeau(),
                backgroundColor: Color(0xFFE8F5E9),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: optioncardEleveur(
                image: 'assets/image/img10.png',
                label: 'Période Chaleur',
                route: const Chaleur(),
                backgroundColor: Color(0xFFFFF3E0),
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
                backgroundColor: Color(0xFFFCE4EC),
              ), 
            ),
            const SizedBox(width: 12),
            Expanded(
              child: optioncardEleveur(
                image: 'assets/image/img14.png', 
                label: 'Enrigistrer Animal',
                route: const AjouterAnimal(),
                backgroundColor: Color(0xFFFFF9C4),
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
                label: "Transport",
                route: const HistoriqueMedicalEleveur(),
                backgroundColor: Color(0xFFE3F2FD),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }


}