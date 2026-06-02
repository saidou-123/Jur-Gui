import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// NOUVELLE VACCINATION — version synchronisée
// ============================================================
class NouvelleVaccinationPage extends StatefulWidget {
  final Map<String, dynamic> animal;
  final String source;

  const NouvelleVaccinationPage({
    super.key,
    required this.animal,
    required this.source,
  });

  @override
  State<NouvelleVaccinationPage> createState() =>
      _NouvelleVaccinationPageState();
}

class _NouvelleVaccinationPageState
    extends State<NouvelleVaccinationPage> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  final _vaccController = TextEditingController();
  final _lotController = TextEditingController();
  final _obsController = TextEditingController();

  DateTime _dateVaccination = DateTime.now();
  DateTime? _dateRappel;
  bool _isLoading = false;

  // Vaccins courants pour les ovins Ladoum
  static const List<String> _vaccinsCommuns = [
    'Antirabique',
    'Peste des petits ruminants (PPR)',
    'Entérotoxémie',
    'Brucellose',
    'Charbon bactéridien',
    'Clavelée',
    'Fièvre aphteuse',
    'Pasteurellose',
    'Autre',
  ];

  @override
  void dispose() {
    _vaccController.dispose();
    _lotController.dispose();
    _obsController.dispose();
    super.dispose();
  }

  Future<void> _enregistrerVaccination() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final veterinaire = supabase.auth.currentUser;
      if (veterinaire == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('❌ Session expirée. Veuillez vous reconnecter.'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
        return;
      }

      // ✅ Champs alignés avec la table vaccinations de Supabase
      final Map<String, dynamic> data = {
        'animal_id': widget.animal['id'],
        'source': widget.source,
        'veterinaire_id': veterinaire.id,
        'nom_vaccin': _vaccController.text.trim(),
        'date_vaccination':
            _dateVaccination.toIso8601String().split('T').first,
        'lot': _lotController.text.trim().isEmpty
            ? null
            : _lotController.text.trim(),
        'observations': _obsController.text.trim().isEmpty
            ? null
            : _obsController.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (_dateRappel != null) {
        data['date_rappel'] =
            _dateRappel!.toIso8601String().split('T').first;
      }

      await supabase.from('vaccinations').insert(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Vaccination enregistrée avec succès'),
            backgroundColor: Colors.blue,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('❌ Erreur enregistrement vaccination: $e');
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
        title: const Text('Nouvelle Vaccination'),
        backgroundColor: Colors.blue[700],
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
                    // Info animal
                    _buildAnimalInfo(),
                    const SizedBox(height: 24),

                    const Text('Informations de vaccination',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    // Sélection vaccin commun
                    const Text('Vaccins fréquents',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _vaccinsCommuns
                          .where((v) => v != 'Autre')
                          .map((vaccin) => GestureDetector(
                                onTap: () => setState(
                                    () => _vaccController.text = vaccin),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _vaccController.text == vaccin
                                        ? Colors.blue[700]
                                        : Colors.blue[50],
                                    borderRadius:
                                        BorderRadius.circular(20),
                                    border: Border.all(
                                        color: Colors.blue.shade200),
                                  ),
                                  child: Text(
                                    vaccin,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _vaccController.text ==
                                              vaccin
                                          ? Colors.white
                                          : Colors.blue[800],
                                    ),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 16),

                    // Champ nom vaccin
                    TextFormField(
                      controller: _vaccController,
                      decoration: const InputDecoration(
                        labelText: 'Nom du vaccin *',
                        hintText: 'Ex: Antirabique, PPR...',
                        border: OutlineInputBorder(),
                        prefixIcon:
                            Icon(Icons.vaccines, color: Colors.blue),
                      ),
                      validator: (val) =>
                          (val == null || val.isEmpty)
                              ? 'Champ requis'
                              : null,
                    ),
                    const SizedBox(height: 16),

                    // Dates
                    Row(
                      children: [
                        Expanded(
                            child: _buildDateCard(
                                'Date vaccination',
                                _dateVaccination,
                                Icons.calendar_today,
                                Colors.blue, (date) {
                          setState(() => _dateVaccination = date);
                        })),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _buildDateCard(
                                'Date rappel',
                                _dateRappel,
                                Icons.event_repeat,
                                Colors.orange, (date) {
                          setState(() => _dateRappel = date);
                        }, nullable: true)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Lot
                    TextFormField(
                      controller: _lotController,
                      decoration: const InputDecoration(
                        labelText: 'Numéro de lot (optionnel)',
                        hintText: 'Ex: LOT2024-001',
                        border: OutlineInputBorder(),
                        prefixIcon:
                            Icon(Icons.tag, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Observations
                    TextFormField(
                      controller: _obsController,
                      decoration: const InputDecoration(
                        labelText: 'Observations (optionnel)',
                        hintText: 'Réactions, remarques...',
                        border: OutlineInputBorder(),
                        prefixIcon:
                            Icon(Icons.notes, color: Colors.grey),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : _enregistrerVaccination,
                        icon: const Icon(Icons.check_circle),
                        label: const Text(
                            'Enregistrer la vaccination',
                            style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text('* Champs obligatoires',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDateCard(
    String label,
    DateTime? date,
    IconData icon,
    Color color,
    Function(DateTime) onPick, {
    bool nullable = false,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label, style: const TextStyle(fontSize: 11)),
        subtitle: Text(
          date != null
              ? '${date.day.toString().padLeft(2, '0')}/'
                  '${date.month.toString().padLeft(2, '0')}/'
                  '${date.year}'
              : 'Non définie',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: date != null ? null : Colors.grey,
          ),
        ),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: date ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
          );
          if (picked != null) onPick(picked);
        },
        trailing: nullable && date != null
            ? IconButton(
                icon: const Icon(Icons.clear, size: 16, color: Colors.grey),
                onPressed: () => setState(() => _dateRappel = null),
              )
            : null,
      ),
    );
  }

  Widget _buildAnimalInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.pets, size: 30, color: Colors.blue),
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
}