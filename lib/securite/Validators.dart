// ============================================================
// UTILITAIRES DE VALIDATION - VERSION COMPLÈTE
// Fichier: lib/utils/validators.dart
// ============================================================

class Validators {
  // ===== VALIDATION EMAIL =====
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email requis';
    }
    
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'
    );
    
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Email invalide';
    }
    
    return null;
  }

  // ===== VALIDATION MOT DE PASSE SÉCURISÉ =====
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Mot de passe requis';
    }
    
    if (value.length < 8) {
      return 'Minimum 8 caractères';
    }
    
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Au moins une majuscule requise';
    }
    
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Au moins une minuscule requise';
    }
    
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Au moins un chiffre requis';
    }
    
    return null;
  }

  // ===== VALIDATION NOM/PRÉNOM =====
  static String? name(String? value, {String fieldName = 'Ce champ'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName est requis';
    }
    
    final trimmed = value.trim();
    
    if (trimmed.length < 2) {
      return '$fieldName trop court (min. 2 caractères)';
    }
    
    if (trimmed.length > 50) {
      return '$fieldName trop long (max. 50 caractères)';
    }
    
    // Lettres, espaces, tirets, apostrophes, accents
    final nameRegex = RegExp(r"^[a-zA-ZÀ-ÿ\s\-']+$");
    if (!nameRegex.hasMatch(trimmed)) {
      return '$fieldName contient des caractères invalides';
    }
    
    return null;
  }

  // ===== VALIDATION TAG RFID =====
  static String? rfid(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Tag RFID requis';
    }
    
    final trimmed = value.trim().toUpperCase();
    
    // Format RFID: 8-14 caractères hexadécimaux
    if (trimmed.length < 8 || trimmed.length > 14) {
      return 'Format RFID invalide (8-14 caractères)';
    }
    
    final rfidRegex = RegExp(r'^[A-F0-9]+$');
    if (!rfidRegex.hasMatch(trimmed)) {
      return 'RFID invalide (hexadécimal uniquement)';
    }
    
    return null;
  }

  // ===== VALIDATION TEXTE OBLIGATOIRE =====
  static String? required(String? value, {String fieldName = 'Ce champ'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName est requis';
    }
    return null;
  }

  // ===== VALIDATION TEXTE AVEC LONGUEUR =====
  static String? textWithLength(
    String? value, {
    required int min,
    required int max,
    String fieldName = 'Ce champ',
  }) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName est requis';
    }
    
    final length = value.trim().length;
    
    if (length < min) {
      return '$fieldName trop court (min. $min caractères)';
    }
    
    if (length > max) {
      return '$fieldName trop long (max. $max caractères)';
    }
    
    return null;
  }

  // ===== VALIDATION DATE =====
  static String? date(
    DateTime? value, {
    DateTime? minDate,
    DateTime? maxDate,
    String? errorMessage,
  }) {
    if (value == null) {
      return errorMessage ?? 'Date requise';
    }
    
    if (minDate != null && value.isBefore(minDate)) {
      return 'Date trop ancienne';
    }
    
    if (maxDate != null && value.isAfter(maxDate)) {
      return 'Date invalide';
    }
    
    return null;
  }

  // ===== SANITIZATION (Nettoyage) =====
  static String sanitize(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'[<>]'), '') // Bloquer HTML
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '') // Caractères de contrôle
        .replaceAll(RegExp(r'\s+'), ' '); // Espaces multiples
  }

  // ===== VALIDATION NUMÉRO DE TÉLÉPHONE (SÉNÉGAL) =====
  static String? phoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Numéro de téléphone requis';
    }
    
    // Format Sénégal: +221 XX XXX XX XX ou 77/78/70/76/75 XXX XX XX
    final cleaned = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    final senegalRegex = RegExp(r'^(\+221)?(7[05678])\d{7}$');
    
    if (!senegalRegex.hasMatch(cleaned)) {
      return 'Numéro invalide (ex: 77 123 45 67)';
    }
    
    return null;
  }

  // ===== VALIDATION RACE ANIMALE =====
  static String? race(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Race requise';
    }
    
    final validRaces = [
      'ladoum',
      'peulh peulh',
      'touabire',
      'djallonké',
      'maure',
      'azawak',
      'bali-bali',
      'waralé',
    ];
    
    if (!validRaces.contains(value.trim().toLowerCase())) {
      return 'Race non reconnue';
    }
    
    return null;
  }

  // ===== VALIDATION SEXE =====
  static String? sexe(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Sexe requis';
    }
    
    final validSexes = ['mâle', 'femelle', 'male'];
    
    if (!validSexes.contains(value.trim().toLowerCase())) {
      return 'Sexe invalide (Mâle ou Femelle)';
    }
    
    return null;
  }

  // ===== VALIDATION CONFIRMATION MOT DE PASSE =====
  static String? confirmPassword(String? value, String originalPassword) {
    if (value == null || value.isEmpty) {
      return 'Confirmation requise';
    }
    
    if (value != originalPassword) {
      return 'Les mots de passe ne correspondent pas';
    }
    
    return null;
  }
}

// ===== EXEMPLE D'UTILISATION =====
/*
TextFormField(
  decoration: const InputDecoration(labelText: 'Email'),
  validator: Validators.email,
),

TextFormField(
  decoration: const InputDecoration(labelText: 'Nom'),
  validator: (value) => Validators.name(value, fieldName: 'Le nom'),
),

TextFormField(
  decoration: const InputDecoration(labelText: 'Tag RFID'),
  validator: Validators.rfid,
),
*/