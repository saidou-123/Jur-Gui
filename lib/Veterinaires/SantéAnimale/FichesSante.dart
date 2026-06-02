import 'package:depart/Veterinaires/Scanveterinaire/FicheSanteDetailAnimal.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


// ============================================================
// FICHES DE SANTÉ — Liste et Gestion (version synchronisée)
// ============================================================
class FichesSante extends StatefulWidget {
  const FichesSante({super.key});

  @override
  State<FichesSante> createState() => _FichesSanteState();
}

class _FichesSanteState extends State<FichesSante> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _animaux = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _chargerAnimaux();
  }

  Future<void> _chargerAnimaux() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      List<Map<String, dynamic>> tousLesAnimaux = [];

      final nees = await supabase
          .from('nouveaux_nee')
          .select('*')
          .order('nom');
      for (var animal in nees) {
        animal['source'] = 'nee';
        tousLesAnimaux.add(animal);
      }

      final achetes = await supabase
          .from('animal_acheter')
          .select('*')
          .order('nom');
      for (var animal in achetes) {
        animal['source'] = 'achete';
        tousLesAnimaux.add(animal);
      }

      if (mounted) {
        setState(() {
          _animaux = tousLesAnimaux;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement animaux: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _animauxFiltres {
    if (_searchQuery.isEmpty) return _animaux;
    return _animaux.where((animal) {
      final nom = animal['nom']?.toString().toLowerCase() ?? '';
      final race = animal['race']?.toString().toLowerCase() ?? '';
      final tag = animal['tag_rfid']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return nom.contains(query) || race.contains(query) || tag.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fiches de Santé'),
        backgroundColor: Colors.green[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerAnimaux,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher par nom, race ou tag...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _animauxFiltres.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucun animal trouvé',
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _chargerAnimaux,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _animauxFiltres.length,
                          itemBuilder: (context, index) =>
                              _buildAnimalCard(_animauxFiltres[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimalCard(Map<String, dynamic> animal) {
    final source =
        animal['source'] == 'achete' ? '🛒 Acheté' : '🐑 Nouveau-né';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: animal['image_url'] != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  animal['image_url'],
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[300],
                    child: const Icon(Icons.pets, size: 30),
                  ),
                ),
              )
            : Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    Icon(Icons.pets, size: 30, color: Colors.green[300]),
              ),
        title: Text(
          animal['nom'] ?? 'Sans nom',
          style:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Race: ${animal['race'] ?? 'N/A'}'),
            Text(source,
                style:
                    TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.green),
        onTap: () {
          // ✅ CORRIGÉ : navigue vers FicheSanteDetailAnimal
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FicheSanteDetailAnimal(
                animal: animal,
                source: animal['source'],
              ),
            ),
          ).then((_) => _chargerAnimaux());
        },
      ),
    );
  }
}