import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// VACCINATIONS — version synchronisée avec Supabase
// ============================================================
class Vaccinations extends StatefulWidget {
  const Vaccinations({super.key});

  @override
  State<Vaccinations> createState() => _VaccinationsState();
}

class _VaccinationsState extends State<Vaccinations>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;

  List<Map<String, dynamic>> _vaccinationsRecentes = [];
  List<Map<String, dynamic>> _rappelsEnCours = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _chargerVaccinations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _chargerVaccinations() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // ✅ Vraies requêtes Supabase
      final vaccinations = await supabase
          .from('vaccinations')
          .select('*')
          .order('date_vaccination', ascending: false);

      List<Map<String, dynamic>> recentes = [];
      List<Map<String, dynamic>> rappels = [];
      final maintenant = DateTime.now();

      for (var v in vaccinations) {
        // Récupérer nom + race de l'animal
        final nomAnimal =
            await _getNomAnimal(v['animal_id']?.toString(), v['source']);
        final raceAnimal =
            await _getRaceAnimal(v['animal_id']?.toString(), v['source']);

        final enrichi = {
          ...v,
          'animal_nom': nomAnimal,
          'animal_race': raceAnimal,
        };

        recentes.add(enrichi);

        // ✅ Calcul dynamique des rappels
        if (v['date_rappel'] != null) {
          try {
            final rappel = DateTime.parse(v['date_rappel'].toString());
            final joursRestants = rappel.difference(maintenant).inDays;

            if (joursRestants >= 0 && joursRestants <= 60) {
              rappels.add({
                ...enrichi,
                'jours_restants': joursRestants,
                'statut': joursRestants <= 7
                    ? 'urgent'
                    : joursRestants <= 14
                        ? 'proche'
                        : 'normal',
              });
            }
          } catch (_) {}
        }
      }

      // Trier les rappels par urgence
      rappels.sort((a, b) =>
          (a['jours_restants'] as int).compareTo(b['jours_restants'] as int));

      if (mounted) {
        setState(() {
          _vaccinationsRecentes = recentes;
          _rappelsEnCours = rappels;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement vaccinations: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String> _getNomAnimal(String? animalId, String? source) async {
    if (animalId == null || source == null) return 'Animal inconnu';
    try {
      final table =
          source == 'nee' ? 'nouveaux_nee' : 'animal_acheter';
      final result = await supabase
          .from(table)
          .select('nom')
          .eq('id', animalId)
          .maybeSingle();
      return result?['nom']?.toString() ?? 'Animal inconnu';
    } catch (_) {
      return 'Animal inconnu';
    }
  }

  Future<String> _getRaceAnimal(String? animalId, String? source) async {
    if (animalId == null || source == null) return 'N/A';
    try {
      final table =
          source == 'nee' ? 'nouveaux_nee' : 'animal_acheter';
      final result = await supabase
          .from(table)
          .select('race')
          .eq('id', animalId)
          .maybeSingle();
      return result?['race']?.toString() ?? 'N/A';
    } catch (_) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vaccinations'),
        backgroundColor: Colors.purple[700],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
                text: 'Récentes (${_vaccinationsRecentes.length})',
                icon: const Icon(Icons.history)),
            Tab(
                text: 'Rappels (${_rappelsEnCours.length})',
                icon: const Icon(Icons.notifications_active)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerVaccinations,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildVaccinationsRecentes(),
                _buildRappels(),
              ],
            ),
    );
  }

  Widget _buildVaccinationsRecentes() {
    if (_vaccinationsRecentes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.vaccines, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('Aucune vaccination enregistrée',
                style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _chargerVaccinations,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _vaccinationsRecentes.length,
        itemBuilder: (context, index) =>
            _buildVaccinationCard(_vaccinationsRecentes[index]),
      ),
    );
  }

  Widget _buildRappels() {
    if (_rappelsEnCours.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 80, color: Colors.green[400]),
            const SizedBox(height: 16),
            const Text('Aucun rappel dans les 60 jours',
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('Tous les vaccins sont à jour !',
                style: TextStyle(
                    fontSize: 14, color: Colors.grey[600])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _chargerVaccinations,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _rappelsEnCours.length,
        itemBuilder: (context, index) =>
            _buildRappelCard(_rappelsEnCours[index]),
      ),
    );
  }

  Widget _buildVaccinationCard(Map<String, dynamic> v) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.vaccines,
                      color: Colors.purple[700], size: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v['nom_vaccin'] ?? 'Vaccin',
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '🐑 ${v['animal_nom']} (${v['animal_race']})',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                    child: _buildInfoItem(
                        Icons.calendar_today,
                        'Date',
                        _formatDate(
                            v['date_vaccination']?.toString() ?? ''))),
                if (v['date_rappel'] != null)
                  Expanded(
                      child: _buildInfoItem(
                          Icons.event_repeat,
                          'Rappel',
                          _formatDate(
                              v['date_rappel'].toString()))),
              ],
            ),
            if (v['lot'] != null && v['lot'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _buildInfoItem(
                    Icons.tag, 'Lot', v['lot'].toString()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRappelCard(Map<String, dynamic> rappel) {
    Color couleur;
    String message;

    final jours = rappel['jours_restants'] as int;
    if (jours <= 7) {
      couleur = Colors.red;
      message = '⚠️ URGENT';
    } else if (jours <= 14) {
      couleur = Colors.orange;
      message = '⚡ Bientôt';
    } else {
      couleur = Colors.blue;
      message = '📅 À venir';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: couleur.withOpacity(0.3), width: 1),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
              left: BorderSide(color: couleur, width: 4)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rappel['nom_vaccin'] ?? 'Vaccin',
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '🐑 ${rappel['animal_nom']} (${rappel['animal_race']})',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: couleur.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: couleur, width: 2),
                    ),
                    child: Text(message,
                        style: TextStyle(
                            color: couleur,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.access_time, size: 20, color: couleur),
                  const SizedBox(width: 8),
                  Text(
                    jours == 0
                        ? "Aujourd'hui !"
                        : 'Dans $jours jour${jours > 1 ? 's' : ''}',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: couleur),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Date du rappel : ${_formatDate(rappel['date_rappel']?.toString() ?? '')}',
                style:
                    TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _effectuerVaccination(rappel),
                  icon: const Icon(Icons.check),
                  label: const Text('Marquer comme effectué'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: couleur,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[600])),
                Text(value,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Enregistrement réel dans Supabase quand on marque le rappel effectué
  void _effectuerVaccination(Map<String, dynamic> rappel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la vaccination'),
        content: Text(
          'Confirmer que la vaccination ${rappel['nom_vaccin']} '
          'pour ${rappel['animal_nom']} a été effectuée aujourd\'hui ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _enregistrerRappelEffectue(rappel);
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirmer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _enregistrerRappelEffectue(
      Map<String, dynamic> rappel) async {
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
        }
        return;
      }

      // ✅ Créer une nouvelle entrée de vaccination dans Supabase
      await supabase.from('vaccinations').insert({
        'animal_id': rappel['animal_id'],
        'source': rappel['source'],
        'veterinaire_id': veterinaire.id,
        'nom_vaccin': rappel['nom_vaccin'],
        'date_vaccination':
            DateTime.now().toIso8601String().split('T').first,
        'observations': 'Rappel effectué suite à la vaccination du '
            '${_formatDate(rappel['date_vaccination']?.toString() ?? '')}',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Vaccination de rappel enregistrée'),
            backgroundColor: Colors.green,
          ),
        );
        await _chargerVaccinations();
      }
    } catch (e) {
      debugPrint('❌ Erreur enregistrement rappel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    } catch (_) {
      return isoDate;
    }
  }
}