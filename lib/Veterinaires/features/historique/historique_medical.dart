import 'package:depart/Veterinaires/constantes/services/consultation_service.dart';
import 'package:depart/Veterinaires/constantes/services/vaccination_service.dart';
import 'package:flutter/material.dart';


class HistoriqueMedical extends StatefulWidget {
  const HistoriqueMedical({super.key});

  @override
  State<HistoriqueMedical> createState() => _HistoriqueMedicalState();
}

class _HistoriqueMedicalState extends State<HistoriqueMedical> {
  final _consultService = ConsultationService();
  final _vaccService = VaccinationService();

  List<Map<String, dynamic>> _historique = [];
  bool _isLoading = true;
  String _filtre = 'Tout';

  @override
  void initState() {
    super.initState();
    _chargerHistorique();
  }

  Future<void> _chargerHistorique() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final consultations = await _consultService.chargerHistorique();
      final vaccinations = await _vaccService.chargerToutes();

      final historique = <Map<String, dynamic>>[];

      for (var c in consultations) {
        historique.add({
          'type': 'consultation',
          'date': c['date_consultation']?.toString() ?? '',
          'animal_id': c['animal_id'],
          'source': c['source'],
          'titre': c['motif'] ?? 'Consultation',
          'description': c['diagnostic'] ?? '',
          'traitement': c['traitement'] ?? '',
        });
      }

      for (var v in vaccinations) {
        historique.add({
          'type': 'vaccination',
          'date': v['date_vaccination']?.toString() ?? '',
          'animal_id': v['animal_id'],
          'source': v['source'],
          'titre': v['nom_vaccin'] ?? 'Vaccination',
          'description': v['observations'] ?? '',
          'date_rappel': v['date_rappel'],
        });
      }

      // Tri chronologique décroissant
      historique.sort((a, b) => b['date'].compareTo(a['date']));

      if (mounted) setState(() { _historique = historique; _isLoading = false; });
    } catch (e) {
      debugPrint('Erreur historique: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _historiqueFiltre {
    if (_filtre == 'Tout') return _historique;
    return _historique.where((i) => i['type'] == _filtre.toLowerCase()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique Médical'),
        backgroundColor: Colors.orange[700],
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _chargerHistorique),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _historiqueFiltre.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _chargerHistorique,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _historiqueFiltre.length,
                          itemBuilder: (_, i) => _buildItem(_historiqueFiltre[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: ['Tout', 'Consultation', 'Vaccination'].map((f) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(f),
              selected: _filtre == f,
              onSelected: (_) => setState(() => _filtre = f),
              selectedColor: Colors.orange[200],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> item) {
    final isConsult = item['type'] == 'consultation';
    final color = isConsult ? Colors.green : Colors.blue;
    final icon = isConsult ? Icons.medical_services : Icons.vaccines;
    final date = _formatDate(item['date']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(date, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item['type'].toString().toUpperCase(),
                          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(item['titre'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  if (item['description']?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(item['description'], style: TextStyle(fontSize: 13, color: Colors.grey[600]), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  if (item['date_rappel'] != null) ...[
                    const SizedBox(height: 4),
                    Text('Rappel: ${_formatDate(item['date_rappel'])}', style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.history, size: 80, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Text('Aucun historique', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
      ],
    ),
  );

  String _formatDate(String iso) {
    if (iso.isEmpty) return 'Date inconnue';
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) { return iso; }
  }
}