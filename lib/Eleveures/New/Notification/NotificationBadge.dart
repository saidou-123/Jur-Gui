import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// PAGE NOTIFICATIONS — côté ÉLEVEUR
// ✅ Affiche toutes les notifications reçues du vétérinaire
// ✅ Permet de marquer comme lu
// ✅ Badge de compteur sur l'icône dans le menu principal
// ============================================================

// ─────────────────────────────────────────────────────────
// Widget badge de compteur — à placer dans le menu éleveur
// Usage : NotificationBadge(child: Icon(Icons.notifications))
// ─────────────────────────────────────────────────────────
class NotificationBadge extends StatefulWidget {
  final Widget child;
  const NotificationBadge({super.key, required this.child});

  @override
  State<NotificationBadge> createState() => _NotificationBadgeState();
}

class _NotificationBadgeState extends State<NotificationBadge> {
  final supabase = Supabase.instance.client;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _chargerCompteur();
    // Écoute temps réel : mise à jour automatique du badge
    supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('destinataire_id', supabase.auth.currentUser?.id ?? '')
        .listen((_) => _chargerCompteur());
  }

  Future<void> _chargerCompteur() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null || !mounted) return;
    try {
      final result = await supabase
          .from('notifications')
          .select('id')
          .eq('destinataire_id', userId)
          .eq('lu', false);
      if (mounted) setState(() => _count = (result as List).length);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (_count > 0)
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints:
                  const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                _count > 99 ? '99+' : '$_count',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// PAGE PRINCIPALE DES NOTIFICATIONS
// ─────────────────────────────────────────────────────────
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String _filtre = 'Tout';
  String? _eleveurId;

  @override
  void initState() {
    super.initState();
    _eleveurId = supabase.auth.currentUser?.id;
    _chargerNotifications();
  }

  Future<void> _chargerNotifications() async {
    if (_eleveurId == null || !mounted) return;
    setState(() => _isLoading = true);

    try {
      final data = await supabase
          .from('notifications')
          .select()
          .eq('destinataire_id', _eleveurId!)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _marquerCommeLu(String notifId) async {
    try {
      await supabase
          .from('notifications')
          .update({'lu': true})
          .eq('id', notifId);
      if (mounted) {
        setState(() {
          final index =
              _notifications.indexWhere((n) => n['id'] == notifId);
          if (index != -1) _notifications[index]['lu'] = true;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur marquage lu: $e');
    }
  }

  Future<void> _toutMarquerCommeLu() async {
    if (_eleveurId == null) return;
    try {
      await supabase
          .from('notifications')
          .update({'lu': true})
          .eq('destinataire_id', _eleveurId!)
          .eq('lu', false);

      if (mounted) {
        setState(() {
          for (var n in _notifications) {
            n['lu'] = true;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✅ Toutes les notifications marquées comme lues'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur tout marquer lu: $e');
    }
  }

  List<Map<String, dynamic>> get _notificationsFiltrees {
    if (_filtre == 'Non lues') {
      return _notifications.where((n) => n['lu'] == false).toList();
    }
    if (_filtre == 'Consultations') {
      return _notifications
          .where((n) => n['type'] == 'nouvelle_consultation')
          .toList();
    }
    if (_filtre == 'Vaccinations') {
      return _notifications
          .where((n) => n['type'] == 'nouvelle_vaccination')
          .toList();
    }
    return _notifications;
  }

  int get _nonLues =>
      _notifications.where((n) => n['lu'] == false).length;

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'À l\'instant';
      if (diff.inHours < 1) return 'Il y a ${diff.inMinutes} min';
      if (diff.inDays < 1) return 'Il y a ${diff.inHours}h';
      if (diff.inDays < 7) return 'Il y a ${diff.inDays} jour(s)';

      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notifications'),
            if (_nonLues > 0)
              Text(
                '$_nonLues non lue${_nonLues > 1 ? 's' : ''}',
                style: const TextStyle(
                    fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          if (_nonLues > 0)
            TextButton.icon(
              onPressed: _toutMarquerCommeLu,
              icon: const Icon(Icons.done_all,
                  color: Colors.white, size: 18),
              label: const Text('Tout lire',
                  style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerNotifications,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFiltres(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _notificationsFiltrees.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _chargerNotifications,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _notificationsFiltrees.length,
                          itemBuilder: (context, index) =>
                              _buildNotifItem(
                                  _notificationsFiltrees[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltres() {
    final filtres = ['Tout', 'Non lues', 'Consultations', 'Vaccinations'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filtres.map((f) {
            final isSelected = _filtre == f;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(f),
                selected: isSelected,
                onSelected: (_) => setState(() => _filtre = f),
                selectedColor: Colors.green[200],
                checkmarkColor: Colors.green[900],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildNotifItem(Map<String, dynamic> notif) {
    final bool nonLue = notif['lu'] == false;
    final String type = notif['type'] ?? 'general';

    Color couleur;
    IconData icone;
    switch (type) {
      case 'nouvelle_consultation':
        couleur = Colors.green;
        icone = Icons.medical_services;
        break;
      case 'nouvelle_vaccination':
        couleur = Colors.blue;
        icone = Icons.vaccines;
        break;
      case 'rappel_vaccin':
        couleur = Colors.orange;
        icone = Icons.event_repeat;
        break;
      default:
        couleur = Colors.grey;
        icone = Icons.notifications;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: nonLue ? 3 : 1,
      color: nonLue ? couleur.withOpacity(0.04) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: nonLue
            ? BorderSide(color: couleur.withOpacity(0.4), width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          if (nonLue) _marquerCommeLu(notif['id']);
          _showDetailNotif(notif, couleur, icone);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icône type
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: couleur.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icone, color: couleur, size: 22),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notif['titre'] ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: nonLue
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (nonLue)
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: couleur,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notif['corps'] ?? '',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDate(notif['created_at']?.toString()),
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500]),
                        ),
                        if (nonLue)
                          TextButton(
                            onPressed: () =>
                                _marquerCommeLu(notif['id']),
                            style: TextButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text('Marquer lu',
                                style: TextStyle(
                                    fontSize: 11, color: couleur)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailNotif(
      Map<String, dynamic> notif, Color couleur, IconData icone) {
    if (notif['lu'] == false) _marquerCommeLu(notif['id']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icone, color: couleur),
            const SizedBox(width: 8),
            Expanded(
              child: Text(notif['titre'] ?? '',
                  style: const TextStyle(fontSize: 15)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: couleur.withOpacity(0.07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                notif['corps'] ?? '',
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time,
                    size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  _formatDate(notif['created_at']?.toString()),
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
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
          Icon(Icons.notifications_none, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _filtre == 'Non lues'
                ? 'Aucune notification non lue'
                : 'Aucune notification',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Les notifications de votre vétérinaire\napparaîtront ici',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}