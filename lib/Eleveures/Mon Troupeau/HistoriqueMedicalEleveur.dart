import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// HISTORIQUE MÉDICAL - VERSION ÉLEVEUR (LECTURE SEULE)
// VERSION CORRIGÉE - Compatible avec votre structure users
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

      // ========== CHARGER CONSULTATIONS ==========
      final consultationsResponse = await supabase
          .from('consultations')
          .select('*')
          .order('date_consultation', ascending: false);

      for (var consultation in consultationsResponse) {
        try {
          String animalNom = "Animal inconnu";
          String animalRace = "";
          
          // Récupérer les infos de l'animal selon la source
          if (consultation['source'] == 'nee') {
            final animalData = await supabase
                .from('nouveaux_nee')
                .select('nom, race')
                .eq('id', consultation['animal_id'])
                .maybeSingle();
            
            if (animalData != null) {
              animalNom = animalData['nom'] ?? 'Animal inconnu';
              animalRace = animalData['race'] ?? '';
            }
          } else if (consultation['source'] == 'achete') {
            final animalData = await supabase
                .from('animal_acheter')
                .select('nom, race')
                .eq('id', consultation['animal_id'])
                .maybeSingle();
            
            if (animalData != null) {
              animalNom = animalData['nom'] ?? 'Animal inconnu';
              animalRace = animalData['race'] ?? '';
            }
          }

          // Récupérer le nom du vétérinaire (gère plusieurs formats possibles)
          String veterinaireName = "Dr. Inconnu";
          try {
            final vetData = await supabase
                .from('users')
                .select('*')
                .eq('id', consultation['veterinaire_id'])
                .maybeSingle();
            
            if (vetData != null) {
              // Essayer plusieurs colonnes possibles
              veterinaireName = vetData['nom_complet'] ?? 
                                vetData['full_name'] ?? 
                                vetData['name'] ??
                                (vetData['prenom'] != null && vetData['nom'] != null 
                                  ? '${vetData['prenom']} ${vetData['nom']}'
                                  : vetData['email']?.split('@')[0] ?? 'Dr. Inconnu');
            }
          } catch (e) {
            debugPrint("Erreur récupération vétérinaire: $e");
          }

          // Formater la date
          String dateFormatted = "Date inconnue";
          try {
            final dateTime = DateTime.parse(consultation['date_consultation'].toString());
            dateFormatted = "${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}";
          } catch (e) {
            debugPrint("Erreur format date: $e");
          }

          historique.add({
            'type': 'consultation',
            'date': dateFormatted,
            'date_sort': consultation['date_consultation'],
            'animal_nom': animalNom,
            'animal_race': animalRace,
            'titre': consultation['motif'] ?? 'Consultation',
            'description': consultation['examen_clinique'] ?? 'Examen général',
            'veterinaire': veterinaireName,
            'diagnostic': consultation['diagnostic'] ?? 'Non spécifié',
            'traitement': consultation['traitement'] ?? 'Non spécifié',
            'observations': consultation['observations'] ?? '',
          });
        } catch (e) {
          debugPrint("Erreur traitement consultation: $e");
        }
      }

      // ========== CHARGER VACCINATIONS ==========
      final vaccinationsResponse = await supabase
          .from('vaccinations')
          .select('*')
          .order('date_vaccination', ascending: false);

      for (var vaccination in vaccinationsResponse) {
        try {
          String animalNom = "Animal inconnu";
          String animalRace = "";
          
          if (vaccination['source'] == 'nee') {
            final animalData = await supabase
                .from('nouveaux_nee')
                .select('nom, race')
                .eq('id', vaccination['animal_id'])
                .maybeSingle();
            
            if (animalData != null) {
              animalNom = animalData['nom'] ?? 'Animal inconnu';
              animalRace = animalData['race'] ?? '';
            }
          } else if (vaccination['source'] == 'achete') {
            final animalData = await supabase
                .from('animal_acheter')
                .select('nom, race')
                .eq('id', vaccination['animal_id'])
                .maybeSingle();
            
            if (animalData != null) {
              animalNom = animalData['nom'] ?? 'Animal inconnu';
              animalRace = animalData['race'] ?? '';
            }
          }

          // Récupérer le nom du vétérinaire (gère plusieurs formats)
          String veterinaireName = "Dr. Inconnu";
          try {
            final vetData = await supabase
                .from('users')
                .select('*')
                .eq('id', vaccination['veterinaire_id'])
                .maybeSingle();
            
            if (vetData != null) {
              veterinaireName = vetData['nom_complet'] ?? 
                                vetData['full_name'] ?? 
                                vetData['name'] ??
                                (vetData['prenom'] != null && vetData['nom'] != null 
                                  ? '${vetData['prenom']} ${vetData['nom']}'
                                  : vetData['email']?.split('@')[0] ?? 'Dr. Inconnu');
            }
          } catch (e) {
            debugPrint("Erreur récupération vétérinaire: $e");
          }

          // Formater les dates
          String dateVaccination = _formatDate(vaccination['date_vaccination'].toString());
          String dateRappel = vaccination['date_rappel'] != null 
              ? _formatDate(vaccination['date_rappel'].toString())
              : 'Aucun rappel';

          historique.add({
            'type': 'vaccination',
            'date': dateVaccination,
            'date_sort': vaccination['date_vaccination'],
            'animal_nom': animalNom,
            'animal_race': animalRace,
            'titre': 'Vaccination ${vaccination['nom_vaccin']}',
            'description': 'Rappel prévu le $dateRappel',
            'veterinaire': veterinaireName,
            'nom_vaccin': vaccination['nom_vaccin'],
            'date_rappel': dateRappel,
            'lot': vaccination['lot'] ?? 'N/A',
            'observations': vaccination['observations'] ?? '',
          });
        } catch (e) {
          debugPrint("Erreur traitement vaccination: $e");
        }
      }

      // Trier par date (plus récent en premier)
      historique.sort((a, b) {
        try {
          final dateA = DateTime.parse(a['date_sort'].toString());
          final dateB = DateTime.parse(b['date_sort'].toString());
          return dateB.compareTo(dateA);
        } catch (e) {
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
      debugPrint("Erreur chargement historique: $e");
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

  List<Map<String, dynamic>> get _historiqueFiltre {
    if (_filtre == 'Tout') return _historique;
    if (_filtre == 'Consultations') {
      return _historique.where((item) => item['type'] == 'consultation').toList();
    }
    if (_filtre == 'Vaccinations') {
      return _historique.where((item) => item['type'] == 'vaccination').toList();
    }
    return _historique;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Historique Médical"),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerHistorique,
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

          // Compteur
          if (!_isLoading && _historiqueFiltre.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    "${_historiqueFiltre.length} enregistrement${_historiqueFiltre.length > 1 ? 's' : ''}",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

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
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
                  if (_historiqueFiltre.indexOf(item) < _historiqueFiltre.length - 1)
                    Container(
                      width: 2,
                      height: 40,
                      margin: const EdgeInsets.only(top: 4),
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
                            item['type'] == 'consultation' ? 'CONSULTATION' : 'VACCINATION',
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
                    Row(
                      children: [
                        const Text("🐑 ", style: TextStyle(fontSize: 14)),
                        Text(
                          item['animal_nom'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (item['animal_race'] != null && item['animal_race'].toString().isNotEmpty) ...[
                          Text(
                            " (${item['animal_race']})",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
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
    String message;
    if (_filtre == 'Consultations') {
      message = "Aucune consultation enregistrée";
    } else if (_filtre == 'Vaccinations') {
      message = "Aucune vaccination enregistrée";
    } else {
      message = "Aucun historique médical";
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medical_information, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            "Les soins vétérinaires apparaîtront ici",
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
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // En-tête
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: couleur.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(icone, color: couleur, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item['titre'],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: couleur,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Contenu
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bannière lecture seule
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!, width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.visibility, color: Colors.blue[700], size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Consultation uniquement - Vous ne pouvez pas modifier ces informations",
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
                    _buildDetailRow("Animal", "${item['animal_nom']}${item['animal_race'] != null && item['animal_race'].toString().isNotEmpty ? ' (${item['animal_race']})' : ''}", Icons.pets),
                    _buildDetailRow("Vétérinaire", item['veterinaire'], Icons.person),
                    
                    // Détails spécifiques aux consultations
                    if (item['type'] == 'consultation') ...[
                      if (item['diagnostic'] != null && item['diagnostic'].toString().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          "Diagnostic :",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Text(
                            item['diagnostic'],
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                      
                      if (item['traitement'] != null && item['traitement'].toString().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          "Traitement :",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: Text(
                            item['traitement'],
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ],

                    // Détails spécifiques aux vaccinations
                    if (item['type'] == 'vaccination') ...[
                      const SizedBox(height: 12),
                      _buildDetailRow("Vaccin", item['nom_vaccin'], Icons.medical_information),
                      _buildDetailRow("Date rappel", item['date_rappel'], Icons.event_repeat),
                      if (item['lot'] != null && item['lot'].toString() != 'N/A')
                        _buildDetailRow("Numéro de lot", item['lot'], Icons.qr_code),
                    ],
                    
                    // Observations (pour les deux types)
                    if (item['observations'] != null && item['observations'].toString().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        "Observations :",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Text(
                          item['observations'],
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: couleur,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          "Fermer",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
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

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.green[700]),
          const SizedBox(width: 12),
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
                    fontSize: 15,
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