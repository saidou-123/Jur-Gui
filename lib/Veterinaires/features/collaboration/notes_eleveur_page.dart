import 'package:depart/Veterinaires/constantes/services/animal_service.dart';
import 'package:depart/Veterinaires/constantes/models/note_eleveur_model.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


/// Page de collaboration vétérinaire → éleveur.
/// Permet d'envoyer des recommandations, alertes et informations à l'éleveur.
class NotesEleveurPage extends StatefulWidget {
  const NotesEleveurPage({super.key});

  @override
  State<NotesEleveurPage> createState() => _NotesEleveurPageState();
}

class _NotesEleveurPageState extends State<NotesEleveurPage> {
  final _noteSvc = NoteService();
  final _db = Supabase.instance.client;

  List<Map<String, dynamic>> _notes = [];
  bool _isLoading = true;

  static const _typeLabels = {
    'recommandation': ('Recommandation', Colors.green, Icons.tips_and_updates),
    'alerte':         ('Alerte', Colors.orange, Icons.warning_amber),
    'information':    ('Information', Colors.blue, Icons.info),
    'urgence':        ('URGENCE', Colors.red, Icons.emergency),
  };

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _isLoading = true);
    try {
      final notes = await _noteSvc.mesNotes();
      if (mounted) setState(() { _notes = notes; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collaboration Éleveur'),
        backgroundColor: Colors.teal[700],
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _charger),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _charger,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notes.length,
                    itemBuilder: (_, i) => _buildNoteCard(_notes[i]),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nouvelleNote,
        icon: const Icon(Icons.send),
        label: const Text('Nouvelle note'),
        backgroundColor: Colors.teal[700],
      ),
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> n) {
    final type = n['type'] ?? 'information';
    final (label, color, icon) = _typeLabels[type] ?? ('Info', Colors.grey, Icons.info);
    final date = _fmt(n['created_at']?.toString() ?? '');
    final lu = n['lu'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: (color as Color).withOpacity(0.4), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon as IconData, size: 14, color: color),
                  const SizedBox(width: 4),
                  Text(label as String, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                ]),
              ),
              const Spacer(),
              if (lu)
                const Icon(Icons.done_all, size: 16, color: Colors.green)
              else
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                ),
              const SizedBox(width: 8),
              Text(date, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ]),
            const SizedBox(height: 10),
            Text(n['titre'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 6),
            Text(n['message'] ?? '', style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.message, size: 80, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text('Aucune note envoyée', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
        const SizedBox(height: 8),
        Text('Envoyez des recommandations à l\'éleveur', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
      ],
    ),
  );

  Future<void> _nouvelleNote() async {
    // Récupérer la liste des éleveurs et animaux
    final animaux = await AnimalService().chargerTousLesAnimaux();
    final eleveurs = await _db.from('users').select('*').eq('role', 'eleveur');
    if (!mounted) return;

    Map<String, dynamic>? animalChoisi;
    Map<String, dynamic>? eleveurChoisi;
    String typeChoisi = 'recommandation';
    final titreCtrl = TextEditingController();
    final msgCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('Nouvelle note', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ]),
                const SizedBox(height: 16),

                // Type de note
                const Text('Type', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: _typeLabels.entries.map((e) {
                  final (label, color, icon) = e.value;
                  final sel = typeChoisi == e.key;
                  return ChoiceChip(
                    label: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, size: 14, color: sel ? Colors.white : color),
                      const SizedBox(width: 4),
                      Text(label as String),
                    ]),
                    selected: sel,
                    selectedColor: color as Color,
                    labelStyle: TextStyle(color: sel ? Colors.white : null, fontSize: 12),
                    onSelected: (_) => setS(() => typeChoisi = e.key),
                  );
                }).toList()),
                const SizedBox(height: 16),

                // Animal
                DropdownButtonFormField<Map<String, dynamic>>(
                  decoration: const InputDecoration(labelText: 'Animal concerné', border: OutlineInputBorder()),
                  items: animaux.map((a) => DropdownMenuItem(
                    value: a,
                    child: Text('${a['nom'] ?? 'Sans nom'} — ${a['race'] ?? ''}'),
                  )).toList(),
                  onChanged: (v) => setS(() => animalChoisi = v),
                ),
                const SizedBox(height: 12),

                // Éleveur destinataire
                DropdownButtonFormField<Map<String, dynamic>>(
                  decoration: const InputDecoration(labelText: 'Envoyer à l\'éleveur', border: OutlineInputBorder()),
                  items: (eleveurs as List<dynamic>).map((e) => DropdownMenuItem(
                    value: e as Map<String, dynamic>,
                    child: Text(e['nom_complet'] ?? e['email'] ?? 'Éleveur'),
                  )).toList(),
                  onChanged: (v) => setS(() => eleveurChoisi = v),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: titreCtrl,
                  decoration: const InputDecoration(labelText: 'Titre *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: msgCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Message / Recommandation *',
                    border: OutlineInputBorder(),
                    hintText: 'Ex: Administrer l\'ivermectine 0.2 mg/kg dans 7 jours...',
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (animalChoisi == null || eleveurChoisi == null ||
                          titreCtrl.text.isEmpty || msgCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Remplissez tous les champs obligatoires')),
                        );
                        return;
                      }
                      try {
                        await _noteSvc.envoyerNote(
                          animalId: animalChoisi!['id'].toString(),
                          source: animalChoisi!['source'],
                          eleveurId: eleveurChoisi!['id'],
                          titre: titreCtrl.text.trim(),
                          message: msgCtrl.text.trim(),
                          type: typeChoisi,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        _charger();
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✅ Note envoyée'), backgroundColor: Colors.green),
                        );
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    icon: const Icon(Icons.send),
                    label: const Text('Envoyer', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) { return iso; }
  }
}