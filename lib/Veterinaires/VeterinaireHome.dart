import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// HISTORIQUE MÉDICAL - Vue chronologique complète
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
  String _filtre = 'Tout'; // Tout, Consultations, Vaccinations, Traitements

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

      // TODO: Charger les consultations
      // final consultations = await supabase
      //     .from('consultations')
      //     .select('*, animal:animal_id(nom, race)')
      //     .order('date_consultation', ascending: false);

      // TODO: Charger les vaccinations
      // final vaccinations = await supabase
      //     .from('vaccinations')
      //     .select('*, animal:animal_id(nom, race)')
      //     .order('date_vaccination', ascending: false);

      // Exemple de données fictives pour démonstration
      historique = [
        {
          'type': 'consultation',
          'date': '2024-12-15',
          'animal_nom': 'Bella',
          'titre': 'Consultation de routine',
          'description': 'Examen général - RAS',
          'veterinaire': 'Dr. Diop',
        },
        {
          'type': 'vaccination',
          'date': '2024-12-10',
          'animal_nom': 'Max',
          'titre': 'Vaccination antirabique',
          'description': 'Première injection - Rappel dans 1 an',
          'veterinaire': 'Dr. Diop',
        },
        {
          'type': 'traitement',
          'date': '2024-12-05',
          'animal_nom': 'Luna',
          'titre': 'Traitement parasitaire',
          'description': 'Vermifuge administré',
          'veterinaire': 'Dr. Diop',
        },
      ];

      if (mounted) {
        setState(() {
          _historique = historique;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur chargement historique: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _historiqueFiltre {
    if (_filtre == 'Tout') return _historique;
    
    return _historique.where((item) {
      return item['type'] == _filtre.toLowerCase();
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Historique Médical"),
        backgroundColor: Colors.orange[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerHistorique,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtres rapides
          _buildFilterChips(),

          // Liste historique
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
                          itemBuilder: (context, index) {
                            final item = _historiqueFiltre[index];
                            return _buildHistoriqueItem(item);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filtres = ['Tout', 'Consultations', 'Vaccinations', 'Traitements'];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filtres.map((filtre) {
            final isSelected = _filtre == filtre;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(filtre),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _filtre = filtre);
                },
                selectedColor: Colors.orange[200],
                checkmarkColor: Colors.orange[900],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildHistoriqueItem(Map<String, dynamic> item) {
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
      case 'traitement':
        couleur = Colors.purple;
        icone = Icons.medication;
        break;
      default:
        couleur = Colors.grey;
        icone = Icons.help_outline;
    }

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
              // Icône et ligne verticale
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
                  if (true) // Toujours afficher la ligne pour la démo
                    Container(
                      width: 2,
                      height: 40,
                      color: couleur.withOpacity(0.3),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              
              // Contenu
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item['date'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: couleur.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item['type'].toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              color: couleur,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item['titre'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "🐑 ${item['animal_nom']}",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['description'],
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "👨‍⚕️ ${item['veterinaire']}",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
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
            "Aucun historique trouvé",
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _filtre != 'Tout' ? "Essayez un autre filtre" : "Les consultations apparaîtront ici",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Filtrer l'historique"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text("Tout afficher"),
              leading: Radio<String>(
                value: 'Tout',
                groupValue: _filtre,
                onChanged: (value) {
                  setState(() => _filtre = value!);
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: const Text("Consultations"),
              leading: Radio<String>(
                value: 'Consultations',
                groupValue: _filtre,
                onChanged: (value) {
                  setState(() => _filtre = value!);
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: const Text("Vaccinations"),
              leading: Radio<String>(
                value: 'Vaccinations',
                groupValue: _filtre,
                onChanged: (value) {
                  setState(() => _filtre = value!);
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: const Text("Traitements"),
              leading: Radio<String>(
                value: 'Traitements',
                groupValue: _filtre,
                onChanged: (value) {
                  setState(() => _filtre = value!);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
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
      case 'traitement':
        couleur = Colors.purple;
        icone = Icons.medication;
        break;
      default:
        couleur = Colors.grey;
        icone = Icons.help_outline;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icone, color: couleur),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item['titre'],
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow("Date", item['date'], Icons.calendar_today),
              _buildDetailRow("Animal", item['animal_nom'], Icons.pets),
              _buildDetailRow("Type", item['type'], icone),
              _buildDetailRow("Vétérinaire", item['veterinaire'], Icons.person),
              const SizedBox(height: 12),
              const Text(
                "Description :",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(item['description']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
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
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}