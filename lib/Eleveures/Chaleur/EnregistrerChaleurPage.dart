import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ============================================================
// PARTIE 3/3 : FORMULAIRE D'ENREGISTREMENT DE CHALEUR
// À ajouter après la Partie 2
// ============================================================

class EnregistrerChaleurPage extends StatefulWidget {
  final Map<String, dynamic> brebis;
  final String source;
  final bool enLactation;
  final DateTime? dateSevrage;

  const EnregistrerChaleurPage({
    super.key,
    required this.brebis,
    required this.source,
    required this.enLactation,
    this.dateSevrage,
  });

  @override
  State<EnregistrerChaleurPage> createState() => _EnregistrerChaleurPageState();
}

class _EnregistrerChaleurPageState extends State<EnregistrerChaleurPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  DateTime _dateSelectionnee = DateTime.now();
  TimeOfDay _heureSelectionnee = TimeOfDay.now();
  String? _intensite;
  final _signesController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _signesController.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final dateComplete = DateTime(
        _dateSelectionnee.year,
        _dateSelectionnee.month,
        _dateSelectionnee.day,
        _heureSelectionnee.hour,
        _heureSelectionnee.minute,
      );

      final mois = _dateSelectionnee.month;
      bool anoestrus = (mois >= 6 && mois <= 8);
      
      final derniereChaleur = await supabase
          .from('chaleurs')
          .select('date_chaleur')
          .eq('animal_id', widget.brebis['id'])
          .eq('source', widget.source)
          .order('date_chaleur', ascending: false)
          .limit(1)
          .maybeSingle();

      int? intervalleJours;
      String? avertissement;
      
      if (derniereChaleur != null) {
        final derniere = DateTime.parse(derniereChaleur['date_chaleur']);
        intervalleJours = _dateSelectionnee.difference(derniere).inDays;

        if (intervalleJours < 14) {
          avertissement = "⚠️ Intervalle de $intervalleJours jours (normal: 17-21 jours).\nCela peut indiquer une anomalie. Consultez un vétérinaire si cela se répète.";
        } else if (intervalleJours > 25) {
          avertissement = "⚠️ Intervalle de $intervalleJours jours (normal: 17-21 jours).\nUn cycle long peut indiquer un stress ou un problème de santé.";
        }
      }

      await supabase.from('chaleurs').insert({
        'animal_id': widget.brebis['id'],
        'source': widget.source,
        'date_chaleur': dateComplete.toIso8601String(),
        'intensite': _intensite,
        'signes': _signesController.text.trim(),
        'user_id': supabase.auth.currentUser!.id,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint("✅ Chaleur enregistrée avec succès");

      final debutFenetre = dateComplete.add(const Duration(hours: 12));
      final finFenetre = dateComplete.add(const Duration(hours: 30));

      DateTime? prochaineMin;
      DateTime? prochaineMax;
      bool predictionActive = !anoestrus;

      if (predictionActive) {
        prochaineMin = dateComplete.add(const Duration(days: 17));
        prochaineMax = dateComplete.add(const Duration(days: 21));
      }

      String niveauConfiance = "Élevé";
      if (widget.enLactation || (widget.dateSevrage != null &&
          _dateSelectionnee.difference(widget.dateSevrage!).inDays < 30)) {
        niveauConfiance = "Modéré";
      }
      if (intervalleJours != null && (intervalleJours < 14 || intervalleJours > 25)) {
        niveauConfiance = "Faible";
      }

      if (mounted) {
        setState(() => _isLoading = false);
        
        await _showSuccessDialog(
          debutFenetre,
          finFenetre,
          prochaineMin,
          prochaineMax,
          niveauConfiance,
          predictionActive,
          avertissement,
        );
      }
    } catch (e) {
      debugPrint("❌ Erreur enregistrement: $e");
      if (mounted) {
        _showSnackBar("❌ Erreur: ${e.toString()}", Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showSuccessDialog(
    DateTime debutFenetre,
    DateTime finFenetre,
    DateTime? prochaineMin,
    DateTime? prochaineMax,
    String niveauConfiance,
    bool predictionActive,
    String? avertissement,
  ) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        title: const Text(
          "✅ Chaleur enregistrée avec succès",
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Récapitulatif et recommandations:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              _buildInfoBox(
                "🎯 Fenêtre d'accouplement optimale",
                "Du ${_formatDateTime(debutFenetre)}\nau ${_formatDateTime(finFenetre)}\n\n(12-30 heures après début chaleur)",
                Colors.green,
              ),
              const SizedBox(height: 12),
              if (predictionActive && prochaineMin != null && prochaineMax != null)
                _buildInfoBox(
                  "📅 Prochaine chaleur prévue",
                  "Entre le ${_formatDate(prochaineMin)}\net le ${_formatDate(prochaineMax)}\n\nNiveau de confiance: $niveauConfiance",
                  Colors.blue,
                )
              else
                _buildInfoBox(
                  "❌ Prédiction désactivée",
                  "Période d'anœstrus saisonnier.\nLes prédictions ne sont pas fiables durant cette période.",
                  Colors.red,
                ),
              if (avertissement != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange, width: 2),
                  ),
                  child: Text(avertissement,
                      style: const TextStyle(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.bold)),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("💡 Notifications programmées:",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text("• Rappel fenêtre accouplement"),
                    Text("• Alerte prochaine chaleur (si active)"),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text("Terminer"),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(String titre, String contenu, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titre, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
          const SizedBox(height: 6),
          Text(contenu, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, duration: const Duration(seconds: 2)),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  String _formatDateTime(DateTime date) {
    return "${_formatDate(date)} à ${date.hour}h${date.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Enregistrer une chaleur"),
        backgroundColor: Colors.pink[700],
      ),
      body: _isLoading
          ? const Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [CircularProgressIndicator(), SizedBox(height: 16), Text("Enregistrement en cours...")],
            ))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.pink[50], borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          Icon(Icons.pets, color: Colors.pink[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.brebis['nom'] ?? 'Sans nom',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                Text("Race: ${widget.brebis['race'] ?? 'N/A'}",
                                    style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text("Informations sur la chaleur",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildDatePicker(),
                    const SizedBox(height: 16),
                    _buildTimePicker(),
                    const SizedBox(height: 16),
                    _buildIntensiteDropdown(),
                    const SizedBox(height: 16),
                    _buildSignesField(),
                    const SizedBox(height: 32),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDatePicker() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.calendar_today, color: Colors.pink),
        title: const Text("Date de la chaleur"),
        subtitle: Text(_formatDate(_dateSelectionnee)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: _dateSelectionnee,
            firstDate: DateTime.now().subtract(const Duration(days: 30)),
            lastDate: DateTime.now(),
          );
          if (date != null && mounted) {
            setState(() => _dateSelectionnee = date);
          }
        },
      ),
    );
  }

  Widget _buildTimePicker() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.access_time, color: Colors.pink),
        title: const Text("Heure"),
        subtitle: Text("${_heureSelectionnee.hour}h${_heureSelectionnee.minute.toString().padLeft(2, '0')}"),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final time = await showTimePicker(context: context, initialTime: _heureSelectionnee);
          if (time != null && mounted) {
            setState(() => _heureSelectionnee = time);
          }
        },
      ),
    );
  }

  Widget _buildIntensiteDropdown() {
    return DropdownButtonFormField<String>(
      value: _intensite,
      decoration: const InputDecoration(
        labelText: "Intensité de la chaleur",
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.thermostat, color: Colors.pink),
      ),
      items: const [
        DropdownMenuItem(value: "Faible", child: Text("Faible")),
        DropdownMenuItem(value: "Moyenne", child: Text("Moyenne")),
        DropdownMenuItem(value: "Forte", child: Text("Forte")),
      ],
      onChanged: (val) => setState(() => _intensite = val),
      validator: (val) => val == null ? 'Champ requis' : null,
    );
  }

  Widget _buildSignesField() {
    return TextFormField(
      controller: _signesController,
      maxLines: 4,
      decoration: const InputDecoration(
        labelText: "Signes observés",
        hintText: "Ex: Agitation, vocalisation, queue relevée, vulve gonflée...",
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.visibility, color: Colors.pink),
      ),
      validator: (val) => val!.isEmpty ? 'Champ requis' : null,
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _enregistrer,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.check_circle),
        label: Text(
          _isLoading ? "Enregistrement..." : "Enregistrer la chaleur",
          style: const TextStyle(fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.pink[700],
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey,
        ),
      ),
    );
  }
}