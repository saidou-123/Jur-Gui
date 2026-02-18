// ============================================================
// PAGE D'INSCRIPTION - VERSION OPTIMISÉE
// Fichier: lib/pages/inscription.dart
// ============================================================

import 'package:depart/pages/Bienvenue/connexion.dart';
import 'package:depart/securite/ErrorHandler.dart';
import 'package:depart/securite/Validators.dart';
import 'package:depart/widgets/couleur.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Inscription extends StatefulWidget {
  const Inscription({super.key});

  @override
  State<Inscription> createState() => _InscriptionState();
}

class _InscriptionState extends State<Inscription> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  
  // Controllers
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  // État
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _roleSelectionne;

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ===== INSCRIPTION =====
  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (_roleSelectionne == null) {
      ErrorHandler.show(
        context,
        'Veuillez sélectionner votre rôle (Éleveur ou Vétérinaire)',
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      // ✅ Sanitizer les inputs
      final nom = Validators.sanitize(_nomController.text);
      final prenom = Validators.sanitize(_prenomController.text);
      final email = _emailController.text.trim().toLowerCase();
      
      // ✅ Inscription avec metadata
      final response = await _supabase.auth.signUp(
        email: email,
        password: _passwordController.text,
        data: {
          'nom': nom,
          'prenom': prenom,
          'role': _roleSelectionne,
          'nom_complet': '$prenom $nom',
        },
      );

      if (response.user != null && mounted) {
        // ✅ Succès
        await _showSuccessDialog();
      }
    } catch (error, stackTrace) {
      ErrorHandler.log(
        error,
        stackTrace,
        context: 'Inscription utilisateur',
        additionalData: {
          'email': _emailController.text,
          'role': _roleSelectionne,
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

  // ===== DIALOGUE DE SUCCÈS =====
  Future<void> _showSuccessDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        icon: const Icon(
          Icons.check_circle,
          color: Colors.green,
          size: 64,
        ),
        title: const Text(
          '✅ Inscription réussie !',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Votre compte a été créé avec succès.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue, width: 2),
              ),
              child: const Row(
                children: [
                  Icon(Icons.email, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Vérifiez votre email pour confirmer votre compte.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const Connexion(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Se connecter'),
          ),
        ],
      ),
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
                  const SizedBox(height: 16),
                  
                  // Header
                  _buildHeader(),
                  const SizedBox(height: 32),
                // Sélection du rôle
                _buildRoleSelection(),
                const SizedBox(height: 24),
                
                // Formulaire
                _buildTextField(
                  controller: _nomController,
                  label: 'Nom',
                  hint: 'Votre nom de famille',
                  icon: Icons.person_outline,
                  validator: (value) => Validators.name(value, fieldName: 'Le nom'),
                ),
                const SizedBox(height: 16),
                
                _buildTextField(
                  controller: _prenomController,
                  label: 'Prénom',
                  hint: 'Votre prénom',
                  icon: Icons.person,
                  validator: (value) => Validators.name(value, fieldName: 'Le prénom'),
                ),
                const SizedBox(height: 16),
                
                _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'votre.email@example.com',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                ),
                const SizedBox(height: 16),
                
                _buildPasswordField(
                  controller: _passwordController,
                  label: 'Mot de passe',
                  hint: 'Minimum 8 caractères',
                  obscure: _obscurePassword,
                  onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                  validator: Validators.password,
                ),
                const SizedBox(height: 16),
                
                _buildPasswordField(
                  controller: _confirmPasswordController,
                  label: 'Confirmer le mot de passe',
                  hint: 'Retapez votre mot de passe',
                  obscure: _obscureConfirmPassword,
                  onToggle: () => setState(() => 
                      _obscureConfirmPassword = !_obscureConfirmPassword),
                  validator: (value) => Validators.confirmPassword(
                    value,
                    _passwordController.text,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Bouton d'inscription
                _buildSubmitButton(),
                const SizedBox(height: 16),
                
                // Lien vers connexion
                _buildLoginLink(),
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
          "Inscription",
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Couleur.PremierColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Connectez-vouss à Jur Gui 4.0",
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }


  Widget _buildRoleSelection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue[200]!, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '👤 Je suis :',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildRoleCard(
                  role: 'eleveur',
                  titre: '🐑 Éleveur',
                  description: 'Gérer mon troupeau',
                  icon: Icons.agriculture,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildRoleCard(
                  role: 'veterinaire',
                  titre: '⚕️ Vétérinaire',
                  description: 'Soigner les animaux',
                  icon: Icons.medical_services,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard({
    required String role,
    required String titre,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _roleSelectionne == role;
    
    return GestureDetector(
      onTap: () => setState(() => _roleSelectionne = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 3 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(
              titre,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.center,
            ),
            if (isSelected) ...[
              const SizedBox(height: 8),
              Icon(Icons.check_circle, color: color, size: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Couleur.PremierColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(Icons.lock_outline, color: Couleur.PremierColor),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey[600],
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _signUp,
        style: ElevatedButton.styleFrom(
          backgroundColor: Couleur.PremierColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
                'S\'inscrire',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Vous avez déjà un compte ?'),
        const SizedBox(width: 4),
        TextButton(
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const Connexion()),
          ),
          child: const Text(
            'Se connecter',
            style: TextStyle(fontWeight: FontWeight.bold,color:Colors.red ),
          ),
        ),
      ],
    );
  }
}