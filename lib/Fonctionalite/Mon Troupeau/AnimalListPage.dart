import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnimalListPage extends StatefulWidget {
  const AnimalListPage({super.key});

  @override
  State<AnimalListPage> createState() => _AnimalListPageState();
}

class _AnimalListPageState extends State<AnimalListPage> {
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
  // ✏️ MODIFIER UN ANIMAL
  // ----------------------------------------------------------
  Future<void> _editAnimal(Map<String, dynamic> animal) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditAnimalPage(
          animal: animal,
          tableName: _selectedTable,
        ),
      ),
    );

    if (result == true && mounted) {
      _loadAnimals();
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
        title: const Text("Mes Animaux"),
        backgroundColor: Colors.green[700],
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
        selectedItemColor: Colors.green[700],
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
                        "Ajoutez un animal pour commencer",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
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

              // Bouton Modifier
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue, size: 28),
                onPressed: () => _editAnimal(animal),
                tooltip: "Modifier",
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
              _editAnimal(animal);
            },
            icon: const Icon(Icons.edit),
            label: const Text("Modifier"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
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
          Icon(icon, size: 20, color: Colors.green[700]),
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

// ============================================================
// PAGE DE MODIFICATION D'ANIMAL
// ============================================================
class EditAnimalPage extends StatefulWidget {
  final Map<String, dynamic> animal;
  final String tableName;

  const EditAnimalPage({
    super.key,
    required this.animal,
    required this.tableName,
  });

  @override
  State<EditAnimalPage> createState() => _EditAnimalPageState();
}

class _EditAnimalPageState extends State<EditAnimalPage> {
  late TextEditingController _nomController;
  late TextEditingController _raceController;
  late TextEditingController _dateController;
  late TextEditingController _provenanceController;

  String? _selectedSexe;
  String? _selectedRace;
  XFile? _newImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController(text: widget.animal['nom']);
    _raceController = TextEditingController(text: widget.animal['race']);
    _dateController = TextEditingController(text: widget.animal['date_naissance']);
    _provenanceController = TextEditingController(text: widget.animal['provenance']);
    _selectedSexe = widget.animal['sexe'];
    
    // Pour la table animal_acheter avec dropdown
    if (widget.tableName == 'animal_acheter') {
      _selectedRace = widget.animal['race'];
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _raceController.dispose();
    _dateController.dispose();
    _provenanceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Choisir une source"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text("Appareil photo"),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text("Galerie"),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 75,
      );

      if (image != null && mounted) {
        setState(() => _newImage = image);
      }
    } catch (e) {
      _showSnackBar("Erreur lors de la sélection", Colors.red);
    }
  }

  Future<String?> _uploadNewImage() async {
    if (_newImage == null) return null;

    try {
      final fileName = '${widget.tableName}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await File(_newImage!.path).readAsBytes();

      await Supabase.instance.client.storage
          .from('uploads')
          .uploadBinary(fileName, bytes, fileOptions: const FileOptions(upsert: true));

      return Supabase.instance.client.storage.from('uploads').getPublicUrl(fileName);
    } catch (e) {
      debugPrint("Erreur upload: $e");
      return null;
    }
  }

  Future<void> _saveChanges() async {
    if (_nomController.text.isEmpty || _selectedSexe == null) {
      _showSnackBar("Veuillez remplir tous les champs obligatoires", Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? newImageUrl;
      if (_newImage != null) {
        newImageUrl = await _uploadNewImage();
        if (newImageUrl == null) {
          throw Exception("Erreur lors de l'upload de l'image");
        }
      }

      final updateData = <String, dynamic>{
        'nom': _nomController.text.trim(),
        'sexe': _selectedSexe,
      };

      if (widget.tableName == 'nouveaux_nee') {
        updateData['race'] = _raceController.text.trim();
        if (_dateController.text.isNotEmpty) {
          updateData['date_naissance'] = _dateController.text;
        }
      } else {
        updateData['race'] = _selectedRace;
        if (_provenanceController.text.isNotEmpty) {
          updateData['provenance'] = _provenanceController.text.trim();
        }
      }

      if (newImageUrl != null) {
        updateData['image_url'] = newImageUrl;
      }

      await Supabase.instance.client
          .from(widget.tableName)
          .update(updateData)
          .eq('id', widget.animal['id']);

      if (mounted) {
        _showSnackBar("✅ Modifications enregistrées avec succès", Colors.green);
        await Future.delayed(const Duration(milliseconds: 500));
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Erreur: $e");
      if (mounted) {
        _showSnackBar("Erreur: ${e.toString()}", Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Modifier ${widget.animal['nom'] ?? 'l\'animal'}"),
        backgroundColor: Colors.green[700],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Enregistrement en cours..."),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Image
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.green, width: 3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: _newImage != null
                                  ? Image.file(File(_newImage!.path), fit: BoxFit.cover)
                                  : widget.animal['image_url'] != null
                                      ? Image.network(widget.animal['image_url'], fit: BoxFit.cover)
                                      : const Icon(Icons.camera_alt, size: 60, color: Colors.grey),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.photo_camera),
                          label: const Text("Changer la photo"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    "Informations de l'animal",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Nom
                  TextField(
                    controller: _nomController,
                    decoration: const InputDecoration(
                      labelText: "Nom *",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.pets),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sexe
                  DropdownButtonFormField<String>(
                    value: _selectedSexe,
                    decoration: const InputDecoration(
                      labelText: "Sexe *",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.wc),
                    ),
                    items: const [
                      DropdownMenuItem(value: "Mâle", child: Text("Mâle")),
                      DropdownMenuItem(value: "Femelle", child: Text("Femelle")),
                    ],
                    onChanged: (val) => setState(() => _selectedSexe = val),
                  ),
                  const SizedBox(height: 16),

                  // Race (différent selon la table)
                  if (widget.tableName == 'nouveaux_nee')
                    TextField(
                      controller: _raceController,
                      decoration: const InputDecoration(
                        labelText: "Race",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.agriculture),
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      value: _selectedRace,
                      decoration: const InputDecoration(
                        labelText: "Race",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.agriculture),
                      ),
                      items: const [
                        DropdownMenuItem(value: "Ladoum", child: Text("Ladoum")),
                        DropdownMenuItem(value: "Peulh Peulh", child: Text("Peulh Peulh")),
                        DropdownMenuItem(value: "Touabire", child: Text("Touabire")),
                      ],
                      onChanged: (val) => setState(() => _selectedRace = val),
                    ),
                  const SizedBox(height: 16),

                  // Champs spécifiques
                  if (widget.tableName == 'nouveaux_nee')
                    TextField(
                      controller: _dateController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: "Date de naissance",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() {
                            _dateController.text =
                                "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
                          });
                        }
                      },
                    )
                  else
                    TextField(
                      controller: _provenanceController,
                      decoration: const InputDecoration(
                        labelText: "Provenance",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Bouton sauvegarder
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _saveChanges,
                      icon: const Icon(Icons.check_circle),
                      label: const Text(
                        "Enregistrer les modifications",
                        style: TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      "* Champs obligatoires",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}