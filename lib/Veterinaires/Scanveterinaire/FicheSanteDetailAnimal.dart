import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ CORRECTION : imports avec 'show' pour éviter tout conflit
// Chaque import expose uniquement la classe dont on a besoin
import 'package:depart/Veterinaires/Scanveterinaire/NouvelleConsultationPage.dart'
    show NouvelleConsultationPage;
import 'package:depart/Veterinaires/Scanveterinaire/NouvelleVaccinationPage.dart'
    show NouvelleVaccinationPage;

// ============================================================
// FICHE DE SANTÉ DÉTAILLÉE — version synchronisée
// ✅ Fix import : préfixes consultation. et vaccination.
//    pour éviter l'ambiguïté de noms entre les deux fichiers
// ============================================================
class FicheSanteDetailAnimal extends StatefulWidget {
  final Map<String, dynamic> animal;
  final String source;

  const FicheSanteDetailAnimal({
    super.key,
    required this.animal,
    required this.source,
  });

  @override
  State<FicheSanteDetailAnimal> createState() =>
      _FicheSanteDetailAnimalState();
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
      final animalId = widget.animal['id']?.toString() ?? '';

      final consultations = await supabase
          .from('consultations')
          .select('*')
          .eq('animal_id', animalId)
          .eq('source', widget.source)
          .order('date_consultation', ascending: false);

      final vaccinations = await supabase
          .from('vaccinations')
          .select('*')
          .eq('animal_id', animalId)
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
      debugPrint('❌ Erreur chargement dossier: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Fiche — ${widget.animal['nom'] ?? 'Animal'}'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
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
                  const SizedBox(height: 80),
                ],
              ),
            ),
      // ✅ FAB avec préfixes corrects
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'vaccination',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NouvelleVaccinationPage(
                  animal: widget.animal,
                  source: widget.source,
                ),
              ),
            ).then((ok) {
              if (ok == true) _chargerDossierMedical();
            }),
            icon: const Icon(Icons.vaccines),
            label: const Text('Vaccination'),
            backgroundColor: Colors.blue[700],
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'consultation',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NouvelleConsultationPage(
                  animal: widget.animal,
                  source: widget.source,
                ),
              ),
            ).then((ok) {
              if (ok == true) _chargerDossierMedical();
            }),
            icon: const Icon(Icons.medical_services),
            label: const Text('Consultation'),
            backgroundColor: Colors.green[700],
          ),
        ],
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
            const Text('Informations Générales',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                    errorBuilder: (_, __, ___) => Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Icon(Icons.error, size: 60),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            _buildInfoRow(
                Icons.pets, 'Nom', widget.animal['nom'] ?? 'N/A'),
            _buildInfoRow(Icons.agriculture, 'Race',
                widget.animal['race'] ?? 'N/A'),
            _buildInfoRow(
                Icons.wc, 'Sexe', widget.animal['sexe'] ?? 'N/A'),
            _buildInfoRow(Icons.nfc, 'Tag RFID',
                widget.animal['tag_rfid'] ?? 'N/A'),
            if (widget.animal['date_naissance'] != null)
              _buildInfoRow(
                  Icons.cake,
                  'Date naissance',
                  _formatDate(
                      widget.animal['date_naissance'].toString())),
            if (widget.animal['provenance'] != null)
              _buildInfoRow(Icons.location_on, 'Provenance',
                  widget.animal['provenance']),
            _buildInfoRow(
              Icons.label,
              'Origine',
              widget.source == 'nee' ? '🐑 Nouveau-né' : '🛒 Acheté',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumeSante() {
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
                Text('Résumé du Dossier Médical',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                    Icons.medical_services,
                    '${_consultations.length}',
                    'Consultation(s)',
                    Colors.green),
                _buildStatItem(Icons.vaccines, '${_vaccinations.length}',
                    'Vaccination(s)', Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      IconData icon, String value, String label, Color color) {
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
        Text(value,
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color)),
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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
                Text('Historique des Consultations',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            if (_consultations.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('Aucune consultation enregistrée',
                      style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey)),
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
                Text('Vaccinations',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            if (_vaccinations.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('Aucune vaccination enregistrée',
                      style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey)),
                ),
              )
            else
              ..._vaccinations.map((v) => _buildVaccinationItem(v)),
          ],
        ),
      ),
    );
  }

  Widget _buildConsultationItem(Map<String, dynamic> c) {
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
                '📅 ${_formatDate(c['date_consultation']?.toString() ?? '')}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Consultation',
                    style: TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Motif: ${c['motif'] ?? 'N/A'}'),
          if (c['diagnostic'] != null &&
              c['diagnostic'].toString().isNotEmpty)
            Text('Diagnostic: ${c['diagnostic']}'),
          if (c['traitement'] != null &&
              c['traitement'].toString().isNotEmpty)
            Text('Traitement: ${c['traitement']}'),
          if (c['examen_clinique'] != null &&
              c['examen_clinique'].toString().isNotEmpty)
            Text('Examen: ${c['examen_clinique']}'),
          if (c['temperature_c'] != null)
            Text('Température: ${c['temperature_c']} °C',
                style: const TextStyle(color: Colors.orange)),
          if (c['poids_kg'] != null) Text('Poids: ${c['poids_kg']} kg'),
        ],
      ),
    );
  }

  Widget _buildVaccinationItem(Map<String, dynamic> v) {
    final rappelDate = v['date_rappel'] != null
        ? _formatDate(v['date_rappel'].toString())
        : null;
    final bool rappelProche =
        _isRappelProche(v['date_rappel']?.toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: rappelProche ? Colors.orange : Colors.blue.shade200,
            width: rappelProche ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '💉 ${v['nom_vaccin'] ?? 'Vaccin'}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Vaccination',
                    style: TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Date: ${_formatDate(v['date_vaccination']?.toString() ?? '')}'),
          if (rappelDate != null)
            Text(
              'Rappel: $rappelDate${rappelProche ? ' ⚠️' : ''}',
              style: TextStyle(
                  color: rappelProche ? Colors.orange : Colors.blue[700],
                  fontWeight: FontWeight.bold),
            ),
          if (v['lot'] != null && v['lot'].toString().isNotEmpty)
            Text('Lot: ${v['lot']}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          if (v['observations'] != null &&
              v['observations'].toString().isNotEmpty)
            Text('Notes: ${v['observations']}'),
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
          Text('$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
              child: Text(value, overflow: TextOverflow.ellipsis)),
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

  bool _isRappelProche(String? dateStr) {
    if (dateStr == null) return false;
    try {
      final date = DateTime.parse(dateStr);
      final diff = date.difference(DateTime.now()).inDays;
      return diff >= 0 && diff <= 30;
    } catch (_) {
      return false;
    }
  }
}