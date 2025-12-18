import 'package:depart/Eleveures/Chaleur/EnregistrerChaleurPage.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ============================================================
// PARTIE 2/3 : FICHE DÉTAILLÉE D'UNE BREBIS
// À ajouter après la Partie 1
// ============================================================

class FicheBrebisPage extends StatefulWidget {
  final Map<String, dynamic> brebis;
  final String source;

  const FicheBrebisPage({
    super.key,
    required this.brebis,
    required this.source,
  });

  @override
  State<FicheBrebisPage> createState() => _FicheBrebisPageState();
}

class _FicheBrebisPageState extends State<FicheBrebisPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _historiqueChaleurs = [];
  bool _isLoading = true;
  bool _estGestante = false;
  bool _enLactation = false;
  DateTime? _dateSevrage;

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  Future<void> _chargerDonnees() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);

    try {
      final chaleurs = await supabase
          .from('chaleurs')
          .select('*')
          .eq('animal_id', widget.brebis['id'])
          .eq('source', widget.source)
          .order('date_chaleur', ascending: false);

      final accouplements = await supabase
          .from('accouplements')
          .select('date_accouplement, date_mise_bas')
          .eq('brebis_id', widget.brebis['id'])
          .eq('source_brebis', widget.source)
          .order('date_accouplement', ascending: false)
          .limit(1)
          .maybeSingle();

      if (accouplements != null && accouplements['date_mise_bas'] == null) {
        _estGestante = true;
      }

      if (accouplements != null && accouplements['date_mise_bas'] != null) {
        final dateMiseBas = DateTime.parse(accouplements['date_mise_bas']);
        final joursDepuisMiseBas = DateTime.now().difference(dateMiseBas).inDays;
        if (joursDepuisMiseBas < 90) {
          _enLactation = true;
        }
      }

      if (widget.source == 'nee' && widget.brebis['date_sevrage'] != null) {
        _dateSevrage = DateTime.parse(widget.brebis['date_sevrage']);
      }

      if (mounted) {
        setState(() {
          _historiqueChaleurs = List<Map<String, dynamic>>.from(chaleurs);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Erreur chargement données: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.brebis['nom'] ?? 'Brebis'),
        backgroundColor: Colors.pink[700],
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
                  _buildStatutReproductif(),
                  const SizedBox(height: 16),
                  _buildHistoriqueChaleurs(),
                ],
              ),
            ),
      floatingActionButton: _estGestante
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EnregistrerChaleurPage(
                      brebis: widget.brebis,
                      source: widget.source,
                      enLactation: _enLactation,
                      dateSevrage: _dateSevrage,
                    ),
                  ),
                ).then((_) => _chargerDonnees());
              },
              icon: const Icon(Icons.add),
              label: const Text("Enregistrer chaleur"),
              backgroundColor: Colors.pink[700],
            ),
    );
  }

  Widget _buildInfoGenerales() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (widget.brebis['image_url'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  widget.brebis['image_url'],
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Icon(Icons.pets, size: 80),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.pets, "Nom", widget.brebis['nom'] ?? 'N/A'),
            _buildInfoRow(Icons.agriculture, "Race", widget.brebis['race'] ?? 'N/A'),
            _buildInfoRow(Icons.nfc, "Tag RFID", widget.brebis['tag_rfid'] ?? 'N/A'),
            if (widget.source == 'achete')
              _buildInfoRow(Icons.location_on, "Provenance", widget.brebis['provenance'] ?? 'N/A'),
            if (widget.source == 'nee')
              _buildInfoRow(Icons.cake, "Date naissance", widget.brebis['date_naissance'] ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatutReproductif() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Statut reproductif", 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_estGestante)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange, width: 2),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.pregnant_woman, color: Colors.orange, size: 30),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text("🤰 Gestante\nEnregistrement chaleur bloqué",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            if (_enLactation && !_estGestante)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue, width: 2),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.baby_changing_station, color: Colors.blue, size: 30),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text("🍼 En lactation\nChaleurs possibles mais irrégulières",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            if (!_estGestante && !_enLactation)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 30),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text("✅ Disponible pour reproduction",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoriqueChaleurs() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: Colors.pink),
                const SizedBox(width: 8),
                const Text("Historique des chaleurs",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            if (_historiqueChaleurs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text("Aucune chaleur enregistrée",
                      style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey)),
                ),
              )
            else
              ..._historiqueChaleurs.map((c) => _buildChaleurItem(c)),
          ],
        ),
      ),
    );
  }

  Widget _buildChaleurItem(Map<String, dynamic> chaleur) {
    final date = DateTime.parse(chaleur['date_chaleur']);
    final joursDepuis = DateTime.now().difference(date).inDays;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.pink[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.pink.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("📅 ${_formatDate(date)}", 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text("Il y a $joursDepuis jours",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
          const SizedBox(height: 4),
          Text("Intensité: ${chaleur['intensite'] ?? 'N/A'}"),
          Text("Signes: ${chaleur['signes'] ?? 'N/A'}"),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.pink),
          const SizedBox(width: 8),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }
}