// ============================================================
// GESTIONNAIRE D'ERREURS CENTRALISÉ - VERSION CORRIGÉE
// Fichier: lib/utils/error_handler.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorHandler {
  // ===== CONVERTIR ERREUR EN MESSAGE UTILISATEUR =====
  static String getMessage(dynamic error) {
    // Erreurs d'authentification
    if (error is AuthException) {
      return _handleAuthException(error);
    }
    
    // Erreurs de base de données
    if (error is PostgrestException) {
      return _handlePostgrestException(error);
    }
    
    // Erreurs de stockage
    if (error is StorageException) {
      return _handleStorageException(error);
    }
    
    // Erreurs réseau
    if (error.toString().contains('SocketException') ||
        error.toString().contains('HandshakeException')) {
      return 'Pas de connexion Internet. Vérifiez votre réseau.';
    }
    
    // Timeout
    if (error.toString().contains('TimeoutException')) {
      return 'Délai d\'attente dépassé. Réessayez.';
    }
    
    // Erreur générique
    return 'Une erreur est survenue. Réessayez.';
  }

  // ===== ERREURS AUTHENTIFICATION =====
  static String _handleAuthException(AuthException error) {
    switch (error.statusCode) {
      case '400':
        if (error.message.contains('Invalid login credentials')) {
          return 'Email ou mot de passe incorrect';
        }
        if (error.message.contains('Email not confirmed')) {
          return 'Email non confirmé. Vérifiez votre boîte mail.';
        }
        return 'Données invalides';
      
      case '422':
        if (error.message.contains('already registered')) {
          return 'Cet email est déjà utilisé';
        }
        return 'Email déjà utilisé';
      
      case '429':
        return 'Trop de tentatives. Attendez quelques minutes.';
      
      case '401':
        return 'Session expirée. Reconnectez-vous.';
      
      default:
        return error.message.isNotEmpty 
            ? error.message 
            : 'Erreur d\'authentification';
    }
  }

  // ===== ERREURS BASE DE DONNÉES =====
  static String _handlePostgrestException(PostgrestException error) {
    final code = error.code ?? '';
    
    switch (code) {
      case '23505':
        return 'Cet enregistrement existe déjà';
      
      case '23503':
        return 'Référence invalide';
      
      case '23502':
        return 'Champ obligatoire manquant';
      
      case '22P02':
        return 'Format de données invalide';
      
      case '42P01':
        return 'Erreur de configuration. Contactez le support.';
      
      default:
        return error.message.isNotEmpty
            ? 'Erreur: ${error.message}'
            : 'Erreur de base de données';
    }
  }

  // ===== ERREURS STOCKAGE =====
  static String _handleStorageException(StorageException error) {
    if (error.message.contains('exceeded')) {
      return 'Fichier trop volumineux (max 5MB)';
    }
    
    if (error.message.contains('not found')) {
      return 'Fichier introuvable';
    }
    
    if (error.message.contains('not allowed')) {
      return 'Format de fichier non autorisé';
    }
    
    return 'Erreur de stockage: ${error.message}';
  }

  // ===== LOGGER L'ERREUR =====
  static void log(
    dynamic error,
    StackTrace? stackTrace, {
    String? context,
    Map<String, dynamic>? additionalData,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    
    debugPrint('═══════════════════════════════════════');
    debugPrint('❌ ERREUR [$timestamp]');
    if (context != null) {
      debugPrint('📍 Contexte: $context');
    }
    debugPrint('🔴 Erreur: $error');
    
    if (additionalData != null) {
      debugPrint('📊 Données supplémentaires:');
      additionalData.forEach((key, value) {
        debugPrint('   - $key: $value');
      });
    }
    
    if (stackTrace != null) {
      debugPrint('📚 Stack trace:');
      debugPrint(stackTrace.toString());
    }
    debugPrint('═══════════════════════════════════════');
  }

  // ===== AFFICHER SNACKBAR D'ERREUR =====
  static void show(
    BuildContext context,
    dynamic error, {
    String? customMessage,
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!context.mounted) return;
    
    final message = customMessage ?? getMessage(error);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: duration,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  // ===== AFFICHER SNACKBAR DE SUCCÈS =====
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: duration,
      ),
    );
  }

  // ✅ CORRECTION: Renommé de showDialog en showErrorDialog
  static Future<void> showErrorDialog(
    BuildContext context,
    dynamic error, {
    String? title,
    String? customMessage,
  }) async {
    if (!context.mounted) return;
    
    final message = customMessage ?? getMessage(error);
    
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        icon: Icon(
          Icons.error_outline,
          color: Colors.red[700],
          size: 64,
        ),
        title: Text(
          title ?? 'Erreur',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// ===== WRAPPER DE FONCTION SÉCURISÉE =====
Future<T?> safeExecute<T>({
  required Future<T> Function() operation,
  required BuildContext context,
  String? operationName,
  T? defaultValue,
  bool showError = true,
}) async {
  try {
    return await operation();
  } catch (error, stackTrace) {
    ErrorHandler.log(
      error,
      stackTrace,
      context: operationName,
    );
    
    if (showError && context.mounted) {
      ErrorHandler.show(context, error);
    }
    
    return defaultValue;
  }
}

// ===== EXEMPLES D'UTILISATION =====
/*
// ✅ Méthode 1: Wrapper automatique
final animals = await safeExecute<List<Map<String, dynamic>>>(
  operation: () async {
    return await Supabase.instance.client
        .from('animal_acheter')
        .select();
  },
  context: context,
  operationName: 'Chargement animaux',
  defaultValue: [],
);

// ✅ Méthode 2: Try-catch manuel avec SnackBar
try {
  await Supabase.instance.client
      .from('animal_acheter')
      .insert({'nom': 'Test'});
  
  ErrorHandler.showSuccess(context, '✅ Animal enregistré');
} catch (error, stackTrace) {
  ErrorHandler.log(error, stackTrace, context: 'Enregistrement animal');
  ErrorHandler.show(context, error);
}
*/