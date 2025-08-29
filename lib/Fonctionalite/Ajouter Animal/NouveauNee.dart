import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io'; // Ajoutez cette importation

class Nouveau_Nee extends StatefulWidget {
  const Nouveau_Nee({super.key});

  @override
  State<Nouveau_Nee> createState() => _AjouteranimalState();
}

class _AjouteranimalState extends State<Nouveau_Nee> {
  String? _selectedSexe;
  String? _selectedRace;
  DateTime? _selectedDate;
  final TextEditingController _dateController = TextEditingController();

  // Variable pour stocker l'image sélectionnée
  XFile? _imageFile;

  // Fonction pour afficher le Date Picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.green,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  // Fonction pour sélectionner une image depuis la galerie
  Future<void> _pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        _imageFile = image;
      });
    }
  }

  // Fonction pour prendre une photo avec la caméra
  Future<void> _takePhotoWithCamera() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );

    if (photo != null) {
      setState(() {
        _imageFile = photo;
      });
    }
  }

  // Fonction pour afficher les options de sélection d'image
  Future<void> _showImageSourceDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Choisir une source"),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                GestureDetector(
                  child: const Text("Prendre une photo"),
                  onTap: () {
                    Navigator.of(context).pop();
                    _takePhotoWithCamera();
                  },
                ),
                const Padding(padding: EdgeInsets.all(8.0)),
                GestureDetector(
                  child: const Text("Choisir depuis la galerie"),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickImageFromGallery();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Jur Gui 4.0 - Nouvel Animal"),
        backgroundColor: Colors.green[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre
            const Center(
              child: Text(
                "Ajouter un nouvel animal",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),

            // Photo de l'animal - CORRECTION ICI
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  // Afficher l'image sélectionnée ou l'icône par défaut
                  _imageFile != null
                      ? Image.file(
                          File(
                            _imageFile!.path,
                          ), // Utilisez Image.file au lieu de Image.network
                          height: 100,
                          width: 100,
                          fit: BoxFit.cover,
                        )
                      : const Icon(
                          Icons.camera_alt,
                          size: 50,
                          color: Colors.grey,
                        ),
                  const SizedBox(height: 10),
                  Text(_imageFile != null ? "Photo ajoutée" : "Aucune photo"),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _showImageSourceDialog,
                    icon: const Icon(Icons.camera),
                    label: const Text("Ajouter une photo"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Le reste de votre formulaire reste inchangé...
            Form(
              child: Column(
                children: [
                  // Nom
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: "Nom",
                      hintText: "Ex: Amina",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.pets),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Date de naissance avec Date Picker
                  TextFormField(
                    controller: _dateController,
                    decoration: const InputDecoration(
                      labelText: "Date de naissance",
                      hintText: "Sélectionner une date",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () {
                      _selectDate(context);
                    },
                  ),
                  const SizedBox(height: 15),

                  // Sexe
                  DropdownButtonFormField(
                    decoration: const InputDecoration(
                      labelText: "Sexe",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.female),
                    ),
                    value: _selectedSexe,
                    items: const [
                      DropdownMenuItem(
                        value: "Femelle",
                        child: Text("Femelle"),
                      ),
                      DropdownMenuItem(value: "Mâle", child: Text("Mâle")),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedSexe = value;
                      });
                    },
                  ),
                  const SizedBox(height: 15),

                  // Race
                  DropdownButtonFormField(
                    decoration: const InputDecoration(
                      labelText: "Race",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.agriculture),
                    ),
                    value: _selectedRace,
                    items: const [
                      DropdownMenuItem(value: "Ladoum", child: Text("Ladoum")),
                      DropdownMenuItem(value: "Peulh", child: Text("Peulh")),
                      DropdownMenuItem(
                        value: "Touabire",
                        child: Text("Touabire"),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedRace = value;
                      });
                    },
                  ),
                  const SizedBox(height: 15),

                  // Père
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: "Père",
                      hintText: "Sélectionner le père",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.male, color: Colors.blue),
                    ),
                    readOnly: true,
                    onTap: () {
                      // Action pour sélectionner le père
                    },
                  ),
                  const SizedBox(height: 15),

                  // Mère
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: "Mère",
                      hintText: "Sélectionner la mère",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.female, color: Colors.pink),
                    ),
                    readOnly: true,
                    onTap: () {
                      // Action pour sélectionner la mère
                    },
                  ),
                  const SizedBox(height: 15),

                  // Tag RFID
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.nfc, size: 40, color: Colors.blue),
                        const SizedBox(height: 10),
                        const Text("Aucun tag RFID associé"),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.nfc),
                          label: const Text("Associer un Tag RFID"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),

                  // Bouton d'enregistrement
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Action d'enregistrement
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Animal enregistré avec succès!"),
                            backgroundColor: Colors.green,
                          ),
                        );
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check_circle),
                      label: const Text(
                        "Enregistrer l'animal",
                        style: TextStyle(fontSize: 18),
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
