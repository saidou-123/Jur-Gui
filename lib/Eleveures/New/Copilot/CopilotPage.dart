// ============================================================
// LADOUM COPILOT PAGE — v2 (Vocal complet)
// Chemin : lib/Eleveures/New/Copilot/CopilotPage.dart
//
// Fonctionnalités :
//   ✅ Écrire une question
//   ✅ Parler (speech_to_text) — appuyer et parler
//   ✅ Réponse lue automatiquement à voix haute (flutter_tts)
//   ✅ Bouton pause/lecture pour relire
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'CopilotService.dart';

class CopilotPage extends StatefulWidget {
  const CopilotPage({super.key});

  @override
  State<CopilotPage> createState() => _CopilotPageState();
}

class _CopilotPageState extends State<CopilotPage>
    with SingleTickerProviderStateMixin {
  // ── Services ──────────────────────────────────────────────
  final _service    = CopilotService();
  final _tts        = FlutterTts();
  final _stt        = stt.SpeechToText();
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();

  // ── État ──────────────────────────────────────────────────
  bool _enChargement  = false;
  bool _enEcoute      = false;
  bool _sttDisponible = false;
  bool _enLecture     = false;
  String _texteReconnu = '';

  static const Color _vert = Color(0xFF1B5E20);

  // ── Questions suggérées ───────────────────────────────────
  static const List<String> _suggestions = [
    "Quelle brebis devrais-je accoupler ce mois-ci ?",
    "Quelles brebis sont prêtes pour l'accouplement ?",
    "Quel est mon taux de fertilité global ?",
    "Quand vont agneler mes brebis gestantes ?",
    "Y a-t-il des alertes sur mon troupeau ?",
    "Quelle est la meilleure période pour accoupler ?",
  ];

  @override
  void initState() {
    super.initState();
    _initTTS();
    _initSTT();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    _tts.stop();
    super.dispose();
  }

  // ── Initialisation TTS (Text-to-Speech) ───────────────────
  Future<void> _initTTS() async {
    await _tts.setLanguage('fr-FR');
    await _tts.setSpeechRate(0.85);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() => setState(() => _enLecture = true));
    _tts.setCompletionHandler(() => setState(() => _enLecture = false));
    _tts.setErrorHandler((_) => setState(() => _enLecture = false));
  }

  // ── Initialisation STT (Speech-to-Text) ───────────────────
  Future<void> _initSTT() async {
    _sttDisponible = await _stt.initialize(
      onError: (e) => setState(() => _enEcoute = false),
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          setState(() => _enEcoute = false);
          if (_texteReconnu.isNotEmpty) {
            _controller.text = _texteReconnu;
            _texteReconnu = '';
          }
        }
      },
    );
    setState(() {});
  }

  // ── Démarrer l'écoute ─────────────────────────────────────
  Future<void> _demarrerEcoute() async {
    if (!_sttDisponible || _enEcoute) return;

    await _tts.stop();

    setState(() {
      _enEcoute    = true;
      _texteReconnu = '';
      _controller.clear();
    });

    await _stt.listen(
      onResult: (result) {
        setState(() {
          _texteReconnu    = result.recognizedWords;
          _controller.text = result.recognizedWords;
        });
      },
      localeId: 'fr_FR',
      cancelOnError: true,
      partialResults: true,
    );
  }

  // ── Arrêter l'écoute et envoyer ───────────────────────────
  Future<void> _arreterEcouteEtEnvoyer() async {
    await _stt.stop();
    setState(() => _enEcoute = false);

    await Future.delayed(const Duration(milliseconds: 300));
    if (_controller.text.trim().isNotEmpty) {
      await _envoyer();
    }
  }

  // ── Envoyer un message ────────────────────────────────────
  Future<void> _envoyer([String? texteForce]) async {
    final texte = (texteForce ?? _controller.text).trim();
    if (texte.isEmpty || _enChargement) return;

    _controller.clear();
    setState(() => _enChargement = true);
    _scrollerEnBas();

    // Arrêter la lecture en cours
    await _tts.stop();

    final reponse = await _service.envoyerMessage(texte);

    if (mounted) {
      setState(() => _enChargement = false);
      _scrollerEnBas();

      // ✅ Lire la réponse automatiquement à voix haute
      await Future.delayed(const Duration(milliseconds: 500));
      await _lireTexte(reponse);
    }
  }

  // ── Lire un texte à voix haute ────────────────────────────
  Future<void> _lireTexte(String texte) async {
    // Nettoyer le markdown avant de lire
    final propre = texte
        .replaceAll(RegExp(r'\*+'), '')
        .replaceAll(RegExp(r'#{1,6} '), '')
        .replaceAll(RegExp(r'\n+'), '. ');

    await _tts.speak(propre);
  }

  // ── Pause / Reprendre la lecture ──────────────────────────
  Future<void> _toggleLecture() async {
    if (_enLecture) {
      await _tts.stop();
      setState(() => _enLecture = false);
    } else {
      // Relire le dernier message assistant
      final dernierAssistant = _service.historique
          .where((m) => m.role == RoleMessage.assistant)
          .lastOrNull;
      if (dernierAssistant != null) {
        await _lireTexte(dernierAssistant.contenu);
      }
    }
  }

  void _scrollerEnBas() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _reinitialiser() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvelle conversation'),
        content: const Text('Effacer l\'historique ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _tts.stop();
              setState(() => _service.reinitialiser());
            },
            child: const Text('Effacer',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final historique = _service.historique;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        backgroundColor: _vert,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.smart_toy_outlined,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ladoum Copilot',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text('Assistant IA élevage',
                    style: TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ],
        ),
        actions: [
          // Bouton pause/lecture
          if (historique.isNotEmpty)
            IconButton(
              icon: Icon(_enLecture
                  ? Icons.stop_circle_outlined
                  : Icons.volume_up_outlined),
              tooltip: _enLecture ? 'Arrêter' : 'Relire',
              onPressed: _toggleLecture,
            ),
          if (historique.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh_outlined),
              tooltip: 'Nouvelle conversation',
              onPressed: _reinitialiser,
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Bannière STT indisponible ──────────────────
          if (!_sttDisponible)
            Container(
              color: Colors.orange.shade100,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.orange, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Microphone non disponible — utilisez le clavier',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),

          // ── Indicateur d'écoute ────────────────────────
          if (_enEcoute)
            Container(
              color: Colors.red.shade50,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _PulseIcon(),
                  const SizedBox(width: 8),
                  const Text(
                    'Je vous écoute... Parlez maintenant',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.red,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

          // ── Messages ───────────────────────────────────
          Expanded(
            child: historique.isEmpty
                ? _buildEtatVide()
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 12),
                    itemCount:
                        historique.length + (_enChargement ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == historique.length && _enChargement) {
                        return _BulleChargement();
                      }
                      return _BulleMessage(
                        message: historique[i],
                        couleurPrimaire: _vert,
                        onRelire: historique[i].role ==
                                RoleMessage.assistant
                            ? () => _lireTexte(historique[i].contenu)
                            : null,
                      );
                    },
                  ),
          ),

          // ── Zone de saisie ─────────────────────────────
          _buildZoneSaisie(),
        ],
      ),
    );
  }

  // ── État vide ─────────────────────────────────────────────
  Widget _buildEtatVide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: _vert.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.smart_toy_outlined,
                color: _vert, size: 36),
          ),
          const SizedBox(height: 16),
          Text('Bonjour ! Je suis votre assistant élevage.',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _vert),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text(
            'Écrivez ou parlez — je connais votre troupeau en temps réel.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mic, color: _vert, size: 16),
              const SizedBox(width: 4),
              Text('Maintenez le micro pour parler',
                  style: TextStyle(fontSize: 12, color: _vert)),
            ],
          ),
          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Questions fréquentes',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black45)),
          ),
          const SizedBox(height: 8),
          ..._suggestions.map((s) => _CarteSuggestion(
                texte: s,
                onTap: () => _envoyer(s),
              )),
        ],
      ),
    );
  }

  // ── Zone de saisie avec micro ─────────────────────────────
  Widget _buildZoneSaisie() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 12, right: 12, top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Champ texte
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.black12),
              ),
              child: TextField(
                controller: _controller,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _envoyer(),
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Écrivez ou parlez...',
                  hintStyle: TextStyle(color: Colors.black38),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // ✅ Bouton micro — maintenir appuyé pour parler
          GestureDetector(
            onLongPressStart: (_) => _demarrerEcoute(),
            onLongPressEnd:   (_) => _arreterEcouteEtEnvoyer(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _enEcoute ? Colors.red : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _enEcoute ? Icons.mic : Icons.mic_none,
                color: _enEcoute ? Colors.white : Colors.grey.shade600,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Bouton envoyer
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: FloatingActionButton.small(
              onPressed: _enChargement ? null : _envoyer,
              backgroundColor:
                  _enChargement ? Colors.grey.shade300 : _vert,
              elevation: 0,
              child: Icon(
                _enChargement
                    ? Icons.hourglass_empty
                    : Icons.send_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// BULLE MESSAGE
// ============================================================

class _BulleMessage extends StatelessWidget {
  final CopilotMessage message;
  final Color couleurPrimaire;
  final VoidCallback? onRelire;

  const _BulleMessage({
    required this.message,
    required this.couleurPrimaire,
    this.onRelire,
  });

  @override
  Widget build(BuildContext context) {
    final estUser = message.role == RoleMessage.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            estUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!estUser) ...[
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: couleurPrimaire,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.smart_toy_outlined,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: estUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onLongPress: () {
                    Clipboard.setData(
                        ClipboardData(text: message.contenu));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Copié'),
                          duration: Duration(seconds: 2)),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: estUser ? couleurPrimaire : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(estUser ? 16 : 4),
                        bottomRight: Radius.circular(estUser ? 4 : 16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      message.contenu,
                      style: TextStyle(
                        fontSize: 14,
                        color: estUser ? Colors.white : Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                // Bouton relire pour les messages assistant
                if (!estUser && onRelire != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: GestureDetector(
                      onTap: onRelire,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.volume_up_outlined,
                              size: 13,
                              color: couleurPrimaire.withOpacity(0.7)),
                          const SizedBox(width: 3),
                          Text('Relire',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: couleurPrimaire
                                      .withOpacity(0.7))),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (estUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ============================================================
// BULLE CHARGEMENT
// ============================================================

class _BulleChargement extends StatefulWidget {
  @override
  State<_BulleChargement> createState() => _BulleChargementState();
}

class _BulleChargementState extends State<_BulleChargement>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF1B5E20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.smart_toy_outlined,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final o =
                      ((_ctrl.value * 3 - i) % 1).clamp(0.2, 1.0);
                  return Container(
                    width: 7, height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B5E20).withOpacity(o),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// PULSE ICON — indicateur d'écoute
// ============================================================

class _PulseIcon extends StatefulWidget {
  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.5, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Icon(Icons.mic,
          color: Colors.red.withOpacity(_anim.value), size: 18),
    );
  }
}

// ============================================================
// CARTE SUGGESTION
// ============================================================

class _CarteSuggestion extends StatelessWidget {
  final String texte;
  final VoidCallback onTap;

  const _CarteSuggestion({required this.texte, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF1B5E20).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.chat_bubble_outline,
                size: 14, color: Color(0xFF1B5E20)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(texte,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF1B5E20))),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 12, color: Color(0xFF1B5E20)),
          ],
        ),
      ),
    );
  }
}