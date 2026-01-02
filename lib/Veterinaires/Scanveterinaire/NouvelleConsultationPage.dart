import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NouvelleConsultationPage extends StatefulWidget {
  final Map<String, dynamic> animal;
  final String source;

  const NouvelleConsultationPage({
    super.key,
    required this.animal,
    required this.source,
  });

  @override
  State<NouvelleConsultationPage> createState() => _NouvelleConsultationPageState();
}

class _NouvelleConsultationPageState extends State<NouvelleConsultationPage> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  // Controllers
  final _motifController = TextEditingController();
  final _examenController = TextEditingController();
  final _diagnosticController = TextEditingController();
  final _traitementController = TextEditingController();
  final _observationsController = TextEditingController();

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
    super.dispose();
  }

  Future<void> _enregistrerConsultation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final dateComplete = DateTime(
        _dateConsultation.year,
        _dateConsultation.month,
        _dateConsultation.day,
        _heureConsultation.hour,
        _heureConsultation.minute,
      );

      final veterinaire = supabase.auth.currentUser;
      if (veterinaire == null) {
        throw Exception("Vétérinaire non connecté");
      }

      await supabase.from('consultations').insert({
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
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Consultation enregistrée avec succès"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Retourner true pour indiquer succès
      }
    } catch (e) {
      debugPrint("❌ Erreur enregistrement consultation: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Erreur: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nouvelle Consultation"),
        backgroundColor: Colors.green[700],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Enregistrement en cours..."),
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
                    // Info animal
                    _buildAnimalInfo(),
                    const SizedBox(height: 24),

                    const Text(
                      "Informations de consultation",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Date et heure
                    Row(
                      children: [
                        Expanded(child: _buildDatePicker()),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTimePicker()),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Motif
                    TextFormField(
                      controller: _motifController,
                      decoration: const InputDecoration(
                        labelText: "Motif de consultation *",
                        hintText: "Ex: Contrôle de routine, boiterie...",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.comment, color: Colors.green),
                      ),
                      maxLines: 2,
                      validator: (val) => val!.isEmpty ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 16),

                    // Examen clinique
                    TextFormField(
                      controller: _examenController,
                      decoration: const InputDecoration(
                        labelText: "Examen clinique *",
                        hintText: "Température, fréquence cardiaque, état général...",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.monitor_heart, color: Colors.green),
                      ),
                      maxLines: 4,
                      validator: (val) => val!.isEmpty ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 16),

                    // Diagnostic
                    TextFormField(
                      controller: _diagnosticController,
                      decoration: const InputDecoration(
                        labelText: "Diagnostic *",
                        hintText: "Diagnostic posé suite à l'examen",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.assignment, color: Colors.green),
                      ),
                      maxLines: 3,
                      validator: (val) => val!.isEmpty ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 16),

                    // Traitement
                    TextFormField(
                      controller: _traitementController,
                      decoration: const InputDecoration(
                        labelText: "Traitement prescrit *",
                        hintText: "Médicaments, posologie, durée...",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.medication, color: Colors.green),
                      ),
                      maxLines: 4,
                      validator: (val) => val!.isEmpty ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 16),

                    // Observations
                    TextFormField(
                      controller: _observationsController,
                      decoration: const InputDecoration(
                        labelText: "Observations additionnelles",
                        hintText: "Remarques, recommandations...",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.notes, color: Colors.green),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),

                    // Bouton enregistrer
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _enregistrerConsultation,
                        icon: const Icon(Icons.check_circle),
                        label: const Text(
                          "Enregistrer la consultation",
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Center(
                      child: Text(
                        "* Champs obligatoires",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
          if (widget.animal['image_url'] != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                widget.animal['image_url'],
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
          else
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.pets, size: 30, color: Colors.green),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.animal['nom'] ?? 'Sans nom',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Race: ${widget.animal['race'] ?? 'N/A'}",
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                Text(
                  "Sexe: ${widget.animal['sexe'] ?? 'N/A'}",
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                Text(
                  "Tag: ${widget.animal['tag_rfid'] ?? 'N/A'}",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontFamily: 'monospace',
                  ),
                ),
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
        title: const Text("Date", style: TextStyle(fontSize: 12)),
        subtitle: Text(
          "${_dateConsultation.day.toString().padLeft(2, '0')}/"
          "${_dateConsultation.month.toString().padLeft(2, '0')}/"
          "${_dateConsultation.year}",
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
        title: const Text("Heure", style: TextStyle(fontSize: 12)),
        subtitle: Text(
          "${_heureConsultation.hour.toString().padLeft(2, '0')}:"
          "${_heureConsultation.minute.toString().padLeft(2, '0')}",
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