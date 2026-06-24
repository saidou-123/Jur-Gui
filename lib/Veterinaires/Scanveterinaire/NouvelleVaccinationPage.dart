import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// NOUVELLE VACCINATION
// ✅ Notification in-app + Push FCM après enregistrement
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
    required String nomVaccin,
    String? dateRappelFormatee,
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

      String corps =
          '$nomVet a effectué une vaccination.\nVaccin : $nomVaccin';
      if (dateRappelFormatee != null) {
        corps += '\nRappel prévu le : $dateRappelFormatee';
      }
      corps += '\nConsultez l\'historique médical pour les détails.';

      await supabase.from('notifications').insert({
        'destinataire_id': eleveurId,
        'expediteur_id': veterinaireId,
        'type': 'nouvelle_vaccination',
        'titre': 'Vaccination enregistrée pour $nomAnimal',
        'corps': corps,
        'animal_id': widget.animal['id'].toString(),
        'animal_source': widget.source,
        'lu': false,
        'created_at': DateTime.now().toIso8601String(),
      });
      debugPrint('Notification in-app vaccination envoyée à $eleveurId');
    } catch (e) {
      debugPrint('Notification in-app non envoyée: $e');
    }
  }

  // ─── Push FCM (Edge Function Supabase) ───────────────────
  Future<void> _envoyerPushFCM({
    required String eleveurId,
    required String nomAnimal,
    required String nomVaccin,
    String? dateRappelFormatee,
  }) async {
    try {
      final titre = 'Vaccination — $nomAnimal';
      String corps = 'Vaccination enregistrée : $nomVaccin.';
      if (dateRappelFormatee != null) {
        corps += ' Rappel le $dateRappelFormatee.';
      }
      corps += ' Ouvrez l\'app pour les détails.';

      await supabase.functions.invoke(
        'send-push-notification',
        body: {
          'user_id': eleveurId,
          'title': titre,
          'body': corps,
          'type': 'nouvelle_vaccination',
          'channel': 'alerte_channel',
          'data': {
            'animal_id': widget.animal['id'].toString(),
            'source': widget.source,
          },
        },
      );
      debugPrint('Push FCM vaccination envoyé à $eleveurId');
    } catch (e) {
      debugPrint('Push FCM non envoyé (silencieux): $e');
    }
  }

  String _formaterDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
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
                  Text('Session expirée. Veuillez vous reconnecter.'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
        return;
      }

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

      // 1. Enregistrer la vaccination
      await supabase.from('vaccinations').insert(data);

      // 2. Récupérer l'éleveur et notifier
      final eleveurId = await _getEleveurId();
      if (eleveurId != null) {
        final nomAnimal =
            widget.animal['nom']?.toString() ?? 'votre animal';
        final nomVaccin = _vaccController.text.trim();
        final dateRappelFormatee =
            _dateRappel != null ? _formaterDate(_dateRappel!) : null;

        // 2a. Notification in-app
        await _notifierEleveurInApp(
          eleveurId: eleveurId,
          veterinaireId: veterinaire.id,
          nomAnimal: nomAnimal,
          nomVaccin: nomVaccin,
          dateRappelFormatee: dateRappelFormatee,
        );

        // 2b. Push FCM sur le téléphone
        await _envoyerPushFCM(
          eleveurId: eleveurId,
          nomAnimal: nomAnimal,
          nomVaccin: nomVaccin,
          dateRappelFormatee: dateRappelFormatee,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Vaccination enregistrée — éleveur notifié (in-app + push)'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Erreur enregistrement vaccination: $e');
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
        title: const Text('Nouvelle Vaccination'),
        backgroundColor: Colors.blue[700],
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
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.notifications_active,
                              color: Colors.blue[700], size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'L\'éleveur recevra une notification in-app ET un push sur son téléphone',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[900]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('Informations de vaccination',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
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
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateCard(
                            'Date vaccination',
                            _dateVaccination,
                            Icons.calendar_today,
                            Colors.blue,
                            (date) =>
                                setState(() => _dateVaccination = date),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDateCard(
                            'Date rappel',
                            _dateRappel,
                            Icons.event_repeat,
                            Colors.orange,
                            (date) =>
                                setState(() => _dateRappel = date),
                            nullable: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                            'Enregistrer & Notifier l\'éleveur',
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
          date != null ? _formaterDate(date) : 'Non définie',
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
                icon: const Icon(Icons.clear,
                    size: 16, color: Colors.grey),
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
            child:
                const Icon(Icons.pets, size: 30, color: Colors.blue),
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
}