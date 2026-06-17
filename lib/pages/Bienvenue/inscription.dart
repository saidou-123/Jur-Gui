/*

// ============================================================
// PAGE D'INSCRIPTION — Éleveur + Vétérinaire (champs complets)
// Fichier: lib/pages/Bienvenue/inscription.dart
//
// MODIFICATIONS vs version précédente :
//   ✅ Champs vétérinaire ajoutés : CNOVS, région, diplôme, établissement
//   ✅ Upload photo carte professionnelle (image_picker + Supabase Storage)
//   ✅ Affichage conditionnel des champs vétérinaire selon le rôle choisi
//   ✅ Statut 'pending_verification' inséré dans users pour les vétérinaires
//   ✅ Création du profil dans veterinaires_profils
//   ✅ Journalisation dans audit_logs à la création du compte
//   ✅ Message de succès adapté selon le rôle (mention vérification pour vétérinaires)
//   ✅ Tous les widgets communs conservés à l'identique
// ============================================================

import 'dart:io';

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
  final _formKey   = GlobalKey<FormState>();
  final _supabase  = Supabase.instance.client;
  final _picker    = ImagePicker();

  // ── Controllers communs ─────────────────────────────────────
  final _nomController              = TextEditingController();
  final _prenomController           = TextEditingController();
  final _emailController            = TextEditingController();
  final _passwordController         = TextEditingController();
  final _confirmPasswordController  = TextEditingController();

  // ── Controllers vétérinaire ─────────────────────────────────
  final _cnovsController          = TextEditingController();
  final _regionController         = TextEditingController();
  final _diplomeController        = TextEditingController();
  final _etablissementController  = TextEditingController();

  // ── État ────────────────────────────────────────────────────
  bool    _isLoading              = false;
  bool    _obscurePassword        = true;
  bool    _obscureConfirmPassword = true;
  String? _roleSelectionne;
  File?   _photoCartePro;

  // ============================================================
  // DISPOSE
  // ============================================================
  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _cnovsController.dispose();
    _regionController.dispose();
    _diplomeController.dispose();
    _etablissementController.dispose();
    super.dispose();
  }

  // ============================================================
  // PHOTO — sélection depuis la galerie
  // ============================================================
  Future<void> _choisirPhoto() async {
    try {
      final picked = await _picker.pickImage(
        source:       ImageSource.gallery,
        maxWidth:     1024,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => _photoCartePro = File(picked.path));
      }
    } catch (e) {
      if (mounted) ErrorHandler.show(context, 'Impossible d\'accéder à la galerie : $e');
    }
  }

  // ============================================================
  // UPLOAD photo vers Supabase Storage
  // Retourne l'URL publique ou null si pas de photo.
  // ============================================================
  Future<String?> _uploadPhoto(String userId) async {
    if (_photoCartePro == null) return null;

    try {
      final ext  = _photoCartePro!.path.split('.').last.toLowerCase();
      final path = 'cartes_pro/$userId.$ext';

      await _supabase.storage
          .from('veterinaires')
          .upload(
            path,
            _photoCartePro!,
            fileOptions: const FileOptions(upsert: true),
          );

      return _supabase.storage.from('veterinaires').getPublicUrl(path);
    } catch (e) {
      // L'upload a échoué — on continue sans la photo (non bloquant)
      debugPrint('⚠️ Upload photo échoué : $e');
      return null;
    }
  }

  // ============================================================
  // INSCRIPTION
  // ============================================================
  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (_roleSelectionne == null) {
      ErrorHandler.show(context, 'Veuillez sélectionner votre rôle (Éleveur ou Vétérinaire)');
      return;
    }

    if (_roleSelectionne == 'veterinaire' && _photoCartePro == null) {
      ErrorHandler.show(context, 'Veuillez ajouter la photo de votre carte professionnelle');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Sanitiser les inputs communs
      final nom    = Validators.sanitize(_nomController.text);
      final prenom = Validators.sanitize(_prenomController.text);
      final email  = _emailController.text.trim().toLowerCase();

      // 2. Créer le compte Auth Supabase
      final response = await _supabase.auth.signUp(
        email:    email,
        password: _passwordController.text,
        data: {
          'nom':        nom,
          'prenom':     prenom,
          'role':       _roleSelectionne,
          'nom_complet': '$prenom $nom',
        },
      );

      if (response.user == null) {
        throw Exception('La création du compte a échoué. Vérifiez vos informations.');
      }

      final userId = response.user!.id;
      debugPrint('✅ Auth créé : $userId');

      // 3. Insérer dans la table users
      await _supabase.from('users').upsert({
        'id':         userId,
        'email':      email,
        'nom':        nom,
        'prenom':     prenom,
        'role':       _roleSelectionne,
        'nom_complet': '$prenom $nom',
        // Les éleveurs n'ont pas de statut de validation
        // Les vétérinaires commencent à pending_verification
        if (_roleSelectionne == 'veterinaire')
          'statut': 'pending_verification',
      });

      debugPrint('✅ Profil users créé');

      // 4. Si vétérinaire : profil professionnel + photo
      if (_roleSelectionne == 'veterinaire') {
        final photoUrl = await _uploadPhoto(userId);

        await _supabase.from('veterinaires_profils').upsert({
          'user_id':            userId,
          'numero_ordre_cnovs': Validators.sanitize(_cnovsController.text),
          'region_exercice':    Validators.sanitize(_regionController.text),
          'diplome':            Validators.sanitize(_diplomeController.text),
          'etablissement':      Validators.sanitize(_etablissementController.text),
          if (photoUrl != null) 'photo_carte_url': photoUrl,
        });

        debugPrint('✅ Profil vétérinaire créé');
      }

      // 5. Journaliser la création de compte
      await _supabase.from('audit_logs').insert({
        'user_id': userId,
        'action':  'account_created',
        'details': {
          'role':  _roleSelectionne,
          'email': email,
        },
      });

      debugPrint('✅ Log account_created enregistré');

      if (mounted) await _showSuccessDialog();
    } catch (error, stackTrace) {
      ErrorHandler.log(
        error,
        stackTrace,
        context: 'Inscription utilisateur',
        additionalData: {
          'email': _emailController.text,
          'role':  _roleSelectionne,
        },
      );
      if (mounted) ErrorHandler.show(context, error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // DIALOGUE DE SUCCÈS — adapté selon le rôle
  // ============================================================
  Future<void> _showSuccessDialog() async {
    final isVet = _roleSelectionne == 'veterinaire';

    return showDialog(
      context:            context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon:  const Icon(Icons.check_circle, color: Colors.green, size: 64),
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

            // Bandeau vérification email (commun)
            _buildInfoBanner(
              icon:  Icons.email,
              color: Colors.blue,
              text:  'Vérifiez votre email pour confirmer votre compte.',
            ),

            // Bandeau vérification vétérinaire (uniquement pour vétérinaires)
            if (isVet) ...[
              const SizedBox(height: 12),
              _buildInfoBanner(
                icon:  Icons.hourglass_empty,
                color: Colors.orange,
                text:  'Votre dossier sera examiné par notre équipe. '
                       'Vous recevrez une notification dès validation.',
              ),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const Connexion()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Se connecter'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner({
    required IconData icon,
    required Color    color,
    required String   text,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: color, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD PRINCIPAL
  // ============================================================
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
                  // ── En-tête ──────────────────────────────────
                  _buildLogo(),
                  const SizedBox(height: 16),
                  _buildHeader(),
                  const SizedBox(height: 32),

                  // ── Sélection du rôle ─────────────────────────
                  _buildRoleSelection(),
                  const SizedBox(height: 24),

                  // ── Champs communs ────────────────────────────
                  _buildTextField(
                    controller: _nomController,
                    label:      'Nom',
                    hint:       'Votre nom de famille',
                    icon:       Icons.person_outline,
                    validator:  (v) => Validators.name(v, fieldName: 'Le nom'),
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _prenomController,
                    label:      'Prénom',
                    hint:       'Votre prénom',
                    icon:       Icons.person,
                    validator:  (v) => Validators.name(v, fieldName: 'Le prénom'),
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller:   _emailController,
                    label:        'Email',
                    hint:         'votre.email@example.com',
                    icon:         Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator:    Validators.email,
                  ),
                  const SizedBox(height: 16),

                  _buildPasswordField(
                    controller: _passwordController,
                    label:      'Mot de passe',
                    hint:       'Minimum 8 caractères',
                    obscure:    _obscurePassword,
                    onToggle:   () => setState(() => _obscurePassword = !_obscurePassword),
                    validator:  Validators.password,
                  ),
                  const SizedBox(height: 16),

                  _buildPasswordField(
                    controller: _confirmPasswordController,
                    label:      'Confirmer le mot de passe',
                    hint:       'Retapez votre mot de passe',
                    obscure:    _obscureConfirmPassword,
                    onToggle:   () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
                    validator: (v) =>
                        Validators.confirmPassword(v, _passwordController.text),
                  ),

                  // ── Champs spécifiques vétérinaire ────────────
                  // Affichés uniquement quand le rôle vétérinaire est sélectionné.
                  // AnimatedSize évite un saut brutal lors de l'apparition.
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve:    Curves.easeInOut,
                    child: _roleSelectionne == 'veterinaire'
                        ? _buildVetSection()
                        : const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 32),

                  // ── Bouton d'inscription ──────────────────────
                  _buildSubmitButton(),
                  const SizedBox(height: 16),

                  // ── Lien vers connexion ───────────────────────
                  _buildLoginLink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SECTION VÉTÉRINAIRE
  // ============================================================
  Widget _buildVetSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        
        const SizedBox(height: 16),

        // Numéro d'ordre CNOVS
        _buildTextField(
          controller: _cnovsController,
          label:      'Numéro d\'ordre CNOVS',
          hint:       'Votre numéro d\'ordre national',
          icon:       Icons.badge_outlined,
          validator:  (v) => (v == null || v.trim().isEmpty)
              ? 'Le numéro d\'ordre CNOVS est requis'
              : null,
        ),
        const SizedBox(height: 16),

        // Région / Zone d'exercice
        _buildTextField(
          controller: _regionController,
          label:      'Région / Zone d\'exercice',
          hint:       'Ex: Dakar, Thiès, Saint-Louis...',
          icon:       Icons.location_on_outlined,
          validator:  (v) => (v == null || v.trim().isEmpty)
              ? 'La région d\'exercice est requise'
              : null,
        ),
        const SizedBox(height: 16),

        // Diplôme obtenu
        _buildTextField(
          controller: _diplomeController,
          label:      'Diplôme obtenu',
          hint:       'Ex: Doctorat vétérinaire',
          icon:       Icons.school_outlined,
          validator:  (v) => (v == null || v.trim().isEmpty)
              ? 'Le diplôme est requis'
              : null,
        ),
        const SizedBox(height: 16),

        // Établissement de formation
        _buildTextField(
          controller: _etablissementController,
          label:      'Établissement de formation',
          hint:       'Ex: EISMV de Dakar',
          icon:       Icons.apartment_outlined,
          validator:  (v) => (v == null || v.trim().isEmpty)
              ? 'L\'établissement de formation est requis'
              : null,
        ),
        const SizedBox(height: 16),

        // Upload photo carte professionnelle
        _buildPhotoUpload(),
      ],
    );
  }

  // ============================================================
  // UPLOAD PHOTO — widget de sélection
  // ============================================================
  Widget _buildPhotoUpload() {
    final hasPhoto = _photoCartePro != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(Icons.photo_camera_outlined,
                  size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                'Photo de la carte professionnelle *',
                style: TextStyle(
                  fontSize:   13,
                  fontWeight: FontWeight.w600,
                  color:      Colors.grey[700],
                ),
              ),
            ],
          ),
        ),

        // Zone de dépôt / aperçu
        GestureDetector(
          onTap: _choisirPhoto,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width:  double.infinity,
            height: 140,
            decoration: BoxDecoration(
              color: hasPhoto ? Colors.green[50] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasPhoto ? Colors.green : Colors.grey[400]!,
                width: hasPhoto ? 2 : 1.5,
              ),
            ),
            child: hasPhoto
                ? _buildPhotoPreview()
                : _buildPhotoPlaceholder(),
          ),
        ),

        // Bouton de remplacement si photo déjà choisie
        if (hasPhoto) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _choisirPhoto,
            icon:  const Icon(Icons.refresh, size: 16),
            label: const Text('Changer la photo'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue[700],
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPhotoPreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Aperçu de l'image
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(_photoCartePro!, fit: BoxFit.cover),
        ),
        // Badge de confirmation
        Positioned(
          top:   8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size:  40,
          color: Colors.grey[400],
        ),
        const SizedBox(height: 10),
        Text(
          'Appuyez pour sélectionner une photo',
          style: TextStyle(
            color:    Colors.grey[600],
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'JPG, PNG — max 5 Mo',
          style: TextStyle(
            color:    Colors.grey[400],
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // WIDGETS RÉUTILISÉS — inchangés par rapport à la version précédente
  // ============================================================

  Widget _buildLogo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Couleur.PremierColor.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Image.asset(
        'assets/image/app_icon.png',
        width:  120,
        height: 120,
        errorBuilder: (_, __, ___) => Icon(
          Icons.pets,
          size:  80,
          color: Couleur.PremierColor,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          'Inscription',
          style: TextStyle(
            fontSize:   32,
            fontWeight: FontWeight.bold,
            color:      Couleur.PremierColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Connectez-vous à Jur Gui',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildRoleSelection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: Colors.blue[200]!, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '👤 Je suis :',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildRoleCard(
                  role:        'eleveur',
                  titre:       '🐑 Éleveur',
                  description: 'Gérer mon troupeau',
                  icon:        Icons.person,
                  color:       Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildRoleCard(
                  role:        'veterinaire',
                  titre:       '⚕️ Vétérinaire',
                  description: 'Soigner les animaux',
                  icon:        Icons.medical_services,
                  color:       Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard({
    required String   role,
    required String   titre,
    required String   description,
    required IconData icon,
    required Color    color,
  }) {
    final isSelected = _roleSelectionne == role;

    return GestureDetector(
      onTap: () => setState(() => _roleSelectionne = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:  const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:        isSelected ? color.withOpacity(0.2) : Colors.white,
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
                color:      color,
                fontSize:   14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style:     const TextStyle(fontSize: 11),
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
    required TextEditingController       controller,
    required String                      label,
    required String                      hint,
    required IconData                    icon,
    TextInputType?                       keyboardType,
    String? Function(String?)?           validator,
  }) {
    return TextFormField(
      controller:   controller,
      keyboardType: keyboardType,
      validator:    validator,
      decoration: InputDecoration(
        labelText:  label,
        hintText:   hint,
        prefixIcon: Icon(icon, color: Couleur.PremierColor),
        border:     OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled:     true,
        fillColor:  Colors.grey[50],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController     controller,
    required String                    label,
    required String                    hint,
    required bool                      obscure,
    required VoidCallback              onToggle,
    String? Function(String?)?         validator,
  }) {
    return TextFormField(
      controller:  controller,
      obscureText: obscure,
      validator:   validator,
      decoration: InputDecoration(
        labelText:  label,
        hintText:   hint,
        prefixIcon: Icon(Icons.lock_outline, color: Couleur.PremierColor),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey[600],
          ),
          onPressed: onToggle,
        ),
        border:    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled:    true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width:  double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _signUp,
        style: ElevatedButton.styleFrom(
          backgroundColor:          Couleur.PremierColor,
          foregroundColor:          Colors.white,
          disabledBackgroundColor:  Colors.grey[300],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width:  24,
                height: 24,
                child: CircularProgressIndicator(
                  color:       Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'S\'inscrire',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
            MaterialPageRoute(builder: (_) => const Connexion()),
          ),
          child: const Text(
            'Se connecter',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          ),
        ),
      ],
    );
  }
}

*/

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