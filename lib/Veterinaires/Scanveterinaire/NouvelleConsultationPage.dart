import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ✅ ÉTAPE 3 : Notification locale vétérinaire
import 'package:depart/Eleveures/New/Notification/NotificationService.dart';

// ============================================================
// NOUVELLE CONSULTATION
// ✅ Notification in-app + Push FCM après enregistrement
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

  // ─── Récupérer l'ID de l'éleveur propriétaire ───────────
  Future<String?> _getEleveurId() async {
    try {
      final table =
          widget.source == 'nee' ? 'nouveaux_nee' : 'animal_acheter';
      final result = await supabase
          .from(table)
          .select('user_id')
          .eq('id', widget.animal['id'])
          .maybeSingle();
      return result?['user_id']?.toString();
    } catch (e) {
      debugPrint('Erreur récupération éleveur: $e');
      return null;
    }
  }

  // ─── Notification in-app (table notifications) ───────────
  Future<void> _notifierEleveurInApp({
    required String eleveurId,
    required String veterinaireId,
    required String nomAnimal,
    required String motif,
  }) async {
    try {
      final vetData = await supabase
          .from('users')
          .select('nom_complet, prenom, nom')
          .eq('id', veterinaireId)
          .maybeSingle();

      String nomVet = 'Dr. Inconnu';
      if (vetData != null) {
        nomVet = vetData['nom_complet'] ??
            ((vetData['prenom'] != null && vetData['nom'] != null)
                ? '${vetData['prenom']} ${vetData['nom']}'
                : 'Dr. Inconnu');
      }

      await supabase.from('notifications').insert({
        'destinataire_id': eleveurId,
        'expediteur_id': veterinaireId,
        'type': 'nouvelle_consultation',
        'titre': 'Consultation enregistrée pour $nomAnimal',
        'corps':
            '$nomVet a effectué une consultation.\nMotif : $motif\nConsultez l\'historique médical pour les détails.',
        'animal_id': widget.animal['id'].toString(),
        'animal_source': widget.source,
        'lu': false,
        'created_at': DateTime.now().toIso8601String(),
      });
      debugPrint('Notification in-app envoyée à $eleveurId');
    } catch (e) {
      debugPrint('Notification in-app non envoyée: $e');
    }
  }

  // ─── Push FCM (Edge Function Supabase) ───────────────────
  Future<void> _envoyerPushFCM({
    required String eleveurId,
    required String nomAnimal,
    required String motif,
  }) async {
    try {
      final titre = 'Consultation — $nomAnimal';
      final corps =
          'Consultation enregistrée.\nMotif : $motif\nOuvrez l\'app pour les détails.';

      await supabase.functions.invoke(
        'send-push-notification',
        body: {
          'user_id': eleveurId,
          'title': titre,
          'body': corps,
          'type': 'nouvelle_consultation',
          'channel': 'alerte_channel',
          'data': {
            'animal_id': widget.animal['id'].toString(),
            'source': widget.source,
          },
        },
      );
      debugPrint('Push FCM consultation envoyé à $eleveurId');
    } catch (e) {
      debugPrint('Push FCM non envoyé (silencieux): $e');
    }
  }

  Future<void> _enregistrerConsultation() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final veterinaire = supabase.auth.currentUser;
      if (veterinaire == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Session expirée. Veuillez vous reconnecter.'),
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

      // 1. Enregistrer la consultation
      await supabase.from('consultations').insert(data);

      // 2. Récupérer l'ID de l'éleveur
      final eleveurId = await _getEleveurId();
      if (eleveurId != null) {
        final nomAnimal =
            widget.animal['nom']?.toString() ?? 'votre animal';
        final motif = _motifController.text.trim();

        // 2a. Notification in-app
        await _notifierEleveurInApp(
          eleveurId: eleveurId,
          veterinaireId: veterinaire.id,
          nomAnimal: nomAnimal,
          motif: motif,
        );

        // 2b. Push FCM sur le téléphone (éleveur)
        await _envoyerPushFCM(
          eleveurId: eleveurId,
          nomAnimal: nomAnimal,
          motif: motif,
        );
      }

      // 3. ✅ Notification locale au vétérinaire (confirmation)
      await NotificationService().afficherNotificationImmediateLocal(
        titre  : 'Consultation enregistrée',
        corps  : '${_motifController.text.trim()} — '
                 '${widget.animal['nom']?.toString() ?? 'Animal'}'
                 '\nL\'éleveur a été notifié.',
        type   : 'consultation_validee',
        urgente: false,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Erreur enregistrement: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
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
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Enregistrement et notification en cours...'),
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
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.notifications_active,
                              color: Colors.green[700], size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'L\'éleveur recevra une notification in-app ET un push sur son téléphone',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.green[900]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('Informations de consultation',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildDatePicker()),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTimePicker()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(_motifController,
                        'Motif de consultation *',
                        'Ex: Contrôle de routine, boiterie...',
                        Icons.comment,
                        maxLines: 2, required: true),
                    const SizedBox(height: 16),
                    _buildTextField(_examenController,
                        'Examen clinique *',
                        'Température, fréquence cardiaque...',
                        Icons.monitor_heart,
                        maxLines: 4, required: true),
                    const SizedBox(height: 16),
                    _buildTextField(_diagnosticController,
                        'Diagnostic *',
                        'Diagnostic posé suite à l\'examen',
                        Icons.assignment,
                        maxLines: 3, required: true),
                    const SizedBox(height: 16),
                    _buildTextField(_traitementController,
                        'Traitement prescrit *',
                        'Médicaments, posologie, durée...',
                        Icons.medication,
                        maxLines: 4, required: true),
                    const SizedBox(height: 16),
                    const Text('Paramètres vitaux (optionnel)',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
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
                        'Remarques, recommandations...',
                        Icons.notes,
                        maxLines: 3),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : _enregistrerConsultation,
                        icon: const Icon(Icons.check_circle),
                        label: const Text(
                            'Enregistrer & Notifier l\'éleveur',
                            style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
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
          ? (val) =>
              (val == null || val.isEmpty) ? 'Champ requis' : null
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
                  widget.animal['nom']?.toString() ?? 'Sans nom',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                    'Race: ${widget.animal['race']?.toString() ?? 'N/A'}',
                    style: TextStyle(
                        fontSize: 14, color: Colors.grey[700])),
                Text(
                    'Sexe: ${widget.animal['sexe']?.toString() ?? 'N/A'}',
                    style: TextStyle(
                        fontSize: 14, color: Colors.grey[700])),
                Text(
                    'Tag: ${widget.animal['tag_rfid']?.toString() ?? 'N/A'}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[600])),
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
        leading:
            const Icon(Icons.calendar_today, color: Colors.green),
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