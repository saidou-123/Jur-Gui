import 'package:depart/Veterinaires/constantes/app_constants.dart';
import 'package:depart/Veterinaires/constantes/services/vaccination_service.dart';
import 'package:flutter/material.dart';


class NouvelleVaccinationForm extends StatefulWidget {
  final Map<String, dynamic> animal;
  final String source;

  const NouvelleVaccinationForm({super.key, required this.animal, required this.source});

  @override
  State<NouvelleVaccinationForm> createState() => _NouvelleVaccinationFormState();
}

class _NouvelleVaccinationFormState extends State<NouvelleVaccinationForm> {
  final _formKey = GlobalKey<FormState>();
  final _vaccSvc = VaccinationService();

  String? _nomVaccin;
  final _lotCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  DateTime _dateVacc = DateTime.now();
  DateTime? _dateRappel;
  bool _isLoading = false;

  @override
  void dispose() { _lotCtrl.dispose(); _obsCtrl.dispose(); super.dispose(); }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      await _vaccSvc.enregistrer(
        animalId: widget.animal['id'].toString(),
        source: widget.source,
        nomVaccin: _nomVaccin!,
        dateVaccination: _dateVacc,
        dateRappel: _dateRappel,
        lot: _lotCtrl.text.trim().isEmpty ? null : _lotCtrl.text.trim(),
        observations: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Vaccination enregistrée'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
      );
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
          ? const Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Enregistrement...')],
            ))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAnimalHeader(),
                    const SizedBox(height: 20),

                    _sectionTitle('💉 Vaccin'),
                    // Dropdown vaccins courants
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Sélectionner le vaccin *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.vaccines, color: Colors.blue),
                      ),
                      items: VaccinsCourants.liste.map((v) =>
                        DropdownMenuItem(value: v, child: Text(v))).toList(),
                      onChanged: (v) => setState(() => _nomVaccin = v),
                      onSaved: (v) => _nomVaccin = v,
                      validator: (v) => v == null ? 'Sélectionnez un vaccin' : null,
                    ),
                    const SizedBox(height: 20),

                    _sectionTitle('📅 Dates'),
                    Row(children: [
                      Expanded(child: _datePicker(
                        label: 'Date administration',
                        date: _dateVacc,
                        onPick: (d) => setState(() => _dateVacc = d),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _datePicker(
                        label: 'Date de rappel',
                        date: _dateRappel,
                        onPick: (d) => setState(() => _dateRappel = d),
                        optional: true,
                        future: true,
                      )),
                    ]),
                    const SizedBox(height: 20),

                    _sectionTitle('📋 Informations complémentaires'),
                    TextFormField(
                      controller: _lotCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Numéro de lot',
                        hintText: 'Ex: LOT-2025-001',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.label, color: Colors.blue),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _obsCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Observations',
                        hintText: 'Réaction post-vaccinale, remarques...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.notes, color: Colors.blue),
                      ),
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _enregistrer,
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Enregistrer la vaccination', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAnimalHeader() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.blue[50],
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.blue.shade200),
    ),
    child: Row(children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(color: Colors.blue[100], borderRadius: BorderRadius.circular(10)),
        child: Icon(Icons.pets, size: 28, color: Colors.blue[700]),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.animal['nom'] ?? 'Sans nom',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          Text('${widget.animal['race'] ?? 'N/A'} · ${widget.animal['sexe'] ?? 'N/A'}',
              style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          Text('RFID: ${widget.animal['tag_rfid'] ?? 'N/A'}',
              style: TextStyle(fontSize: 11, color: Colors.grey[500], fontFamily: 'monospace')),
        ],
      )),
    ]),
  );

  Widget _datePicker({
    required String label,
    required DateTime? date,
    required Function(DateTime) onPick,
    bool optional = false,
    bool future = false,
  }) => Card(
    child: ListTile(
      dense: true,
      leading: Icon(future ? Icons.event_repeat : Icons.calendar_today,
          color: future ? Colors.orange : Colors.blue),
      title: Text(label, style: const TextStyle(fontSize: 12)),
      subtitle: Text(
        date != null ? _fmt(date) : (optional ? 'Non défini' : 'Sélectionner'),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: date == null && !optional ? Colors.red : null,
        ),
      ),
      onTap: () async {
        final now = DateTime.now();
        final d = await showDatePicker(
          context: context,
          initialDate: date ?? (future ? now.add(const Duration(days: 365)) : now),
          firstDate: future ? now : DateTime(2020),
          lastDate: future ? DateTime(2030) : now,
        );
        if (d != null) onPick(d);
      },
    ),
  );

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
  );

  String _fmt(DateTime d) =>
    '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
}