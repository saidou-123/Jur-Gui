// ============================================================
// ANIMAL ACHETÉ - VERSION BLE
// Fichier: lib/Eleveures/Ajouter Animal/AnimalAchateBluetooth.dart
// Communication Bluetooth BLE avec ESP32 + RFID
// ============================================================

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:depart/securite/ErrorHandler.dart';
import 'package:depart/securite/Validators.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:convert';

class AnimalAchateBluetooth extends StatefulWidget {
  const AnimalAchateBluetooth({super.key});

  @override
  State<AnimalAchateBluetooth> createState() => _AnimalAchateBluetoothState();
}

class _AnimalAchateBluetoothState extends State<AnimalAchateBluetooth> {
  // ===== CONTROLLERS =====
  final _nomController = TextEditingController();
  final _raceController = TextEditingController();
  final _dateController = TextEditingController();
  final _uidController = TextEditingController();
  final _provenanceController = TextEditingController();

  // ===== ÉTAT UI =====
  String? _selectedSexe;
  String? _selectedRace;
  XFile? _pickedFile;
  bool _isLoading = false;
  String? _tagRFID;

  // ===== BLUETOOTH BLE =====
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _rfidCharacteristic;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _deviceStateSubscription;
  StreamSubscription? _characteristicSubscription;
  bool _isScanning = false;
  bool _isConnected = false;
  
