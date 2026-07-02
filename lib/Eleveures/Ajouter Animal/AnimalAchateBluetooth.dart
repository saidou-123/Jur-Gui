// ============================================================
// ANIMAL ACHETÉ - VERSION BLE CORRIGÉE (DESIGN ALIGNÉ)
// Fichier: lib/Eleveures/Ajouter Animal/AnimalAchateBluetooth.dart
// Communication Bluetooth BLE avec ESP32 + RFID
//
// NOTE : Seul le DESIGN (couleurs, style des champs, badges de
// confirmation) a été aligné sur NouveauNeeBluetooth.dart.
// Aucune logique (BLE, Supabase, validations) n'a été ajoutée,
// supprimée ou modifiée.
// ============================================================

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
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

  // UUID identiques à NouveauNeeBluetooth
  static const String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  // Anti-doublon
  String? _lastReceivedUID;
  DateTime? _lastScanTime;
  static const Duration _antiSpamDelay = Duration(seconds: 2);

  // ===== COULEURS DES CHAMPS (alignées sur NouveauNeeBluetooth) =====
  static const Color _couleurNom = Color(0xFF2E7D32);
  static const Color _couleurSexe = Color(0xFF6A1B9A);
  static const Color _couleurRace = Color(0xFF00838F);
  static const Color _couleurProvenance = Color(0xFFE65100);

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
  // BLUETOOTH BLE - INITIALISATION AVEC PERMISSIONS
  // =====================================================
  Future<void> _initializeBluetooth() async {
    if (!mounted) return;

    try {
      debugPrint("📱 Initialisation Bluetooth...");

      // ✅ Demander les permissions au runtime
      final permissions = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      permissions.forEach((perm, status) {
        debugPrint("🔑 $perm → $status");
      });

      final denied = permissions.entries
          .where((e) => !e.value.isGranted)
          .map((e) => e.key.toString())
          .toList();

      if (denied.isNotEmpty) {
        debugPrint("❌ Permissions refusées: $denied");
        if (mounted) {
          _showSnackBar("❌ Permissions BLE refusées", Colors.red);
        }
        return;
      }

      debugPrint("✅ Toutes les permissions accordées");

      if (await FlutterBluePlus.isSupported == false) {
        if (mounted) _showSnackBar("❌ Bluetooth non supporté", Colors.red);
        return;
      }

      final state = await FlutterBluePlus.adapterState.first;
      debugPrint("📡 État Bluetooth: $state");

      if (state != BluetoothAdapterState.on) {
        if (mounted) _showSnackBar("⚠️ Activez le Bluetooth", Colors.orange);
        return;
      }

      _startBLEScan();

    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace, context: 'Init Bluetooth');
      if (mounted) ErrorHandler.show(context, e, customMessage: 'Erreur Bluetooth');
    }
  }

  // =====================================================
  // BLUETOOTH BLE - SCAN CORRIGÉ
  // =====================================================
  Future<void> _startBLEScan() async {
    if (_isScanning || _isConnected) return;

    setState(() => _isScanning = true);
    debugPrint("🔍 Scan BLE démarré...");
    _showSnackBar("🔍 Recherche du lecteur RFID...", Colors.blue);

    try {
      await FlutterBluePlus.stopScan();
      await Future.delayed(const Duration(milliseconds: 500));

      // ✅ Vérifier d'abord les appareils bondés
      final bonded = await FlutterBluePlus.bondedDevices;
      debugPrint("📋 Appareils bondés: ${bonded.length}");
      for (final d in bonded) {
        debugPrint("   🔗 Bondé: '${d.platformName}' | ${d.remoteId}");
        if (d.platformName.contains("Jur-Gui") ||
            d.platformName.contains("JUR-GUI") ||
            d.platformName.contains("ESP32") ||
            d.platformName.contains("RFID")) {
          debugPrint("✅ ESP32 trouvé dans les bondés!");
          setState(() => _isScanning = false);
          _connectToDevice(d);
          return;
        }
      }

      // ✅ Écouter AVANT de démarrer le scan
      _scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
        if (results.isEmpty) return;
        for (ScanResult r in results) {
          final name = r.device.platformName;
          debugPrint("📡 '$name' | ${r.device.remoteId} | RSSI:${r.rssi}");

          if (name.contains("Jur-Gui") ||
              name.contains("JUR-GUI") ||
              name.contains("ESP32") ||
              name.contains("RFID") ||
              name.contains("BLE_RFID")) {
            debugPrint("✅ ESP32 détecté via scan!");
            _stopBLEScan().then((_) => _connectToDevice(r.device));
            return;
          }
        }
      });

      // ✅ Démarrer APRÈS l'écoute
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 30),
        androidUsesFineLocation: false,
        withServices: [],
      );

      debugPrint("✅ Scan actif, en attente d'appareils...");

      Future.delayed(const Duration(seconds: 30), () {
        if (_isScanning && !_isConnected && mounted) {
          _stopBLEScan();
          _showSnackBar("⚠️ ESP32 non trouvé — réessayez", Colors.orange);
        }
      });

    } catch (e) {
      debugPrint("❌ Erreur scan: $e");
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
    if (mounted) setState(() => _isScanning = false);
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

      // ✅ Ignorer le premier événement "disconnected" au démarrage
      bool firstEvent = true;
      _deviceStateSubscription = device.connectionState.listen((state) {
        debugPrint("📶 État connexion: $state");

        if (firstEvent) {
          firstEvent = false;
          return;
        }

        if (state == BluetoothConnectionState.disconnected && mounted) {
          debugPrint("🔴 Appareil déconnecté");
          _handleDisconnection();
        }
      });

      await _discoverServices(device);

    } catch (e) {
      debugPrint("❌ Erreur connexion: $e");
      if (mounted) {
        _showSnackBar("❌ Échec de connexion", Colors.red);
        setState(() {
          _connectedDevice = null;
          _isConnected = false;
        });
        Future.delayed(const Duration(seconds: 2), _startBLEScan);
      }
    }
  }

  // =====================================================
  // BLUETOOTH BLE - DÉCOUVERTE DES SERVICES
  // =====================================================
  Future<void> _discoverServices(BluetoothDevice device) async {
    try {
      debugPrint("🔍 Découverte des services...");

      // ✅ Délai de stabilisation
      await Future.delayed(const Duration(milliseconds: 800));

      List<BluetoothService> services = await device.discoverServices();
      debugPrint("📋 Nombre de services trouvés: ${services.length}");

      for (BluetoothService service in services) {
        debugPrint("📋 Service UUID: ${service.uuid.toString().toLowerCase()}");
        for (BluetoothCharacteristic c in service.characteristics) {
          debugPrint("   └─ Caractéristique: ${c.uuid} | notify:${c.properties.notify} | read:${c.properties.read}");
        }
      }

      // ✅ Recherche par contains (plus robuste)
      BluetoothService? targetService;
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase().contains(
            SERVICE_UUID.substring(0, 8).toLowerCase())) {
          targetService = service;
          debugPrint("✅ Service trouvé!");
          break;
        }
      }

      if (targetService == null) {
        debugPrint("❌ Service introuvable — UUIDs disponibles:");
        for (var s in services) debugPrint("   → ${s.uuid}");
        _showSnackBar("❌ Service RFID non trouvé", Colors.red);
        return;
      }

      BluetoothCharacteristic? targetChar;
      for (BluetoothCharacteristic c in targetService.characteristics) {
        if (c.uuid.toString().toLowerCase().contains(
            CHARACTERISTIC_UUID.substring(0, 8).toLowerCase())) {
          targetChar = c;
          debugPrint("✅ Caractéristique trouvée!");
          break;
        }
      }

      if (targetChar == null) {
        debugPrint("❌ Caractéristique introuvable");
        _showSnackBar("❌ Caractéristique RFID non trouvée", Colors.red);
        return;
      }

      _rfidCharacteristic = targetChar;
      await _subscribeToRFID(targetChar);

    } catch (e, stack) {
      debugPrint("❌ Erreur discoverServices: $e");
      debugPrint("$stack");
      if (mounted) _showSnackBar("❌ Erreur de communication", Colors.red);
    }
  }

  // =====================================================
  // BLUETOOTH BLE - ÉCOUTE DES NOTIFICATIONS RFID
  // =====================================================
  Future<void> _subscribeToRFID(BluetoothCharacteristic characteristic) async {
    try {
      // ✅ Attendre stabilisation
      await Future.delayed(const Duration(milliseconds: 500));

      // ✅ Lecture initiale pour réveiller la caractéristique
      try {
        final initial = await characteristic.read();
        if (initial.isNotEmpty) {
          debugPrint("📖 Valeur initiale: ${utf8.decode(initial)}");
        }
      } catch (_) {}

      // ✅ Activer les notifications
      await characteristic.setNotifyValue(true);
      await Future.delayed(const Duration(milliseconds: 300));

      debugPrint("✅ Notifications RFID activées");
      _showSnackBar("✅ Système RFID prêt", Colors.green);

      // ✅ onValueReceived au lieu de lastValueStream
      _characteristicSubscription = characteristic.onValueReceived.listen(
        (value) {
          debugPrint("📥 Données BLE brutes: $value");
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
      if (mounted) _showSnackBar("❌ Échec d'activation RFID", Colors.red);
    }
  }

  // =====================================================
  // TRAITEMENT DES DONNÉES RFID REÇUES
  // =====================================================
  void _onRFIDDataReceived(List<int> value) {
    try {
      String uid = utf8.decode(value).trim();

      debugPrint("═══════════════════════════════");
      debugPrint("🏷️  UID REÇU VIA BLE : $uid");
      debugPrint("═══════════════════════════════");

      final now = DateTime.now();
      if (_lastReceivedUID == uid &&
          _lastScanTime != null &&
          now.difference(_lastScanTime!) < _antiSpamDelay) {
        debugPrint("⏭️  Ignoré (anti-spam)");
        return;
      }

      _lastReceivedUID = uid;
      _lastScanTime = now;

      if (mounted) _onTagDetected(uid);

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

    try {
      final result = await Supabase.instance.client
          .from('animal_acheter')
          .select('id, nom, race, sexe, provenance, tag_rfid')
          .eq('tag_rfid', uid);

      if (result.isNotEmpty) {
        final existing = result.first;
        debugPrint("⚠️ DOUBLON DÉTECTÉ!");

        if (mounted) {
          _showSnackBar("⚠️ Tag déjà utilisé par: ${existing['nom']}", Colors.orange);
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

      if (mounted) setState(() => _isConnected = false);

      debugPrint("🔴 Bluetooth déconnecté");
    } catch (e) {
      debugPrint("⚠️ Erreur déconnexion: $e");
    }
  }

  // ✅ Sans boucle infinie — relance uniquement _startBLEScan
  void _handleDisconnection() {
    if (!mounted) return;

    _deviceStateSubscription?.cancel();
    _deviceStateSubscription = null;

    _showSnackBar("🔴 Lecteur RFID déconnecté", Colors.red);

    setState(() {
      _isConnected = false;
      _connectedDevice = null;
      _rfidCharacteristic = null;
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !_isConnected && !_isScanning) {
        debugPrint("🔄 Relance du scan après déconnexion...");
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
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 64),
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
                  _buildInfoRow(Icons.wc, "Sexe", existing['sexe'] ?? 'N/A'),
                  _buildInfoRow(Icons.location_on, "Provenance", existing['provenance'] ?? 'N/A'),
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
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
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
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Galerie"),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
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
        source: source, maxWidth: 1920, maxHeight: 1080, imageQuality: 85,
      );
      if (image != null) {
        setState(() => _pickedFile = image);
        debugPrint("✅ Image sélectionnée: ${image.path}");
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace, context: 'Sélection image');
      if (mounted) ErrorHandler.show(context, e);
    }
  }

  Future<String?> _uploadImage(XFile file) async {
    try {
      debugPrint("📤 Début upload image...");
      final bytes = await file.readAsBytes();
      final fileExt = file.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'animal_acheter/$fileName';

      await Supabase.instance.client.storage
          .from('uploads')
          .uploadBinary(filePath, bytes);

      final url = Supabase.instance.client.storage
          .from('uploads')
          .getPublicUrl(filePath);

      debugPrint("✅ Image uploadée: $url");
      return url;
    } catch (e, stackTrace) {
      debugPrint("❌ Erreur upload: $e");
      ErrorHandler.log(e, stackTrace, context: 'Upload image');
      return null;
    }
  }

  // ===== ENREGISTREMENT =====
  Future<void> _enregistrer() async {
    debugPrint("═══════════════════════════════════════");
    debugPrint("🚀 DÉBUT ENREGISTREMENT");
    debugPrint("═══════════════════════════════════════");

    if (_nomController.text.trim().isEmpty) {
      ErrorHandler.show(context, "Le nom est requis"); return;
    }
    if (_provenanceController.text.trim().isEmpty) {
      ErrorHandler.show(context, "La provenance est requise"); return;
    }
    if (_selectedRace == null || _selectedRace!.trim().isEmpty) {
      ErrorHandler.show(context, "La race est requise"); return;
    }
    if (_selectedSexe == null) {
      ErrorHandler.show(context, "Le sexe est requis"); return;
    }
    if (_pickedFile == null) {
      ErrorHandler.show(context, "Une photo est requise"); return;
    }
    if (_tagRFID == null) {
      ErrorHandler.show(context, "Scannez un tag RFID"); return;
    }

    final rfidValidation = Validators.rfid(_tagRFID);
    if (rfidValidation != null) {
      ErrorHandler.show(context, rfidValidation); return;
    }

    setState(() => _isLoading = true);

    try {
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

      final url = await _uploadImage(_pickedFile!);
      if (url == null) throw Exception("Erreur upload image");

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception("Utilisateur non connecté");

      final dataToInsert = {
        'nom': Validators.sanitize(_nomController.text),
        'provenance': Validators.sanitize(_provenanceController.text),
        'race': Validators.sanitize(_selectedRace!),
        'sexe': _selectedSexe,
        'image_url': url,
        'tag_rfid': _tagRFID,
        'user_id': userId,
        'created_at': DateTime.now().toIso8601String(),
      };

      debugPrint("📝 Données à insérer: $dataToInsert");

      await Supabase.instance.client
          .from('animal_acheter')
          .insert(dataToInsert);

      debugPrint("✅✅✅ ENREGISTREMENT RÉUSSI!");

      if (mounted) {
        ErrorHandler.showSuccess(context, "✅ Animal acheté enregistré avec succès!");
        _resetForm();
      }

    } catch (error, stackTrace) {
      debugPrint("❌ ERREUR: $error");
      ErrorHandler.log(error, stackTrace, context: 'Enregistrement animal acheté');
      if (mounted) ErrorHandler.show(context, error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    _nomController.clear();
    _raceController.clear();
    _provenanceController.clear();
    _dateController.clear();
    _uidController.clear();
    setState(() {
      _selectedSexe = null;
      _selectedRace = null;
      _pickedFile = null;
      _tagRFID = null;
    });
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, duration: const Duration(seconds: 2)),
    );
  }

  // ====================================================================
  // BUILD
  // ====================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Jur Gui 4.0 - Animal Acheté"),
        backgroundColor: Colors.green[700],
        actions: [
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
                  _buildBLEStatusCard(),
                  const SizedBox(height: 16),
                  _buildPhotoSection(),
                  const SizedBox(height: 16),

                  _buildChampStyleParent(
                    label: "Nom",
                    icone: Icons.pets,
                    couleur: _couleurNom,
                    valeur: _nomController.text.trim().isEmpty ? null : _nomController.text.trim(),
                    resume: _nomController.text.trim().isEmpty ? null : _nomController.text.trim(),
                    champSaisie: TextFormField(
                      controller: _nomController,
                      onChanged: (_) => setState(() {}),
                      decoration: _inputDeco(
                        "Saisir le nom…",
                        Icons.pets,
                        _couleurNom,
                        suffixClear: _nomController.text.isNotEmpty,
                        onClear: () { _nomController.clear(); setState(() {}); },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildChampStyleParent(
                    label: "Sexe",
                    icone: Icons.wc,
                    couleur: _couleurSexe,
                    valeur: _selectedSexe,
                    resume: _selectedSexe,
                    champSaisie: _buildSexeDropdownStyled(),
                  ),
                  const SizedBox(height: 12),

                  _buildChampStyleParent(
                    label: "Provenance",
                    icone: Icons.location_on,
                    couleur: _couleurProvenance,
                    valeur: _provenanceController.text.trim().isEmpty ? null : _provenanceController.text.trim(),
                    resume: _provenanceController.text.trim().isEmpty ? null : _provenanceController.text.trim(),
                    champSaisie: TextFormField(
                      controller: _provenanceController,
                      onChanged: (_) => setState(() {}),
                      decoration: _inputDeco(
                        "Saisir la provenance…",
                        Icons.location_on,
                        _couleurProvenance,
                        suffixClear: _provenanceController.text.isNotEmpty,
                        onClear: () { _provenanceController.clear(); setState(() {}); },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildChampStyleParent(
                    label: "Race",
                    icone: Icons.agriculture,
                    couleur: _couleurRace,
                    valeur: _selectedRace,
                    resume: _selectedRace,
                    champSaisie: _buildRaceDropdownStyled(),
                  ),
                  const SizedBox(height: 12),

                  _buildChampStyleParent(
                    label: "UID RFID",
                    icone: Icons.nfc,
                    couleur: _tagRFID != null ? Colors.teal : Colors.grey,
                    valeur: _tagRFID,
                    resume: _tagRFID != null ? "Tag détecté : $_tagRFID" : null,
                    champSaisie: _buildUidFieldStyled(),
                  ),
                  const SizedBox(height: 24),

                  _buildSaveButton(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // ====================================================================
  // WIDGETS CHAMPS GÉNÉRIQUES (identiques à NouveauNeeBluetooth)
  // ====================================================================

  Widget _buildChampStyleParent({
    required String label,
    required IconData icone,
    required Color couleur,
    required String? valeur,
    required String? resume,
    required Widget champSaisie,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Icon(icone, size: 18, color: couleur),
              const SizedBox(width: 6),
              Text(
                "$label *",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: couleur,
                ),
              ),
            ],
          ),
        ),
        champSaisie,
        if (valeur != null && valeur.isNotEmpty)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: couleur.withOpacity(0.07),
              border: Border.all(color: couleur.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: couleur.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icone, size: 20, color: couleur),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    resume ?? valeur,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: couleur,
                      fontSize: 13,
                    ),
                  ),
                ),
                Icon(Icons.check_circle, color: couleur, size: 20),
              ],
            ),
          ),
      ],
    );
  }

  InputDecoration _inputDeco(
    String hint,
    IconData prefixIcon,
    Color couleur, {
    bool suffixClear = false,
    VoidCallback? onClear,
  }) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: couleur.withOpacity(0.5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: couleur.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: couleur, width: 2),
      ),
      prefixIcon: Icon(prefixIcon, color: couleur),
      suffixIcon: suffixClear && onClear != null
          ? IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: "Effacer",
              onPressed: onClear,
            )
          : null,
    );
  }

  Widget _buildSexeDropdownStyled() {
    return DropdownButtonFormField<String>(
      value: _selectedSexe,
      decoration: _inputDeco("Choisir le sexe…", Icons.wc, _couleurSexe),
      items: const [
        DropdownMenuItem(value: "Mâle", child: Text("Mâle")),
        DropdownMenuItem(value: "Femelle", child: Text("Femelle")),
      ],
      onChanged: (val) => setState(() => _selectedSexe = val),
    );
  }

  Widget _buildRaceDropdownStyled() {
    return DropdownButtonFormField<String>(
      value: _selectedRace,
      decoration: _inputDeco("Choisir la race…", Icons.agriculture, _couleurRace),
      items: const [
        DropdownMenuItem(value: "Ladoum", child: Text("Ladoum")),
        DropdownMenuItem(value: "Peulh Peulh", child: Text("Peulh Peulh")),
        DropdownMenuItem(value: "Touabire", child: Text("Touabire")),
      ],
      onChanged: (val) {
        setState(() {
          _selectedRace = val;
          if (val != null) _raceController.text = val;
        });
      },
    );
  }

  Widget _buildUidFieldStyled() {
    final couleur = _tagRFID != null ? Colors.teal : Colors.grey;
    return TextFormField(
      controller: _uidController,
      readOnly: true,
      enabled: false,
      decoration: InputDecoration(
        hintText: "En attente du scan RFID…",
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: couleur.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: couleur.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: couleur, width: 2),
        ),
        prefixIcon: Icon(Icons.nfc, color: couleur),
        suffixIcon: _tagRFID != null
            ? const Icon(Icons.check_circle, color: Colors.teal)
            : const Icon(Icons.pending, color: Colors.orange),
        helperText: _tagRFID == null
            ? "Approchez le tag du lecteur BLE"
            : "Tag détecté via BLE",
        helperStyle: TextStyle(
          color: _tagRFID == null ? Colors.grey : Colors.teal,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
    );
  }

  // ====================================================================
  // WIDGETS UI GÉNÉRIQUES (identiques à NouveauNeeBluetooth)
  // ====================================================================

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
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 16),
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
                  child: Image.file(File(_pickedFile!.path), height: 150, width: 150, fit: BoxFit.cover),
                )
              : const Icon(Icons.camera_alt, size: 80, color: Colors.grey),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _showImageSourceDialog,
            icon: const Icon(Icons.add_a_photo),
            label: const Text("Ajouter photo"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700], foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _enregistrer,
        icon: _isLoading
            ? const SizedBox(
                width: 20, height: 20,
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}