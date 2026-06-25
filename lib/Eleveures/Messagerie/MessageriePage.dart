import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:depart/constants.dart';

// ============================================================
// MESSAGERIE — éleveur ↔ vétérinaire
// ✅ Temps réel via Supabase Realtime
// ✅ Contexte animal optionnel (lié à une consultation)
// ✅ Push FCM au destinataire à chaque nouveau message
// ✅ Marquage automatique comme lu à l'ouverture
// ============================================================
class MessageriePage extends StatefulWidget {
  final String interlocuteurId;
  final String interlocuteurNom;
  final String? animalId;
  final String? animalSource;
  final String? animalNom;

  const MessageriePage({
    super.key,
    required this.interlocuteurId,
    required this.interlocuteurNom,
    this.animalId,
    this.animalSource,
    this.animalNom,
  });

  @override
  State<MessageriePage> createState() => _MessageriePageState();
}

class _MessageriePageState extends State<MessageriePage> {
  final supabase        = Supabase.instance.client;
  final _messageCtrl    = TextEditingController();
  final _scrollCtrl     = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool   _isLoading   = false;
  bool   _envoi       = false;
  String? _userId;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _userId = supabase.auth.currentUser?.id;
    _chargerMessages();
    _ecouterTempsReel();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ─── Charger les messages + marquer comme lus ─────────────
  Future<void> _chargerMessages() async {
    if (_userId == null) return;
    setState(() => _isLoading = true);

    try {
      // Charger la conversation entre les deux utilisateurs
      final data = await supabase
          .from('messages')
          .select()
          .or('and(expediteur_id.eq.$_userId,destinataire_id.eq.${widget.interlocuteurId}),'
              'and(expediteur_id.eq.${widget.interlocuteurId},destinataire_id.eq.$_userId)')
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
        _scrollerEnBas();
      }

      // Marquer tous les messages reçus comme lus
      await supabase
          .from('messages')
          .update({'lu': true})
          .eq('destinataire_id', _userId!)
          .eq('expediteur_id', widget.interlocuteurId)
          .eq('lu', false);

    } catch (e) {
      debugPrint('Erreur chargement messages: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Écoute temps réel ────────────────────────────────────
  void _ecouterTempsReel() {
    if (_userId == null) return;

    _channel = supabase
        .channel('messages_${_userId}_${widget.interlocuteurId}')
        .onPostgresChanges(
          event : PostgresChangeEvent.insert,
          schema: 'public',
          table : 'messages',
          callback: (payload) async {
            final msg = payload.newRecord;
            // Ajouter seulement si message de cette conversation
            if ((msg['expediteur_id']   == _userId &&
                 msg['destinataire_id'] == widget.interlocuteurId) ||
                (msg['expediteur_id']   == widget.interlocuteurId &&
                 msg['destinataire_id'] == _userId)) {
              if (mounted) {
                setState(() => _messages.add(msg));
                _scrollerEnBas();
                // Marquer comme lu si c'est un message reçu
                if (msg['destinataire_id'] == _userId && msg['lu'] == false) {
                  await supabase
                      .from('messages')
                      .update({'lu': true})
                      .eq('id', msg['id']);
                }
              }
            }
          },
        )
        .subscribe();
  }

  // ─── Envoyer un message ───────────────────────────────────
  Future<void> _envoyerMessage() async {
    final texte = _messageCtrl.text.trim();
    if (texte.isEmpty || _envoi || _userId == null) return;

    setState(() => _envoi = true);
    _messageCtrl.clear();

    try {
      final msgData = {
        'expediteur_id'  : _userId!,
        'destinataire_id': widget.interlocuteurId,
        'contenu'        : texte,
        'lu'             : false,
        'created_at'     : DateTime.now().toIso8601String(),
      };

      // Ajouter le contexte animal si disponible
      if (widget.animalId != null) {
        msgData['animal_id']    = widget.animalId!;
        msgData['animal_source']= widget.animalSource ?? '';
        msgData['animal_nom']   = widget.animalNom ?? '';
      }

      await supabase.from('messages').insert(msgData);

      // Push FCM au destinataire
      await _envoyerPushMessage(texte);

    } catch (e) {
      debugPrint('Erreur envoi message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        // Remettre le texte si erreur
        _messageCtrl.text = texte;
      }
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  // ─── Push FCM au destinataire ─────────────────────────────
  Future<void> _envoyerPushMessage(String texte) async {
    try {
      // Récupérer le nom de l'expéditeur
      final userData = await supabase
          .from(Tables.users)
          .select('nom_complet, prenom, nom')
          .eq('id', _userId!)
          .maybeSingle();

      String nomExp = 'Un utilisateur';
      if (userData != null) {
        nomExp = userData['nom_complet'] ??
            ((userData['prenom'] != null && userData['nom'] != null)
                ? '${userData['prenom']} ${userData['nom']}'
                : 'Un utilisateur');
      }

      String titre = 'Message de $nomExp';
      if (widget.animalNom != null) {
        titre += ' — ${widget.animalNom}';
      }

      await supabase.functions.invoke(
        EdgeFunctions.sendPushNotification,
        body: {
          'user_id': widget.interlocuteurId,
          'title'  : titre,
          'body'   : texte.length > 100
              ? '${texte.substring(0, 100)}...'
              : texte,
          'type'   : TypeNotification.general,
          'channel': CanalNotification.alerte,
          'data'   : {
            'action'         : 'ouvrir_messagerie',
            'expediteur_id'  : _userId!,
            'expediteur_nom' : nomExp,
            if (widget.animalId != null) 'animal_id': widget.animalId!,
          },
        },
      );
    } catch (e) {
      debugPrint('Push message non envoyé (silencieux): $e');
    }
  }

  void _scrollerEnBas() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve   : Curves.easeOut,
        );
      }
    });
  }

  String _formatHeure(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt  = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
        return "Aujourd'hui";
      }
      final hier = now.subtract(const Duration(days: 1));
      if (dt.day == hier.day && dt.month == hier.month && dt.year == hier.year) {
        return 'Hier';
      }
      return '${dt.day.toString().padLeft(2, '0')}/'
             '${dt.month.toString().padLeft(2, '0')}/'
             '${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              radius: 18,
              child: Icon(Icons.person, color: Colors.green[700], size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.interlocuteurNom,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  if (widget.animalNom != null)
                    Text(
                      'À propos de ${widget.animalNom}',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.white70),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Bandeau contexte animal
          if (widget.animalNom != null)
            Container(
              width : double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color : Colors.green[50],
              child : Row(
                children: [
                  Icon(Icons.pets, color: Colors.green[700], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Conversation liée à : ${widget.animalNom}',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[900],
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

          // Liste des messages
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller : _scrollCtrl,
                        padding    : const EdgeInsets.all(16),
                        itemCount  : _messages.length,
                        itemBuilder: (context, index) {
                          final msg     = _messages[index];
                          final estMoi  = msg['expediteur_id'] == _userId;
                          final showDate = index == 0 ||
                              _formatDate(msg['created_at']?.toString()) !=
                              _formatDate(_messages[index - 1]['created_at']?.toString());
                          return Column(
                            children: [
                              if (showDate) _buildDateSeparator(msg['created_at']?.toString()),
                              _buildBubble(msg, estMoi),
                            ],
                          );
                        },
                      ),
          ),

          // Zone de saisie
          _buildZoneSaisie(),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(String? iso) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey[300])),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _formatDate(iso),
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey[300])),
        ],
      ),
    );
  }

  Widget _buildBubble(Map<String, dynamic> msg, bool estMoi) {
    return Align(
      alignment: estMoi ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Container(
          margin: EdgeInsets.only(
            bottom: 6,
            left : estMoi ? 60 : 0,
            right: estMoi ? 0  : 60,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: estMoi ? Colors.green[600] : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft    : const Radius.circular(16),
              topRight   : const Radius.circular(16),
              bottomLeft : Radius.circular(estMoi ? 16 : 4),
              bottomRight: Radius.circular(estMoi ? 4  : 16),
            ),
            boxShadow: [
              BoxShadow(
                color  : Colors.black.withOpacity(0.06),
                blurRadius: 4,
                offset : const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                msg['contenu'] ?? '',
                style: TextStyle(
                  fontSize: 14,
                  color   : estMoi ? Colors.white : Colors.grey[900],
                  height  : 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize     : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _formatHeure(msg['created_at']?.toString()),
                    style: TextStyle(
                      fontSize: 10,
                      color   : estMoi
                          ? Colors.white.withOpacity(0.7)
                          : Colors.grey[500],
                    ),
                  ),
                  if (estMoi) ...[
                    const SizedBox(width: 4),
                    Icon(
                      msg['lu'] == true ? Icons.done_all : Icons.done,
                      size : 14,
                      color: msg['lu'] == true
                          ? Colors.white
                          : Colors.white.withOpacity(0.6),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZoneSaisie() {
    return Container(
      padding: EdgeInsets.only(
        left  : 12,
        right : 12,
        top   : 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      decoration: BoxDecoration(
        color     : Colors.white,
        boxShadow : [
          BoxShadow(
            color     : Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset    : const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller : _messageCtrl,
              maxLines   : 4,
              minLines   : 1,
              textCapitalization: TextCapitalization.sentences,
              decoration : InputDecoration(
                hintText    : 'Écrire un message...',
                hintStyle   : TextStyle(color: Colors.grey[400]),
                filled      : true,
                fillColor   : Colors.grey[100],
                border      : OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide  : BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _envoyerMessage(),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: _envoi
                ? Container(
                    width : 48,
                    height: 48,
                    padding: const EdgeInsets.all(12),
                    child : const CircularProgressIndicator(strokeWidth: 2),
                  )
                : Material(
                    color       : Colors.green[700],
                    borderRadius: BorderRadius.circular(24),
                    child       : InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap       : _envoyerMessage,
                      child       : const SizedBox(
                        width : 48,
                        height: 48,
                        child : Icon(Icons.send, color: Colors.white, size: 22),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Aucun message',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Envoyez un message à ${widget.interlocuteurNom}',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          if (widget.animalNom != null) ...[
            const SizedBox(height: 8),
            Text(
              'À propos de : ${widget.animalNom}',
              style: TextStyle(
                  fontSize: 13,
                  color  : Colors.green[700],
                  fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );
  }
}