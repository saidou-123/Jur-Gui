import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:depart/constants.dart';

// ============================================================
// PAGE NOTIFICATIONS — côté VÉTÉRINAIRE
// ✅ Notifications reçues des éleveurs (messages, partages)
// ✅ Marquage lu / tout lire
// ✅ Temps réel
// ============================================================
class NotificationsVeterinairePage extends StatefulWidget {
  const NotificationsVeterinairePage({super.key});

  @override
  State<NotificationsVeterinairePage> createState() =>
      _NotificationsVeterinairePageState();
}

class _NotificationsVeterinairePageState
    extends State<NotificationsVeterinairePage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String _filtre = FiltreNotification.tout;
  String? _vetId;

  @override
  void initState() {
    super.initState();
    _vetId = supabase.auth.currentUser?.id;
    _chargerNotifications();
  }

  Future<void> _chargerNotifications() async {
    if (_vetId == null || !mounted) return;
    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from(Tables.notifications)
          .select()
          .eq('destinataire_id', _vetId!)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _marquerCommeLu(String id) async {
    try {
      await supabase
          .from(Tables.notifications)
          .update({'lu': true}).eq('id', id);
      if (mounted) {
        setState(() {
          final idx = _notifications.indexWhere((n) => n['id'] == id);
          if (idx != -1) _notifications[idx]['lu'] = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _toutMarquerCommeLu() async {
    if (_vetId == null) return;
    try {
      await supabase
          .from(Tables.notifications)
          .update({'lu': true})
          .eq('destinataire_id', _vetId!)
          .eq('lu', false);
      if (mounted) {
        setState(() {
          for (var n in _notifications) n['lu'] = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Toutes les notifications marquées comme lues'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (_) {}
  }

  int get _nonLues =>
      _notifications.where((n) => n['lu'] == false).length;

  List<Map<String, dynamic>> get _filtrees {
    if (_filtre == FiltreNotification.nonLues) {
      return _notifications.where((n) => n['lu'] == false).toList();
    }
    if (_filtre == FiltreNotification.consultations) {
      return _notifications
          .where((n) => n['type'] == TypeNotification.nouvelleConsultation)
          .toList();
    }
    if (_filtre == FiltreNotification.vaccinations) {
      return _notifications
          .where((n) => n['type'] == TypeNotification.nouvelleVaccination)
          .toList();
    }
    return _notifications;
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt  = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'À l\'instant';
      if (diff.inHours < 1)  return 'Il y a ${diff.inMinutes} min';
      if (diff.inDays < 1)   return 'Il y a ${diff.inHours}h';
      if (diff.inDays < 7)   return 'Il y a ${diff.inDays} jour(s)';
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return '';
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
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          if (_nonLues > 0)
            TextButton.icon(
              onPressed: _toutMarquerCommeLu,
              icon: const Icon(Icons.done_all, color: Colors.white, size: 18),
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
          // Filtres
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    FiltreNotification.tous.map((f) {
                  final sel = _filtre == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f),
                      selected: sel,
                      onSelected: (_) => setState(() => _filtre = f),
                      selectedColor: Colors.blue[200],
                      checkmarkColor: Colors.blue[900],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtrees.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _chargerNotifications,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filtrees.length,
                          itemBuilder: (context, index) =>
                              _buildNotifItem(_filtrees[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotifItem(Map<String, dynamic> notif) {
    final bool nonLue = notif['lu'] == false;
    final String type  = notif['type'] ?? TypeNotification.general;

    Color couleur;
    IconData icone;
    switch (type) {
      case 'nouvelle_consultation':
        couleur = Colors.green;
        icone   = Icons.medical_services;
        break;
      case 'nouvelle_vaccination':
        couleur = Colors.blue;
        icone   = Icons.vaccines;
        break;
      case 'rappel_vaccin':
        couleur = Colors.orange;
        icone   = Icons.event_repeat;
        break;
      default:
        couleur = Colors.grey;
        icone   = Icons.notifications;
    }

    return Card(
      margin    : const EdgeInsets.only(bottom: 10),
      elevation : nonLue ? 3 : 1,
      color     : nonLue ? couleur.withOpacity(0.04) : null,
      shape     : RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: nonLue
            ? BorderSide(color: couleur.withOpacity(0.4), width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          if (nonLue) _marquerCommeLu(notif['id']);
          _showDetail(notif, couleur, icone);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color : couleur.withOpacity(0.12),
                  shape : BoxShape.circle,
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
                              fontSize  : 14,
                              fontWeight: nonLue
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (nonLue)
                          Container(
                            width : 10,
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
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey[600]),
                      maxLines : 2,
                      overflow : TextOverflow.ellipsis,
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8),
                              minimumSize   : Size.zero,
                              tapTargetSize :
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

  void _showDetail(
      Map<String, dynamic> notif, Color couleur, IconData icone) {
    if (notif['lu'] == false) _marquerCommeLu(notif['id']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
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
                color        : couleur.withOpacity(0.07),
                borderRadius : BorderRadius.circular(8),
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
            _filtre == FiltreNotification.nonLues
                ? 'Aucune notification non lue'
                : 'Aucune notification',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Les notifications des éleveurs apparaîtront ici',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}