import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ✅ ÉTAPE 4 : Import des constantes partagées
import 'package:depart/constants.dart';

// ============================================================
// HISTORIQUE MÉDICAL VÉTÉRINAIRE
// ✅ ÉTAPE 1 : Filtrage sécurisé par veterinaire_id
// ✅ ÉTAPE 2 : Vue SQL (zéro requête N+1)
// ✅ ÉTAPE 4 : Constantes partagées (FiltreHistorique, Tables)
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

  // ✅ Utilise FiltreHistorique.tout au lieu de 'tout' en dur
  String _filtre = FiltreHistorique.tout;
  String? _veterinaireId;

  @override
  void initState() {
    super.initState();
    _veterinaireId = supabase.auth.currentUser?.id;
    _chargerHistorique();
  }

  Future<void> _chargerHistorique() async {
    if (!mounted) return;

    if (_veterinaireId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expirée. Veuillez vous reconnecter.'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ✅ Tables.historiqueComplet au lieu de 'historique_medical_complet'
      final data = await supabase
          .from(Tables.historiqueComplet)
          .select()
          .eq('veterinaire_id', _veterinaireId!)
          .order('date_acte', ascending: false);

      if (mounted) {
        setState(() {
          _historique = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement historique vét: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _historiqueFiltre {
    // ✅ Compare avec FiltreHistorique.tout au lieu de 'tout'
    if (_filtre == FiltreHistorique.tout) return _historique;
    return _historique
        .where((item) => item['type_acte'] == _filtre)
        .toList();
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return 'Date inconnue';
    try {
      final dt = DateTime.parse(iso);
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
        title: const Text('Historique Médical'),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '${_historique.length} acte(s)',
                  style: const TextStyle(
                      fontSize: 13, color: Colors.white70),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerHistorique,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.orange[50],
            child: Row(
              children: [
                Icon(Icons.verified_user,
                    color: Colors.orange[700], size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Affichage limité à vos actes médicaux — chargement optimisé',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[900],
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
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
                              _buildItem(_historiqueFiltre[index], index),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          // ✅ FiltreHistorique.filtres au lieu de la liste définie en dur
          children: FiltreHistorique.filtres.map((f) {
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

  Widget _buildItem(Map<String, dynamic> item, int index) {
    // ✅ TypeActe.consultation au lieu de 'consultation'
    final isConsultation =
        item['type_acte'] == TypeActe.consultation;
    final couleur = isConsultation ? Colors.green : Colors.blue;
    final icone =
        isConsultation ? Icons.medical_services : Icons.vaccines;
    final isLast = index == _historiqueFiltre.length - 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showDetail(item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: couleur.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: couleur, width: 2),
                    ),
                    child: Icon(icone, color: couleur, size: 24),
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDate(item['date_acte']?.toString()),
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: couleur.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            // ✅ FiltreHistorique.labelConsultation
                            isConsultation
                                ? FiltreHistorique.labelConsultation
                                    .toUpperCase()
                                : FiltreHistorique.labelVaccination
                                    .toUpperCase(),
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
                      item['titre'] ?? 'Sans titre',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '🐑 ${item['animal_nom'] ?? 'Inconnu'}'
                      '${item['animal_race'] != null && item['animal_race'].toString().isNotEmpty ? ' (${item['animal_race']})' : ''}',
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['description'] ?? '',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item['date_rappel'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Rappel: ${_formatDate(item['date_rappel']?.toString())}',
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
          Text('Aucun historique trouvé',
              style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text(
            _filtre != FiltreHistorique.tout
                ? 'Essayez un autre filtre'
                : 'Vos actes médicaux apparaîtront ici',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  void _showDetail(Map<String, dynamic> item) {
    final isConsultation =
        item['type_acte'] == TypeActe.consultation;
    final couleur = isConsultation ? Colors.green : Colors.blue;
    final icone =
        isConsultation ? Icons.medical_services : Icons.vaccines;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icone, color: couleur),
            const SizedBox(width: 8),
            Expanded(
              child: Text(item['titre'] ?? 'Détail',
                  style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Date',
                  _formatDate(item['date_acte']?.toString()),
                  Icons.calendar_today),
              _detailRow(
                  'Animal',
                  '${item['animal_nom'] ?? 'Inconnu'}'
                      '${item['animal_race'] != null && item['animal_race'].toString().isNotEmpty ? ' (${item['animal_race']})' : ''}',
                  Icons.pets),
              if (isConsultation) ...[
                if (item['diagnostic'] != null)
                  _detailRow('Diagnostic', item['diagnostic'],
                      Icons.assignment),
                if (item['traitement'] != null)
                  _detailRow('Traitement', item['traitement'],
                      Icons.medication),
                if (item['temperature_c'] != null)
                  _detailRow('Température',
                      '${item['temperature_c']} °C',
                      Icons.thermostat),
                if (item['poids_kg'] != null)
                  _detailRow('Poids', '${item['poids_kg']} kg',
                      Icons.monitor_weight),
              ] else ...[
                if (item['nom_vaccin'] != null)
                  _detailRow(
                      'Vaccin', item['nom_vaccin'], Icons.vaccines),
                if (item['date_rappel'] != null)
                  _detailRow(
                      'Rappel prévu',
                      _formatDate(
                          item['date_rappel']?.toString()),
                      Icons.event_repeat),
                if (item['lot'] != null)
                  _detailRow('Lot', item['lot'], Icons.tag),
              ],
              if (item['observations'] != null &&
                  item['observations'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Observations :',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(item['observations']),
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

  Widget _detailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.orange[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[600])),
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
}