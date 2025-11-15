import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class NouveauNeePage extends StatefulWidget {
  const NouveauNeePage({super.key});

  @override
  State<NouveauNeePage> createState() => _NouveauNeePageState();
}

class _NouveauNeePageState extends State<NouveauNeePage> {
  final _nomController = TextEditingController();
  final _raceController = TextEditingController();
  final _dateController = TextEditingController();
  String? _selectedSexe;
  XFile? _pickedFile;
  bool _isLoading = false;

  // --- Gestion image ---
  Future<void> _pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );
    if (image != null) setState(() => _pickedFile = image);
  }

  Future<void> _takePhotoWithCamera() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );
    if (photo != null) setState(() => _pickedFile = photo);
  }

  Future<void> _showImageSourceDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Choisir une source"),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text("Prendre une photo"),
                onTap: () {
                  Navigator.of(context).pop();
                  _takePhotoWithCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text("Choisir depuis la galerie"),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImageFromGallery();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Upload vers Supabase ---
  Future<String?> _uploadImage(XFile image) async {
    try {
      final fileName =
          'nouveaux_nee/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final fileBytes = await File(image.path).readAsBytes();

      await supabase.storage
          .from('uploads')
          .uploadBinary(fileName, fileBytes,
              fileOptions: const FileOptions(upsert: true));

      return supabase.storage.from('uploads').getPublicUrl(fileName);
    } catch (e) {
      debugPrint('Erreur upload image : $e');
      return null;
    }
  }

  // --- Enregistrement dans Supabase ---
  Future<void> _enregistrer() async {
    if (_nomController.text.isEmpty ||
        _raceController.text.isEmpty ||
        _dateController.text.isEmpty ||
        _selectedSexe == null ||
        _pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Veuillez remplir tous les champs et ajouter une photo"),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final imageUrl = await _uploadImage(_pickedFile!);
      if (imageUrl == null) throw Exception("Erreur lors de l'upload de l'image");

      //
      // ❗️❗️❗️ C'EST LA LIGNE QUE J'AI CORRIGÉE ❗️❗️❗️
      //
      // Avant c'était 'Nouveau_Nee'
      //
      await supabase.from('nouveaux_nee').insert({
        'nom': _nomController.text,
        'race': _raceController.text,
        'date_naissance': _dateController.text,
        'sexe': _selectedSexe,
        'image_url': imageUrl,
        'created_at': DateTime.now().toIso8601String(),
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Nouveau-né enregistré avec succès ✅"),
        backgroundColor: Colors.green,
      ));

      _nomController.clear();
      _raceController.clear();
      _dateController.clear();
      setState(() {
        _selectedSexe = null;
        _pickedFile = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Erreur : $e"),
        backgroundColor: Colors.red,
      ));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Jur Gui 4.0 - Nouveau-né"),
        backgroundColor: Colors.green[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                "Ajouter un nouveau-né",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),

            // --- Photo de l’animal ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _pickedFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_pickedFile!.path),
                            height: 120,
                            width: 120,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(Icons.camera_alt,
                          size: 60, color: Colors.grey),
                  const SizedBox(height: 10),
                  Text(
                    _pickedFile != null
                        ? "Photo ajoutée"
                        : "Aucune photo sélectionnée",
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _showImageSourceDialog,
                    icon: const Icon(Icons.add_a_photo),
                    label: const Text("Ajouter une photo"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // --- Formulaire principal ---
            Form(
              child: Column(
                children: [
                  TextFormField(
                    controller: _nomController,
                    decoration: const InputDecoration(
                      labelText: "Nom de l'animal",
                      hintText: "Ex: Agnèle 1",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.pets),
                    ),
                  ),
                  const SizedBox(height: 15),

                  DropdownButtonFormField<String>(
                    value: _selectedSexe,
                    decoration: const InputDecoration(
                      labelText: "Sexe",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.wc),
                    ),
                    items: const [
                      DropdownMenuItem(value: "Mâle", child: Text("Mâle")),
                      DropdownMenuItem(value: "Femelle", child: Text("Femelle")),
                    ],
                    onChanged: (value) => setState(() => _selectedSexe = value),
                  ),
                  const SizedBox(height: 15),

                  TextFormField(
                    controller: _raceController,
                    decoration: const InputDecoration(
                      labelText: "Race",
                      hintText: "Ex: Ladoum",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.agriculture),
                    ),
                  ),
                  const SizedBox(height: 15),

                  TextFormField(
                    controller: _dateController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: "Date de naissance",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.date_range),
                    ),
                    onTap: () async {
                      DateTime? date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        _dateController.text =
                            "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
                      }
                    },
                  ),
                  const SizedBox(height: 30),

                  // --- Bouton d’enregistrement ---
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _enregistrer,
                      icon: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.check_circle),
                      label: Text(
                        _isLoading
                            ? "Enregistrement..."
                            : "Enregistrer le nouveau-né",
                        style: const TextStyle(fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}