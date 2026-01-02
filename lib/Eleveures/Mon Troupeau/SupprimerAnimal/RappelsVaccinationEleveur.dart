import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// RAPPELS DE VACCINATION - VERSION ÉLEVEUR (LECTURE SEULE)
// ============================================================
class RappelsVaccinationEleveur extends StatefulWidget {
  const RappelsVaccinationEleveur({super.key});

  @override
  State<RappelsVaccinationEleveur> createState() => _RappelsVaccinationEleveurState();
}

class _RappelsVaccinationEleveurState extends State<RappelsVaccinationEleveur> 
    with SingleTickerProviderStateMixin {
  
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

      debugPrint("📊 Chargement des vaccinations et rappels...");

      // ========== CHARGER LES RAPPELS DEPUIS LA VUE ==========
      final rappelsData = await supabase
          .from('rappels_vaccination_urgents')
          .select('*')
          .order('jours_restants', ascending: true);

      debugPrint("✅ ${rappelsData.length} rappels chargés");

      // ========== CHARGER LES VACCINATIONS RÉCENTES ==========
      List<Map<String, dynamic>> vaccinationsRecentes = [];

      // Vaccinations des animaux achetés
      try {
        final vaccinationsAchetes = await supabase
            .from('vaccinations')
            .select('*')
            .eq('source', 'achete')
            .order('date_vaccination', ascending: false)
            .limit(50);

        for (var vaccination in vaccinationsAchetes) {
          try {
            // Récupérer les infos de l'animal
            final animalData = await supabase
                .from('animal_acheter')
                .select('nom, race, user_id')
                .eq('id', vaccination['animal_id'])
                .maybeSingle();

            // Vérifier si c'est notre animal
            if (animalData != null && animalData['user_id'] == userId) {
              // Récupérer le nom du vétérinaire
              String veterinaireName = "Dr. Inconnu";
              try {
                final vetData = await supabase
                    .from('users')
                    .select('nom_complet, prenom, nom, email')
                    .eq('id', vaccination['veterinaire_id'])
                    .maybeSingle();

                if (vetData != null) {
                  veterinaireName = vetData['nom_complet'] ?? 
                                    (vetData['prenom'] != null && vetData['nom'] != null 
                                      ? '${vetData['prenom']} ${vetData['nom']}'
                                      : vetData['email']?.split('@')[0] ?? 'Dr. Inconnu');
                }
              } catch (e) {
                debugPrint("Erreur récupération vétérinaire: $e");
              }

              vaccinationsRecentes.add({
                'animal_nom': animalData['nom'] ?? 'Animal inconnu',
                'animal_race': animalData['race'] ?? 'Race inconnue',
                'nom_vaccin': vaccination['nom_vaccin'],
                'date_vaccination': _formatDate(vaccination['date_vaccination'].toString()),
                'date_rappel': vaccination['date_rappel'] != null 
                    ? _formatDate(vaccination['date_rappel'].toString())
                    : 'Aucun rappel',
                'veterinaire': veterinaireName,
                'lot': vaccination['lot'] ?? 'N/A',
                'observations': vaccination['observations'] ?? '',
              });
            }
          } catch (e) {
            debugPrint("Erreur traitement vaccination achete: $e");
          }
        }
      } catch (e) {
        debugPrint("Erreur chargement vaccinations achetes: $e");
      }

      // Vaccinations des nouveaux-nés
      try {
        final vaccinationsNees = await supabase
            .from('vaccinations')
            .select('*')
            .eq('source', 'nee')
            .order('date_vaccination', ascending: false)
            .limit(50);

        for (var vaccination in vaccinationsNees) {
          try {
            // Récupérer les infos de l'animal
            final animalData = await supabase
                .from('nouveaux_nee')
                .select('nom, race, user_id')
                .eq('id', vaccination['animal_id'])
                .maybeSingle();

            // Vérifier si c'est notre animal
            if (animalData != null && animalData['user_id'] == userId) {
              // Récupérer le nom du vétérinaire
              String veterinaireName = "Dr. Inconnu";
              try {
                final vetData = await supabase
                    .from('users')
                    .select('nom_complet, prenom, nom, email')
                    .eq('id', vaccination['veterinaire_id'])
                    .maybeSingle();

                if (vetData != null) {
                  veterinaireName = vetData['nom_complet'] ?? 
                                    (vetData['prenom'] != null && vetData['nom'] != null 
                                      ? '${vetData['prenom']} ${vetData['nom']}'
                                      : vetData['email']?.split('@')[0] ?? 'Dr. Inconnu');
                }
              } catch (e) {
                debugPrint("Erreur récupération vétérinaire: $e");
              }

              vaccinationsRecentes.add({
                'animal_nom': animalData['nom'] ?? 'Animal inconnu',
                'animal_race': animalData['race'] ?? 'Race inconnue',
                'nom_vaccin': vaccination['nom_vaccin'],
                'date_vaccination': _formatDate(vaccination['date_vaccination'].toString()),
                'date_rappel': vaccination['date_rappel'] != null 
                    ? _formatDate(vaccination['date_rappel'].toString())
                    : 'Aucun rappel',
                'veterinaire': veterinaireName,
                'lot': vaccination['lot'] ?? 'N/A',
                'observations': vaccination['observations'] ?? '',
              });
            }
          } catch (e) {
            debugPrint("Erreur traitement vaccination nee: $e");
          }
        }
      } catch (e) {
        debugPrint("Erreur chargement vaccinations nees: $e");
      }

      if (mounted) {
        setState(() {
          _rappelsEnCours = List<Map<String, dynamic>>.from(rappelsData);
          _vaccinationsRecentes = vaccinationsRecentes;
          _isLoading = false;
        });

        // Notification pour rappels urgents
        final nbUrgents = _rappelsEnCours
            .where((r) => r['statut_urgence'] == 'urgent')
            .length;

        if (nbUrgents > 0) {
          _showSnackBar(
            "⚠️ $nbUrgents rappel${nbUrgents > 1 ? 's' : ''} urgent${nbUrgents > 1 ? 's' : ''} !",
            Colors.red,
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint("❌ Erreur chargement vaccinations: $e");
      debugPrint("Stack trace: $stackTrace");
      
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur de chargement: ${e.toString()}"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  String _formatDate(String dateString) {
    try {
      final dateTime = DateTime.parse(dateString);
      return "${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}";
    } catch (e) {
      return dateString;
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Vaccinations"),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history),
                  const SizedBox(width: 8),
                  Text("Récentes (${_vaccinationsRecentes.length})"),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.notifications_active),
                  const SizedBox(width: 8),
                  Text("Rappels (${_rappelsEnCours.length})"),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerVaccinations,
            tooltip: "Actualiser",
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

          // Badge d'alertes urgentes
          if (_rappelsEnCours.where((r) => r['statut_urgence'] == 'urgent').isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.red[50],
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "⚠️ ${_rappelsEnCours.where((r) => r['statut_urgence'] == 'urgent').length} rappel(s) urgent(s) à planifier",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.red[900],
                        fontWeight: FontWeight.bold,
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.vaccines, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "Aucune vaccination enregistrée",
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              "Les vaccinations apparaîtront ici",
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Tous les vaccins sont à jour ! 🎉",
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
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
                        vaccination['nom_vaccin'] ?? 'Vaccin',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text("🐑 ", style: TextStyle(fontSize: 14)),
                          Flexible(
                            child: Text(
                              "${vaccination['animal_nom']} (${vaccination['animal_race']})",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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
                    "Administré le",
                    vaccination['date_vaccination'] ?? 'N/A',
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    Icons.event_repeat,
                    "Rappel prévu",
                    vaccination['date_rappel'] ?? 'N/A',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInfoItem(
              Icons.person,
              "Vétérinaire",
              vaccination['veterinaire'] ?? 'N/A',
            ),
            if (vaccination['lot'] != null && vaccination['lot'] != 'N/A') ...[
              const SizedBox(height: 8),
              _buildInfoItem(
                Icons.qr_code,
                "Lot",
                vaccination['lot'],
              ),
            ],
            if (vaccination['observations'] != null && 
                vaccination['observations'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Observations :",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vaccination['observations'],
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
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
    
    final joursRestants = (rappel['jours_restants'] as num?)?.toInt() ?? 0;
    
    if (joursRestants <= 7) {
      couleur = Colors.red;
      message = "⚠️ URGENT";
      iconeStatut = Icons.error;
    } else if (joursRestants <= 14) {
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
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: couleur, width: 5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rappel['nom_vaccin'] ?? 'Vaccin',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text("🐑 ", style: TextStyle(fontSize: 14)),
                            Flexible(
                              child: Text(
                                "${rappel['animal_nom'] ?? 'N/A'} (${rappel['animal_race'] ?? 'N/A'})",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
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
              const SizedBox(height: 16),
              
              // Compteur de jours
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: couleur.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, size: 24, color: couleur),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            joursRestants == 0
                                ? "Aujourd'hui !"
                                : joursRestants == 1
                                    ? "Demain"
                                    : "Dans $joursRestants jours",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: couleur,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Date du rappel : ${_formatDate(rappel['date_rappel']?.toString() ?? '')}",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Message d'action
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
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        joursRestants <= 7
                            ? "Contactez rapidement votre vétérinaire pour prendre rendez-vous"
                            : "Pensez à prendre rendez-vous avec votre vétérinaire",
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
              
              // Bouton d'action pour rappels urgents
              if (joursRestants <= 7) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Implémenter l'action (appel, SMS, email, etc.)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Fonctionnalité à venir : Contacter le vétérinaire"),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    },
                    icon: const Icon(Icons.phone),
                    label: const Text("Contacter le vétérinaire"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: couleur,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
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