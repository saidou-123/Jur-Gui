import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart'; // 🔵 WEBSOCKET

final supabase = Supabase.instance.client;

class NouveauNeePage extends StatefulWidget {
  const NouveauNeePage({super.key});

  @override
  State<NouveauNeePage> createState() => _NouveauNeePageState();
}

class _NouveauNeePageState extends State<NouveauNeePage> {
  // ------------------ CONTROLLERS ------------------------
  final _nomController = TextEditingController();
  final _raceController = TextEditingController();
  final _dateController = TextEditingController();
  final _uidController = TextEditingController();

  // ------------------ VARIABLES --------------------------
  String? _selectedSexe;
  XFile? _pickedFile;
  bool _isLoading = false;
  String? _tagRFID;

  // 🔵 WEBSOCKET CHANNEL
  WebSocketChannel? channel;

  // ----------------------------------------------------------
  // 🔵 INITSTATE : Connexion WebSocket ESP32
  // ----------------------------------------------------------
  @override
  void initState() {
    super.initState();

    try {
      channel = WebSocketChannel.connect(
        Uri.parse("ws://192.168.4.1:81"), // 🔥 IP de l'ESP32 en mode AP
      );

      channel!.stream.listen((message) {
        print("📡 UID reçu : $message");
        _onTagDetected(message);
      }, onError: (e) {
        print("❌ WebSocket Error : $e");
      }, onDone: () {
        print("🔌 WebSocket fermé");
      });

    } catch (e) {
      print("⚠️ Impossible de se connecter au WebSocket : $e");
    }
  }

  // 🔵 Fermeture propre
  @override
  void dispose() {
    channel?.sink.close();
    super.dispose();
  }

  // ----------------------------------------------------------
  // 🔵 Quand l’ESP32 envoie l’UID RFID → On met à jour l’UI
  // ----------------------------------------------------------
  void _onTagDetected(String uid) {
    setState(() {
      _tagRFID = uid;
      _uidController.text = uid;
    });
  }

  // ----------------------------------------------------------
  //                 IMAGE PICKER
  // ----------------------------------------------------------
  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );
    if (image != null) setState(() => _pickedFile = image);
  }

  Future<void> _takePhotoWithCamera() async {
    final picker = ImagePicker();
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Prendre une photo"),
              onTap: () {
                Navigator.pop(context);
                _takePhotoWithCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Choisir depuis la galerie"),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  //                UPLOAD IMAGE SUPABASE
  // ----------------------------------------------------------
  Future<String?> _uploadImage(XFile image) async {
    try {
      final fileName =
          'nouveaux_nee/${DateTime.now().millisecondsSinceEpoch}.jpg';

      final bytes = await File(image.path).readAsBytes();

      await supabase.storage
          .from('uploads')
          .uploadBinary(fileName, bytes,
              fileOptions: const FileOptions(upsert: true));

      return supabase.storage.from('uploads').getPublicUrl(fileName);
    } catch (e) {
      debugPrint("Erreur upload : $e");
      return null;
    }
  }

  // ----------------------------------------------------------
  //                   ENREGISTRER
  // ----------------------------------------------------------
  Future<void> _enregistrer() async {
    if (_nomController.text.isEmpty ||
        _raceController.text.isEmpty ||
        _dateController.text.isEmpty ||
        _selectedSexe == null ||
        _pickedFile == null ||
        _tagRFID == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez remplir tout le formulaire"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = await _uploadImage(_pickedFile!);

      if (url == null) throw ("Erreur upload image");

     await supabase.from('nouveaux_nee').insert({
  'nom': _nomController.text,
  'race': _raceController.text,
  'date_naissance': _dateController.text,
  'sexe': _selectedSexe,
  'image_url': url,
  'tag_rfid': _tagRFID,
  'user_id': supabase.auth.currentUser!.id,   // 🟢 AJOUT OBLIGATOIRE
  'created_at': DateTime.now().toIso8601String(),
});


      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Nouveau-né enregistré avec succès !"),
        backgroundColor: Colors.green,
      ));

      _nomController.clear();
      _raceController.clear();
      _dateController.clear();
      _uidController.clear();

      setState(() {
        _selectedSexe = null;
        _pickedFile = null;
        _tagRFID = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ----------------------------------------------------------
  //                           UI
  // ----------------------------------------------------------
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
          children: [
            const Text("Ajouter un nouveau-né",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // ------------------- PHOTO -------------------
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
                          child: Image.file(File(_pickedFile!.path),
                              height: 120, width: 120, fit: BoxFit.cover),
                        )
                      : const Icon(Icons.camera_alt,
                          size: 60, color: Colors.grey),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _showImageSourceDialog,
                    icon: const Icon(Icons.add_a_photo),
                    label: const Text("Ajouter une photo"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // ------------------- FORMULAIRE -------------------
            TextFormField(
              controller: _nomController,
              decoration: const InputDecoration(
                labelText: "Nom de l'animal",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.pets),
              ),
            ),
            const SizedBox(height: 15),

            DropdownButtonFormField(
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
              onChanged: (val) => setState(() => _selectedSexe = val),
            ),
            const SizedBox(height: 15),

            TextFormField(
              controller: _raceController,
              decoration: const InputDecoration(
                labelText: "Race",
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
                prefixIcon: Icon(Icons.calendar_today),
              ),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (d != null) {
                  _dateController.text = "${d.year}-${d.month}-${d.day}";
                }
              },
            ),

            const SizedBox(height: 15),

            // 🔵 ------------------ UID REÇU ------------------
            TextFormField(
              controller: _uidController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: "UID reçu du RFID",
                hintText: "En attente du scan...",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.nfc),
              ),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),

            const SizedBox(height: 25),

            // ------------------- RFID STATE -------------------
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.nfc, size: 50, color: Colors.blue),
                  const SizedBox(height: 10),
                  Text(
                    _tagRFID != null
                        ? "Tag RFID détecté : $_tagRFID"
                        : "Aucun Tag RFID scanné",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ------------------- BOUTON -------------------
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _enregistrer,
                icon: _isLoading
                    ? const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
