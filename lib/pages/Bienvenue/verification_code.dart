// ============================================================
// ÉCRAN DE VÉRIFICATION DU CODE (6 chiffres) après inscription
// Fichier: lib/pages/Bienvenue/verification_code.dart
//
// Flux :
// 1. L'utilisateur reçoit un code à 6 chiffres par email (valable 5 min)
// 2. Il le saisit ici -> supabase.auth.verifyOTP(type: signup)
// 3. Une fois vérifié -> on déclenche l'email/push "compte en attente
//    de validation admin (72h)" puis on redirige vers la connexion.
// ============================================================

import 'dart:async';

import 'package:depart/Eleveures/New/Notification/NotificationService.dart';
import 'package:depart/pages/Bienvenue/connexion.dart';
import 'package:depart/securite/ErrorHandler.dart';
import 'package:depart/widgets/couleur.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VerificationCodePage extends StatefulWidget {
  final String email;
  final String userId;
  final String role;

  const VerificationCodePage({
    super.key,
    required this.email,
    required this.userId,
    required this.role,
  });

  @override
  State<VerificationCodePage> createState() => _VerificationCodePageState();
}

class _VerificationCodePageState extends State<VerificationCodePage> {
  final _supabase = Supabase.instance.client;
  final _codeController = TextEditingController();
  final _focusNode = FocusNode();

  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;

  // Compte à rebours avant de pouvoir renvoyer un code (évite le spam)
  static const int _resendCooldownSeconds = 60;
  int _secondsRestants = _resendCooldownSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _demarrerCompteARebours();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _demarrerCompteARebours() {
    _secondsRestants = _resendCooldownSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRestants <= 0) {
        timer.cancel();
      } else {
        setState(() => _secondsRestants--);
      }
    });
  }

  // ===== VÉRIFIER LE CODE =====
  Future<void> _verifierCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Le code doit contenir 6 chiffres.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      await _supabase.auth.verifyOTP(
        email: widget.email,
        token: code,
        type: OtpType.signup,
      );

      if (!mounted) return;

      // ✅ Code validé -> déclenche l'email/push "compte en attente (72h)"
      // Non bloquant : si ça échoue, l'inscription reste valide.
      try {
        final session = _supabase.auth.currentSession;
        if (session != null) {
          await _supabase.functions.invoke(
            'notifier-statut-veterinaire',
            body: {'user_id': widget.userId, 'event': 'inscription'},
            headers: {'Authorization': 'Bearer ${session.accessToken}'},
          );
          debugPrint('✅ Email "en cours de vérification (72h)" déclenché');
        }
      } catch (e) {
        debugPrint('⚠️ Envoi email inscription échoué (non bloquant) : $e');
      }

      // ✅ Notification locale/push équivalente
      try {
        await NotificationService().notifierInscriptionEnAttenteConfirmation(
          userId: widget.userId,
        );
      } catch (e) {
        debugPrint('⚠️ Notification échouée (non bloquant) : $e');
      }

      if (!mounted) return;
      await _afficherSucces();
    } on AuthException catch (e) {
      final estExpire = e.message.toLowerCase().contains('expired');
      setState(() {
        _errorMessage = estExpire
            ? 'Ce code a expiré. Demandez-en un nouveau ci-dessous.'
            : 'Code invalide. Vérifiez et réessayez.';
      });
    } catch (e) {
      setState(() => _errorMessage = 'Une erreur est survenue : $e');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  // ===== RENVOYER LE CODE =====
  Future<void> _renvoyerCode() async {
    if (_secondsRestants > 0 || _isResending) return;

    setState(() => _isResending = true);
    try {
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );
      if (mounted) {
        _codeController.clear();
        setState(() => _errorMessage = null);
        _demarrerCompteARebours();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nouveau code envoyé ✅')),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.show(context, 'Impossible de renvoyer le code : $e');
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  // ===== SUCCÈS =====
  Future<void> _afficherSucces() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        title: const Text(
          '✅ Email confirmé !',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange[200]!, width: 2),
          ),
          child: const Row(
            children: [
              Icon(Icons.hourglass_top_rounded, color: Colors.orange),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Votre compte est maintenant en attente de validation '
                  'par notre équipe (délai habituel : jusqu\'à 72h).',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const Connexion()),
                (route) => false,
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 241, 248, 233),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Icon(Icons.mark_email_read_outlined,
                  size: 64, color: Couleur.PremierColor),
              const SizedBox(height: 24),
              const Text(
                'Vérifiez votre email',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  text: 'Entrez le code à 6 chiffres envoyé à ',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                  children: [
                    TextSpan(
                      text: widget.email,
                      style: const TextStyle(
                          color: Colors.black87, fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: '. Il expire dans 5 minutes.'),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Champ de saisie du code
              TextField(
                controller: _codeController,
                focusNode: _focusNode,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(fontSize: 28, letterSpacing: 12),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••••',
                  errorText: _errorMessage,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Couleur.PremierColor, width: 2),
                  ),
                ),
                onChanged: (value) {
                  if (_errorMessage != null) {
                    setState(() => _errorMessage = null);
                  }
                  if (value.length == 6) _verifierCode();
                },
              ),
              const SizedBox(height: 24),

              // Bouton valider
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _verifierCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Couleur.PremierColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Confirmer',
                          style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 20),

              // Renvoyer le code
              Center(
                child: _secondsRestants > 0
                    ? Text(
                        'Renvoyer le code dans ${_secondsRestants}s',
                        style: const TextStyle(color: Colors.grey),
                      )
                    : TextButton(
                        onPressed: _isResending ? null : _renvoyerCode,
                        child: _isResending
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Text('Renvoyer le code'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}