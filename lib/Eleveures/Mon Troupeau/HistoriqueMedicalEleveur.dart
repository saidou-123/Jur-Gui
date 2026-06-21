import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// HISTORIQUE MÉDICAL ÉLEVEUR (LECTURE SEULE)
// ✅ ÉTAPE 2 : Zéro requête N+1 — utilise la vue SQL
//    historique_medical_complet (1 seule requête au lieu de N*2)
// ✅ ÉTAPE 1 : Filtrage sécurisé par eleveur_id
// ============================================================
class HistoriqueMedicalEleveur extends StatefulWidget {
  const HistoriqueMedicalEleveur({super.key});

  @override
  State<HistoriqueMedicalEleveur> createState() =>
      _HistoriqueMedicalEleveurState();
}

class _HistoriqueMedicalEleveurState
    extends State<HistoriqueMedicalEleveur> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _historique = [];
  bool _isLoading = true;
  String _filtre = 'Tout';
  String? _eleveurId;

  @override
  void initState() {
    super.initState();
    _eleveurId = supabase.auth.currentUser?.id;
    _chargerHistorique();
  }

  Future<void> _chargerHistorique() async {
    if (!mounted) return;

    if (_eleveurId == null) {
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

    setState(() => _isLoading = true);

    try {
      // ✅ UNE SEULE REQUÊTE grâce à la vue SQL
      // La vue contient eleveur_id calculé depuis nouveaux_nee.user_id
      // ou animal_acheter.user_id selon la source de l'animal
      // Avant : boucles avec N*2 requêtes supplémentaires
      // Après : 1 requête filtrée = résultat instantané
      final data = await supabase
          .from('historique_medical_complet')
          .select()
          .eq('eleveur_id', _eleveurId!) // ✅ sécurité : seulement ses animaux
          .order('date_acte', ascending: false);

      if (mounted) {
        setState(() {
          _historique = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement historique éleveur: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _historiqueFiltre {
    if (_filtre == 'Tout') return _historique;
    if (_filtre == 'Consultations') {
      return _historique
          .where((item) => item['type_acte'] == 'consultation')
          .toList();
    }
    if (_filtre == 'Vaccinations') {
      return _historique
          .where((item) => item['type_acte'] == 'vaccination')
          .toList();
    }
    return _historique;
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return 'Date inconnue';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique Médical'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_isLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '${_historique.length} acte(s)',
                  style:
                      const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerHistorique,
          ),
        ],
      ),
      body: Column(
        children: [
          // Bannière sécurité + performance
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.green[50],
            child: Row(
              children: [
                Icon(Icons.verified_user,
                    color: Colors.green[700], size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '🔒 Affichage limité à vos animaux — chargement optimisé',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[900],
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

          _buildFilterChips(),

          if (!_isLoading && _historiqueFiltre.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(children: [
                Text(
                  '${_historiqueFiltre.length} enregistrement${_historiqueFiltre.length > 1 ? 's' : ''}',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500),
                ),
              ]),
            ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _historiqueFiltre.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _chargerHistorique,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _historiqueFiltre.length,
                          itemBuilder: (context, index) => _buildItem(
                              _historiqueFiltre[index], index),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filtres = ['Tout', 'Consultations', 'Vaccinations'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filtres.map((f) {
            final isSelected = _filtre == f;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(f),
                selected: isSelected,
                onSelected: (_) => setState(() => _filtre = f),
                selectedColor: Colors.green[200],
                checkmarkColor: Colors.green[900],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> item, int index) {
    final isConsultation = item['type_acte'] == 'consultation';
    final couleur = isConsultation ? Colors.green : Colors.blue;
    final icone =
        isConsultation ? Icons.medical_services : Icons.vaccines;
    final isLast = index == _historiqueFiltre.length - 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showDetail(item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: couleur.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: couleur, width: 2),
                    ),
                    child: Icon(icone, color: couleur, size: 24),
                  ),
                  if (!isLast)
                    Container(
                        width: 2,
                        height: 40,
                        margin: const EdgeInsets.only(top: 4),
                        color: couleur.withOpacity(0.3)),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDate(item['date_acte']?.toString()),
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: couleur.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isConsultation
                                ? 'CONSULTATION'
                                : 'VACCINATION',
                            style: TextStyle(
                                fontSize: 10,
                                color: couleur,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item['titre'] ?? 'Sans titre',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Text('🐑 '),
                      Text(
                        item['animal_nom'] ?? 'Inconnu',
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600),
                      ),
                      if (item['animal_race'] != null &&
                          item['animal_race'].toString().isNotEmpty)
                        Text(' (${item['animal_race']})',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[600])),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      item['description'] ?? '',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '👨‍⚕️ ${item['veterinaire_nom'] ?? 'Dr. Inconnu'}',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String msg;
    if (_filtre == 'Consultations') {
      msg = 'Aucune consultation enregistrée';
    } else if (_filtre == 'Vaccinations') {
      msg = 'Aucune vaccination enregistrée';
    } else {
      msg = 'Aucun historique médical';
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medical_information,
              size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(msg,
              style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('Les soins vétérinaires apparaîtront ici',
              style:
                  TextStyle(fontSize: 14, color: Colors.grey[500])),
        ],
      ),
    );
  }

  void _showDetail(Map<String, dynamic> item) {
    final isConsultation = item['type_acte'] == 'consultation';
    final couleur = isConsultation ? Colors.green : Colors.blue;
    final icone =
        isConsultation ? Icons.medical_services : Icons.vaccines;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // En-tête
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: couleur.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(icone, color: couleur, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item['titre'] ?? 'Détail',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: couleur),
                      ),
                    ),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bannière lecture seule
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(children: [
                        Icon(Icons.visibility,
                            color: Colors.blue[700], size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Mode consultation — vous ne pouvez pas modifier ces informations',
                            style: TextStyle(
                                fontSize: 12, color: Colors.blue[900]),
                          ),
                        ),
                      ]),
                    ),

                    _detailRow('Date',
                        _formatDate(item['date_acte']?.toString()),
                        Icons.calendar_today),
                    _detailRow(
                        'Animal',
                        '${item['animal_nom'] ?? 'Inconnu'}'
                            '${item['animal_race'] != null && item['animal_race'].toString().isNotEmpty ? ' (${item['animal_race']})' : ''}',
                        Icons.pets),
                    _detailRow('Vétérinaire',
                        item['veterinaire_nom'] ?? 'Dr. Inconnu',
                        Icons.person),

                    if (isConsultation) ...[
                      if (item['diagnostic'] != null &&
                          item['diagnostic'].toString().isNotEmpty)
                        _sectionBox('Diagnostic', item['diagnostic'],
                            Colors.green),
                      if (item['traitement'] != null &&
                          item['traitement'].toString().isNotEmpty)
                        _sectionBox('Traitement', item['traitement'],
                            Colors.orange),
                    ] else ...[
                      const SizedBox(height: 8),
                      _detailRow('Vaccin',
                          item['nom_vaccin'] ?? 'N/A', Icons.vaccines),
                      _detailRow(
                          'Date rappel',
                          _formatDate(
                              item['date_rappel']?.toString()),
                          Icons.event_repeat),
                      if (item['lot'] != null && item['lot'] != 'N/A')
                        _detailRow(
                            'N° de lot', item['lot'], Icons.tag),
                    ],

                    if (item['observations'] != null &&
                        item['observations'].toString().isNotEmpty)
                      _sectionBox('Observations',
                          item['observations'], Colors.grey),

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: couleur,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Fermer',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.green[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionBox(String titre, String contenu, Color couleur) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text('$titre :',
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: couleur.withOpacity(0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: couleur.withOpacity(0.3)),
          ),
          child: Text(contenu, style: const TextStyle(fontSize: 14)),
        ),
      ],
    );
  }
}