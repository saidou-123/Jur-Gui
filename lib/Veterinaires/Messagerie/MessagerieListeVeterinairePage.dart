import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:depart/constants.dart';
import 'package:depart/Eleveures/Messagerie/MessageriePage.dart'
    show MessageriePage;

// ============================================================
// LISTE DES CONVERSATIONS — côté VÉTÉRINAIRE
// ✅ Affiche toutes les conversations avec les éleveurs
// ✅ Badge non lus par conversation
// ✅ Dernier message + heure
// ✅ Temps réel
// ============================================================
class MessagerieListeVeterinairePage extends StatefulWidget {
  const MessagerieListeVeterinairePage({super.key});

  @override
  State<MessagerieListeVeterinairePage> createState() =>
      _MessagerieListeVeterinairePageState();
}

class _MessagerieListeVeterinairePageState
    extends State<MessagerieListeVeterinairePage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  String? _vetId;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _vetId = supabase.auth.currentUser?.id;
    _chargerConversations();
    _ecouterTempsReel();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  // ─── Charger toutes les conversations du vétérinaire ──────
  Future<void> _chargerConversations() async {
    if (_vetId == null || !mounted) return;
    setState(() => _isLoading = true);

    try {
      // Récupérer tous les messages impliquant ce vétérinaire
      final data = await supabase
          .from(Tables.messages)
          .select()
          .or('expediteur_id.eq.$_vetId,destinataire_id.eq.$_vetId')
          .order('created_at', ascending: false);

      // Grouper par interlocuteur (éleveur)
      final Map<String, Map<String, dynamic>> convMap = {};

      for (final msg in data as List) {
        final String interlocuteurId = msg['expediteur_id'] == _vetId
            ? msg['destinataire_id'].toString()
            : msg['expediteur_id'].toString();

        if (!convMap.containsKey(interlocuteurId)) {
          convMap[interlocuteurId] = {
            'interlocuteur_id': interlocuteurId,
            'dernier_message' : msg['contenu'] ?? '',
            'date'            : msg['created_at']?.toString() ?? '',
            'animal_nom'      : msg['animal_nom']?.toString(),
            'nb_non_lus'      : 0,
          };
        }

        // Compter les non lus (messages reçus non lus)
        if (msg['destinataire_id'] == _vetId && msg['lu'] == false) {
          convMap[interlocuteurId]!['nb_non_lus'] =
              (convMap[interlocuteurId]!['nb_non_lus'] as int) + 1;
        }
      }

      // Enrichir avec les noms des éleveurs
      final conversations = <Map<String, dynamic>>[];
      for (final entry in convMap.entries) {
        final eleveurData = await supabase
            .from(Tables.users)
            .select('nom_complet, prenom, nom, email')
            .eq('id', entry.key)
            .maybeSingle();

        String nomEleveur = 'Éleveur inconnu';
        if (eleveurData != null) {
          nomEleveur = eleveurData['nom_complet'] ??
              ((eleveurData['prenom'] != null && eleveurData['nom'] != null)
                  ? '${eleveurData['prenom']} ${eleveurData['nom']}'
                  : eleveurData['email']?.toString().split('@').first ??
                      'Éleveur inconnu');
        }

        conversations.add({
          ...entry.value,
          'nom_eleveur': nomEleveur,
        });
      }

      // Trier par date décroissante
      conversations.sort((a, b) =>
          (b['date'] as String).compareTo(a['date'] as String));

      if (mounted) {
        setState(() {
          _conversations = conversations;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement conversations: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Temps réel ───────────────────────────────────────────
  void _ecouterTempsReel() {
    if (_vetId == null) return;
    _channel = supabase
        .channel('conv_vet_$_vetId')
        .onPostgresChanges(
          event   : PostgresChangeEvent.insert,
          schema  : 'public',
          table   : Tables.messages,
          callback: (_) => _chargerConversations(),
        )
        .subscribe();
  }

  // ─── Total non lus ────────────────────────────────────────
  int get _totalNonLus => _conversations.fold(
      0, (sum, c) => sum + (c['nb_non_lus'] as int));

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt  = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'À l\'instant';
      if (diff.inHours < 1)  return '${diff.inMinutes} min';
      if (diff.inDays < 1)   return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
      if (diff.inDays < 7)   return '${diff.inDays}j';
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Messagerie'),
            if (_totalNonLus > 0)
              Text(
                '$_totalNonLus message${_totalNonLus > 1 ? 's' : ''} non lu${_totalNonLus > 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerConversations,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _chargerConversations,
                  child: ListView.separated(
                    itemCount  : _conversations.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) =>
                        _buildConvItem(_conversations[index]),
                  ),
                ),
    );
  }

  Widget _buildConvItem(Map<String, dynamic> conv) {
    final int nonLus     = conv['nb_non_lus'] as int;
    final bool hasUnread = nonLus > 0;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 8),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue[100],
            radius: 26,
            child: Text(
              (conv['nom_eleveur'] as String)
                  .substring(0, 1)
                  .toUpperCase(),
              style: TextStyle(
                  fontSize  : 20,
                  fontWeight: FontWeight.bold,
                  color     : Colors.blue[700]),
            ),
          ),
          if (hasUnread)
            Positioned(
              right: -2,
              top  : -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$nonLus',
                  style: const TextStyle(
                      color    : Colors.white,
                      fontSize : 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        conv['nom_eleveur'] as String,
        style: TextStyle(
          fontWeight: hasUnread ? FontWeight.bold : FontWeight.w500,
          fontSize  : 16,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            conv['dernier_message'] as String,
            maxLines : 1,
            overflow : TextOverflow.ellipsis,
            style    : TextStyle(
              fontSize  : 13,
              color     : hasUnread ? Colors.black87 : Colors.grey[600],
              fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
          if (conv['animal_nom'] != null) ...[
            const SizedBox(height: 2),
            Text(
              '🐑 ${conv['animal_nom']}',
              style: TextStyle(fontSize: 11, color: Colors.green[700]),
            ),
          ],
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatDate(conv['date'] as String?),
            style: TextStyle(
              fontSize  : 11,
              color     : hasUnread ? Colors.blue[700] : Colors.grey[500],
              fontWeight: hasUnread ? FontWeight.bold  : FontWeight.normal,
            ),
          ),
        ],
      ),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MessageriePage(
              interlocuteurId : conv['interlocuteur_id'] as String,
              interlocuteurNom: conv['nom_eleveur']      as String,
              animalNom       : conv['animal_nom']       as String?,
            ),
          ),
        );
        // Rafraîchir après retour
        _chargerConversations();
      },
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
            'Aucune conversation',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Les messages des éleveurs apparaîtront ici',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}