  // UUID personnalisés (À ADAPTER selon ton ESP32)
  static const String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  
  // Anti-doublon
  String? _lastReceivedUID;
  DateTime? _lastScanTime;
  static const Duration _antiSpamDelay = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeBluetooth();
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
    _disconnectBLE();
  }

  // =====================================================
  // BLUETOOTH BLE - INITIALISATION
  // =====================================================
  Future<void> _initializeBluetooth() async {
    if (!mounted) return;

    try {
      debugPrint("📱 Initialisation Bluetooth...");

      // Vérifier si le Bluetooth est supporté
      if (await FlutterBluePlus.isSupported == false) {
        if (mounted) {
          _showSnackBar("❌ Bluetooth non supporté sur cet appareil", Colors.red);
        }
        return;
      }

      // Vérifier l'état du Bluetooth
      final state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        if (mounted) {
          _showSnackBar("⚠️ Activez le Bluetooth", Colors.orange);
        }
        return;
      }

      // Démarrer le scan automatiquement
      _startBLEScan();
      
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace, context: 'Init Bluetooth');
      if (mounted) {
        ErrorHandler.show(context, e, customMessage: 'Erreur Bluetooth');
      }
    }
  }

  // =====================================================
  // BLUETOOTH BLE - SCAN DES APPAREILS
  // =====================================================
  Future<void> _startBLEScan() async {
    if (_isScanning || _isConnected) return;

    setState(() => _isScanning = true);
    debugPrint("🔍 Scan BLE démarré...");
    
    _showSnackBar("🔍 Recherche du lecteur RFID...", Colors.blue);

    try {
      // Arrêter tout scan en cours
      await FlutterBluePlus.stopScan();
      
      // Démarrer un nouveau scan
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: true,
      );

      // Écouter les résultats du scan
      _scanSubscription = FlutterBluePlus.scanResults.listen(
        (results) {
          for (ScanResult result in results) {
            final deviceName = result.device.platformName;
            
            debugPrint("📡 Appareil trouvé: $deviceName (${result.device.remoteId})");
            
            // Chercher notre ESP32 (adapter le nom selon ton code ESP32)
            if (deviceName.contains("ESP32") || 
                deviceName.contains("RFID") ||
                deviceName.contains("BLE_RFID")) {
              
              debugPrint("✅ ESP32 RFID détecté!");
              _connectToDevice(result.device);
              break;
            }
          }
        },
        onError: (error) {
          debugPrint("❌ Erreur scan: $error");
          if (mounted) {
            setState(() => _isScanning = false);
          }
        },
      );

      // Timeout après 15 secondes
      Future.delayed(const Duration(seconds: 15), () {
        if (_isScanning && !_isConnected && mounted) {
          _stopBLEScan();
          _showSnackBar("⚠️ Aucun lecteur RFID trouvé", Colors.orange);
        }
      });
      
    } catch (e) {
      debugPrint("❌ Erreur démarrage scan: $e");
      if (mounted) {
        setState(() => _isScanning = false);
        _showSnackBar("❌ Erreur lors du scan", Colors.red);
      }
    }
  }

  Future<void> _stopBLEScan() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await FlutterBluePlus.stopScan();
    
    if (mounted) {
      setState(() => _isScanning = false);
    }
    
    debugPrint("🛑 Scan BLE arrêté");
  }

  // =====================================================
  // BLUETOOTH BLE - CONNEXION À L'ESP32
  // =====================================================
  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await _stopBLEScan();
      
      debugPrint("🔗 Connexion à ${device.platformName}...");
      _showSnackBar("🔗 Connexion au lecteur...", Colors.blue);

      // Se connecter à l'appareil
      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      setState(() {
        _connectedDevice = device;
        _isConnected = true;
      });

      debugPrint("✅ Connecté à ${device.platformName}");
      _showSnackBar("✅ Lecteur RFID connecté", Colors.green);

      // Écouter les déconnexions
      _deviceStateSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected && mounted) {
          debugPrint("🔴 Appareil déconnecté");
          _handleDisconnection();
        }
      });

      // Découvrir les services
      await _discoverServices(device);
      
    } catch (e) {
      debugPrint("❌ Erreur connexion: $e");
      if (mounted) {
        _showSnackBar("❌ Échec de connexion", Colors.red);
        setState(() {
          _connectedDevice = null;
          _isConnected = false;
        });
      }
    }
  }

  // =====================================================
  // BLUETOOTH BLE - DÉCOUVERTE DES SERVICES
  // =====================================================
  Future<void> _discoverServices(BluetoothDevice device) async {
    try {
      debugPrint("🔍 Découverte des services...");
      
      List<BluetoothService> services = await device.discoverServices();
      
      for (BluetoothService service in services) {
        debugPrint("📋 Service: ${service.uuid}");
        
        // Chercher notre service RFID
        if (service.uuid.toString().toLowerCase() == SERVICE_UUID.toLowerCase()) {
          debugPrint("✅ Service RFID trouvé!");
          
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            debugPrint("   📝 Caractéristique: ${characteristic.uuid}");
            
            // Chercher notre caractéristique RFID
            if (characteristic.uuid.toString().toLowerCase() == CHARACTERISTIC_UUID.toLowerCase()) {
              debugPrint("✅ Caractéristique RFID trouvée!");
              
              _rfidCharacteristic = characteristic;
              await _subscribeToRFID(characteristic);
              return;
            }
          }
        }
      }
      
      // Service non trouvé
      debugPrint("⚠️ Service RFID non trouvé");
      _showSnackBar("⚠️ Service RFID non disponible", Colors.orange);
      
    } catch (e) {
      debugPrint("❌ Erreur découverte services: $e");
      if (mounted) {
        _showSnackBar("❌ Erreur de communication", Colors.red);
      }
    }
  }

  // =====================================================
  // BLUETOOTH BLE - ÉCOUTE DES NOTIFICATIONS RFID
  // =====================================================
  Future<void> _subscribeToRFID(BluetoothCharacteristic characteristic) async {
    try {
      // Activer les notifications
      await characteristic.setNotifyValue(true);
      
      debugPrint("✅ Notifications RFID activées");
      _showSnackBar("✅ Système RFID prêt", Colors.green);

      // Écouter les données
      _characteristicSubscription = characteristic.lastValueStream.listen(
        (value) {
          if (value.isNotEmpty) {
            _onRFIDDataReceived(value);
          }
        },
        onError: (error) {
          debugPrint("❌ Erreur notification: $error");
        },
      );
      
    } catch (e) {
      debugPrint("❌ Erreur souscription: $e");
      if (mounted) {
        _showSnackBar("❌ Échec d'activation RFID", Colors.red);
      }
    }
  }

  // =====================================================
  // TRAITEMENT DES DONNÉES RFID REÇUES
  // =====================================================
  void _onRFIDDataReceived(List<int> value) {
    try {
      // Convertir les bytes en String
      String uid = utf8.decode(value).trim();
      
      debugPrint("═══════════════════════════════");
      debugPrint("🏷️  UID REÇU VIA BLE : $uid");
      debugPrint("═══════════════════════════════");

      // Anti-spam: ignorer si même UID dans les 2 dernières secondes
      final now = DateTime.now();
      if (_lastReceivedUID == uid && 
          _lastScanTime != null && 
          now.difference(_lastScanTime!) < _antiSpamDelay) {
        debugPrint("⏭️  Ignoré (anti-spam)");
        return;
      }

      _lastReceivedUID = uid;
      _lastScanTime = now;

      // Traiter le tag
      if (mounted) {
        _onTagDetected(uid);
      }
      
    } catch (e) {
      debugPrint("❌ Erreur décodage UID: $e");
    }
  }

  // =====================================================
  // DÉTECTION TAG AVEC VALIDATION
  // =====================================================
  Future<void> _onTagDetected(String uid) async {
    if (!mounted) return;

    debugPrint("🔍 Validation du tag...");

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

    // Vérifier doublon dans la base de données
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

  // =====================================================
  // DÉCONNEXION BLUETOOTH
  // =====================================================
  Future<void> _disconnectBLE() async {
    try {
      await _characteristicSubscription?.cancel();
      await _deviceStateSubscription?.cancel();
      await _scanSubscription?.cancel();
      
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }
      
      _characteristicSubscription = null;
      _deviceStateSubscription = null;
      _scanSubscription = null;
      _connectedDevice = null;
      _rfidCharacteristic = null;
      
      if (mounted) {
        setState(() => _isConnected = false);
      }
      
      debugPrint("🔴 Bluetooth déconnecté");
    } catch (e) {
      debugPrint("⚠️ Erreur déconnexion: $e");
    }
  }

  void _handleDisconnection() {
    _showSnackBar("🔴 Lecteur RFID déconnecté", Colors.red);
    
    setState(() {
      _isConnected = false;
      _connectedDevice = null;
      _rfidCharacteristic = null;
    });
    
    // Optionnel: Reconnexion automatique
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_isConnected) {
        _showSnackBar("🔄 Tentative de reconnexion...", Colors.blue);
        _startBLEScan();
      }
    });
  }

  Future<void> _reconnectBLE() async {
    await _disconnectBLE();
    await Future.delayed(const Duration(milliseconds: 500));
    _initializeBluetooth();
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
          Icon(icon, size: 20, color: Colors.orange[700]),
          const SizedBox(width: 8),
          Text(
            "$label: ",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ===== IMAGE PICKER =====
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
              title: const Text("Caméra"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Galerie"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() => _pickedFile = image);
        debugPrint("✅ Image sélectionnée: ${image.path}");
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace, context: 'Sélection image');
      if (mounted) {
        ErrorHandler.show(context, e);
      }
    }
  }

  Future<String?> _uploadImage(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final fileExt = file.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'animals/$fileName';

      await Supabase.instance.client.storage
          .from('images')
          .uploadBinary(filePath, bytes);

      final url = Supabase.instance.client.storage
          .from('images')
          .getPublicUrl(filePath);

      return url;
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace, context: 'Upload image');
      return null;
    }
  }

  // ===== ENREGISTREMENT =====
  Future<void> _enregistrer() async {
    // Validation des champs
    if (_nomController.text.trim().isEmpty) {
      ErrorHandler.show(context, "Le nom est requis");
      return;
    }

    if (_provenanceController.text.trim().isEmpty) {
      ErrorHandler.show(context, "La provenance est requise");
      return;
    }

    if (_selectedSexe == null) {
      ErrorHandler.show(context, "Le sexe est requis");
      return;
    }

    if (_selectedRace == null) {
      ErrorHandler.show(context, "La race est requise");
      return;
    }

    if (_pickedFile == null) {
      ErrorHandler.show(context, "Une photo est requise");
      return;
    }

    if (_tagRFID == null) {
      ErrorHandler.show(context, "Scannez un tag RFID");
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
          // Icône Bluetooth avec état
          IconButton(
            icon: Icon(
              _isConnected ? Icons.bluetooth_connected : 
              _isScanning ? Icons.bluetooth_searching : 
              Icons.bluetooth_disabled,
              color: _isConnected ? Colors.white : 
                     _isScanning ? Colors.blue : 
                     Colors.orange,
            ),
            onPressed: _isConnected ? null : _reconnectBLE,
            tooltip: _isConnected ? "Connecté" : 
                    _isScanning ? "Recherche..." : 
                    "Reconnecter",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Indicateur de connexion BLE
                  _buildBLEStatusCard(),
                  const SizedBox(height: 16),
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

  // Carte d'état BLE
  Widget _buildBLEStatusCard() {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (_isConnected) {
      statusText = "✅ Lecteur RFID connecté";
      statusColor = Colors.green;
      statusIcon = Icons.bluetooth_connected;
    } else if (_isScanning) {
      statusText = "🔍 Recherche du lecteur...";
      statusColor = Colors.blue;
      statusIcon = Icons.bluetooth_searching;
    } else {
      statusText = "❌ Lecteur non connecté";
      statusColor = Colors.orange;
      statusIcon = Icons.bluetooth_disabled;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        border: Border.all(color: statusColor, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          if (!_isConnected && !_isScanning)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _reconnectBLE,
              color: statusColor,
              tooltip: "Reconnecter",
            ),
        ],
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
      readOnly: true, // ✅ CHAMP EN LECTURE SEULE
      enabled: false,  // ✅ DÉSACTIVÉ POUR EMPÊCHER TOUTE MODIFICATION
      decoration: InputDecoration(
        labelText: "UID RFID *",
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.nfc),
        suffixIcon: _tagRFID != null
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.pending, color: Colors.orange),
        helperText: _tagRFID == null ? "En attente du scan..." : "Tag détecté via BLE",
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