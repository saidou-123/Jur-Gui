import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// NOUVELLE CONSULTATION — version synchronisée
// ============================================================
class NouvelleConsultationPage extends StatefulWidget {
  final Map<String, dynamic> animal;
  final String source;

  const NouvelleConsultationPage({
    super.key,
    required this.animal,
    required this.source,
  });

  @override
  State<NouvelleConsultationPage> createState() =>
      _NouvelleConsultationPageState();
}

class _NouvelleConsultationPageState
    extends State<NouvelleConsultationPage> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  final _motifController = TextEditingController();
  final _examenController = TextEditingController();
  final _diagnosticController = TextEditingController();
  final _traitementController = TextEditingController();
  final _observationsController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _poidsController = TextEditingController();
  final _fcController = TextEditingController();

  DateTime _dateConsultation = DateTime.now();
  TimeOfDay _heureConsultation = TimeOfDay.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _motifController.dispose();
    _examenController.dispose();
    _diagnosticController.dispose();
    _traitementController.dispose();
    _observationsController.dispose();
    _temperatureController.dispose();
    _poidsController.dispose();
    _fcController.dispose();
    super.dispose();
  }

  Future<void> _enregistrerConsultation() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // ✅ Vérification session avant insertion
      final veterinaire = supabase.auth.currentUser;
      if (veterinaire == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Session expirée. Veuillez vous reconnecter.'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
        return;
      }

      final dateComplete = DateTime(
        _dateConsultation.year,
        _dateConsultation.month,
        _dateConsultation.day,
        _heureConsultation.hour,
        _heureConsultation.minute,
      );

      // ✅ Champs alignés avec la table consultations de Supabase
      final Map<String, dynamic> data = {
        'animal_id': widget.animal['id'],
        'source': widget.source,
        'veterinaire_id': veterinaire.id,
        'date_consultation': dateComplete.toIso8601String(),
        'motif': _motifController.text.trim(),
        'examen_clinique': _examenController.text.trim(),
        'diagnostic': _diagnosticController.text.trim(),
        'traitement': _traitementController.text.trim(),
        'observations': _observationsController.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Champs optionnels numériques
      if (_temperatureController.text.isNotEmpty) {
        data['temperature_c'] =
            double.tryParse(_temperatureController.text.trim());
      }
      if (_poidsController.text.isNotEmpty) {
        data['poids_kg'] =
            double.tryParse(_poidsController.text.trim());
      }
      if (_fcController.text.isNotEmpty) {
        data['frequence_cardiaque'] =
            int.tryParse(_fcController.text.trim());
      }

      await supabase.from('consultations').insert(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Consultation enregistrée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('❌ Erreur enregistrement: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle Consultation'),
        backgroundColor: Colors.green[700],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Enregistrement en cours...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAnimalInfo(),
                    const SizedBox(height: 24),
                    const Text('Informations de consultation',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildDatePicker()),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTimePicker()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(_motifController, 'Motif de consultation *',
                        'Ex: Contrôle de routine, boiterie...', Icons.comment,
                        maxLines: 2, required: true),
                    const SizedBox(height: 16),
                    _buildTextField(
                        _examenController,
                        'Examen clinique *',
                        'Température, fréquence cardiaque, état général...',
                        Icons.monitor_heart,
                        maxLines: 4,
                        required: true),
                    const SizedBox(height: 16),
                    _buildTextField(_diagnosticController, 'Diagnostic *',
                        'Diagnostic posé suite à l\'examen', Icons.assignment,
                        maxLines: 3, required: true),
                    const SizedBox(height: 16),
                    _buildTextField(_traitementController,
                        'Traitement prescrit *',
                        'Médicaments, posologie, durée...', Icons.medication,
                        maxLines: 4, required: true),
                    const SizedBox(height: 16),

                    // ✅ Champs numériques alignés avec la table Supabase
                    const Text('Paramètres vitaux (optionnel)',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _temperatureController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Température (°C)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.thermostat,
                                  color: Colors.orange),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _poidsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Poids (kg)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.monitor_weight,
                                  color: Colors.green),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fcController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Fréquence cardiaque (bpm)',
                        border: OutlineInputBorder(),
                        prefixIcon:
                            Icon(Icons.favorite, color: Colors.red),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(_observationsController,
                        'Observations additionnelles',
                        'Remarques, recommandations...', Icons.notes,
                        maxLines: 3),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed:
                            _isLoading ? null : _enregistrerConsultation,
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Enregistrer la consultation',
                            style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        '* Champs obligatoires',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon, {
    int maxLines = 1,
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon, color: Colors.green),
      ),
      maxLines: maxLines,
      validator: required
          ? (val) => (val == null || val.isEmpty) ? 'Champ requis' : null
          : null,
    );
  }

  Widget _buildAnimalInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green, width: 2),
      ),
      child: Row(
        children: [
          widget.animal['image_url'] != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    widget.animal['image_url'],
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[300],
                      child: const Icon(Icons.pets, size: 30),
                    ),
                  ),
                )
              : Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.pets,
                      size: 30, color: Colors.green),
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.animal['nom'] ?? 'Sans nom',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text('Race: ${widget.animal['race'] ?? 'N/A'}',
                    style: TextStyle(
                        fontSize: 14, color: Colors.grey[700])),
                Text('Sexe: ${widget.animal['sexe'] ?? 'N/A'}',
                    style: TextStyle(
                        fontSize: 14, color: Colors.grey[700])),
                Text('Tag: ${widget.animal['tag_rfid'] ?? 'N/A'}',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontFamily: 'monospace')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.calendar_today, color: Colors.green),
        title: const Text('Date', style: TextStyle(fontSize: 12)),
        subtitle: Text(
          '${_dateConsultation.day.toString().padLeft(2, '0')}/'
          '${_dateConsultation.month.toString().padLeft(2, '0')}/'
          '${_dateConsultation.year}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: _dateConsultation,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
          );
          if (date != null && mounted) {
            setState(() => _dateConsultation = date);
          }
        },
      ),
    );
  }

  Widget _buildTimePicker() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.access_time, color: Colors.green),
        title: const Text('Heure', style: TextStyle(fontSize: 12)),
        subtitle: Text(
          '${_heureConsultation.hour.toString().padLeft(2, '0')}:'
          '${_heureConsultation.minute.toString().padLeft(2, '0')}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onTap: () async {
          final time = await showTimePicker(
            context: context,
            initialTime: _heureConsultation,
          );
          if (time != null && mounted) {
            setState(() => _heureConsultation = time);
          }
        },
      ),
    );
  }
}