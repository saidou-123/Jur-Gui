import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnimalAchate extends StatefulWidget {
  const AnimalAchate({super.key});

  @override
  State<AnimalAchate> createState() => _AnimalAchateState();
}

class _AnimalAchateState extends State<AnimalAchate> {
  // ------------------ CONTROLLERS ------------------------
  final _nomController = TextEditingController();
  final _raceController = TextEditingController();
  final _dateController = TextEditingController();
  final _uidController = TextEditingController();
  final _provenanceController = TextEditingController();

  // ------------------ VARIABLES --------------------------
  String? _selectedSexe;
  String? _selectedRace;
  XFile? _pickedFile;
  bool _isLoading = false;
  String? _tagRFID;
  RealtimeChannel? _rfidChannel;
  bool _realtimeConnected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeRealtime();
    });
  }

  @override
  void dispose() {
    _cleanupResources();
    super.dispose();
  }

  void _cleanupResources() {
    _nomController.dispose();
    _raceController.dispose();
    _dateController.dispose();
    _uidController.dispose();
    _provenanceController.dispose();
    _unsubscribeRealtime();
  }

  // ----------------------------------------------------------
  // 🟢 INITIALISATION REALTIME SUPABASE
  // ----------------------------------------------------------
  Future<void> _initializeRealtime() async {
    if (!mounted) return;

    try {
      debugPrint("🔌 Initialisation du canal Realtime...");

      await Future.delayed(const Duration(milliseconds: 500));

      final channelName = 'rfid_scanner_${DateTime.now().millisecondsSinceEpoch}';

      _rfidChannel = Supabase.instance.client.channel(channelName);

      _rfidChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'rfid_scans',
            callback: (payload) {
              debugPrint("⚡ PAYLOAD: $payload");

              if (payload.newRecord.isEmpty) return;

              final uid = payload.newRecord['uid']?.toString();

              if (uid == null || uid.isEmpty) return;

              debugPrint("🟢 UID détecté = $uid");

              if (mounted) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _onTagDetected(uid);
                });
              }
            },
          )
          .subscribe((status, [error]) {
            debugPrint("📡 Realtime status = $status");

            if (!mounted) return;

            setState(() {
              _realtimeConnected = (status == RealtimeSubscribeStatus.subscribed);
            });

            if (status == RealtimeSubscribeStatus.subscribed) {
              _showSnackBar("Système RFID connecté", Colors.green);
            } else if (status == RealtimeSubscribeStatus.closed) {
              _showSnackBar("Connexion RFID perdue", Colors.orange);
            } else if (error != null) {
              _showSnackBar("Erreur RFID: ${error.toString()}", Colors.red);
            }
          });
    } catch (e) {
      debugPrint("❌ Erreur Realtime : $e");
      _showSnackBar("Erreur Realtime: ${e.toString()}", Colors.red);
    }
  }

  void _unsubscribeRealtime() {
    try {
      if (_rfidChannel != null) {
        Supabase.instance.client.removeChannel(_rfidChannel!);
        _rfidChannel = null;
        debugPrint("🔴 Canal Realtime désabonné");
      }
    } catch (e) {
      debugPrint("⚠️ Erreur désabonnement : $e");
    }
  }

  void _onTagDetected(String uid) {
    if (!mounted) return;

    setState(() {
      _tagRFID = uid;
      _uidController.text = uid;
    });

    _showSnackBar("Tag RFID détecté : $uid", Colors.blue);
  }

  // ----------------------------------------------------------
  // RECONNEXION MANUELLE
  // ----------------------------------------------------------
  Future<void> _reconnectRealtime() async {
    if (!mounted) return;

    _showSnackBar("Reconnexion en cours...", Colors.orange);

    setState(() => _isLoading = true);

    _unsubscribeRealtime();
    await Future.delayed(const Duration(milliseconds: 500));
    await _initializeRealtime();

    if (mounted) setState(() => _isLoading = false);
  }

  // ----------------------------------------------------------
  // UTILITAIRE : SnackBar
  // ----------------------------------------------------------
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
  // IMAGE PICKER
  // ----------------------------------------------------------
  Future<void> _pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 75,
      );
      if (image != null && mounted) {
        setState(() => _pickedFile = image);
      }
    } catch (e) {
      _showSnackBar("Erreur sélection image", Colors.red);
    }
  }

  Future<void> _takePhotoWithCamera() async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 75,
      );
      if (photo != null && mounted) {
        setState(() => _pickedFile = photo);
      }
    } catch (e) {
      _showSnackBar("Erreur caméra", Colors.red);
    }
  }

  Future<void> _showImageSourceDialog() async {
    if (!mounted) return;

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
              title: const Text("Depuis galerie"),
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

  Future<String?> _uploadImage(XFile image) async {
    try {
      final fileName = 'animal_acheter/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await File(image.path).readAsBytes();

      await Supabase.instance.client.storage
          .from('uploads')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      return Supabase.instance.client.storage
          .from('uploads')
          .getPublicUrl(fileName);
    } catch (e) {
      debugPrint("Erreur upload : $e");
      return null;
    }
  }

  // ----------------------------------------------------------
  // ENREGISTRER
  // ----------------------------------------------------------
  Future<void> _enregistrer() async {
    if (!mounted) return;

    if (_nomController.text.isEmpty ||
        _provenanceController.text.isEmpty ||
        _selectedRace == null ||
        _selectedSexe == null ||
        _pickedFile == null ||
        _tagRFID == null) {
      _showSnackBar("Veuillez remplir tous les champs", Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = await _uploadImage(_pickedFile!);

      if (url == null) throw Exception("Erreur upload image");

      await Supabase.instance.client.from('nouveaux_nee').insert({
        'nom': _nomController.text.trim(),
        'provenance': _provenanceController.text.trim(),
        'race': _selectedRace,
        'sexe': _selectedSexe,
        'image_url': url,
        'tag_rfid': _tagRFID,
        'user_id': Supabase.instance.client.auth.currentUser!.id,
        'created_at': DateTime.now().toIso8601String(),
      });

      _showSnackBar("Animal enregistré avec succès !", Colors.green);
      _resetForm();
    } catch (e) {
      _showSnackBar("Erreur : ${e.toString()}", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    _nomController.clear();
    _provenanceController.clear();
    _uidController.clear();

    setState(() {
      _selectedRace = null;
      _selectedSexe = null;
      _pickedFile = null;
      _tagRFID = null;
    });
  }

  // ----------------------------------------------------------
  // UI
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Jur Gui 4.0 - Animal-Ajout"),
        backgroundColor: Colors.green[700],
        actions: [
          IconButton(
            icon: Icon(
              _realtimeConnected ? Icons.wifi : Icons.wifi_off,
              color: _realtimeConnected ? Colors.white : Colors.orange,
            ),
            tooltip: _realtimeConnected
                ? "RFID connecté"
                : "RFID déconnecté, appuyer pour reconnecter",
            onPressed: _reconnectRealtime,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    "Ajouter un animal acheté",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildPhotoSection(),
                  const SizedBox(height: 16),
                  _buildTextFormField(_nomController, "Nom", Icons.pets),
                  const SizedBox(height: 12),
                  _buildSexeDropdown(),
                  const SizedBox(height: 12),
                  _buildTextFormField(
                    _provenanceController,
                    "Provenance",
                    Icons.agriculture,
                  ),
                  const SizedBox(height: 12),
                  _buildRaceDropdown(),
                  const SizedBox(height: 12),
                  _buildUidRfidField(),
                  const SizedBox(height: 24),
                  _buildSaveButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildPhotoSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _pickedFile != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_pickedFile!.path),
                    height: 150,
                    width: 150,
                    fit: BoxFit.cover,
                  ),
                )
              : const Icon(Icons.camera_alt, size: 80, color: Colors.grey),
          const SizedBox(height: 8),
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
    );
  }

  Widget _buildTextFormField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
      ),
    );
  }

  Widget _buildSexeDropdown() {
    return DropdownButtonFormField<String>(
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
    );
  }

  Widget _buildRaceDropdown() {
    return DropdownButtonFormField<String>(
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
    );
  }

  Widget _buildUidRfidField() {
    return TextFormField(
      controller: _uidController,
      readOnly: true,
      decoration: InputDecoration(
        labelText: "UID du RFID",
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.nfc),
        suffixIcon: _tagRFID != null
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.pending, color: Colors.orange),
      ),
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: Colors.blue,
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _enregistrer,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.check_circle),
        label: Text(
          _isLoading ? "Enregistrement..." : "Enregistrer",
          style: const TextStyle(fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey,
        ),
      ),
    );
  }
}
