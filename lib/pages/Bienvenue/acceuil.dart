//

// ============================================================
// PAGE D'ACCUEIL - VERSION OPTIMISÉE (fond blanc)
// Fichier: lib/pages/acceuil.dart
// ============================================================

import 'package:depart/main.dart' show supabasePret;
import 'package:depart/pages/Bienvenue/descriptionPages/homePage.dart';
import 'package:depart/pages/Interface/interfaceEleveur/interfaceElevaur.dart';
import 'package:depart/pages/Interface/interfaceVeterinaire/interfaceVeterinaire.dart';
import 'package:depart/pages/Interface/VetPendingPage.dart';
import 'package:depart/pages/Interface/VetRejectedPage.dart';
import 'package:depart/widgets/couleur.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class Acceuil extends StatefulWidget {
  const Acceuil({super.key});

  @override
  State<Acceuil> createState() => _AcceuilState();
}

class _AcceuilState extends State<Acceuil> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  Timer? _autoNavigateTimer;
  bool _navigationDejaEffectuee = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startAutoNavigate();
    // ★ Vérifie si une session existe déjà (utilisateur déjà connecté),
    //   pour éviter de le renvoyer vers l'onboarding/connexion à chaque
    //   démarrage à froid — notamment quand l'app est ouverte depuis
    //   une notification.
    _verifierSessionExistante();
  }

  Future<void> _verifierSessionExistante() async {
    try {
      // ★ On attend que Supabase.initialize() soit terminé (signal réel),
      //   avec un maximum de 4s pour ne jamais bloquer si quelque chose
      //   se passe mal — au-delà, on suppose "pas connecté" par sécurité.
      await supabasePret.future.timeout(
        const Duration(seconds: 4),
        onTimeout: () => debugPrint('⚠️ Supabase pas prêt après 4s'),
      );

      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return; // Pas connecté : onboarding normal.

      final userId = session.user.id;
      final userData = await Supabase.instance.client
          .from('users')
          .select('role, statut')
          .eq('id', userId)
          .maybeSingle();

      if (!mounted || _navigationDejaEffectuee) return;

      final role   = (userData?['role'] as String?) ?? 'eleveur';
      final statut = userData?['statut'] as String?;

      Widget destination;
      if (role.toLowerCase() == 'veterinaire') {
        if (statut == 'pending_verification') {
          destination = const VetPendingPage();
        } else if (statut == 'rejected') {
          destination = const VetRejectedPage();
        } else {
          destination = const interfaceVeterinaire();
        }
      } else {
        destination = const interfaceElevaur();
      }

      _navigationDejaEffectuee = true;
      _autoNavigateTimer?.cancel();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => destination),
      );
    } catch (e) {
      debugPrint('⚠️ _verifierSessionExistante: $e');
      // En cas d'erreur, on laisse le flux normal (onboarding) continuer.
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _autoNavigateTimer?.cancel();
    super.dispose();
  }

  // ===== ANIMATIONS =====
  void _initAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _animationController.forward();
  }

  // ===== AUTO-NAVIGATION =====
  void _startAutoNavigate() {
    _autoNavigateTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        _navigateToLogin();
      }
    });
  }

  void _navigateToLogin() {
    if (_navigationDejaEffectuee) return;
    _navigationDejaEffectuee = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        // ★ Acceuil -> Homepage (onboarding). C'est Homepage qui navigue
        //   ensuite vers Connexion quand l'utilisateur clique "Commencer".
        pageBuilder: (context, animation, secondaryAnimation) => const Homepage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;

          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ★ Fond blanc uni (au lieu du dégradé de couleurs).
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Logo et titre animés
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      children: [
                        // Logo
                        Container(
                          padding: const EdgeInsets.all(20),
                        ),

                        const SizedBox(height: 32),

                        // Titre
                        // ★ Couleur passée de blanc à la couleur de la marque,
                        //   pour rester lisible sur fond blanc.
                        Text(
                          "JUR GUI",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 40,
                            color: Couleur.PremierColor,
                            letterSpacing: 2,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Sous-titre
                        Text(
                          "Gestion d'Élevage Intelligente",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 60),

                // Image animée
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/image/app_icon.png',
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 200,
                              decoration: BoxDecoration(
                                color: Couleur.PremierColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                Icons.image,
                                size: 80,
                                color: Couleur.PremierColor.withOpacity(0.4),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Description
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    ' Gestion d\'Élevage Intelligente Mon appli mon troupeau ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                      height: 1.5,
                    ),
                  ),
                ),

                const Spacer(),

                const SizedBox(height: 16),

                // Indicateur auto-navigation
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.grey[500],
                    ),
                   
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===== VERSION SPLASH SCREEN ALTERNATIVE =====
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const Homepage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ★ Fond blanc, cohérent avec Acceuil.
      backgroundColor: Colors.white,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pets,
            size: 100,
            color: Couleur.PremierColor,
          ),
          const SizedBox(height: 24),
          Text(
            "JUR GUI",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Couleur.PremierColor,
            ),
          ),
          const SizedBox(height: 40),
          CircularProgressIndicator(
            color: Couleur.PremierColor,
          ),
        ],
      ),
    );
  }
}