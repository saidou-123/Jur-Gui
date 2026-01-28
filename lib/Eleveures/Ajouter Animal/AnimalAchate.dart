// ============================================================
// ANIMAL ACHETÉ - VERSION OPTIMISÉE
// Fichier: lib/Eleveures/Ajouter Animal/AnimalAchate.dart
// ============================================================

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:depart/securite/ErrorHandler.dart';
import 'package:depart/securite/Validators.dart';

class AnimalAchate extends StatefulWidget {
  const AnimalAchate({super.key});

  @override
  State<AnimalAchate> createState() => _AnimalAchateState();
}

class _AnimalAchateState extends State<AnimalAchate> {
  // Controllers
  final _nomController = TextEditingController();
  final _raceController = TextEditingController();
  final _dateController = TextEditingController();
  final _uidController = TextEditingController();
  final _provenanceController = TextEditingController();

  // État
  String? _selectedSexe;
  String? _selectedRace;
  XFile? _pickedFile;
  bool _isLoading = false;
  String? _tagRFID;
  RealtimeChannel? _rfidChannel;
  bool _realtimeConnected = false;
  
  // ✅ Ajout: Timer de cleanup
  Timer? _rfidCleanupTimer;

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
    _rfidCleanupTimer?.cancel();
    _unsubscribeRealtime();
  }

  // ===== REALTIME RFID OPTIMISÉ =====
  Future<void> _initializeRealtime() async {
    if (!mounted) return;

    try {
      debugPrint("📌 Initialisation canal RFID...");

      await Future.delayed(const Duration(milliseconds: 500));

      final channelName = 'rfid_achete_${DateTime.now().millisecondsSinceEpoch}';
      
      _rfidChannel = Supabase.instance.client.channel(channelName);

      _rfidChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'rfid_scans',
            callback: (payload) {
              if (!mounted) return;
              
              final uid = payload.newRecord['uid']?.toString();
              if (uid != null && uid.isNotEmpty) {
                debugPrint("🟢 UID SCANNÉ = $uid");
                
                // ✅ Réinitialiser timer cleanup
                _startCleanupTimer();
                
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _onTagDetected(uid);
                });
              }
            },
          )
          .subscribe((status, [error]) {
            if (!mounted) return;

            setState(() {
              _realtimeConnected = (status == RealtimeSubscribeStatus.subscribed);
            });

            if (status == RealtimeSubscribeStatus.subscribed) {
              debugPrint("✅ Canal RFID connecté");
              _showSnackBar("✅ Système RFID connecté", Colors.green);
              _startCleanupTimer();
            } else if (status == RealtimeSubscribeStatus.closed) {
              debugPrint("🔴 Canal RFID fermé");
            }

            if (error != null) {
              debugPrint("❌ Erreur Realtime: $error");
            }
          });
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace, context: 'Init RFID Animal Acheté');
      if (mounted) {
        ErrorHandler.show(context, e, customMessage: 'Erreur connexion RFID');
      }
    }
  }

  // ✅ Timer de cleanup auto (5 minutes inactivité)
  void _startCleanupTimer() {
    _rfidCleanupTimer?.cancel();
    _rfidCleanupTimer = Timer(const Duration(minutes: 5), () {
      if (mounted && _tagRFID == null) {
        debugPrint("🧹 Auto-cleanup: Fermeture RFID inactif");
        _unsubscribeRealtime();
      }
    });
  }

  void _unsubscribeRealtime() {
    try {
      if (_rfidChannel != null) {
        Supabase.instance.client.removeChannel(_rfidChannel!);
        _rfidChannel = null;
        debugPrint("🔴 Canal RFID désabonné");
      }
    } catch (e) {
      debugPrint("⚠️ Erreur désabonnement: $e");
    }
  }

  // ===== DÉTECTION TAG AVEC VALIDATION =====
  Future<void> _onTagDetected(String uid) async {
    if (!mounted) return;

    debugPrint("═══════════════════════════════");
    debugPrint("🏷️  TAG DÉTECTÉ : $uid");
    debugPrint("═══════════════════════════════");

    // ✅ Valider format RFID
    final validation = Validators.rfid(uid);
    if (validation != null) {
      _showSnackBar("⚠️ Format RFID invalide: $validation", Colors.orange);
      return;
    }

    setState(() {
      _tagRFID = uid;
      _uidController.text = uid;
    });

    _showSnackBar("Tag RFID détecté : $uid", Colors.blue);

    // Vérifier doublon
    try {
      final result = await Supabase.instance.client
          .from('animal_acheter')
          .select('id, nom, race, sexe, provenance, tag_rfid')
          .eq('tag_rfid', uid);

      if (result.isNotEmpty) {
        final existing = result.first;
        debugPrint("⚠️ DOUBLON DÉTECTÉ!");
        
        if (mounted) {
          _showSnackBar(
            "⚠️ Tag déjà utilisé par: ${existing['nom']}",
            Colors.orange,
          );
          
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) _showDuplicateDialog(existing);
          });
        }
      } else {
        debugPrint("✅ Tag disponible");
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace, context: 'Vérification doublon RFID');
    }
  }

  // ===== DIALOGUE DOUBLON =====
  Future<void> _showDuplicateDialog(Map<String, dynamic> existing) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.orange,
          size: 64,
        ),
        title: const Text(
          "⚠️ Tag RFID déjà utilisé",
          style: TextStyle(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Ce tag est déjà attribué à:"),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200, width: 2),
              ),
              child: Column(
                children: [
                  _buildInfoRow(Icons.pets, "Nom", existing['nom'] ?? 'N/A'),
                  _buildInfoRow(Icons.agriculture, "Race", existing['race'] ?? 'N/A'),
                  _buildInfoRow(Icons.nfc, "Tag", existing['tag_rfid'] ?? 'N/A'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _tagRFID = null;
                _uidController.clear();
              });
            },
            icon: const Icon(Icons.nfc),
            label: const Text("Scanner autre tag"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.orange),
          const SizedBox(width: 8),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  // ===== RECONNEXION =====
  Future<void> _reconnectRealtime() async {
    if (!mounted) return;

    _showSnackBar("Reconnexion...", Colors.orange);
    setState(() => _isLoading = true);
    
    _unsubscribeRealtime();
    await Future.delayed(const Duration(milliseconds: 500));
    await _initializeRealtime();

    if (mounted) setState(() => _isLoading = false);
  }

  // ===== SÉLECTION IMAGE =====
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
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text("Appareil photo"),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text("Galerie"),
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _takePhoto() async {
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 75,
      );
      if (photo != null && mounted) {
        setState(() => _pickedFile = photo);
      }
    } catch (e) {
      ErrorHandler.show(context, e, customMessage: 'Erreur caméra');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 75,
      );
      if (image != null && mounted) {
        setState(() => _pickedFile = image);
      }
    } catch (e) {
      ErrorHandler.show(context, e, customMessage: 'Erreur sélection image');
    }
  }

  // ===== UPLOAD IMAGE =====
  Future<String?> _uploadImage(XFile image) async {
    try {
      final fileName = 'animal_acheter/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await File(image.path).readAsBytes();

      await Supabase.instance.client.storage
          .from('uploads')
          .uploadBinary(fileName, bytes, fileOptions: const FileOptions(upsert: true));

      return Supabase.instance.client.storage.from('uploads').getPublicUrl(fileName);
    } catch (e) {
      debugPrint("Erreur upload: $e");
      return null;
    }
  }

  // ===== ENREGISTRER AVEC VALIDATION =====
  Future<void> _enregistrer() async {
    if (!mounted) return;

    // ✅ Validations
    final nomValidation = Validators.name(_nomController.text, fieldName: 'Le nom');
    if (nomValidation != null) {
      ErrorHandler.show(context, nomValidation);
      return;
    }

    final provenanceValidation = Validators.required(
      _provenanceController.text,
      fieldName: 'La provenance',
    );
    if (provenanceValidation != null) {
      ErrorHandler.show(context, provenanceValidation);
      return;
    }

    if (_selectedRace == null) {
      ErrorHandler.show(context, 'Veuillez sélectionner une race');
      return;
    }

    if (_selectedSexe == null) {
      ErrorHandler.show(context, 'Veuillez sélectionner un sexe');
      return;
    }

    if (_pickedFile == null) {
      ErrorHandler.show(context, 'Veuillez ajouter une photo');
      return;
    }

    final rfidValidation = Validators.rfid(_tagRFID);
    if (rfidValidation != null) {
      ErrorHandler.show(context, rfidValidation);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Vérification finale doublon
      final existing = await Supabase.instance.client
          .from('animal_acheter')
          .select('id, nom')
          .eq('tag_rfid', _tagRFID!)
          .maybeSingle();

      if (existing != null) {
        if (mounted) {
          setState(() => _isLoading = false);
          await _showDuplicateDialog(existing);
        }
        return;
      }

      // Upload image
      final url = await _uploadImage(_pickedFile!);
      if (url == null) {
        throw Exception("Erreur upload image");
      }

      // ✅ Sanitizer les données
      await Supabase.instance.client.from('animal_acheter').insert({
        'nom': Validators.sanitize(_nomController.text),
        'provenance': Validators.sanitize(_provenanceController.text),
        'race': _selectedRace,
        'sexe': _selectedSexe,
        'image_url': url,
        'tag_rfid': _tagRFID,
        'user_id': Supabase.instance.client.auth.currentUser!.id,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint("✅ Animal enregistré");

      if (mounted) {
        ErrorHandler.showSuccess(context, "✅ Animal enregistré avec succès!");
        _resetForm();
      }
    } catch (error, stackTrace) {
      ErrorHandler.log(error, stackTrace, context: 'Enregistrement animal acheté');
      if (mounted) {
        ErrorHandler.show(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Animal Acheté"),
        backgroundColor: Colors.green[700],
        actions: [
          IconButton(
            icon: Icon(
              _realtimeConnected ? Icons.wifi : Icons.wifi_off,
              color: _realtimeConnected ? Colors.white : Colors.orange,
            ),
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
                  _buildPhotoSection(),
                  const SizedBox(height: 16),
                  _buildTextField(_nomController, "Nom *", Icons.pets),
                  const SizedBox(height: 12),
                  _buildSexeDropdown(),
                  const SizedBox(height: 12),
                  _buildTextField(_provenanceController, "Provenance *", Icons.location_on),
                  const SizedBox(height: 12),
                  _buildRaceDropdown(),
                  const SizedBox(height: 12),
                  _buildUidField(),
                  const SizedBox(height: 24),
                  _buildSaveButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildPhotoSection() {
    return Container(
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
            label: const Text("Ajouter photo"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
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
        labelText: "Sexe *",
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
        labelText: "Race *",
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

  Widget _buildUidField() {
    return TextFormField(
      controller: _uidController,
      readOnly: true,
      decoration: InputDecoration(
        labelText: "UID RFID *",
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.nfc),
        suffixIcon: _tagRFID != null
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.pending, color: Colors.orange),
        helperText: _tagRFID == null ? "Scannez un tag" : "Tag détecté",
        helperStyle: TextStyle(
          color: _tagRFID == null ? Colors.grey : Colors.green,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: const TextStyle(
        fontWeight: FontWeight.bold,
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
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.check_circle),
        label: Text(
          _isLoading ? "Enregistrement..." : "Enregistrer",
          style: const TextStyle(fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}