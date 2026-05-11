import 'package:depart/Veterinaires/Scanveterinaire/FicheSanteDetailAnimal.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// FICHES DE SANTÉ - Liste et Gestion
// ============================================================
class FichesSante extends StatefulWidget {
  const FichesSante({super.key});

  @override
  State<FichesSante> createState() => _FichesSanteState();
}

class _FichesSanteState extends State<FichesSante> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _animaux = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _chargerAnimaux();
  }

  Future<void> _chargerAnimaux() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      List<Map<String, dynamic>> tousLesAnimaux = [];

      // Charger nouveaux_nee
      final nees = await supabase
          .from('nouveaux_nee')
          .select('*')
          .order('nom');

      for (var animal in nees) {
        animal['source'] = 'nee';
        tousLesAnimaux.add(animal);
      }

      // Charger animal_acheter
      final achetes = await supabase
          .from('animal_acheter')
          .select('*')
          .order('nom');

      for (var animal in achetes) {
        animal['source'] = 'achete';
        tousLesAnimaux.add(animal);
      }

      if (mounted) {
        setState(() {
          _animaux = tousLesAnimaux;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur chargement animaux: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _animauxFiltres {
    if (_searchQuery.isEmpty) return _animaux;
    
    return _animaux.where((animal) {
      final nom = animal['nom']?.toString().toLowerCase() ?? '';
      final race = animal['race']?.toString().toLowerCase() ?? '';
      final tag = animal['tag_rfid']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      
      return nom.contains(query) || race.contains(query) || tag.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Fiches de Santé"),
        backgroundColor: Colors.green[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerAnimaux,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Rechercher par nom, race ou tag...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),

          // Liste des animaux
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _animauxFiltres.isEmpty
                    ? const Center(
                        child: Text(
                          "Aucun animal trouvé",
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _chargerAnimaux,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _animauxFiltres.length,
                          itemBuilder: (context, index) {
                            final animal = _animauxFiltres[index];
                            return _buildAnimalCard(animal);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimalCard(Map<String, dynamic> animal) {
    final source = animal['source'] == 'achete' ? '🛒 Acheté' : '🐑 Nouveau-né';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: animal['image_url'] != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  animal['image_url'],
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[300],
                      child: const Icon(Icons.pets, size: 30),
                    );
                  },
                ),
              )
            : Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.pets, size: 30, color: Colors.green[300]),
              ),
        title: Text(
          animal['nom'] ?? 'Sans nom',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text("Race: ${animal['race'] ?? 'N/A'}"),
            Text(source, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward_ios, color: Colors.green),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>FicheSanteDetailAnimal(
                  animal: animal,
                  source: animal['source'],
                ),
              ),
            ).then((_) => _chargerAnimaux());
          },
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FicheSanteDetailPage(
                animal: animal,
                source: animal['source'],
              ),
            ),
          ).then((_) => _chargerAnimaux());
        },
      ),
    );
  }
}

// ============================================================
// FICHE DE SANTÉ DÉTAILLÉE
// ============================================================
class FicheSanteDetailPage extends StatefulWidget {
  final Map<String, dynamic> animal;
  final String source;

  const FicheSanteDetailPage({
    super.key,
    required this.animal,
    required this.source,
  });

  @override
  State<FicheSanteDetailPage> createState() => _FicheSanteDetailPageState();
}

class _FicheSanteDetailPageState extends State<FicheSanteDetailPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _consultations = [];
  List<Map<String, dynamic>> _vaccinations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _chargerDossierMedical();
  }

  Future<void> _chargerDossierMedical() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      // Charger consultations (à créer dans Supabase)
      // final consultations = await supabase
      //     .from('consultations')
      //     .select('*')
      //     .eq('animal_id', widget.animal['id'])
      //     .eq('source', widget.source)
      //     .order('date_consultation', ascending: false);

      // Charger vaccinations (à créer dans Supabase)
      // final vaccinations = await supabase
      //     .from('vaccinations')
      //     .select('*')
      //     .eq('animal_id', widget.animal['id'])
      //     .eq('source', widget.source)
      //     .order('date_vaccination', ascending: false);

      if (mounted) {
        setState(() {
          // _consultations = List<Map<String, dynamic>>.from(consultations);
          // _vaccinations = List<Map<String, dynamic>>.from(vaccinations);
          _consultations = []; // Temporaire
          _vaccinations = []; // Temporaire
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur chargement dossier: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.animal['nom'] ?? 'Fiche Santé'),
        backgroundColor: Colors.green[700],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoGenerales(),
                  const SizedBox(height: 16),
                  _buildStatutSante(),
                  const SizedBox(height: 16),
                  _buildConsultations(),
                  const SizedBox(height: 16),
                  _buildVaccinations(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _ajouterConsultation();
        },
        icon: const Icon(Icons.add),
        label: const Text("Nouvelle Consultation"),
        backgroundColor: Colors.green[700],
      ),
    );
  }

  Widget _buildInfoGenerales() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Informations Générales",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (widget.animal['image_url'] != null)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    widget.animal['image_url'],
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.pets, "Nom", widget.animal['nom'] ?? 'N/A'),
            _buildInfoRow(Icons.agriculture, "Race", widget.animal['race'] ?? 'N/A'),
            _buildInfoRow(Icons.wc, "Sexe", widget.animal['sexe'] ?? 'N/A'),
            _buildInfoRow(Icons.nfc, "Tag RFID", widget.animal['tag_rfid'] ?? 'N/A'),
            if (widget.animal['date_naissance'] != null)
              _buildInfoRow(Icons.cake, "Date naissance", widget.animal['date_naissance']),
            if (widget.animal['provenance'] != null)
              _buildInfoRow(Icons.location_on, "Provenance", widget.animal['provenance']),
          ],
        ),
      ),
    );
  }

  Widget _buildStatutSante() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Statut de Santé",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 30),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "✅ Bonne santé générale",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Dernière visite : Non enregistrée",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsultations() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.medical_services, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  "Historique des Consultations",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_consultations.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    "Aucune consultation enregistrée",
                    style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey),
                  ),
                ),
              )
            else
              ..._consultations.map((c) => _buildConsultationItem(c)),
          ],
        ),
      ),
    );
  }

  Widget _buildVaccinations() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.vaccines, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  "Vaccinations",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_vaccinations.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    "Aucune vaccination enregistrée",
                    style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey),
                  ),
                ),
              )
            else
              ..._vaccinations.map((v) => _buildVaccinationItem(v)),
          ],
        ),
      ),
    );
  }

  Widget _buildConsultationItem(Map<String, dynamic> consultation) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "📅 ${consultation['date_consultation']}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text("Motif: ${consultation['motif'] ?? 'N/A'}"),
          Text("Diagnostic: ${consultation['diagnostic'] ?? 'N/A'}"),
        ],
      ),
    );
  }

  Widget _buildVaccinationItem(Map<String, dynamic> vaccination) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "💉 ${vaccination['nom_vaccin']}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text("Date: ${vaccination['date_vaccination']}"),
          if (vaccination['rappel'] != null)
            Text("Rappel: ${vaccination['rappel']}", style: const TextStyle(color: Colors.orange)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.green),
          const SizedBox(width: 8),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  void _ajouterConsultation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nouvelle Consultation"),
        content: const Text("Formulaire de consultation à implémenter"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Enregistrer consultation
            },
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );
  }
}