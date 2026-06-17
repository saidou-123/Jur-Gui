// ============================================================
// ÉCRAN — VÉTÉRINAIRE EN ATTENTE DE VALIDATION
// Fichier: lib/pages/Interface/VetPendingPage.dart
//
// Affiché quand statut == 'pending_verification'.
// L'utilisateur ne peut rien faire d'autre que se déconnecter
// ou rafraîchir son statut.
// ============================================================

import 'package:depart/pages/Bienvenue/connexion.dart';
import 'package:depart/widgets/couleur.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VetPendingPage extends StatefulWidget {
  const VetPendingPage({super.key});

  @override
  State<VetPendingPage> createState() => _VetPendingPageState();
}

class _VetPendingPageState extends State<VetPendingPage>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  late AnimationController _pulseController;
  late Animation<double>   _pulseAnimation;

  bool _isCheckingStatus = false;

  // Étapes du processus de validation — informe l'utilisateur
  static const _etapes = [
    (Icons.how_to_reg_outlined,    'Dossier reçu',          true),
    (Icons.manage_search_outlined, 'Vérification en cours', true),
    (Icons.verified_outlined,      'Décision finale',       false),
  ];

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ── Vérifier si le statut a changé depuis la dernière connexion ──
  Future<void> _verifierStatut() async {
    setState(() => _isCheckingStatus = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await _supabase
          .from('users')
          .select('statut')
          .eq('id', userId)
          .maybeSingle();

      final statut = data?['statut'] as String?;

      if (!mounted) return;

      if (statut == 'approved') {
        // Le dossier vient d'être approuvé — enregistrer la première connexion
        await _supabase.from('users').update({
          'first_login_after_approval': DateTime.now().toIso8601String(),
        }).eq('id', userId);

        await _supabase.from('audit_logs').insert({
          'user_id': userId,
          'action':  'first_login_after_approval',
          'details': {'source': 'VetPendingPage_refresh'},
        });

        if (!mounted) return;
        _showStatusChangedDialog(approved: true);
      } else if (statut == 'rejected') {
        if (!mounted) return;
        _showStatusChangedDialog(approved: false);
      } else {
        // Toujours en attente
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.hourglass_empty,
                    color: Colors.white, size: 18),
                const SizedBox(width: 10),
                const Text('Votre dossier est toujours en cours d\'examen.'),
              ],
            ),
            backgroundColor: Colors.orange[700],
            behavior:        SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Erreur vérification statut : $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:         Text('Impossible de vérifier le statut.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingStatus = false);
    }
  }

  void _showStatusChangedDialog({required bool approved}) {
    showDialog(
      context:            context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        icon: Icon(
          approved ? Icons.verified : Icons.cancel_outlined,
          color: approved ? Colors.green : Colors.red,
          size: 56,
        ),
        title: Text(
          approved ? 'Dossier approuvé !' : 'Dossier non retenu',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          approved
              ? 'Votre compte vétérinaire est maintenant actif. '
                'Reconnectez-vous pour accéder à toutes les fonctionnalités.'
              : 'Votre dossier n\'a pas pu être validé. '
                'Reconnectez-vous pour voir les détails.',
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _supabase.auth.signOut();
                if (mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const Connexion()),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: approved ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Se reconnecter'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _seDeconnecter() async {
    try {
      await _supabase.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const Connexion()),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Erreur déconnexion : $e');
    }
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
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
                    onPressed: _seDeconnecter,
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Déconnexion'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // ── Icône animée ────────────────────────────────
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width:  120,
                  height: 120,
                  decoration: BoxDecoration(
                    color:  Colors.orange[50],
                    shape:  BoxShape.circle,
                    border: Border.all(
                      color: Colors.orange[200]!,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.hourglass_top_rounded,
                    size:  56,
                    color: Colors.orange[600],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Titre ───────────────────────────────────────
              Text(
                'Dossier en cours d\'examen',
                style: TextStyle(
                  fontSize:   24,
                  fontWeight: FontWeight.bold,
                  color:      Colors.orange[900],
                  height:     1.2,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              // ── Sous-titre ──────────────────────────────────
              Text(
                'Notre équipe vérifie vos informations professionnelles. '
                'Vous recevrez une notification dès que votre dossier sera traité.',
                style: TextStyle(
                  fontSize: 15,
                  color:    Colors.grey[700],
                  height:   1.6,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // ── Indicateur de progression ───────────────────
              _buildProgressIndicator(),

              const SizedBox(height: 40),

              // ── Bouton vérifier le statut ───────────────────
              SizedBox(
                width:  double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isCheckingStatus ? null : _verifierStatut,
                  icon: _isCheckingStatus
                      ? const SizedBox(
                          width:  18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color:       Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(
                    _isCheckingStatus
                        ? 'Vérification...'
                        : 'Vérifier mon statut',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.orange[200],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Message d'information ───────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color:        Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.notifications_outlined,
                        size: 18, color: Colors.blue[700]),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Vous recevrez également un email et une notification '
                        'push dès validation.',
                        style: TextStyle(
                          fontSize: 12,
                          color:    Colors.blue[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Indicateur d'étapes ──────────────────────────────────────
  Widget _buildProgressIndicator() {
    return Row(
      children: List.generate(_etapes.length * 2 - 1, (i) {
        // Index impair = connecteur entre étapes
        if (i.isOdd) {
          final etapeGauche = _etapes[(i - 1) ~/ 2];
          return Expanded(
            child: Container(
              height: 2,
              color: etapeGauche.$3
                  ? Colors.orange[400]
                  : Colors.grey[300],
            ),
          );
        }

        final index = i ~/ 2;
        final etape = _etapes[index];
        final isDone = etape.$3;

        return Column(
          children: [
            Container(
              width:       44,
              height:      44,
              decoration: BoxDecoration(
                color:  isDone
                    ? Colors.orange[100]
                    : Colors.grey[100],
                shape:  BoxShape.circle,
                border: Border.all(
                  color: isDone
                      ? Colors.orange[400]!
                      : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: Icon(
                etape.$1,
                size:  20,
                color: isDone
                    ? Colors.orange[700]
                    : Colors.grey[400],
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 72,
              child: Text(
                etape.$2,
                style: TextStyle(
                  fontSize:   10,
                  fontWeight: isDone
                      ? FontWeight.w600
                      : FontWeight.normal,
                  color: isDone
                      ? Colors.orange[800]
                      : Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        );
      }),
    );
  }
}