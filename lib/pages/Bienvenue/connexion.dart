// ============================================================
// PAGE DE CONNEXION - VERSION OPTIMISÉE
// Fichier: lib/pages/connexion.dart
// ============================================================

import 'package:depart/pages/Interface/interfaceEleveur/interfaceElevaur.dart';
import 'package:depart/pages/Interface/interfaceVeterinaire/interfaceVeterinaire.dart';
import 'package:depart/Eleveures/New/Notification/NotificationService.dart';
import 'package:depart/pages/Bienvenue/inscription.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:depart/securite/ErrorHandler.dart';
import 'package:depart/securite/Validators.dart';
import 'package:depart/widgets/couleur.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Connexion extends StatefulWidget {
  const Connexion({super.key});

  @override
  State<Connexion> createState() => _ConnexionState();
}

class _ConnexionState extends State<Connexion> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // État
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ===== CONNEXION SÉCURISÉE =====
  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // ✅ Nettoyer et normaliser l'email
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text;

      debugPrint('🔐 Tentative de connexion: $email');

      // ✅ Authentification
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Échec de connexion');
      }

      debugPrint('✅ Utilisateur authentifié: ${response.user!.id}');

      // ✅ Notification locale "email confirmé" — une seule fois,
      // la première fois qu'on détecte que l'email vient d'être validé.
      // Non bloquant : ne doit jamais empêcher la connexion.
      try {
        final prefs = await SharedPreferences.getInstance();
        final dejaNotifie = prefs.getBool('email_confirme_notifie_${response.user!.id}') ?? false;
        if (!dejaNotifie && response.user!.emailConfirmedAt != null) {
          await NotificationService().notifierCompteConfirme();
          await prefs.setBool('email_confirme_notifie_${response.user!.id}', true);
        }
      } catch (e) {
        debugPrint('⚠️ Notification email confirmé échouée (non bloquant) : $e');
      }

      // ✅ Récupérer le rôle et le statut (validation admin pour tous les rôles)
      final userData = await _supabase
          .from('users')
          .select('role, nom, prenom, statut, motif_rejet')
          .eq('id', response.user!.id)
          .maybeSingle();

      if (userData == null) {
        // Fallback sur metadata
        final role = response.user!.userMetadata?['role'] as String? ?? 'eleveur';
        debugPrint('⚠️ Pas de données user, utilisation metadata: $role');

        // Créer l'entrée manquante
        await _supabase.from('users').insert({
          'id': response.user!.id,
          'email': response.user!.email,
          'nom': response.user!.userMetadata?['nom'] ?? 'Non renseigné',
          'prenom': response.user!.userMetadata?['prenom'] ?? 'Non renseigné',
          'role': role,
          'nom_complet': response.user!.userMetadata?['nom_complet'] ?? 'Utilisateur',
        });

        await _traiterConnexion(role: role, statut: null, motifRejet: null);
      } else {
        debugPrint('✅ Rôle récupéré: ${userData['role']}');
        await _traiterConnexion(
          role: userData['role'] as String,
          statut: userData['statut'] as String?,
          motifRejet: userData['motif_rejet'] as String?,
        );
      }
    } catch (error, stackTrace) {
      ErrorHandler.log(
        error,
        stackTrace,
        context: 'Connexion utilisateur',
        additionalData: {
          'email': _emailController.text,
        },
      );

      if (mounted) {
        ErrorHandler.show(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ===== TRAITEMENT DE LA CONNEXION SELON LE STATUT (tous les rôles) =====
  //
  // statut == null      -> ancien compte créé avant la validation générale,
  //                         on ne le bloque pas rétroactivement.
  // statut == 'approved' -> accès normal à l'interface du rôle.
  // statut == 'pending_verification' / 'rejected' -> ACCÈS BLOQUÉ.
  //   Au lieu d'une page dédiée plein écran, on affiche :
  //     1. une notification push/locale
  //     2. une petite alerte (AlertDialog) explicative
  //   puis on déconnecte l'utilisateur et on reste sur l'écran de connexion.
  Future<void> _traiterConnexion({
    required String role,
    required String? statut,
    String? motifRejet,
  }) async {
    if (!mounted) return;

    final roleNormalise = role.toLowerCase();
    debugPrint('🚀 Connexion: $roleNormalise (statut: $statut)');

    if (statut == 'pending_verification' || statut == 'rejected') {
      final estRejete = statut == 'rejected';

      final titre = estRejete
          ? 'Compte non validé'
          : 'Compte en cours de vérification';
      final corps = estRejete
          ? (motifRejet != null && motifRejet.isNotEmpty
              ? 'Votre compte n\'a pas été validé : $motifRejet'
              : 'Votre compte n\'a pas pu être validé par notre équipe.')
          : 'Votre compte est en cours de vérification par notre équipe. '
              'Vous serez notifié dès qu\'une décision sera prise.';

      // 1. Notification push/locale
      try {
        await NotificationService().afficherNotificationImmediateLocal(
          titre: titre,
          corps: corps,
          type: estRejete ? 'compte_rejete' : 'compte_en_attente',
          urgente: estRejete,
        );
      } catch (e) {
        debugPrint('⚠️ Notification statut compte échouée (non bloquant) : $e');
      }

      // 2. Petite alerte, puis déconnexion (accès bloqué)
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: Icon(
            estRejete ? Icons.cancel_outlined : Icons.hourglass_top_rounded,
            color: estRejete ? Colors.red : Colors.orange[700],
            size: 56,
          ),
          title: Text(
            titre,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(corps, textAlign: TextAlign.center),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: estRejete ? Colors.red : Colors.orange[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('J\'ai compris'),
              ),
            ),
          ],
        ),
      );

      await _supabase.auth.signOut();
      // On reste simplement sur l'écran de connexion (formulaire vidé).
      if (mounted) {
        _emailController.clear();
        _passwordController.clear();
      }
      return;
    }

    // statut == null (ancien compte) ou 'approved' -> accès normal.
    Widget destination;
    if (roleNormalise == 'veterinaire') {
      destination = const interfaceVeterinaire();
    } else if (roleNormalise == 'eleveur') {
      destination = const interfaceElevaur();
    } else {
      debugPrint('⚠️ Rôle inconnu: $role, redirection vers éleveur');
      destination = const interfaceElevaur();
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 241, 248, 233),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  _buildLogo(),
                  const SizedBox(height: 40),

                  // Titre
                  _buildHeader(),
                  const SizedBox(height: 40),

                  // Champ Email
                  _buildEmailField(),
                  const SizedBox(height: 20),

                  // Champ Mot de passe
                  _buildPasswordField(),
                  const SizedBox(height: 12),

                  // Mot de passe oublié
                  _buildForgotPassword(),
                  const SizedBox(height: 32),

                  // Bouton Connexion
                  _buildLoginButton(),
                  const SizedBox(height: 24),

                  // Lien vers inscription
                  _buildSignUpLink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Couleur.PremierColor.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Image.asset(
        "assets/image/app_icon.png",
        width: 120,
        height: 120,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.pets,
            size: 80,
            color: Couleur.PremierColor,
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          "Bienvenue",
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Couleur.PremierColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Connectez-vous à Jur Gui",
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      validator: Validators.email,
      decoration: InputDecoration(
        labelText: "Email",
        hintText: "votre.email@example.com",
        prefixIcon: Icon(
          Icons.email_outlined,
          color: Couleur.PremierColor,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _signIn(),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Mot de passe requis';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: "Mot de passe",
        hintText: "Votre mot de passe",
        prefixIcon: Icon(
          Icons.lock_outline,
          color: Couleur.PremierColor,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey[600],
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {
          // TODO: Implémenter récupération mot de passe
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fonctionnalité à venir'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        child: Text(
          'Mot de passe oublié ?',
          style: TextStyle(
            color: Couleur.PremierColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _signIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: Couleur.PremierColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                "Se connecter",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildSignUpLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Pas de compte ?",
          style: TextStyle(color: Colors.grey[700]),
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const Inscription(),
              ),
            );
          },
          child: const Text(
            "Inscrivez-vous",
            style: TextStyle(
              fontWeight: FontWeight.bold, color: Colors.red,
            ),
          ),
        ),
      ],
    );
  }
}