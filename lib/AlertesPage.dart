// ============================================================
// PAGE ALERTES SANTÉ — Jur-Gui 4.0
// Fichier: lib/Eleveures/New/sante/AlertesPage.dart
//
// Page de destination pour les notifications de type :
//   • cycle anormal (court, long, absence, anœstrus)
//   • alerte éleveur / consultation vétérinaire validée
//
// Remplace le TODO de main.dart (route '/sante').
// ============================================================
 
import 'package:depart/Eleveures/New/chaleur/AlerteCycleService.dart';
import 'package:depart/Eleveures/New/chaleur/AlerteCycleWidget.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
 
class AlertesPage extends StatefulWidget {
  const AlertesPage({super.key});
 
  @override
  State<AlertesPage> createState() => _AlertesPageState();
}
 
class _AlertesPageState extends State<AlertesPage> {
  final supabase          = Supabase.instance.client;
  final _alerteService    = AlerteCycleService();
 
  List<Map<String, dynamic>> _alertes = [];
  bool _chargement = true;
 
  @override
  void initState() {
    super.initState();
    _chargerAlertes();
  }
 
  // ── Charger toutes les alertes actives de l'éleveur ───────
  Future<void> _chargerAlertes() async {
    setState(() => _chargement = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) { setState(() => _chargement = false); return; }
 
      final data = await supabase
          .from('alertes_cycle')
          .select('*')
          .eq('user_id', userId)
          .eq('statut', 'active')
          .order('created_at', ascending: false);
 
      setState(() {
        _alertes    = List<Map<String, dynamic>>.from(data);
        _chargement = false;
      });
    } catch (e) {
      debugPrint('❌ Erreur chargement alertes: $e');
      setState(() => _chargement = false);
    }
  }
 
  // ── Marquer une alerte comme vue ──────────────────────────
  Future<void> _marquerVue(String alerteId) async {
    await _alerteService.marquerAlerte(alerteId: alerteId, statut: 'vue');
    setState(() {
      _alertes.removeWhere((a) => a['id'] == alerteId);
    });
  }
 
  // ── Marquer comme résolue ─────────────────────────────────
  Future<void> _marquerResolue(String alerteId) async {
    await _alerteService.marquerAlerte(alerteId: alerteId, statut: 'resolue');
    setState(() {
      _alertes.removeWhere((a) => a['id'] == alerteId);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Alerte marquée comme résolue'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
 
  // ── Convertir un enregistrement BD en ResultatAnalyseCycle ─
  ResultatAnalyseCycle _bdVersResultat(Map<String, dynamic> alerte) {
    final typeStr = alerte['type_alerte'] as String? ?? 'normal';
    final type = TypeAlerteCycle.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => TypeAlerteCycle.normal,
    );
    return ResultatAnalyseCycle(
      type           : type,
      intervalleJours: alerte['intervalle_jours'] as int?,
      message        : alerte['message']          as String? ?? '',
      suggestion     : alerte['suggestion']       as String? ?? '',
      nomAnimal      : alerte['nom_animal']        as String? ?? '',
    );
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Alertes santé',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerAlertes,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _alertes.isEmpty
              ? _buildEtatVide()
              : RefreshIndicator(
                  onRefresh: _chargerAlertes,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _alertes.length,
                    itemBuilder: (context, index) {
                      final alerte  = _alertes[index];
                      final resultat = _bdVersResultat(alerte);
                      return AlerteCycleWidget(
                        alerte: resultat,
                        onIgnorer: () => _marquerVue(alerte['id']),
                        onVoirVeterinaire: () async {
                          // Marquer comme résolue après consultation
                          await _marquerResolue(alerte['id']);
                        },
                      );
                    },
                  ),
                ),
    );
  }
 
  Widget _buildEtatVide() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline,
              size: 72, color: Colors.green.shade300),
          const SizedBox(height: 16),
          Text(
            'Aucune alerte active',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tous vos animaux sont en bonne santé reproductive.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _chargerAlertes,
            icon: const Icon(Icons.refresh),
            label: const Text('Vérifier à nouveau'),
          ),
        ],
      ),
    );
  }
}