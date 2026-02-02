import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';

class AnimalInfoBLEPage extends StatefulWidget {
  const AnimalInfoBLEPage({super.key});

  @override
  State<AnimalInfoBLEPage> createState() => _AnimalInfoBLEPageState();
}

class _AnimalInfoBLEPageState extends State<AnimalInfoBLEPage> {
  // BLE Variables
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _rfidCharacteristic;
  StreamSubscription<List<int>>? _characteristicSubscription;
  bool _isScanning = false;
  bool _isConnected = false;
  bool _scanAuthorized = false;
  
  // Data variables
  String? _lastScannedUID;
  Map<String, dynamic>? _animalInfo;
  String? _sourceTable;
  bool _isSearching = false;

  // ESP32 BLE Service and Characteristic UUIDs (from Arduino code)
  static const String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  static const String DEVICE_NAME = "Jur-Gui";

  @override
  void initState() {
    super.initState();
    _checkBluetoothAndPermissions();
  }

  @override
  void dispose() {
    _characteristicSubscription?.cancel();
    _connectedDevice?.disconnect();
    super.dispose();
  }

  // ----------------------------------------------------------
  // 🔵 BLUETOOTH - PERMISSIONS ET INITIALISATION
  // ----------------------------------------------------------
  Future<void> _checkBluetoothAndPermissions() async {
    // Vérifier les permissions Bluetooth
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (statuses.values.any((status) => !status.isGranted)) {
      _showSnackBar("⚠️ Permissions Bluetooth requises", Colors.orange);
      return;
    }

    // Vérifier si le Bluetooth est activé
    if (await FlutterBluePlus.isAvailable == false) {
      _showSnackBar("❌ Bluetooth non disponible", Colors.red);
      return;
    }

    var state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      _showSnackBar("⚠️ Veuillez activer le Bluetooth", Colors.orange);
      return;
    }

