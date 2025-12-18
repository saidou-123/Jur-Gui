import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnimalDeletePage extends StatefulWidget {
  const AnimalDeletePage({super.key});

  @override
  State<AnimalDeletePage> createState() => _AnimalDeletePageState();
}

class _AnimalDeletePageState extends State<AnimalDeletePage> {
  List<Map<String, dynamic>> _animals = [];
  bool _isLoading = true;
  String _selectedTable = 'nouveaux_nee'; // Table par défaut

  @override
  void initState() {
    super.initState();
    _loadAnimals();
  }

  // ----------------------------------------------------------
  // 📥 CHARGER LES ANIMAUX DEPUIS SUPABASE
  // ----------------------------------------------------------
  Future<void> _loadAnimals() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      
      if (userId == null) {
        _showSnackBar("Utilisateur non connecté", Colors.red);
        return;
      }

      debugPrint("📥 Chargement des animaux depuis: $_selectedTable");

      final response = await Supabase.instance.client
          .from(_selectedTable)
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      debugPrint("✅ ${response.length} animaux chargés");

      if (mounted) {
        setState(() {
          _animals = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Erreur de chargement: $e");
      if (mounted) {
        _showSnackBar("Erreur: ${e.toString()}", Colors.red);
        setState(() => _isLoading = false);
      }
    }
  }

  // ----------------------------------------------------------
  // 🗑️ SUPPRIMER UN ANIMAL
  // ----------------------------------------------------------
  Future<void> _deleteAnimal(Map<String, dynamic> animal) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.red,
          size: 64,
        ),
        title: const Text(
          "⚠️ Confirmer la suppression",
          style: TextStyle(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Voulez-vous vraiment supprimer cet animal ?",
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200, width: 2),
              ),
              child: Column(
                children: [
                  if (animal['image_url'] != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        animal['image_url'],
                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    animal['nom'] ?? 'Sans nom',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${animal['race']} • ${animal['sexe']}",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  if (animal['tag_rfid'] != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.nfc, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          animal['tag_rfid'],
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Cette action est irréversible !",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_forever),
            label: const Text("Supprimer"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // Afficher un indicateur de chargement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Suppression en cours..."),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Supprimer l'image du storage si elle existe
      if (animal['image_url'] != null) {
        final url = animal['image_url'] as String;
        if (url.contains('uploads')) {
          final parts = url.split('/uploads/');
          if (parts.length > 1) {
            final filePath = parts[1];
            try {
              await Supabase.instance.client.storage
                  .from('uploads')
                  .remove([filePath]);
              debugPrint("✅ Image supprimée du storage");
            } catch (e) {
              debugPrint("⚠️ Erreur suppression image: $e");
            }
          }
        }
      }

      // Supprimer l'enregistrement de la base de données
      await Supabase.instance.client
          .from(_selectedTable)
          .delete()
          .eq('id', animal['id']);

      debugPrint("✅ Animal supprimé: ${animal['nom']}");

      if (mounted) {
        Navigator.pop(context); // Fermer le dialogue de chargement
        _showSnackBar(
          "✅ ${animal['nom']} supprimé avec succès",
          Colors.green,
        );
        _loadAnimals();
      }
    } catch (e) {
      debugPrint("❌ Erreur suppression: $e");
      if (mounted) {
        Navigator.pop(context); // Fermer le dialogue de chargement
        _showSnackBar("❌ Erreur: ${e.toString()}", Colors.red);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ----------------------------------------------------------
  // 🎨 UI
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Supprimer des Animaux"),
        backgroundColor: Colors.red[700],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTable == 'nouveaux_nee' ? 0 : 1,
        onTap: (index) {
          final newTable = index == 0 ? 'nouveaux_nee' : 'animal_acheter';
          if (newTable != _selectedTable) {
            setState(() => _selectedTable = newTable);
            _loadAnimals();
          }
        },
        selectedItemColor: Colors.red[700],
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.child_care),
            label: 'Nouveaux-nés',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Animaux achetés',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _animals.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.pets, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        "Aucun animal enregistré",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Cette catégorie est vide",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Bannière d'avertissement
                    Container(
                      width: double.infinity,
                      color: Colors.red.shade50,
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.red[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Mode suppression : cliquez sur la corbeille pour supprimer un animal",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.red[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Liste des animaux
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadAnimals,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _animals.length,
                          itemBuilder: (context, index) {
                            final animal = _animals[index];
                            return _buildAnimalCard(animal);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildAnimalCard(Map<String, dynamic> animal) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showAnimalDetails(animal),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: animal['image_url'] != null
                    ? Image.network(
                        animal['image_url'],
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[300],
                            child: const Icon(Icons.error, color: Colors.red),
                          );
                        },
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[300],
                        child: const Icon(Icons.pets, size: 40),
                      ),
              ),
              const SizedBox(width: 12),

              // Informations
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      animal['nom'] ?? 'Sans nom',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildInfoChip(Icons.agriculture, animal['race'] ?? 'N/A'),
                    const SizedBox(height: 4),
                    _buildInfoChip(Icons.wc, animal['sexe'] ?? 'N/A'),
                    if (animal['tag_rfid'] != null) ...[
                      const SizedBox(height: 4),
                      _buildInfoChip(Icons.nfc, animal['tag_rfid']),
                    ],
                  ],
                ),
              ),

              // Bouton Supprimer
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 28),
                onPressed: () => _deleteAnimal(animal),
                tooltip: "Supprimer",
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showAnimalDetails(Map<String, dynamic> animal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.pets, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                animal['nom'] ?? 'Détails',
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (animal['image_url'] != null)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      animal['image_url'],
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              _buildDetailRow("Nom", animal['nom'] ?? 'N/A', Icons.pets),
              _buildDetailRow("Race", animal['race'] ?? 'N/A', Icons.agriculture),
              _buildDetailRow("Sexe", animal['sexe'] ?? 'N/A', Icons.wc),
              if (animal['date_naissance'] != null)
                _buildDetailRow("Date naissance", animal['date_naissance'], Icons.calendar_today),
              if (animal['provenance'] != null)
                _buildDetailRow("Provenance", animal['provenance'], Icons.location_on),
              if (animal['tag_rfid'] != null)
                _buildDetailRow("Tag RFID", animal['tag_rfid'], Icons.nfc),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _deleteAnimal(animal);
            },
            icon: const Icon(Icons.delete),
            label: const Text("Supprimer"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.red[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}