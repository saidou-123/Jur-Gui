import 'package:depart/Eleveures/Mon%20Troupeau/SupprimerAnimal/AnimalService.dart';
import 'package:depart/Veterinaires/constantes/models/note_eleveur_model.dart';
import 'package:depart/Veterinaires/constantes/services/consultation_service.dart';
import 'package:depart/Veterinaires/constantes/services/vaccination_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class DashboardVeterinaire extends StatefulWidget {
  const DashboardVeterinaire({super.key});

  @override
  State<DashboardVeterinaire> createState() => _DashboardVeterinaireState();
}

class _DashboardVeterinaireState extends State<DashboardVeterinaire> {
  final _db = Supabase.instance.client;
  final _animalSvc = AnimalService();
  final _consultSvc = ConsultationService();
  final _vaccSvc = VaccinationService();
  final _noteSvc = NoteService();

  int _nbAnimaux = 0;
  int _nbConsultations = 0;
  int _nbRappelsUrgents = 0;
  int _nbAlertes = 0;
  List<Map<String, dynamic>> _activiteRecente = [];
  List<Map<String, dynamic>> _alertes = [];
  bool _isLoading = true;

  String get _nomVet {
    final u = _db.auth.currentUser;
    return u?.userMetadata?['nom_complet'] ?? u?.email ?? 'Vétérinaire';
  }

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final animaux = await _animalSvc.chargerTousLesAnimaux();
      final consultations = await _consultSvc.chargerHistorique();
      final rappels = await _vaccSvc.chargerRappels();
      final alertes = await _noteSvc.alertesActives();

      // Activité récente : 5 dernières consultations
      final recentes = consultations.take(5).toList();

      if (mounted) {
        setState(() {
          _nbAnimaux = animaux.length;
          _nbConsultations = consultations.length;
          _nbRappelsUrgents = rappels.where((v) {
            final d = DateTime.tryParse(v['date_rappel']?.toString() ?? '');
            if (d == null) return false;
            return d.difference(DateTime.now()).inDays <= 7;
          }).length;
          _nbAlertes = alertes.length;
          _activiteRecente = recentes;
          _alertes = alertes.take(3).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Dashboard error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _charger,
              child: CustomScrollView(
                slivers: [
                  _buildAppBar(),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildStats(),
                        const SizedBox(height: 20),
                        if (_alertes.isNotEmpty) ...[
                          _buildSection('🚨 Alertes actives', Colors.red),
                          const SizedBox(height: 8),
                          ..._alertes.map(_buildAlerteCard),
                          const SizedBox(height: 20),
                        ],
                        _buildSection('📋 Activité récente', Colors.green[700]!),
                        const SizedBox(height: 8),
                        if (_activiteRecente.isEmpty)
                          _emptyCard('Aucune consultation enregistrée')
                        else
                          ..._activiteRecente.map(_buildActiviteCard),
                        const SizedBox(height: 80),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAppBar() => SliverAppBar(
    expandedHeight: 160,
    pinned: true,
    backgroundColor: Colors.green[700],
    flexibleSpace: FlexibleSpaceBar(
      background: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green[800]!, Colors.green[500]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Row(children: [
              CircleAvatar(
                backgroundColor: Colors.white24,
                child: const Icon(Icons.medical_services, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bonjour,', style: TextStyle(color: Colors.green[100], fontSize: 13)),
                  Text(_nomVet, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              )),
              IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _charger),
            ]),
          ],
        ),
      ),
    ),
  );

  Widget _buildStats() => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
    childAspectRatio: 1.5,
    children: [
      _statCard('Animaux suivis', '$_nbAnimaux', Icons.pets, Colors.green[600]!),
      _statCard('Consultations', '$_nbConsultations', Icons.medical_services, Colors.blue[600]!),
      _statCard('Rappels urgents', '$_nbRappelsUrgents', Icons.notifications_active,
          _nbRappelsUrgents > 0 ? Colors.red[600]! : Colors.grey[500]!),
      _statCard('Alertes ouvertes', '$_nbAlertes', Icons.warning_amber,
          _nbAlertes > 0 ? Colors.orange[600]! : Colors.grey[500]!),
    ],
  );

  Widget _statCard(String label, String val, IconData icon, Color color) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4))],
    ),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Icon(icon, color: color, size: 28),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(val, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ],
    ),
  );

  Widget _buildSection(String titre, Color color) => Row(children: [
    Text(titre, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
  ]);

  Widget _buildAlerteCard(Map<String, dynamic> a) {
    final priorite = a['priorite'] ?? 'normale';
    final color = priorite == 'urgente' ? Colors.red
        : priorite == 'haute' ? Colors.orange
        : Colors.amber;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.shade200),
      ),
      child: ListTile(
        leading: Icon(Icons.warning_amber, color: color, size: 28),
        title: Text(a['type_alerte']?.toString().replaceAll('_', ' ').toUpperCase() ?? '',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        subtitle: Text(a['message'] ?? '', style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: TextButton(
          onPressed: () async {
            await _noteSvc.resoudreAlerte(a['id']);
            _charger();
          },
          child: const Text('Résoudre', style: TextStyle(fontSize: 12)),
        ),
      ),
    );
  }

  Widget _buildActiviteCard(Map<String, dynamic> c) {
    final date = _fmt(c['date_consultation']?.toString() ?? '');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.green[50], shape: BoxShape.circle),
          child: Icon(Icons.medical_services, color: Colors.green[700], size: 20),
        ),
        title: Text(c['motif'] ?? 'Consultation', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(date, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        trailing: c['diagnostic'] != null
            ? const Icon(Icons.check_circle, color: Colors.green, size: 18)
            : null,
      ),
    );
  }

  Widget _emptyCard(String msg) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
    child: Center(child: Text(msg, style: TextStyle(color: Colors.grey[600]))),
  );

  String _fmt(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) { return iso; }
  }
}