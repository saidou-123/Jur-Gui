// ============================================================
// ÉCRAN — VÉTÉRINAIRE REJETÉ
// Fichier: lib/pages/Interface/VetRejectedPage.dart
//
// Affiché quand statut == 'rejected'.
// Informe l'utilisateur du rejet, fournit le contact support,
// et permet de se déconnecter.
// Aucun rappel supplémentaire ne sera envoyé (règle métier).
// ============================================================

import 'package:depart/pages/Bienvenue/connexion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VetRejectedPage extends StatelessWidget {
  const VetRejectedPage({super.key});

  static const _emailSupport = 'support@jurgui.sn';

  Future<void> _seDeconnecter(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const Connexion()),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Erreur déconnexion : $e');
    }
  }

  void _copierEmail(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: _emailSupport));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Email copié dans le presse-papier'),
          ],
        ),
        backgroundColor: Colors.green[700],
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Column(
            children: [
              // ── Barre supérieure ────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _seDeconnecter(context),
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Déconnexion'),
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[600]),
                  ),
                ],
              ),

              const Spacer(),

              // ── Icône ───────────────────────────────────────
              Container(
                width:  120,
                height: 120,
                decoration: BoxDecoration(
                  color:  Colors.red[50],
                  shape:  BoxShape.circle,
                  border: Border.all(color: Colors.red[200]!, width: 2),
                ),
                child: Icon(
                  Icons.gpp_bad_outlined,
                  size:  56,
                  color: Colors.red[600],
                ),
              ),

              const SizedBox(height: 32),

              // ── Titre ───────────────────────────────────────
              Text(
                'Dossier non retenu',
                style: TextStyle(
                  fontSize:   24,
                  fontWeight: FontWeight.bold,
                  color:      Colors.red[900],
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              // ── Explication ─────────────────────────────────
              Text(
                'Votre demande d\'inscription en tant que vétérinaire '
                'n\'a pas pu être approuvée après examen de votre dossier.',
                style: TextStyle(
                  fontSize: 15,
                  color:    Colors.grey[700],
                  height:   1.6,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // ── Raisons possibles ───────────────────────────
              _buildRaisonsTile(context),

              const SizedBox(height: 24),

              // ── Contact support ─────────────────────────────
              _buildContactSupport(context),

              const Spacer(),

              // ── Bouton déconnexion ──────────────────────────
              SizedBox(
                width:  double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => _seDeconnecter(context),
                  icon:  const Icon(Icons.logout_rounded),
                  label: const Text('Se déconnecter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Raisons possibles ──────────────────────────────────────
  Widget _buildRaisonsTile(BuildContext context) {
    const raisons = [
      (Icons.badge_outlined,         'Numéro CNOVS non reconnu'),
      (Icons.photo_outlined,         'Photo de carte illisible ou invalide'),
      (Icons.description_outlined,   'Documents incomplets'),
    ];

    return Container(
      decoration: BoxDecoration(
        color:        Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: Colors.red[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              'Raisons fréquentes de rejet',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize:   13,
                color:      Colors.red[800],
              ),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ...raisons.map(
            (r) => Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(r.$1, size: 18, color: Colors.red[400]),
                  const SizedBox(width: 12),
                  Text(
                    r.$2,
                    style: TextStyle(
                        fontSize: 13, color: Colors.red[900]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Contact support ────────────────────────────────────────
  Widget _buildContactSupport(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contactez notre support',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize:   13,
              color:      Colors.grey[800],
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onLongPress: () => _copierEmail(context),
            child: Row(
              children: [
                Icon(Icons.email_outlined,
                    size: 18, color: Colors.grey[600]),
                const SizedBox(width: 10),
                Text(
                  _emailSupport,
                  style: TextStyle(
                    fontSize:  14,
                    color:     Colors.blue[700],
                    decoration: TextDecoration.underline,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _copierEmail(context),
                  child: Icon(Icons.copy_outlined,
                      size: 16, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Appuyez longuement sur l\'email pour le copier.',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
