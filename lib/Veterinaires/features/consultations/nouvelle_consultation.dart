import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Page d'enregistrement d'une consultation vétérinaire complète.
/// Inclut les constantes vitales (poids, température, FC) pour les moutons Ladoum.
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
  final _db = Supabase.instance.client;

  // Controllers texte
  final _motifCtrl = TextEditingController();
  final _examenCtrl = TextEditingController();
  final _diagnosticCtrl = TextEditingController();
  final _traitementCtrl = TextEditingController();
  final _observationsCtrl = TextEditingController();

  // Constantes vitales
  final _poidsCtrl = TextEditingController();
  final _tempCtrl = TextEditingController();
  final _fcCtrl = TextEditingController();

  DateTime _date = DateTime.now();
  TimeOfDay _heure = TimeOfDay.now();
  bool _isLoading = false;

  // Valeurs normales Ladoum pour aide à la saisie
  static const _normales = {
    'poids': '40 – 120 kg',
    'temperature': '38.5 – 39.5 °C',
    'fc': '70 – 90 bpm',
  };

  @override
  void dispose() {
    for (final c in [_motifCtrl, _examenCtrl, _diagnosticCtrl, _traitementCtrl, _observationsCtrl, _poidsCtrl, _tempCtrl, _fcCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final vet = _db.auth.currentUser;
      if (vet == null) throw Exception('Vétérinaire non connecté');

      final dateComplete = DateTime(
        _date.year, _date.month, _date.day,
        _heure.hour, _heure.minute,
      );

      await _db.from('consultations').insert({
        'animal_id': widget.animal['id'],
        'source': widget.source,
        'veterinaire_id': vet.id,
        'date_consultation': dateComplete.toIso8601String(),
        'motif': _motifCtrl.text.trim(),
        'examen_clinique': _examenCtrl.text.trim(),
        'diagnostic': _diagnosticCtrl.text.trim(),
        'traitement': _traitementCtrl.text.trim(),
        'observations': _observationsCtrl.text.trim(),
        if (_poidsCtrl.text.isNotEmpty) 'poids_kg': double.tryParse(_poidsCtrl.text),
        if (_tempCtrl.text.isNotEmpty) 'temperature_c': double.tryParse(_tempCtrl.text),
        if (_fcCtrl.text.isNotEmpty) 'frequence_cardiaque': int.tryParse(_fcCtrl.text),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Consultation enregistrée'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
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

                    // ── Date & heure ──────────────────────────
                    _sectionTitle('📅 Date et heure'),
                    Row(children: [
                      Expanded(child: _datePicker()),
                      const SizedBox(width: 12),
                      Expanded(child: _timePicker()),
                    ]),
                    const SizedBox(height: 20),

                    // ── Constantes vitales ────────────────────
                    _sectionTitle('💊 Constantes vitales (Ladoum)'),
                    _buildVitalesRow(),
                    const SizedBox(height: 20),

                    // ── Informations cliniques ─────────────────
                    _sectionTitle('🩺 Informations cliniques'),
                    _field(_motifCtrl, 'Motif de consultation *', Icons.comment, maxLines: 2, required: true),
                    const SizedBox(height: 12),
                    _field(_examenCtrl, 'Examen clinique *', Icons.monitor_heart, maxLines: 4,
                        hint: 'État général, muqueuses, auscultation...', required: true),
                    const SizedBox(height: 12),
                    _field(_diagnosticCtrl, 'Diagnostic *', Icons.assignment, maxLines: 3, required: true),
                    const SizedBox(height: 12),
                    _field(_traitementCtrl, 'Traitement prescrit *', Icons.medication,
                        maxLines: 4, hint: 'Médicament, posologie, durée...', required: true),
                    const SizedBox(height: 12),
                    _field(_observationsCtrl, 'Observations / Recommandations à l\'éleveur',
                        Icons.notes, maxLines: 3),
                    const SizedBox(height: 32),

                    // ── Bouton ────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _enregistrer,
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Enregistrer la consultation', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(child: Text('* Champs obligatoires',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic))),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAnimalHeader() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.green[50],
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.green.shade300, width: 1.5),
    ),
    child: Row(children: [
      Container(
        width: 56, height: 56,
        decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(12)),
        child: Icon(Icons.pets, size: 30, color: Colors.green[700]),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.animal['nom'] ?? 'Sans nom',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text('${widget.animal['race'] ?? 'N/A'} · ${widget.animal['sexe'] ?? 'N/A'}',
              style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          Text('Tag: ${widget.animal['tag_rfid'] ?? 'N/A'}',
              style: TextStyle(color: Colors.grey[500], fontSize: 12, fontFamily: 'monospace')),
        ],
      )),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: widget.source == 'nee' ? Colors.blue[100] : Colors.orange[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          widget.source == 'nee' ? '🐑 Né' : '🛒 Acheté',
          style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold,
            color: widget.source == 'nee' ? Colors.blue[800] : Colors.orange[800],
          ),
        ),
      ),
    ]),
  );

  Widget _buildVitalesRow() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.blue[50],
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.blue.shade200),
    ),
    child: Column(
      children: [
        Row(children: [
          Expanded(child: _vitaleField(_poidsCtrl, 'Poids', 'kg', _normales['poids']!)),
          const SizedBox(width: 12),
          Expanded(child: _vitaleField(_tempCtrl, 'Température', '°C', _normales['temperature']!)),
          const SizedBox(width: 12),
          Expanded(child: _vitaleField(_fcCtrl, 'Fréquence card.', 'bpm', _normales['fc']!)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.info_outline, size: 14, color: Colors.blue[600]),
          const SizedBox(width: 4),
          Text('Valeurs normales Ladoum indiquées', style: TextStyle(fontSize: 11, color: Colors.blue[700])),
        ]),
      ],
    ),
  );

  Widget _vitaleField(TextEditingController ctrl, String label, String unite, String normale) => TextFormField(
    controller: ctrl,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: '$label ($unite)',
      hintText: normale,
      hintStyle: const TextStyle(fontSize: 11),
      border: const OutlineInputBorder(),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
    ),
    style: const TextStyle(fontSize: 14),
  );

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {int maxLines = 1, String? hint, bool required = false}) =>
    TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon, color: Colors.green[700]),
      ),
      validator: required ? (v) => v!.trim().isEmpty ? 'Champ requis' : null : null,
    );

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
  );

  Widget _datePicker() => Card(
    child: ListTile(
      dense: true,
      leading: const Icon(Icons.calendar_today, color: Colors.green),
      title: const Text('Date', style: TextStyle(fontSize: 12)),
      subtitle: Text(_fmtDate(_date), style: const TextStyle(fontWeight: FontWeight.bold)),
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: _date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (d != null && mounted) setState(() => _date = d);
      },
    ),
  );

  Widget _timePicker() => Card(
    child: ListTile(
      dense: true,
      leading: const Icon(Icons.access_time, color: Colors.green),
      title: const Text('Heure', style: TextStyle(fontSize: 12)),
      subtitle: Text('${_heure.hour.toString().padLeft(2,'0')}:${_heure.minute.toString().padLeft(2,'0')}',
          style: const TextStyle(fontWeight: FontWeight.bold)),
      onTap: () async {
        final t = await showTimePicker(context: context, initialTime: _heure);
        if (t != null && mounted) setState(() => _heure = t);
      },
    ),
  );

  String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}