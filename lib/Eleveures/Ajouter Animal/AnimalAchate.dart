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
  // 🟢 REALTIME SUPABASE
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
              debugPrint("⚡ PAYLOAD REÇU = $payload");

              if (payload.newRecord.isEmpty) {
                debugPrint("⚠️ Payload vide, ignoré");
                return;
              }

              if (!payload.newRecord.containsKey('uid')) {
                debugPrint("⚠️ Pas de clé 'uid' dans le payload");
                return;
              }

              final uid = payload.newRecord['uid']?.toString();
              
              if (uid == null || uid.isEmpty) {
                debugPrint("⚠️ UID null ou vide");
                return;
              }

              debugPrint("🟢 UID SCANNÉ = $uid");

              if (mounted) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _onTagDetected(uid);
                });
              }
            },
          )
          .subscribe((status, [error]) {
            debugPrint("📡 Canal status = $status");

            if (!mounted) return;

            setState(() {
              _realtimeConnected = (status == RealtimeSubscribeStatus.subscribed);
            });

            if (status == RealtimeSubscribeStatus.subscribed) {
              debugPrint("✅ Canal Realtime connecté");
              _showSnackBar("Système RFID connecté", Colors.green);
            } else if (status == RealtimeSubscribeStatus.closed) {
              debugPrint("🔴 Canal Realtime fermé");
              _showSnackBar("Connexion RFID perdue", Colors.orange);
            } else if (error != null) {
              debugPrint("❌ Erreur Realtime : $error");
            }
          });
    } catch (e) {
      debugPrint("❌ ERREUR Realtime : $e");
      if (mounted) {
        _showSnackBar("Erreur Realtime: ${e.toString()}", Colors.red);
      }
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

  // ----------------------------------------------------------
  // 🔍 DÉTECTION DU TAG AVEC VÉRIFICATION DE DOUBLON
  // ----------------------------------------------------------
  Future<void> _onTagDetected(String uid) async {
    if (!mounted) return;

    debugPrint("════════════════════════════════════");
    debugPrint("🏷️  NOUVEAU TAG DÉTECTÉ : $uid");
    debugPrint("════════════════════════════════════");

    setState(() {
      _tagRFID = uid;
      _uidController.text = uid;
    });

    _showSnackBar("Tag RFID détecté : $uid", Colors.blue);

    // 🔍 Vérifier immédiatement si le tag existe déjà
    try {
      debugPrint("🔍 Démarrage de la vérification de doublon...");
      
      // ✅ CORRECTION: orthographe correcte de "provenance"
      final result = await Supabase.instance.client
          .from('animal_acheter')
          .select('id, nom, race, sexe, provenance, tag_rfid')
          .eq('tag_rfid', uid);

      debugPrint("📊 Résultat de la requête : $result");
      debugPrint("📊 Nombre de résultats : ${result.length}");

      if (result.isNotEmpty) {
        final existing = result.first;
        debugPrint("⚠️⚠️⚠️ DOUBLON DÉTECTÉ ! ⚠️⚠️⚠️");
        debugPrint("Animal existant : ${existing['nom']}");
        debugPrint("════════════════════════════════════");
        
        if (mounted) {
          // Afficher un avertissement immédiat
          _showSnackBar(
            "⚠️ ATTENTION ! Tag déjà utilisé par : ${existing['nom']}",
            Colors.orange,
          );
          
          // Afficher le dialogue après un court délai
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              _showDuplicateDialog(existing);
            }
          });
        }
      } else {
        debugPrint("✅ Tag RFID disponible - Aucun doublon");
        debugPrint("════════════════════════════════════");
      }
    } catch (e, stackTrace) {
      debugPrint("❌❌❌ ERREUR lors de la vérification !");
      debugPrint("Erreur : $e");
      debugPrint("Stack trace : $stackTrace");
      debugPrint("════════════════════════════════════");
    }
  }

  // ----------------------------------------------------------
  // 📋 DIALOGUE D'ALERTE DOUBLON
  // ----------------------------------------------------------
  Future<void> _showDuplicateDialog(Map<String, dynamic> existing) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Ce tag RFID est déjà attribué à un animal :",
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      Icons.pets,
                      "Nom",
                      existing['nom'] ?? 'N/A',
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      Icons.agriculture,
                      "Race",
                      existing['race'] ?? 'N/A',
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      Icons.wc,
                      "Sexe",
                      existing['sexe'] ?? 'N/A',
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      Icons.nfc,
                      "Tag RFID",
                      existing['tag_rfid'] ?? 'N/A',
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      Icons.location_on,
                      "Provenance",
                      existing['provenance'] ?? 'N/A',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Veuillez utiliser un autre tag RFID",
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
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _tagRFID = null;
                  _uidController.clear();
                });
              },
              icon: const Icon(Icons.nfc),
              label: const Text("Scanner un autre tag"),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text("OK, compris"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.orange.shade700),
        const SizedBox(width: 8),
        Text(
          "$label : ",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
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
  // 💾 ENREGISTRER AVEC DÉTECTION DE DOUBLONS
  // ----------------------------------------------------------
  Future<void> _enregistrer() async {
    if (!mounted) return;

    if (_nomController.text.isEmpty ||
        _provenanceController.text.isEmpty ||
        _selectedRace == null ||
        _selectedSexe == null ||
        _pickedFile == null ||
        _tagRFID == null) {
      _showSnackBar(
        "⚠️ Veuillez remplir tous les champs et scanner un tag RFID",
        Colors.red,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint("🔍 Vérification finale du tag RFID : $_tagRFID");
      
      final existing = await Supabase.instance.client
          .from('animal_acheter')
          .select('id, nom, race, tag_rfid, provenance')
          .eq('tag_rfid', _tagRFID!)
          .maybeSingle();

      if (existing != null) {
        debugPrint("❌ Tag RFID déjà utilisé : ${existing['nom']}");
        
        if (mounted) {
          setState(() => _isLoading = false);
          await _showDuplicateDialog(existing);
        }
        return;
      }

      debugPrint("✅ Tag RFID disponible, insertion en cours...");

      final url = await _uploadImage(_pickedFile!);
      if (url == null) {
        throw Exception("Erreur lors de l'upload de l'image");
      }

      debugPrint("✅ Image uploadée : $url");

      await Supabase.instance.client.from('animal_acheter').insert({
        'nom': _nomController.text.trim(),
        'provenance': _provenanceController.text.trim(),
        'race': _selectedRace,
        'sexe': _selectedSexe,
        'image_url': url,
        'tag_rfid': _tagRFID,
        'user_id': Supabase.instance.client.auth.currentUser!.id,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint("✅ Animal acheté enregistré avec succès !");

      if (mounted) {
        _showSnackBar("✅ Animal acheté enregistré avec succès !", Colors.green);
        _resetForm();
      }
    } catch (e) {
      debugPrint("❌ Erreur lors de l'enregistrement : $e");
      if (mounted) {
        _showSnackBar("❌ Erreur : ${e.toString()}", Colors.red);
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

  // ----------------------------------------------------------
  // UI
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Jur Gui 4.0 - Animal Acheté"),
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
                    Icons.location_on,
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
        helperText: _tagRFID == null 
            ? "Scannez un tag RFID pour continuer" 
            : "Tag RFID détecté",
        helperStyle: TextStyle(
          color: _tagRFID == null ? Colors.grey : Colors.green,
          fontWeight: FontWeight.bold,
        ),
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