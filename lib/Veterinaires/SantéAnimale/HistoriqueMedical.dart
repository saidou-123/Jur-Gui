import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// HISTORIQUE MÉDICAL — version synchronisée avec Supabase
// ============================================================
class HistoriqueMedical extends StatefulWidget {
  const HistoriqueMedical({super.key});

  @override
  State<HistoriqueMedical> createState() => _HistoriqueMedicalState();
}

class _HistoriqueMedicalState extends State<HistoriqueMedical> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _historique = [];
  bool _isLoading = true;

  // ✅ CORRIGÉ : valeurs en minuscule pour matcher item['type']
  String _filtre = 'tout';

  @override
  void initState() {
    super.initState();
    _chargerHistorique();
  }

  Future<void> _chargerHistorique() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      List<Map<String, dynamic>> historique = [];

      // ✅ Charger consultations depuis Supabase
      final consultations =
          await supabase.from('consultations').select('*').order(
                'date_consultation',
                ascending: false,
              );

      for (var c in consultations) {
        // Récupérer le nom de l'animal selon la source
        final nomAnimal =
            await _getNomAnimal(c['animal_id']?.toString(), c['source']);
        historique.add({
          'type': 'consultation',
          'date': c['date_consultation']?.toString() ?? '',
          'animal_nom': nomAnimal,
          'animal_id': c['animal_id'],
          'source': c['source'],
          'titre': 'Consultation — ${c['motif'] ?? 'N/A'}',
          'description': c['diagnostic'] ?? c['examen_clinique'] ?? 'N/A',
          'details': c,
        });
      }

      // ✅ Charger vaccinations depuis Supabase
      final vaccinations =
          await supabase.from('vaccinations').select('*').order(
                'date_vaccination',
                ascending: false,
              );

      for (var v in vaccinations) {
        final nomAnimal =
            await _getNomAnimal(v['animal_id']?.toString(), v['source']);
        historique.add({
          'type': 'vaccination',
          'date': v['date_vaccination']?.toString() ?? '',
          'animal_nom': nomAnimal,
          'animal_id': v['animal_id'],
          'source': v['source'],
          'titre': 'Vaccination — ${v['nom_vaccin'] ?? 'N/A'}',
          'description': v['observations'] ?? 'Aucune observation',
          'date_rappel': v['date_rappel'],
          'details': v,
        });
      }

      // Trier par date décroissante
      historique.sort((a, b) {
        try {
          final da = DateTime.parse(a['date']);
          final db = DateTime.parse(b['date']);
          return db.compareTo(da);
        } catch (_) {
          return 0;
        }
      });

      if (mounted) {
        setState(() {
          _historique = historique;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement historique: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String> _getNomAnimal(String? animalId, String? source) async {
    if (animalId == null || source == null) return 'Animal inconnu';
    try {
      final table =
          source == 'nee' ? 'nouveaux_nee' : 'animal_acheter';
      final result = await supabase
          .from(table)
          .select('nom')
          .eq('id', animalId)
          .maybeSingle();
      return result?['nom']?.toString() ?? 'Animal inconnu';
    } catch (_) {
      return 'Animal inconnu';
    }
  }

  // ✅ CORRIGÉ : filtre en minuscule, correspondance exacte avec item['type']
  List<Map<String, dynamic>> get _historiqueFiltre {
    if (_filtre == 'tout') return _historique;
    return _historique
        .where((item) => item['type'] == _filtre)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique Médical'),
        backgroundColor: Colors.orange[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerHistorique,
          ),
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
                          itemBuilder: (context, index) =>
                              _buildHistoriqueItem(
                                  _historiqueFiltre[index], index),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    // ✅ CORRIGÉ : valeurs en minuscule pour correspondre à item['type']
    final filtres = [
      {'label': 'Tout', 'value': 'tout'},
      {'label': 'Consultations', 'value': 'consultation'},
      {'label': 'Vaccinations', 'value': 'vaccination'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filtres.map((f) {
            final isSelected = _filtre == f['value'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(f['label']!),
                selected: isSelected,
                onSelected: (_) =>
                    setState(() => _filtre = f['value']!),
                selectedColor: Colors.orange[200],
                checkmarkColor: Colors.orange[900],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildHistoriqueItem(
      Map<String, dynamic> item, int index) {
    Color couleur;
    IconData icone;

    switch (item['type']) {
      case 'consultation':
        couleur = Colors.green;
        icone = Icons.medical_services;
        break;
      case 'vaccination':
        couleur = Colors.blue;
        icone = Icons.vaccines;
        break;
      default:
        couleur = Colors.grey;
        icone = Icons.help_outline;
    }

    final isLast = index == _historiqueFiltre.length - 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showDetailDialog(item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icône + ligne verticale
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: couleur.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: couleur, width: 2),
                    ),
                    child:
                        Icon(icone, color: couleur, size: 24),
                  ),
                  if (!isLast)
                    Container(
                        width: 2,
                        height: 30,
                        color: couleur.withOpacity(0.3)),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDate(item['date']),
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: couleur.withOpacity(0.1),
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: Text(
                            item['type'].toString().toUpperCase(),
                            style: TextStyle(
                                fontSize: 10,
                                color: couleur,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item['titre'],
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('🐑 ${item['animal_nom']}',
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700])),
                    const SizedBox(height: 4),
                    Text(
                      item['description'],
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item['date_rappel'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '🔔 Rappel: ${_formatDate(item['date_rappel'].toString())}',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                              fontWeight: FontWeight.w500),
                        ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Aucun historique trouvé',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            _filtre != 'tout'
                ? 'Essayez un autre filtre'
                : 'Les actes médicaux apparaîtront ici',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  void _showDetailDialog(Map<String, dynamic> item) {
    Color couleur;
    IconData icone;
    switch (item['type']) {
      case 'consultation':
        couleur = Colors.green;
        icone = Icons.medical_services;
        break;
      case 'vaccination':
        couleur = Colors.blue;
        icone = Icons.vaccines;
        break;
      default:
        couleur = Colors.grey;
        icone = Icons.help_outline;
    }

    final details = item['details'] as Map<String, dynamic>? ?? {};

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icone, color: couleur),
            const SizedBox(width: 8),
            Expanded(
              child: Text(item['titre'],
                  style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                  'Date', _formatDate(item['date']), Icons.calendar_today),
              _buildDetailRow(
                  'Animal', item['animal_nom'], Icons.pets),
              _buildDetailRow(
                  'Type', item['type'], icone),
              if (item['type'] == 'consultation') ...[
                if (details['motif'] != null)
                  _buildDetailRow(
                      'Motif', details['motif'], Icons.comment),
                if (details['diagnostic'] != null)
                  _buildDetailRow('Diagnostic', details['diagnostic'],
                      Icons.assignment),
                if (details['traitement'] != null)
                  _buildDetailRow('Traitement', details['traitement'],
                      Icons.medication),
                if (details['temperature_c'] != null)
                  _buildDetailRow('Température',
                      '${details['temperature_c']} °C', Icons.thermostat),
                if (details['poids_kg'] != null)
                  _buildDetailRow('Poids',
                      '${details['poids_kg']} kg', Icons.monitor_weight),
              ],
              if (item['type'] == 'vaccination') ...[
                if (details['nom_vaccin'] != null)
                  _buildDetailRow(
                      'Vaccin', details['nom_vaccin'], Icons.vaccines),
                if (item['date_rappel'] != null)
                  _buildDetailRow('Rappel prévu',
                      _formatDate(item['date_rappel'].toString()),
                      Icons.event_repeat),
                if (details['lot'] != null)
                  _buildDetailRow('Lot', details['lot'], Icons.tag),
              ],
              if (details['observations'] != null &&
                  details['observations'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Observations :',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(details['observations']),
              ],
            ],
          ),
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

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.orange[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return 'Date inconnue';
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    } catch (_) {
      return isoDate;
    }
  }
}