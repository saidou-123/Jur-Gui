// ============================================================
// INFO ANIMAL - VERSION BLE CORRIGÉE
// Fichier: lib/pages/AnimalInfoRFIDPageBluetooth.dart
// Communication Bluetooth BLE avec ESP32 + RFID
// ============================================================

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:convert';

class AnimalInfoRFIDPageBluetooth extends StatefulWidget {
  const AnimalInfoRFIDPageBluetooth({super.key});

  @override
  State<AnimalInfoRFIDPageBluetooth> createState() => _AnimalInfoRFIDPageBluetoothState();
}

class _AnimalInfoRFIDPageBluetoothState extends State<AnimalInfoRFIDPageBluetooth> {
  // ===== BLUETOOTH BLE =====
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _rfidCharacteristic;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _deviceStateSubscription;  
  StreamSubscription? _characteristicSubscription;
  bool _isScanning = false;
  bool _isConnected = false;
  
  // UUID personnalisés (MÊME UUID que NouveauNeeBluetooth et AnimalAchateBluetooth)
  static const String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  
  // ===== ÉTAT UI =====
  bool _isSearching = false;
  bool _scanAuthorized = false;
  String? _lastScannedUID;
  Map<String, dynamic>? _animalInfo;
  String? _sourceTable;
  
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
    _disconnectBLE();
    super.dispose();
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
      debugPrint("❌ Erreur Init Bluetoothss: $e");
      debugPrint("Stack trace: $stackTrace");
      if (mounted) {
        _showSnackBar("❌ Erreur Bluetooth: $e", Colors.red);
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
            
            // Chercher notre ESP32
            if (deviceName.contains("ESP32") || 
                deviceName.contains("RFID") ||
                deviceName.contains("BLE_RFID") ||
                deviceName.contains("Jur-Gui")) {
              
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
      _showSnackBar("🔗 Connexion au lecteur.......", Colors.blue);

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
      debugPrint("🔑 État scan autorisé: $_scanAuthorized");
      debugPrint("═══════════════════════════════");

      // Vérifier si le scan est autorisé
      if (!_scanAuthorized) {
        debugPrint("🚫 Scan non autorisé - ignoré");
        debugPrint("❗ ACTION REQUISE: L'utilisateur doit appuyer sur 'AUTORISER LE SCAN'");
        if (mounted) {
          _showSnackBar("⚠️ Veuillez d'abord autoriser le scan", Colors.orange);
        }
        return;
      }

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
      _scanAuthorized = false; // Désactiver le scan en cas de déconnexion
    });
    
    // Reconnexion automatique
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

