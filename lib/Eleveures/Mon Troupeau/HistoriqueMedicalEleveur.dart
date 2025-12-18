import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// 1. HISTORIQUE MÉDICAL - VERSION ÉLEVEUR (LECTURE SEULE)
// ============================================================
class HistoriqueMedicalEleveur extends StatefulWidget {
  const HistoriqueMedicalEleveur({super.key});

  @override
  State<HistoriqueMedicalEleveur> createState() => _HistoriqueMedicalEleveurState();
}

class _HistoriqueMedicalEleveurState extends State<HistoriqueMedicalEleveur> {
  final supabase = Supabase.instance.client;
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
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception("Non connecté");

      List<Map<String, dynamic>> historique = [];

      // Charger consultations de MES animaux uniquement
      // final consultations = await supabase
      //     .from('consultations')
      //     .select('''
      //       *,
      //       nouveaux_nee!inner(nom, race, user_id),
      //       animal_acheter!inner(nom, race, user_id)
      //     ''')
      //     .or('nouveaux_nee.user_id.eq.$userId,animal_acheter.user_id.eq.$userId')
      //     .order('date_consultation', ascending: false);

      // Données fictives pour démonstration
      historique = [
        {
          'type': 'consultation',
          'date': '2024-12-15',
          'animal_nom': 'Bella',
          'titre': 'Consultation de routine',
          'description': 'Examen général - RAS',
          'veterinaire': 'Dr. Diop',
          'diagnostic': 'Bonne santé générale',
          'traitement': 'Aucun traitement nécessaire',
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
          'type': 'consultation',
          'date': '2024-12-05',
          'animal_nom': 'Luna',
          'titre': 'Traitement parasitaire',
          'description': 'Vermifuge administré',
          'veterinaire': 'Dr. Diop',
          'diagnostic': 'Parasites intestinaux',
          'traitement': 'Vermifuge - 1 dose',
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
    return _historique.where((item) => item['type'] == _filtre.toLowerCase()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Historique Médical"),
        backgroundColor: Colors.green[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerHistorique,
          ),
        ],
      ),
      body: Column(
        children: [
          // Bannière info lecture seule
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.blue[50],
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "👁️ Mode consultation : Vous pouvez voir l'historique médical de vos animaux",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue[900],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Filtres
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
    final filtres = ['Tout', 'Consultations', 'Vaccinations'];
    
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
                selectedColor: Colors.green[200],
                checkmarkColor: Colors.green[900],
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
                  Container(
                    width: 2,
                    height: 40,
                    color: couleur.withOpacity(0.3),
                  ),
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
          Icon(Icons.medical_information, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            "Aucun historique médical",
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            "Les consultations vétérinaires apparaîtront ici",
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
              // Bannière lecture seule
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.visibility, color: Colors.blue[700], size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Consultation uniquement",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[900],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              _buildDetailRow("Date", item['date'], Icons.calendar_today),
              _buildDetailRow("Animal", item['animal_nom'], Icons.pets),
              _buildDetailRow("Vétérinaire", item['veterinaire'], Icons.person),
              
              if (item['diagnostic'] != null) ...[
                const SizedBox(height: 12),
                const Text(
                  "Diagnostic :",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(item['diagnostic']),
              ],
              
              if (item['traitement'] != null) ...[
                const SizedBox(height: 12),
                const Text(
                  "Traitement :",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(item['traitement']),
              ],
              
              const SizedBox(height: 12),
              const Text(
                "Description :",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
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
          Icon(icon, size: 20, color: Colors.green[700]),
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

// ============================================================
// 2. RAPPELS DE VACCINATION - VERSION ÉLEVEUR (LECTURE SEULE)
// ============================================================
class RappelsVaccinationEleveur extends StatefulWidget {
  const RappelsVaccinationEleveur({super.key});

  @override
  State<RappelsVaccinationEleveur> createState() => _RappelsVaccinationEleveurState();
}

class _RappelsVaccinationEleveurState extends State<RappelsVaccinationEleveur> with SingleTickerProviderStateMixin {
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
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception("Non connecté");

      // TODO: Charger vaccinations de MES animaux uniquement
      // final vaccinations = await supabase
      //     .from('vaccinations')
      //     .select('''
      //       *,
      //       nouveaux_nee!inner(nom, race, user_id),
      //       animal_acheter!inner(nom, race, user_id)
      //     ''')
      //     .or('nouveaux_nee.user_id.eq.$userId,animal_acheter.user_id.eq.$userId')
      //     .order('date_vaccination', ascending: false);

      // Données fictives
      _vaccinationsRecentes = [
        {
          'animal_nom': 'Bella',
          'animal_race': 'Ladoum',
          'nom_vaccin': 'Antirabique',
          'date_vaccination': '2024-12-10',
          'date_rappel': '2025-12-10',
          'veterinaire': 'Dr. Diop',
          'lot': 'LOT-2024-001',
        },
        {
          'animal_nom': 'Max',
          'animal_race': 'Peulh Peulh',
          'nom_vaccin': 'Entérotoxémie',
          'date_vaccination': '2024-11-15',
          'date_rappel': '2025-05-15',
          'veterinaire': 'Dr. Diop',
          'lot': 'LOT-2024-002',
        },
      ];

      _rappelsEnCours = [
        {
          'animal_nom': 'Luna',
          'animal_race': 'Touabire',
          'nom_vaccin': 'Antirabique',
          'date_rappel': '2024-12-20',
          'jours_restants': 2,
          'statut': 'urgent',
        },
        {
          'animal_nom': 'Rocky',
          'animal_race': 'Ladoum',
          'nom_vaccin': 'Peste des petits ruminants',
          'date_rappel': '2024-12-25',
          'jours_restants': 7,
          'statut': 'proche',
        },
        {
          'animal_nom': 'Bella',
          'animal_race': 'Ladoum',
          'nom_vaccin': 'Entérotoxémie',
          'date_rappel': '2025-01-07',
          'jours_restants': 20,
          'statut': 'normal',
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
        backgroundColor: Colors.green[700],
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
      body: Column(
        children: [
          // Bannière info lecture seule
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.blue[50],
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "👁️ Mode consultation : Suivez les vaccinations de vos animaux",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue[900],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildVaccinationsRecentes(),
                      _buildRappels(),
                    ],
                  ),
          ),
        ],
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
            Text("Aucune vaccination enregistrée", style: TextStyle(fontSize: 16)),
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
            const Text("Aucun rappel en attente", style: TextStyle(fontSize: 16)),
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
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.vaccines, color: Colors.green[700], size: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vaccination['nom_vaccin'],
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "🐑 ${vaccination['animal_nom']} (${vaccination['animal_race']})",
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
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
            _buildInfoItem(Icons.person, "Vétérinaire", vaccination['veterinaire']),
            if (vaccination['lot'] != null) ...[
              const SizedBox(height: 8),
              _buildInfoItem(Icons.qr_code, "Lot", vaccination['lot']),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRappelCard(Map<String, dynamic> rappel) {
    Color couleur;
    String message;
    IconData iconeStatut;
    
    if (rappel['jours_restants'] <= 7) {
      couleur = Colors.red;
      message = "⚠️ URGENT";
      iconeStatut = Icons.error;
    } else if (rappel['jours_restants'] <= 14) {
      couleur = Colors.orange;
      message = "⚡ Bientôt";
      iconeStatut = Icons.warning;
    } else {
      couleur = Colors.blue;
      message = "📅 À venir";
      iconeStatut = Icons.info;
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
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "🐑 ${rappel['animal_nom']} (${rappel['animal_race']})",
                          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(iconeStatut, size: 16, color: couleur),
                        const SizedBox(width: 4),
                        Text(
                          message,
                          style: TextStyle(
                            color: couleur,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
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
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Contactez votre vétérinaire pour prendre rendez-vous",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue[900],
                        ),
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
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}