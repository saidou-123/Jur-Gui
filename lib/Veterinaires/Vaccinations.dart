import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// VACCINATIONS - Gestion et Rappels
// ============================================================
class Vaccinations extends StatefulWidget {
  const Vaccinations({super.key});

  @override
  State<Vaccinations> createState() => _VaccinationsState();
}

class _VaccinationsState extends State<Vaccinations> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;
  
  List<Map<String, dynamic>> _vaccinationsRecentes = [];
  List<Map<String, dynamic>> _rappelsEnCours = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _chargerVaccinations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _chargerVaccinations() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      // TODO: Charger les vaccinations depuis Supabase
      // final vaccinations = await supabase
      //     .from('vaccinations')
      //     .select('*, animal:animal_id(nom, race, image_url)')
      //     .order('date_vaccination', ascending: false);

      // Données fictives pour démonstration
  
      
      _vaccinationsRecentes = [
        {
          'id': '1',
          'animal_nom': 'Bella',
          'animal_race': 'Ladoum',
          'nom_vaccin': 'Antirabique',
          'date_vaccination': '2024-12-10',
          'date_rappel': '2025-12-10',
          'veterinaire': 'Dr. Diop',
          'statut': 'ok',
        },
        {
          'id': '2',
          'animal_nom': 'Max',
          'animal_race': 'Peulh Peulh',
          'nom_vaccin': 'Entérotoxémie',
          'date_vaccination': '2024-11-15',
          'date_rappel': '2025-05-15',
          'veterinaire': 'Dr. Diop',
          'statut': 'ok',
        },
      ];

      _rappelsEnCours = [
        {
          'id': '3',
          'animal_nom': 'Luna',
          'animal_race': 'Touabire',
          'nom_vaccin': 'Antirabique',
          'date_rappel': '2024-12-20',
          'jours_restants': 5,
          'statut': 'urgent',
        },
        {
          'id': '4',
          'animal_nom': 'Rocky',
          'animal_race': 'Ladoum',
          'nom_vaccin': 'Peste des petits ruminants',
          'date_rappel': '2024-12-25',
          'jours_restants': 10,
          'statut': 'proche',
        },
      ];

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Erreur chargement vaccinations: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Vaccinations"),
        backgroundColor: Colors.purple[700],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: "Récentes", icon: Icon(Icons.history)),
            Tab(text: "Rappels", icon: Icon(Icons.notifications_active)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerVaccinations,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildVaccinationsRecentes(),
                _buildRappels(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ajouterVaccination,
        icon: const Icon(Icons.add),
        label: const Text("Nouvelle Vaccination"),
        backgroundColor: Colors.purple[700],
      ),
    );
  }

  Widget _buildVaccinationsRecentes() {
    if (_vaccinationsRecentes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.vaccines, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              "Aucune vaccination enregistrée",
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _chargerVaccinations,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _vaccinationsRecentes.length,
        itemBuilder: (context, index) {
          final vaccination = _vaccinationsRecentes[index];
          return _buildVaccinationCard(vaccination);
        },
      ),
    );
  }

  Widget _buildRappels() {
    if (_rappelsEnCours.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 80, color: Colors.green[400]),
            const SizedBox(height: 16),
            const Text(
              "Aucun rappel en attente",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              "Tous les vaccins sont à jour !",
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _chargerVaccinations,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _rappelsEnCours.length,
        itemBuilder: (context, index) {
          final rappel = _rappelsEnCours[index];
          return _buildRappelCard(rappel);
        },
      ),
    );
  }

  Widget _buildVaccinationCard(Map<String, dynamic> vaccination) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.vaccines, color: Colors.purple[700], size: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vaccination['nom_vaccin'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "🐑 ${vaccination['animal_nom']} (${vaccination['animal_race']})",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    Icons.calendar_today,
                    "Date",
                    vaccination['date_vaccination'],
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    Icons.event_repeat,
                    "Rappel",
                    vaccination['date_rappel'],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInfoItem(
              Icons.person,
              "Vétérinaire",
              vaccination['veterinaire'],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRappelCard(Map<String, dynamic> rappel) {
    Color couleur;
    String message;
    
    if (rappel['jours_restants'] <= 7) {
      couleur = Colors.red;
      message = "⚠️ URGENT";
    } else if (rappel['jours_restants'] <= 14) {
      couleur = Colors.orange;
      message = "⚡ Bientôt";
    } else {
      couleur = Colors.blue;
      message = "📅 À venir";
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: couleur, width: 4)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rappel['nom_vaccin'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "🐑 ${rappel['animal_nom']} (${rappel['animal_race']})",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: couleur.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: couleur, width: 2),
                    ),
                    child: Text(
                      message,
                      style: TextStyle(
                        color: couleur,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.access_time, size: 20, color: couleur),
                  const SizedBox(width: 8),
                  Text(
                    "Dans ${rappel['jours_restants']} jours",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: couleur,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Date du rappel : ${rappel['date_rappel']}",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _effectuerVaccination(rappel);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text("Marquer comme effectué"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: couleur,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
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
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _ajouterVaccination() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nouvelle Vaccination"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Formulaire de vaccination à implémenter :"),
              const SizedBox(height: 12),
              const Text("• Sélection de l'animal"),
              const Text("• Nom du vaccin"),
              const Text("• Date d'administration"),
              const Text("• Date du rappel"),
              const Text("• Observations"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Enregistrer vaccination
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple[700],
            ),
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );
  }

  void _effectuerVaccination(Map<String, dynamic> rappel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmer la vaccination"),
        content: Text(
          "Confirmer que la vaccination ${rappel['nom_vaccin']} "
          "pour ${rappel['animal_nom']} a été effectuée ?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Marquer comme effectué et créer nouvelle entrée
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("✅ Vaccination enregistrée"),
                  backgroundColor: Colors.green,
                ),
              );
              _chargerVaccinations();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text("Confirmer"),
          ),
        ],
      ),
    );
  }
}