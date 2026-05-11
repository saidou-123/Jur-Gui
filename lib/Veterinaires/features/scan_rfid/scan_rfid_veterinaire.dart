import 'dart:async';
import 'package:depart/Veterinaires/Scanveterinaire/FicheSanteDetailAnimal.dart';
import 'package:depart/Veterinaires/Scanveterinaire/NouvelleConsultationPage.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';

class ScanRFIDVeterinaireBluetooth extends StatefulWidget {
  const ScanRFIDVeterinaireBluetooth({super.key});

  @override
  State<ScanRFIDVeterinaireBluetooth> createState() =>
      _ScanRFIDVeterinaireBluetoothState();
}

class _ScanRFIDVeterinaireBluetoothState
    extends State<ScanRFIDVeterinaireBluetooth> {
  // ========== BLUETOOTH BLE ==========
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _rfidCharacteristic;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _deviceStateSubscription;
  StreamSubscription? _characteristicSubscription;
  bool _isScanning = false;
  bool _isConnected = false;

  // UUIDs identiques aux autres pages
  static const String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String CHARACTERISTIC_UUID =
      "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  // Anti-doublon
  String? _lastReceivedUID;
  DateTime? _lastScanTime;
  static const Duration _antiSpamDelay = Duration(seconds: 2);

  // ========== ÉTAT UI ==========
  bool _isSearching = false;
  String? _lastScannedUID;
  Map<String, dynamic>? _animalInfo;
  String? _sourceTable;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeBluetooth();
    });
  }

  @override
  void dispose() {
    _disconnectBLE();
    super.dispose();
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
        if (mounted) _showSnackBar("❌ Permissions BLE refusées", Colors.red);
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
      debugPrint("❌ Erreur Init Bluetooth: $e");
      debugPrint("Stack: $stackTrace");
      if (mounted) _showSnackBar("❌ Erreur Bluetooth: $e", Colors.red);
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

      // ✅ Ignorer le premier événement "disconnected"
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
          debugPrint(
              "   └─ Caractéristique: ${c.uuid} | notify:${c.properties.notify}");
        }
      }

      // ✅ Recherche par contains
      BluetoothService? targetService;
      for (BluetoothService service in services) {
        if (service.uuid
            .toString()
            .toLowerCase()
            .contains(SERVICE_UUID.substring(0, 8).toLowerCase())) {
          targetService = service;
          debugPrint("✅ Service trouvé!");
          break;
        }
      }

      if (targetService == null) {
        debugPrint("❌ Service introuvable");
        for (var s in services) debugPrint("   → ${s.uuid}");
        _showSnackBar("❌ Service RFID non trouvé", Colors.red);
        return;
      }

      BluetoothCharacteristic? targetChar;
      for (BluetoothCharacteristic c in targetService.characteristics) {
        if (c.uuid
            .toString()
            .toLowerCase()
            .contains(CHARACTERISTIC_UUID.substring(0, 8).toLowerCase())) {
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
      debugPrint("❌ Erreur discoverServices: $e\n$stack");
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

      // ✅ Lecture initiale
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

      // ✅ onValueReceived au lieu de value/lastValueStream
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

      // Anti-spam
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

  // ✅ Sans boucle infinie
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

  // =====================================================
  // DÉTECTION TAG ET RECHERCHE DE L'ANIMAL
  // =====================================================
  Future<void> _onTagDetected(String uid) async {
    if (!mounted) return;

    final cleanUid = uid.trim().toUpperCase();
    debugPrint("════════════════════════════════════");
    debugPrint("🏷️  TAG DÉTECTÉ : $cleanUid");
    debugPrint("════════════════════════════════════");

    final currentUser = Supabase.instance.client.auth.currentUser;
    debugPrint("👤 User: ${currentUser?.id} | ${currentUser?.email}");

    setState(() {
      _isSearching = true;
      _lastScannedUID = cleanUid;
      _animalInfo = null;
      _sourceTable = null;
    });

    _showSnackBar("🔍 Recherche en cours...", Colors.blue);

    try {
      // 🔍 Rechercher dans nouveaux_nee
      debugPrint("🔎 Recherche dans nouveaux_nee...");
      var result = await Supabase.instance.client
          .from('nouveaux_nee')
          .select('*')
          .ilike('tag_rfid', cleanUid)
          .maybeSingle();

      if (result != null) {
        debugPrint("✅ Trouvé dans nouveaux_nee: ${result['nom']}");
        if (mounted) {
          setState(() {
            _animalInfo = result;
            _sourceTable = 'nee';
            _isSearching = false;
          });
          _showSnackBar("✅ Animal trouvé : ${result['nom']}", Colors.green);
        }
        return;
      }

      // 🔍 Rechercher dans animal_acheter
      debugPrint("🔎 Recherche dans animal_acheter...");
      result = await Supabase.instance.client
          .from('animal_acheter')
          .select('*')
          .ilike('tag_rfid', cleanUid)
          .maybeSingle();

      if (result != null) {
        debugPrint("✅ Trouvé dans animal_acheter: ${result['nom']}");
        if (mounted) {
          setState(() {
            _animalInfo = result;
            _sourceTable = 'achete';
            _isSearching = false;
          });
          _showSnackBar("✅ Animal trouvé : ${result['nom']}", Colors.green);
        }
        return;
      }

      // ❌ Non trouvé
      debugPrint("❌ Aucun animal trouvé avec UID: $cleanUid");
      if (mounted) {
        setState(() {
          _isSearching = false;
          _animalInfo = null;
          _sourceTable = null;
        });
        _showSnackBar("❌ Aucun animal avec ce tag RFID", Colors.red);
      }

    } catch (e, stackTrace) {
      debugPrint("❌ Erreur recherche: $e\nStack: $stackTrace");
      if (mounted) {
        setState(() => _isSearching = false);
        _showSnackBar("Erreur: ${e.toString()}", Colors.red);
      }
    }
  }

  // =====================================================
  // TEST MANUEL
  // =====================================================
  Future<void> _testManuelRecherche() async {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Test Manuel"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: "Entrez un tag RFID",
            hintText: "Ex: D3F1CD2C",
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (controller.text.isNotEmpty) {
                _onTagDetected(controller.text);
              }
            },
            child: const Text("Rechercher"),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // =====================================================
  // BUILD UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan RFID - Vétérinaire"),
        backgroundColor: Colors.blue[700],
        actions: [
          IconButton(
            icon: Icon(
              _isConnected
                  ? Icons.bluetooth_connected
                  : _isScanning
                      ? Icons.bluetooth_searching
                      : Icons.bluetooth_disabled,
              color: _isConnected
                  ? Colors.white
                  : _isScanning
                      ? Colors.blue
                      : Colors.orange,
            ),
            onPressed: _isConnected ? null : _reconnectBLE,
            tooltip: _isConnected
                ? "Connecté"
                : _isScanning
                    ? "Recherche..."
                    : "Reconnecter",
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildBLEStatusCard(),
            const SizedBox(height: 16),
            _buildScanSection(),
            const SizedBox(height: 24),
            if (_isSearching)
              _buildLoadingSection()
            else if (_animalInfo != null)
              _buildAnimalInfoCard()
            else if (_lastScannedUID != null)
              _buildNoResultCard()
            else
              _buildWaitingCard(),
          ],
        ),
      ),
    );
  }

  // ✅ Carte d'état BLE (nouvelle — absente dans l'original)
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
            ),
        ],
      ),
    );
  }

  Widget _buildScanSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isConnected
              ? [Colors.blue[700]!, Colors.blue[500]!]
              : [Colors.grey[700]!, Colors.grey[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (_isConnected ? Colors.blue : Colors.grey).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_searching,
            size: 80,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          Text(
            _isConnected
                ? "Prêt à scanner"
                : _isScanning
                    ? "Recherche ESP32..."
                    : "Non connecté",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isConnected
                ? "Approchez un tag RFID du lecteur"
                : "Vérifiez que l'ESP32 est allumé",
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (!_isConnected)
            ElevatedButton.icon(
              onPressed: _isScanning ? null : _reconnectBLE,
              icon: _isScanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.bluetooth_searching),
              label: Text(_isScanning ? "Recherche..." : "Connecter"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue[700],
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _testManuelRecherche,
            icon: const Icon(Icons.edit, color: Colors.white),
            label: const Text("Test manuel",
                style: TextStyle(color: Colors.white)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white, width: 2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSection() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue[200]!, width: 2),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          const Text("Recherche en cours...",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            "Tag RFID : $_lastScannedUID",
            style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 2),
      ),
      child: Column(
        children: [
          Icon(Icons.touch_app, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text("En attente de scan",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700])),
          const SizedBox(height: 8),
          Text("Scannez un tag RFID ou utilisez le test manuel",
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildNoResultCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[200]!, width: 2),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 80, color: Colors.red),
          const SizedBox(height: 16),
          const Text("Animal non trouvé",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.nfc, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(_lastScannedUID ?? 'N/A',
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _testManuelRecherche,
            icon: const Icon(Icons.search),
            label: const Text("Réessayer manuellement"),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimalInfoCard() {
    if (_animalInfo == null) return const SizedBox.shrink();

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // En-tête
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[700],
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 50),
                const SizedBox(height: 8),
                Text(
                  _animalInfo!['nom'] ?? 'Sans nom',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  _sourceTable == 'nee' ? '🐑 Nouveau-né' : '🛒 Animal acheté',
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),

          // Image
          if (_animalInfo!['image_url'] != null)
            Image.network(
              _animalInfo!['image_url'],
              width: double.infinity,
              height: 250,
              fit: BoxFit.cover,
              errorBuilder: (context, error, _) => Container(
                height: 250,
                color: Colors.grey[300],
                child:
                    const Icon(Icons.error, size: 60, color: Colors.red),
              ),
            ),

          // Infos
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildInfoRow(
                    Icons.agriculture, "Race", _animalInfo!['race'] ?? 'N/A'),
                const Divider(height: 24),
                _buildInfoRow(
                    Icons.wc, "Sexe", _animalInfo!['sexe'] ?? 'N/A'),
                const Divider(height: 24),
                _buildInfoRow(Icons.nfc, "Tag RFID",
                    _animalInfo!['tag_rfid'] ?? 'N/A'),
                if (_animalInfo!['date_naissance'] != null) ...[
                  const Divider(height: 24),
                  _buildInfoRow(Icons.calendar_today, "Date naissance",
                      _animalInfo!['date_naissance']),
                ],
                if (_animalInfo!['provenance'] != null) ...[
                  const Divider(height: 24),
                  _buildInfoRow(Icons.location_on, "Provenance",
                      _animalInfo!['provenance']),
                ],
              ],
            ),
          ),

          // Boutons d'action
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FicheSanteDetailAnimal(
                            animal: _animalInfo!,
                            source: _sourceTable!,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.medical_services),
                    label: const Text("Fiche de Santé"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NouvelleConsultationPage(
                            animal: _animalInfo!,
                            source: _sourceTable!,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text("Nouvelle Consultation"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue[700],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 24, color: Colors.green[700]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }
}