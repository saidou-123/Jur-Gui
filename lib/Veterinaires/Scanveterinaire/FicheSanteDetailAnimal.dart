import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FicheSanteDetailAnimal extends StatefulWidget {
  final Map<String, dynamic> animal;
  final String source;

  const FicheSanteDetailAnimal({
    super.key,
    required this.animal,
    required this.source,
  });

  @override
  State<FicheSanteDetailAnimal> createState() => _FicheSanteDetailAnimalState();
}

class _FicheSanteDetailAnimalState extends State<FicheSanteDetailAnimal> {
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
      // Charger consultations
      final consultations = await supabase
          .from('consultations')
          .select('*')
          .eq('animal_id', widget.animal['id'])
          .eq('source', widget.source)
          .order('date_consultation', ascending: false);

      // Charger vaccinations
      final vaccinations = await supabase
          .from('vaccinations')
          .select('*')
          .eq('animal_id', widget.animal['id'])
          .eq('source', widget.source)
          .order('date_vaccination', ascending: false);

      if (mounted) {
        setState(() {
          _consultations = List<Map<String, dynamic>>.from(consultations);
          _vaccinations = List<Map<String, dynamic>>.from(vaccinations);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Erreur chargement dossier: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Fiche de Santé - ${widget.animal['nom'] ?? 'Animal'}"),
        backgroundColor: Colors.green[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerDossierMedical,
          ),
        ],
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
                  _buildResumeSante(),
                  const SizedBox(height: 16),
                  _buildConsultations(),
                  const SizedBox(height: 16),
                  _buildVaccinations(),
                ],
              ),
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
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.grey[300],
                        child: const Icon(Icons.error, size: 60),
                      );
                    },
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

  Widget _buildResumeSante() {
    final nbConsultations = _consultations.length;
    final nbVaccinations = _vaccinations.length;

    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  "Résumé du Dossier Médical",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  Icons.medical_services,
                  "$nbConsultations",
                  "Consultation${nbConsultations > 1 ? 's' : ''}",
                  Colors.green,
                ),
                _buildStatItem(
                  Icons.vaccines,
                  "$nbVaccinations",
                  "Vaccination${nbVaccinations > 1 ? 's' : ''}",
                  Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(icon, color: color, size: 30),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDate(consultation['date_consultation']?.toString() ?? ''),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "Consultation",
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text("Motif: ${consultation['motif'] ?? 'N/A'}"),
          if (consultation['diagnostic'] != null)
            Text("Diagnostic: ${consultation['diagnostic']}"),
          if (consultation['traitement'] != null)
            Text("Traitement: ${consultation['traitement']}"),
        ],
      ),
    );
  }

  Widget _buildVaccinationItem(Map<String, dynamic> vaccination) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                vaccination['nom_vaccin'] ?? 'Vaccin',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "Vaccination",
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text("Date: ${_formatDate(vaccination['date_vaccination']?.toString() ?? '')}"),
          if (vaccination['date_rappel'] != null)
            Text(
              "Rappel: ${_formatDate(vaccination['date_rappel']?.toString() ?? '')}",
              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
            ),
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

  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return 'Date inconnue';
    try {
      final date = DateTime.parse(isoDate);
      return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
    } catch (e) {
      return isoDate;
    }
  }
}