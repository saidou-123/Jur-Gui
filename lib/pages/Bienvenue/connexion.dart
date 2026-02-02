// ============================================================
// PAGE DE CONNEXION - VERSION OPTIMISÉE
// Fichier: lib/pages/connexion.dart
// ============================================================

import 'package:depart/pages/Interface/interfaceEleveur/interfaceElevaur.dart';
import 'package:depart/pages/Interface/interfaceVeterinaire/interfaceVeterinaire.dart';
import 'package:depart/pages/Bienvenue/inscription.dart';
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

      // ✅ Récupérer le rôle
      final userData = await _supabase
          .from('users')
          .select('role, nom, prenom')
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
        
        _navigateByRole(role);
      } else {
        debugPrint('✅ Rôle récupéré: ${userData['role']}');
        _navigateByRole(userData['role'] as String);
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

  // ===== NAVIGATION PAR RÔLE =====
  void _navigateByRole(String role) {
    if (!mounted) return;
    
    debugPrint('🚀 Navigation vers interface: $role');
    
    Widget destination;
    
    if (role.toLowerCase() == 'eleveur') {
      destination = const interfaceElevaur();
    } else if (role.toLowerCase() == 'veterinaire') {
      destination = const interfaceVeterinaire();
    } else {
      // Par défaut, rediriger vers éleveur
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
      backgroundColor: Colors.white,
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
        "assets/image/img3.png",
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
          "Connectez-vous à Jur Gui 4.0",
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
              fontWeight: FontWeight.bold,color: Colors.red,
            ),
          ),
        ),
      ],
    );
  }
}