  // =====================================================
  // GESTION DE L'AUTORISATION DE SCAN
  // =====================================================
  void _toggleScanAuthorization() {
    if (!_isConnected) {
      _showSnackBar("⚠️ Connexion RFID non disponible", Colors.orange);
      return;
    }

    setState(() {
      _scanAuthorized = !_scanAuthorized;
      
      // Réinitialiser les résultats quand on désactive
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

  // =====================================================
  // DÉTECTION TAG ET RECHERCHE DE L'ANIMAL
  // =====================================================
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
      
      final nouveauxNeeQuery = Supabase.instance.client
          .from('nouveaux_nee')
          .select('*')
          .eq('tag_rfid', uid);
      
      debugPrint("📝 Requête nouveaux_nee construite");
      
      var result = await nouveauxNeeQuery.maybeSingle();
      
      debugPrint("📊 Résultat nouveaux_nee: ${result != null ? 'TROUVÉ' : 'NON TROUVÉ'}");
      if (result != null) {
        debugPrint("✅ Données trouvées: $result");
      }

      if (result != null) {
        debugPrint("✅ Animal trouvé dans nouveaux_nee - Mise à jour UI");
        if (mounted) {
          setState(() {
            _animalInfo = result;
            _sourceTable = 'nouveaux_nee';
            _isSearching = false;
            _scanAuthorized = false; // Désactiver le scan après résultat
          });
          debugPrint("✅ État mis à jour - Animal: ${result['nom']}");
          _showSnackBar("✅ Animal trouvé : ${result['nom']}", Colors.green);
        }
        return;
      }

      // 🔍 Rechercher dans la table animal_acheter
      debugPrint("🔍 Recherche dans animal_acheter avec UID: $uid");
      
      final animalAcheterQuery = Supabase.instance.client
          .from('animal_acheter')
          .select('*')
          .eq('tag_rfid', uid);
      
      debugPrint("📝 Requête animal_acheter construite");
      
      result = await animalAcheterQuery.maybeSingle();
      
      debugPrint("📊 Résultat animal_acheter: ${result != null ? 'TROUVÉ' : 'NON TROUVÉ'}");
      if (result != null) {
        debugPrint("✅ Données trouvées: $result");
      }

      if (result != null) {
        debugPrint("✅ Animal trouvé dans animal_acheter - Mise à jour UI");
        if (mounted) {
          setState(() {
            _animalInfo = result;
            _sourceTable = 'animal_acheter';
            _isSearching = false;
            _scanAuthorized = false; // Désactiver le scan après résultat
          });
          debugPrint("✅ État mis à jour - Animal: ${result['nom']}");
          _showSnackBar("✅ Animal trouvé : ${result['nom']}", Colors.green);
        }
        return;
      }

      // ❌ Animal non trouvé dans aucune table
      debugPrint("❌❌❌ AUCUN ANIMAL TROUVÉ AVEC UID: $uid ❌❌❌");
      debugPrint("💡 Vérifiez que le tag_rfid dans la base correspond exactement");
      debugPrint("💡 Format du UID reçu: '$uid' (longueur: ${uid.length})");
      
      if (mounted) {
        setState(() {
          _isSearching = false;
          _animalInfo = null;
          _sourceTable = null;
          _scanAuthorized = false; // Désactiver le scan après résultat négatif
        });
        _showSnackBar("❌ Aucun animal avec ce tag: $uid", Colors.red);
      }
    } catch (e, stackTrace) {
      debugPrint("❌❌❌ ERREUR LORS DE LA RECHERCHE ❌❌❌");
      debugPrint("Erreur: $e");
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

  // =====================================================
  // UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Jur Gui 4.0 - Info Animal"),
        backgroundColor: Colors.blue[700],
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Indicateur de connexion BLE
            _buildBLEStatusCard(),
            const SizedBox(height: 16),

            // Section de scan
            _buildScanSection(),
            const SizedBox(height: 16),

            // Bouton d'autorisation de scan
            _buildScanButton(),
            const SizedBox(height: 24),

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

  Widget _buildScanSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _scanAuthorized 
              ? [Colors.green[700]!, Colors.green[500]!]
              : (_isConnected 
                  ? [Colors.blue[700]!, Colors.blue[500]!]
                  : [Colors.grey[700]!, Colors.grey[500]!]),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (_scanAuthorized ? Colors.green : (_isConnected ? Colors.blue : Colors.grey))
                .withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            _scanAuthorized 
                ? Icons.nfc 
                : (_isConnected ? Icons.nfc_outlined : Icons.bluetooth_disabled),
            size: 80,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          Text(
            _scanAuthorized 
                ? "SCAN AUTORISÉ" 
                : (_isConnected 
                    ? "Scan désactivé" 
                    : "Déconnecté"),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _scanAuthorized
                ? "Approchez un tag RFID du lecteur"
                : (_isConnected 
                    ? "Appuyez sur le bouton ci-dessous pour autoriser"
                    : "Appuyez sur l'icône Bluetooth pour reconnecter"),
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
        onPressed: _isConnected 
            ? _toggleScanAuthorization 
            : null,
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
            "En attente de scan",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Autorisez le scan puis approchez un tag RFID pour afficher les informations de l'animal",
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