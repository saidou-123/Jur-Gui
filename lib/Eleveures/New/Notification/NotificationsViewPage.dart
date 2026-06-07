// ============================================================
// PAGE DE VISUALISATION DES NOTIFICATIONS
// Voir toutes les notifications: en attente, historique, statistiques
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationsViewPage extends StatefulWidget {
  const NotificationsViewPage({super.key});

  @override
  State<NotificationsViewPage> createState() => _NotificationsViewPageState();
}

class _NotificationsViewPageState extends State<NotificationsViewPage>
    with SingleTickerProviderStateMixin {
  final _notifications = FlutterLocalNotificationsPlugin();
  final _supabase = Supabase.instance.client;

  late TabController _tabController;

  List<PendingNotificationRequest> _notificationsEnAttente = [];
  List<Map<String, dynamic>> _historiqueNotifications = [];
  // ✅ AJOUT : push distants programmés en BD (visibles même app fermée)
  List<Map<String, dynamic>> _pushProgrammes = [];
  
  bool _isLoading = true;
  int _totalNotifications = 0;
  int _notificationsChaleur = 0;
  int _notificationsAgnelage = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _chargerDonnees();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _chargerDonnees() async {
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _chargerNotificationsEnAttente(),
        _chargerHistoriqueNotifications(),
        _chargerPushProgrammes(), // ✅ AJOUT
      ]);
    } catch (e) {
      debugPrint("❌ Erreur chargement: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _chargerNotificationsEnAttente() async {
    try {
      final pending = await _notifications.pendingNotificationRequests();
      
      if (mounted) {
        setState(() {
          _notificationsEnAttente = pending;
          // ✅ total = local + push BD (comptés ensemble dans la stat)
          _totalNotifications = pending.length + _pushProgrammes.length;
        });
      }

      debugPrint("✅ ${pending.length} notifications en attente");
    } catch (e) {
      debugPrint("❌ Erreur chargement notifications: $e");
    }
  }

  // ✅ AJOUT : charger les push distants programmés en BD
  Future<void> _chargerPushProgrammes() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final pushes = await _supabase
          .from('notifications_programmees')
          .select('*')
          .eq('user_id', userId)
          .eq('statut', 'planifie')
          .gte('date_envoi', DateTime.now().toIso8601String())
          .order('date_envoi', ascending: true);

      if (mounted) {
        setState(() {
          _pushProgrammes = List<Map<String, dynamic>>.from(pushes);
          _totalNotifications =
              _notificationsEnAttente.length + _pushProgrammes.length;
        });
      }
      debugPrint('✅ ${pushes.length} push distants programmés chargés');
    } catch (e) {
      debugPrint('❌ Erreur chargement push programmés: $e');
    }
  }

  // ✅ AJOUT : annuler un push distant en BD
  Future<void> _annulerPushProgramme(String pushId, String nomAnimal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Annuler ce rappel"),
        content: Text(
          "Voulez-vous vraiment annuler ce rappel push pour $nomAnimal ?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Non"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Oui, annuler"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase
          .from('notifications_programmees')
          .update({'statut': 'annule'})
          .eq('id', pushId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Rappel push annulé"),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _chargerDonnees();
    } catch (e) {
      debugPrint('❌ Erreur annulation push: $e');
    }
  }

  Future<void> _chargerHistoriqueNotifications() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final rappels = await _supabase
          .from('rappels_reproduction')
          .select('*')
          .eq('user_id', userId)
          .order('date_rappel', ascending: false)
          .limit(50);

      // Compter par type
      int chaleur = 0;
      int agnelage = 0;

      for (var rappel in rappels) {
        final type = rappel['type'] as String;
        if (type.contains('chaleur') || type.contains('fenetre')) {
          chaleur++;
        } else if (type.contains('agnelage')) {
          agnelage++;
        }
      }

      if (mounted) {
        setState(() {
          _historiqueNotifications = List<Map<String, dynamic>>.from(rappels);
          _notificationsChaleur = chaleur;
          _notificationsAgnelage = agnelage;
        });
      }

      debugPrint("✅ ${rappels.length} rappels dans l'historique");
    } catch (e) {
      debugPrint("❌ Erreur historique: $e");
    }
  }

  Future<void> _annulerNotification(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Annuler le rappel"),
        content: const Text("Voulez-vous vraiment annuler ce rappel ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Non"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Oui, annuler"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _notifications.cancel(id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Rappel annulé"),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _chargerDonnees();
    } catch (e) {
      debugPrint("❌ Erreur annulation: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Erreur: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _annulerToutesNotifications() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Annuler tous les rappels"),
        content: const Text(
          "⚠️ ATTENTION: Cette action annulera TOUS vos rappels programmés "
          "(chaleurs, agnelages, etc.).\n\n"
          "Voulez-vous vraiment continuer ?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Non"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Oui, tout annuler"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _notifications.cancelAll();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Tous les rappels ont été annulés"),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _chargerDonnees();
    } catch (e) {
      debugPrint("❌ Erreur annulation totale: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mes Notifications"),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerDonnees,
            tooltip: "Actualiser",
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'annuler_tout') {
                _annulerToutesNotifications();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'annuler_tout',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red),
                    SizedBox(width: 8),
                    Text("Annuler tous les rappels"),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: "En attente", icon: Icon(Icons.schedule, size: 20)),
            Tab(text: "Historique", icon: Icon(Icons.history, size: 20)),
            Tab(text: "Statistiques", icon: Icon(Icons.bar_chart, size: 20)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOngletEnAttente(),
                _buildOngletHistorique(),
                _buildOngletStatistiques(),
              ],
            ),
    );
  }

  // ===== ONGLET: NOTIFICATIONS EN ATTENTE =====

  Widget _buildOngletEnAttente() {
    if (_notificationsEnAttente.isEmpty && _pushProgrammes.isEmpty) {
      return _buildEmptyState(
        Icons.notifications_off,
        "Aucune notification en attente",
        "Vos rappels programmés apparaîtront ici",
      );
    }

    return RefreshIndicator(
      onRefresh: _chargerDonnees,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Section : notifications locales ───────────────
          if (_notificationsEnAttente.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.phone_android, size: 16,
                      color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    "Locales (${_notificationsEnAttente.length})",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            ...List.generate(
              _notificationsEnAttente.length,
              (i) => _buildNotificationCard(_notificationsEnAttente[i]),
            ),
          ],
          // ── Section : push distants programmés ───────────
          if (_pushProgrammes.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.cloud_queue, size: 16,
                      color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    "Push programmés — BD (${_pushProgrammes.length})",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            ...List.generate(
              _pushProgrammes.length,
              (i) => _buildPushProgrammeCard(_pushProgrammes[i]),
            ),
          ],
        ],
      ),
    );
  }

  // ✅ AJOUT : carte pour un push distant programmé
  Widget _buildPushProgrammeCard(Map<String, dynamic> push) {
    final type = push['type'] as String? ?? '';
    final titre = push['titre'] as String? ?? '';
    final nomAnimal = push['nom_animal'] as String? ?? '';
    final dateEnvoi = DateTime.parse(push['date_envoi'] as String);
    final pushId = push['id']?.toString() ?? '';

    IconData icon;
    Color color;

    if (type.contains('chaleur') || type.contains('fenetre')) {
      icon = Icons.local_fire_department;
      color = Colors.orange;
    } else if (type.contains('agnelage')) {
      icon = Icons.pregnant_woman;
      color = Colors.purple;
    } else if (type.contains('derniere_chance')) {
      icon = Icons.alarm;
      color = Colors.red;
    } else if (type.contains('alerte') || type.contains('cycle')) {
      icon = Icons.warning_rounded;
      color = Colors.deepOrange;
    } else {
      icon = Icons.cloud_queue;
      color = Colors.blue;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(
          titre,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              nomAnimal,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.cloud_queue, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  "Push — ${_formatDateRappel(dateEnvoi)}",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: pushId.isNotEmpty
              ? () => _annulerPushProgramme(pushId, nomAnimal)
              : null,
          tooltip: "Annuler",
        ),
      ),
    );
  }

  Widget _buildNotificationCard(PendingNotificationRequest notif) {
    // Déterminer le type de notification par l'ID ou le titre
    IconData icon;
    Color color;
    String type = "Inconnu";

    final titre = notif.title ?? '';
    if (titre.contains('Chaleur') || titre.contains('chaleur')) {
      icon = Icons.local_fire_department;
      color = Colors.orange;
      type = "Chaleur";
    } else if (titre.contains('Agnelage') || titre.contains('agnelage')) {
      icon = Icons.pregnant_woman;
      color = Colors.purple;
      type = "Agnelage";
    } else if (titre.contains('Fenêtre') || titre.contains('fenêtre')) {
      icon = Icons.access_time;
      color = Colors.green;
      type = "Fenêtre fertile";
    } else {
      icon = Icons.notifications;
      color = Colors.blue;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(
          notif.title ?? 'Notification',
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notif.body ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.label, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  type,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  "ID: ${notif.id}",
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _annulerNotification(notif.id),
          tooltip: "Annuler",
        ),
      ),
    );
  }

  // ===== ONGLET: HISTORIQUE =====

  Widget _buildOngletHistorique() {
    if (_historiqueNotifications.isEmpty) {
      return _buildEmptyState(
        Icons.history,
        "Aucun historique",
        "L'historique de vos notifications apparaîtra ici",
      );
    }

    return RefreshIndicator(
      onRefresh: _chargerDonnees,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _historiqueNotifications.length,
        itemBuilder: (context, index) {
          final rappel = _historiqueNotifications[index];
          return _buildHistoriqueCard(rappel);
        },
      ),
    );
  }

  Widget _buildHistoriqueCard(Map<String, dynamic> rappel) {
    final type = rappel['type'] as String;
    final message = rappel['message'] as String?;
    final dateRappel = DateTime.parse(rappel['date_rappel']);
    final statut = rappel['statut'] as String;

    // Icône et couleur selon le type
    IconData icon;
    Color color;
    
    if (type.contains('chaleur')) {
      icon = Icons.local_fire_department;
      color = Colors.orange;
    } else if (type.contains('fenetre')) {
      icon = Icons.access_time;
      color = Colors.green;
    } else if (type.contains('agnelage')) {
      icon = Icons.pregnant_woman;
      color = Colors.purple;
    } else {
      icon = Icons.notifications;
      color = Colors.blue;
    }

    // Couleur selon le statut
    Color statutColor;
    String statutText;
    
    switch (statut) {
      case 'planifie':
        statutColor = Colors.blue;
        statutText = "Planifié";
        break;
      case 'envoye':
        statutColor = Colors.green;
        statutText = "Envoyé";
        break;
      case 'annule':
        statutColor = Colors.red;
        statutText = "Annulé";
        break;
      case 'expire':
        statutColor = Colors.grey;
        statutText = "Expiré";
        break;
      default:
        statutColor = Colors.grey;
        statutText = statut;
    }

    final estPasse = dateRappel.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          _formatTypeNotification(type),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  estPasse ? Icons.event_available : Icons.schedule,
                  size: 12,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDateRappel(dateRappel),
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statutColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            statutText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: statutColor,
            ),
          ),
        ),
      ),
    );
  }

  // ===== ONGLET: STATISTIQUES =====

  Widget _buildOngletStatistiques() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cartes de statistiques
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  Icons.schedule,
                  _totalNotifications.toString(),
                  "En attente",
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  Icons.history,
                  _historiqueNotifications.length.toString(),
                  "Historique",
                  Colors.purple,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  Icons.local_fire_department,
                  _notificationsChaleur.toString(),
                  "Chaleurs",
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  Icons.pregnant_woman,
                  _notificationsAgnelage.toString(),
                  "Agnelages",
                  Colors.pink,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Graphique de répartition par type
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Répartition des rappels",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildBarreRepartition(
                    "Chaleurs",
                    _notificationsChaleur,
                    _historiqueNotifications.length,
                    Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  _buildBarreRepartition(
                    "Agnelages",
                    _notificationsAgnelage,
                    _historiqueNotifications.length,
                    Colors.pink,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Légende des statuts
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Légende des statuts",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildLegendeStatut(Colors.blue, "Planifié", "Rappel programmé"),
                  _buildLegendeStatut(Colors.green, "Envoyé", "Notification affichée"),
                  _buildLegendeStatut(Colors.red, "Annulé", "Rappel supprimé"),
                  _buildLegendeStatut(Colors.grey, "Expiré", "Date dépassée"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String valeur, String label, Color couleur) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [couleur.withOpacity(0.1), couleur.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: couleur.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: couleur),
          const SizedBox(height: 8),
          Text(
            valeur,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: couleur,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: couleur.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBarreRepartition(String label, int valeur, int total, Color couleur) {
    final pourcentage = total > 0 ? (valeur / total) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              "$valeur / $total (${(pourcentage * 100).toStringAsFixed(0)}%)",
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pourcentage,
            minHeight: 20,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(couleur),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendeStatut(Color couleur, String label, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: couleur,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String titre, String sousTitre) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            titre,
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            sousTitre,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ===== UTILITAIRES =====

  String _formatTypeNotification(String type) {
    switch (type) {
      case 'chaleur_prevue':
        return "Prochaine chaleur prévue";
      case 'fenetre_fertile':
        return "Fenêtre fertile";
      case 'agnelage_30j':
        return "Agnelage dans 1 mois";
      case 'agnelage_7j':
        return "Agnelage dans 1 semaine";
      case 'agnelage_1j':
        return "Agnelage dans 24h";
      default:
        return type.replaceAll('_', ' ');
    }
  }

  String _formatDateRappel(DateTime date) {
    final maintenant = DateTime.now();
    final difference = date.difference(maintenant);

    if (difference.isNegative) {
      final jours = difference.inDays.abs();
      if (jours == 0) return "Aujourd'hui";
      if (jours == 1) return "Hier";
      return "Il y a $jours jours";
    } else {
      final jours = difference.inDays;
      if (jours == 0) return "Aujourd'hui";
      if (jours == 1) return "Demain";
      return "Dans $jours jours";
    }
  }
}