// ============================================================
// PAGE D'INSCRIPTION - VERSION OPTIMISÉE
// Fichier: lib/pages/inscription.dart
// ============================================================

import 'dart:io';

import 'package:depart/Eleveures/New/Notification/NotificationService.dart';
import 'package:depart/pages/Bienvenue/connexion.dart';
import 'package:depart/securite/ErrorHandler.dart';
import 'package:depart/securite/Validators.dart';
import 'package:depart/widgets/couleur.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Inscription extends StatefulWidget {
  const Inscription({super.key});

  @override
  State<Inscription> createState() => _InscriptionState();
}

class _InscriptionState extends State<Inscription> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  final _picker = ImagePicker();

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
  File? _photoCartePro;

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ============================================================
  // PHOTO — sélection depuis la galerie (carte professionnelle vétérinaire)
  // ============================================================
  Future<void> _choisirPhoto() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => _photoCartePro = File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.show(context, 'Impossible d\'accéder à la galerie : $e');
      }
    }
  }

  // ============================================================
  // UPLOAD photo vers le bucket privé Supabase "documents-pro"
  // Convention de chemin : {user_id}/carte_pro.{ext}
  // Retourne le CHEMIN du fichier (pas une URL publique, car le bucket
  // est privé) ou null si pas de photo / échec non bloquant.
  // ============================================================
  Future<String?> _uploadPhoto(String userId) async {
    if (_photoCartePro == null) return null;

    try {
      final ext = _photoCartePro!.path.split('.').last.toLowerCase();
      final path = '$userId/carte_pro.$ext';

      await _supabase.storage.from('documents-pro').upload(
            path,
            _photoCartePro!,
            fileOptions: const FileOptions(upsert: true),
          );

      debugPrint('✅ Photo carte pro uploadée : $path');
      return path;
    } catch (e) {
      // L'upload a échoué — on continue l'inscription sans la photo
      // (non bloquant : mieux vaut un compte en attente sans photo
      // qu'un blocage total de l'inscription).
      debugPrint('⚠️ Upload photo échoué : $e');
      return null;
    }
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

    if (_roleSelectionne == 'veterinaire' && _photoCartePro == null) {
      ErrorHandler.show(
        context,
        'Veuillez ajouter la photo de votre carte professionnelle',
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
        final userId = response.user!.id;

        // ✅ Si vétérinaire : upload de la photo + enregistrement du chemin
        if (_roleSelectionne == 'veterinaire') {
          final photoPath = await _uploadPhoto(userId);
          if (photoPath != null) {
            await _supabase
                .from('users')
                .update({'photo_carte_pro_url': photoPath})
                .eq('id', userId);
            debugPrint('✅ photo_carte_pro_url enregistré');
          }

          // ✅ Déclenche l'email "dossier en cours de vérification (72h)"
          // Non bloquant : si ça échoue, l'inscription reste valide,
          // le vétérinaire verra simplement la page d'attente dans l'app.
          try {
            final session = _supabase.auth.currentSession;
            if (session != null) {
              await _supabase.functions.invoke(
                'notifier-statut-veterinaire',
                body: {'user_id': userId, 'event': 'inscription'},
                headers: {'Authorization': 'Bearer ${session.accessToken}'},
              );
              debugPrint('✅ Email "en cours de vérification" déclenché');
            }
          } catch (e) {
            debugPrint('⚠️ Envoi email inscription échoué (non bloquant) : $e');
          }
        }

        // ✅ Notification locale + push : "confirmez votre email"
        // S'applique à tous les rôles (éleveur et vétérinaire).
        // Non bloquant : l'inscription reste valide même si ça échoue.
        try {
          await NotificationService().notifierInscriptionEnAttenteConfirmation(
            userId: userId,
          );
        } catch (e) {
          debugPrint('⚠️ Notification confirmation email échouée (non bloquant) : $e');
        }

        // ✅ Succès
        await _showSuccessDialog();
      }
    } catch (error, stackTrace) {
      // ✅ Cas spécial : email déjà utilisé → dialogue dédié plus clair
      final isEmailTaken = error.toString().contains('already registered') ||
          error.toString().contains('already been registered') ||
          error.toString().contains('422') ||
          (error.runtimeType.toString().contains('AuthApiException') &&
              error.toString().contains('already'));

      if (isEmailTaken && mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            icon: const Icon(Icons.email_outlined,
                color: Colors.orange, size: 56),
            title: const Text(
              'Email déjà utilisé',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text(
              'Un compte existe déjà avec cette adresse email.\n\n'
              'Vous pouvez modifier votre email et réessayer, '
              'ou vous connecter si ce compte est le vôtre.',
              textAlign: TextAlign.center,
            ),
            actions: [
              // Bouton : modifier l'email (retour au formulaire)
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Met le focus sur le champ email pour correction facile
                  _emailController.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _emailController.text.length,
                  );
                },
                child: const Text('Changer l\'email'),
              ),
              // Bouton : aller se connecter
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                        builder: (context) => const Connexion()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Couleur.PremierColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Se connecter'),
              ),
            ],
          ),
        );
        return;
      }

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

                // Photo de carte professionnelle (vétérinaire uniquement)
                if (_roleSelectionne == 'veterinaire') ...[
                  _buildPhotoCartePro(),
                  const SizedBox(height: 24),
                ],

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
          "Connectez-vous à Jur Gui 4.0",
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

  // ============================================================
  // PHOTO DE CARTE PROFESSIONNELLE (vétérinaire uniquement)
  // ============================================================
  Widget _buildPhotoCartePro() {
    final hasPhoto = _photoCartePro != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange[200]!, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📋 Carte professionnelle',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Votre compte sera vérifié manuellement avant validation '
            '(délai habituel : jusqu\'à 72h).',
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _choisirPhoto,
            child: Container(
              height: hasPhoto ? 180 : 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasPhoto ? Colors.green : Colors.orange[300]!,
                  width: 2,
                ),
              ),
              child: hasPhoto
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(_photoCartePro!, fit: BoxFit.cover),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              radius: 16,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.edit,
                                    color: Colors.white, size: 16),
                                onPressed: _choisirPhoto,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined,
                            size: 36, color: Colors.orange[400]),
                        const SizedBox(height: 8),
                        Text(
                          'Ajouter une photo',
                          style: TextStyle(color: Colors.orange[700]),
                        ),
                      ],
                    ),
            ),
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