    debugPrint("✅ Bluetooth prêt");
  }

  // ----------------------------------------------------------
  // 🔍 SCAN ET CONNEXION BLE
  // ----------------------------------------------------------
  Future<void> _scanAndConnect() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _isConnected = false;
    });

    _showSnackBar("🔍 Recherche de $DEVICE_NAME...", Colors.blue);

    try {
      // Démarrer le scan
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      // Écouter les résultats du scan
      StreamSubscription<List<ScanResult>>? scanSubscription;
      
      scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult result in results) {
          debugPrint("📡 Appareil trouvé: ${result.device.platformName}");
          
          if (result.device.platformName == DEVICE_NAME) {
            debugPrint("✅ ESP32 trouvé!");
            
            // Arrêter le scan
            await FlutterBluePlus.stopScan();
            scanSubscription?.cancel();
            
            // Connecter à l'appareil
            await _connectToDevice(result.device);
            return;
          }
        }
      });

      // Timeout après 10 secondes
      await Future.delayed(const Duration(seconds: 10));
      
      if (!_isConnected) {
        await FlutterBluePlus.stopScan();
        scanSubscription?.cancel();
        
        if (mounted) {
          setState(() => _isScanning = false);
          _showSnackBar("❌ ESP32 non trouvé", Colors.red);
        }
      }
    } catch (e) {
      debugPrint("❌ Erreur scan: $e");
      if (mounted) {
        setState(() => _isScanning = false);
        _showSnackBar("❌ Erreur: ${e.toString()}", Colors.red);
      }
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      debugPrint("🔌 Connexion à ${device.platformName}...");
      
      await device.connect(timeout: const Duration(seconds: 15));
      
      setState(() {
        _connectedDevice = device;
        _isConnected = true;
        _isScanning = false;
      });

      _showSnackBar("✅ Connecté à $DEVICE_NAME", Colors.green);

      // Découvrir les services
      await _discoverServices(device);

      // Écouter la déconnexion
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          debugPrint("🔴 Déconnecté de ${device.platformName}");
          if (mounted) {
            setState(() {
              _isConnected = false;
              _connectedDevice = null;
              _scanAuthorized = false;
            });
            _showSnackBar("🔴 Déconnecté", Colors.orange);
          }
        }
      });

    } catch (e) {
      debugPrint("❌ Erreur connexion: $e");
      if (mounted) {
        setState(() {
          _isScanning = false;
          _isConnected = false;
        });
        _showSnackBar("❌ Échec de connexion", Colors.red);
      }
    }
  }

  Future<void> _discoverServices(BluetoothDevice device) async {
    try {
      debugPrint("🔍 Découverte des services...");
      
      List<BluetoothService> services = await device.discoverServices();
      
      for (BluetoothService service in services) {
        debugPrint("📋 Service: ${service.uuid}");
        
        if (service.uuid.toString().toLowerCase() == SERVICE_UUID.toLowerCase()) {
          debugPrint("✅ Service RFID trouvé!");
          
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            debugPrint("   Characteristic: ${characteristic.uuid}");
            
            if (characteristic.uuid.toString().toLowerCase() == CHARACTERISTIC_UUID.toLowerCase()) {
              debugPrint("✅ Characteristic RFID trouvée!");
              
              _rfidCharacteristic = characteristic;
              
              // S'abonner aux notifications
              await _subscribeToCharacteristic(characteristic);
              break;
            }
          }
        }
      }

      if (_rfidCharacteristic == null) {
        _showSnackBar("⚠️ Service RFID non trouvé", Colors.orange);
      }

    } catch (e) {
      debugPrint("❌ Erreur découverte services: $e");
      _showSnackBar("❌ Erreur services: ${e.toString()}", Colors.red);
    }
  }

  Future<void> _subscribeToCharacteristic(BluetoothCharacteristic characteristic) async {
    try {
      // Activer les notifications
      await characteristic.setNotifyValue(true);
      
      // Écouter les notifications
      _characteristicSubscription = characteristic.lastValueStream.listen((value) {
        if (value.isNotEmpty) {
          String uid = String.fromCharCodes(value).trim();
          debugPrint("📨 UID reçu via BLE: $uid");
          
          if (_scanAuthorized && mounted) {
            _onTagDetected(uid);
          } else {
            debugPrint("🚫 Scan non autorisé - UID ignoré");
            _showSnackBar("⚠️ Scan non autorisé", Colors.orange);
          }
        }
      });

      debugPrint("✅ Abonné aux notifications RFID");
      
    } catch (e) {
      debugPrint("❌ Erreur abonnement: $e");
      _showSnackBar("❌ Erreur abonnement", Colors.red);
    }
  }

  Future<void> _disconnect() async {
    if (_connectedDevice != null) {
      await _characteristicSubscription?.cancel();
      await _connectedDevice!.disconnect();
      
      setState(() {
        _isConnected = false;
        _connectedDevice = null;
        _scanAuthorized = false;
        _animalInfo = null;
        _lastScannedUID = null;
      });

      _showSnackBar("🔴 Déconnecté", Colors.grey);
    }
  }

  // ----------------------------------------------------------
  // 🔑 GESTION DE L'AUTORISATION DE SCAN
  // ----------------------------------------------------------
  void _toggleScanAuthorization() {
    if (!_isConnected) {
      _showSnackBar("⚠️ Connectez-vous d'abord à l'ESP32", Colors.orange);
      return;
    }

    setState(() {
      _scanAuthorized = !_scanAuthorized;
      
      if (!_scanAuthorized) {
        _animalInfo = null;
        _lastScannedUID = null;
        _sourceTable = null;
      }
    });

    _showSnackBar(
      _scanAuthorized 
          ? "✅ Scan autorisé - Approchez un tag RFID" 
          : "🔒 Scan désactivé",
      _scanAuthorized ? Colors.green : Colors.grey,
    );

    debugPrint("🔑 Scan autorisé: $_scanAuthorized");
  }

  // ----------------------------------------------------------
  // 🔍 DÉTECTION DU TAG ET RECHERCHE DE L'ANIMAL
  // ----------------------------------------------------------
  Future<void> _onTagDetected(String uid) async {
    if (!mounted) return;

    debugPrint("════════════════════════════════════");
    debugPrint("🏷️  TAG DÉTECTÉ : $uid");
    debugPrint("🔍 Début de la recherche...");
    debugPrint("════════════════════════════════════");

    setState(() {
      _isSearching = true;
      _lastScannedUID = uid;
      _animalInfo = null;
      _sourceTable = null;
    });

    _showSnackBar("🔍 Recherche de l'animal...", Colors.blue);

    try {
      // 🔍 Rechercher dans la table nouveaux_nee
      debugPrint("🔍 Recherche dans nouveaux_nee avec UID: $uid");
      
      var result = await Supabase.instance.client
          .from('nouveaux_nee')
          .select('*')
          .eq('tag_rfid', uid)
          .maybeSingle();

      if (result != null) {
        debugPrint("✅ Animal trouvé dans nouveaux_nee");
        if (mounted) {
          setState(() {
            _animalInfo = result;
            _sourceTable = 'nouveaux_nee';
            _isSearching = false;
            _scanAuthorized = false;
          });
          _showSnackBar("✅ Animal trouvé : ${result['nom']}", Colors.green);
        }
        return;
      }

      // 🔍 Rechercher dans la table animal_acheter
      debugPrint("🔍 Recherche dans animal_acheter avec UID: $uid");
      
      result = await Supabase.instance.client
          .from('animal_acheter')
          .select('*')
          .eq('tag_rfid', uid)
          .maybeSingle();

      if (result != null) {
        debugPrint("✅ Animal trouvé dans animal_acheter");
        if (mounted) {
          setState(() {
            _animalInfo = result;
            _sourceTable = 'animal_acheter';
            _isSearching = false;
            _scanAuthorized = false;
          });
          _showSnackBar("✅ Animal trouvé : ${result['nom']}", Colors.green);
        }
        return;
      }

      // ❌ Animal non trouvé
      debugPrint("❌ Aucun animal trouvé avec UID: $uid");
      
      if (mounted) {
        setState(() {
          _isSearching = false;
          _animalInfo = null;
          _sourceTable = null;
          _scanAuthorized = false;
        });
        _showSnackBar("❌ Aucun animal avec ce tag: $uid", Colors.red);
      }

    } catch (e, stackTrace) {
      debugPrint("❌ Erreur recherche: $e");
      debugPrint("Stack trace: $stackTrace");
      
      if (mounted) {
        setState(() {
          _isSearching = false;
          _scanAuthorized = false;
        });
        _showSnackBar("❌ Erreur: ${e.toString()}", Colors.red);
      }
    }
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

  // ----------------------------------------------------------
  // 🎨 UI
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Info Animal - BLE RFID"),
        backgroundColor: Colors.blue[700],
        actions: [
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          IconButton(
            icon: Icon(
              _isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
              color: _isConnected ? Colors.white : Colors.orange,
            ),
            tooltip: _isConnected 
                ? "Connecté - Appuyez pour déconnecter" 
                : "Déconnecté - Appuyez pour scanner",
            onPressed: _isConnected ? _disconnect : _scanAndConnect,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Section de statut BLE
            _buildBLEStatusSection(),
            const SizedBox(height: 16),

            // Bouton d'autorisation de scan
            if (_isConnected) ...[
              _buildScanButton(),
              const SizedBox(height: 24),
            ],

            // Affichage des résultats
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

  Widget _buildBLEStatusSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isConnected
              ? (_scanAuthorized 
                  ? [Colors.green[700]!, Colors.green[500]!]
                  : [Colors.blue[700]!, Colors.blue[500]!])
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
          Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                _isConnected 
                    ? (_scanAuthorized ? Icons.nfc : Icons.bluetooth_connected)
                    : Icons.bluetooth,
                size: 80,
                color: Colors.white,
              ),
              if (_isScanning)
                const SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _isConnected
                ? (_scanAuthorized ? "SCAN AUTORISÉ" : "Connecté à $DEVICE_NAME")
                : (_isScanning ? "Recherche..." : "Non connecté"),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isConnected
                ? (_scanAuthorized 
                    ? "Approchez un tag RFID du lecteur"
                    : "Appuyez sur le bouton pour autoriser le scan")
                : (_isScanning 
                    ? "Recherche de l'ESP32 en cours..."
                    : "Appuyez sur l'icône Bluetooth pour vous connecter"),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildScanButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: _isConnected ? _toggleScanAuthorization : null,
        icon: Icon(
          _scanAuthorized ? Icons.stop : Icons.play_arrow,
          size: 28,
        ),
        label: Text(
          _scanAuthorized ? "ARRÊTER LE SCAN" : "AUTORISER LE SCAN",
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _scanAuthorized ? Colors.red[600] : Colors.green[600],
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[400],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
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
          const Text(
            "Recherche en cours...",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Tag RFID : $_lastScannedUID",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontFamily: 'monospace',
            ),
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
          Text(
            _isConnected ? "En attente de scan" : "Non connecté",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isConnected
                ? "Autorisez le scan puis approchez un tag RFID pour afficher les informations de l'animal"
                : "Connectez-vous d'abord à l'ESP32 via Bluetooth",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
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
          const Text(
            "Animal non trouvé",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.nfc, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  _lastScannedUID ?? 'N/A',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Ce tag RFID n'est associé à aucun animal enregistré",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
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
          // En-tête avec badge de catégorie
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _sourceTable == 'nouveaux_nee' 
                  ? Colors.green[700] 
                  : Colors.blue[700],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _sourceTable == 'nouveaux_nee' 
                      ? Icons.child_care 
                      : Icons.shopping_cart,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _animalInfo!['nom'] ?? 'Sans nom',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _sourceTable == 'nouveaux_nee' 
                            ? 'Nouveau-né' 
                            : 'Animal acheté',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Image
          if (_animalInfo!['image_url'] != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(0),
              ),
              child: Image.network(
                _animalInfo!['image_url'],
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 250,
                    color: Colors.grey[300],
                    child: const Icon(Icons.error, size: 60, color: Colors.red),
                  );
                },
              ),
            ),

          // Informations détaillées
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildInfoRow(Icons.agriculture, "Race", _animalInfo!['race'] ?? 'N/A'),
                const Divider(height: 24),
                _buildInfoRow(Icons.wc, "Sexe", _animalInfo!['sexe'] ?? 'N/A'),
                const Divider(height: 24),
                _buildInfoRow(Icons.nfc, "Tag RFID", _animalInfo!['tag_rfid'] ?? 'N/A'),
                
                if (_animalInfo!['date_naissance'] != null) ...[
                  const Divider(height: 24),
                  _buildInfoRow(Icons.calendar_today, "Date naissance", _animalInfo!['date_naissance']),
                ],
                
                if (_animalInfo!['provenance'] != null) ...[
                  const Divider(height: 24),
                  _buildInfoRow(Icons.location_on, "Provenance", _animalInfo!['provenance']),
                ],

                if (_animalInfo!['created_at'] != null) ...[
                  const Divider(height: 24),
                  _buildInfoRow(
                    Icons.access_time, 
                    "Enregistré le", 
                    _formatDate(_animalInfo!['created_at']),
                  ),
                ],
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
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 24, color: Colors.blue[700]),
        ),
        const SizedBox(width: 12),
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
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
    } catch (e) {
      return isoDate;
    }
  }
}