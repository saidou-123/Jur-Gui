import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'FicheSanteDetailAnimal.dart';
import 'NouvelleConsultationPage.dart';

// ============================================================
// SCAN RFID VÉTÉRINAIRE BLE — version synchronisée
// ============================================================
class ScanRFIDVeterinaireBluetooth extends StatefulWidget {
  const ScanRFIDVeterinaireBluetooth({super.key});

  @override
  State<ScanRFIDVeterinaireBluetooth> createState() =>
      _ScanRFIDVeterinaireBluetoothState();
}

class _ScanRFIDVeterinaireBluetoothState
    extends State<ScanRFIDVeterinaireBluetooth> {
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _rfidCharacteristic;
  bool _isScanning = false;
  bool _isConnected = false;

  static const String SERVICE_UUID =
      '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const String CHARACTERISTIC_UUID =
      'beb5483e-36e1-4688-b7f5-ea07361b26a8';
  static const String ESP32_NAME = 'Jur-Gui';

  bool _isSearching = false;
  String? _lastScannedUID;
  Map<String, dynamic>? _animalInfo;
  String? _sourceTable;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermissionsAndConnect();
    });
  }

  @override
  void dispose() {
    _disconnectBLE();
    super.dispose();
  }

  // =====================================================
  // PERMISSIONS
  // =====================================================
  Future<void> _requestPermissionsAndConnect() async {
    if (!mounted) return;

    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (statuses.values.any((s) => !s.isGranted)) {
      _showSnackBar('❌ Permissions Bluetooth refusées', Colors.red);
      return;
    }

    if (!await FlutterBluePlus.isOn) {
      _showSnackBar('⚠️ Veuillez activer le Bluetooth', Colors.orange);
      return;
    }

    await _connectToESP32();
  }

  // =====================================================
  // CONNEXION ESP32
  // =====================================================
  Future<void> _connectToESP32() async {
    if (!mounted) return;
    setState(() => _isScanning = true);
    _showSnackBar('🔍 Recherche de $ESP32_NAME...', Colors.blue);

    try {
      await FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 4));

      FlutterBluePlus.scanResults.listen((results) async {
        for (final result in results) {
          if (result.device.name == ESP32_NAME) {
            await FlutterBluePlus.stopScan();
            await _connectToDevice(result.device);
            break;
          }
        }
      });

      await Future.delayed(const Duration(seconds: 5));

      if (!_isConnected && mounted) {
        setState(() => _isScanning = false);
        _showSnackBar('❌ ESP32 non trouvé', Colors.red);
      }
    } catch (e) {
      debugPrint('❌ Erreur scan BLE: $e');
      if (mounted) {
        setState(() => _isScanning = false);
        _showSnackBar('Erreur: $e', Colors.red);
      }
    }
  }

  // =====================================================
  // CONNEXION DEVICE
  // =====================================================
  Future<void> _connectToDevice(BluetoothDevice device) async {
    if (!mounted) return;

    try {
      await device.connect(timeout: const Duration(seconds: 10));
      _connectedDevice = device;

      // ✅ Écoute de la déconnexion inattendue
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected && mounted) {
          setState(() {
            _isConnected = false;
            _rfidCharacteristic = null;
          });
          _showSnackBar(
              '⚠️ ESP32 déconnecté. Appuyez pour reconnecter.',
              Colors.orange);
        }
      });

      final services = await device.discoverServices();

      for (final service in services) {
        if (service.uuid.toString().toLowerCase() ==
            SERVICE_UUID.toLowerCase()) {
          for (final characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() ==
                CHARACTERISTIC_UUID.toLowerCase()) {
              _rfidCharacteristic = characteristic;
              await characteristic.setNotifyValue(true);
              characteristic.value.listen((value) {
                if (value.isNotEmpty) {
                  final uid = String.fromCharCodes(value);
                  _onTagDetected(uid);
                }
              });
              break;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _isConnected = true;
          _isScanning = false;
        });
        _showSnackBar('✅ Connecté à $ESP32_NAME', Colors.green);
      }
    } catch (e) {
      debugPrint('❌ Erreur connexion: $e');
      if (mounted) {
        setState(() {
          _isConnected = false;
          _isScanning = false;
        });
        _showSnackBar('Erreur connexion: $e', Colors.red);
      }
    }
  }

  // =====================================================
  // DÉCONNEXION BLE
  // =====================================================
  Future<void> _disconnectBLE() async {
    try {
      if (_rfidCharacteristic != null) {
        await _rfidCharacteristic!.setNotifyValue(false);
      }
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isConnected = false;
        _connectedDevice = null;
        _rfidCharacteristic = null;
      });
    }
  }

  // =====================================================
  // DÉTECTION TAG RFID
  // =====================================================
  Future<void> _onTagDetected(String uid) async {
    if (!mounted) return;

    final cleanUid = uid.trim().toUpperCase();

    setState(() {
      _isSearching = true;
      _lastScannedUID = cleanUid;
      _animalInfo = null;
      _sourceTable = null;
    });

    _showSnackBar('🔍 Recherche en cours...', Colors.blue);

    try {
      // Chercher dans nouveaux_nee
      var result = await Supabase.instance.client
          .from('nouveaux_nee')
          .select('*')
          .ilike('tag_rfid', cleanUid)
          .maybeSingle();

      if (result != null && mounted) {
        setState(() {
          _animalInfo = result;
          _sourceTable = 'nee';
          _isSearching = false;
        });
        _showSnackBar('✅ Animal trouvé !', Colors.green);
        return;
      }

      // Chercher dans animal_acheter
      result = await Supabase.instance.client
          .from('animal_acheter')
          .select('*')
          .ilike('tag_rfid', cleanUid)
          .maybeSingle();

      if (result != null && mounted) {
        setState(() {
          _animalInfo = result;
          _sourceTable = 'achete';
          _isSearching = false;
        });
        _showSnackBar('✅ Animal trouvé !', Colors.green);
        return;
      }

      if (mounted) {
        setState(() {
          _isSearching = false;
          _animalInfo = null;
          _sourceTable = null;
        });
        _showSnackBar('❌ Aucun animal avec ce tag RFID', Colors.red);
      }
    } catch (e) {
      debugPrint('❌ Erreur recherche: $e');
      if (mounted) {
        setState(() => _isSearching = false);
        _showSnackBar('Erreur: ${e.toString()}', Colors.red);
      }
    }
  }

  // =====================================================
  // RECONNEXION
  // =====================================================
  Future<void> _reconnectBLE() async {
    if (!mounted) return;
    _showSnackBar('🔄 Reconnexion en cours...', Colors.orange);
    setState(() => _isScanning = true);
    await _disconnectBLE();
    await Future.delayed(const Duration(milliseconds: 500));
    await _connectToESP32();
  }

  // =====================================================
  // TEST MANUEL
  // =====================================================
  Future<void> _testManuelRecherche() async {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Test Manuel'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Entrez un tag RFID',
            hintText: 'Ex: D3F1CD2C',
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (controller.text.isNotEmpty) {
                _onTagDetected(controller.text);
              }
            },
            child: const Text('Rechercher'),
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
  // BUILD
  // =====================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan RFID — Vétérinaire'),
        backgroundColor: Colors.blue[700],
        actions: [
          IconButton(
            icon: Icon(
              _isConnected
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth_disabled,
              color: _isConnected ? Colors.white : Colors.orange,
            ),
            onPressed: _reconnectBLE,
            tooltip:
                _isConnected ? 'Connecté — tap pour reconnecter' : 'Reconnecter',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
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

  Widget _buildScanSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[700],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            _isConnected
                ? Icons.bluetooth_connected
                : Icons.bluetooth_searching,
            size: 80,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          Text(
            _isConnected
                ? 'Prêt à scanner'
                : _isScanning
                    ? 'Recherche ESP32...'
                    : 'Non connecté',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _isConnected
                ? 'Approchez un tag RFID du lecteur'
                : 'Vérifiez que l\'ESP32 est allumé',
            style:
                const TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (!_isConnected)
            ElevatedButton.icon(
              onPressed:
                  _isScanning ? null : _reconnectBLE,
              icon: _isScanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white))
                  : const Icon(Icons.bluetooth_searching),
              label: Text(_isScanning ? 'Recherche...' : 'Connecter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue[700],
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _testManuelRecherche,
            icon: const Icon(Icons.edit, color: Colors.white),
            label: const Text('Test manuel',
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
          const Text('Recherche en cours...',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Tag RFID : $_lastScannedUID',
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
          Text('En attente de scan',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700])),
          const SizedBox(height: 8),
          Text(
            'Scannez un tag RFID ou utilisez le test manuel',
            style:
                TextStyle(fontSize: 14, color: Colors.grey[600]),
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
          const Text('Animal non trouvé',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red)),
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
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _testManuelRecherche,
            icon: const Icon(Icons.search),
            label: const Text('Réessayer manuellement'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimalInfoCard() {
    if (_animalInfo == null) return const SizedBox.shrink();

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[700],
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                const Icon(Icons.check_circle,
                    color: Colors.white, size: 50),
                const SizedBox(height: 8),
                Text(
                  _animalInfo!['nom'] ?? 'Sans nom',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  _sourceTable == 'nee'
                      ? '🐑 Nouveau-né'
                      : '🛒 Animal acheté',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          if (_animalInfo!['image_url'] != null)
            Image.network(
              _animalInfo!['image_url'],
              width: double.infinity,
              height: 220,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const SizedBox(height: 0),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildInfoRow(Icons.agriculture, 'Race',
                    _animalInfo!['race'] ?? 'N/A'),
                const Divider(height: 24),
                _buildInfoRow(
                    Icons.wc, 'Sexe', _animalInfo!['sexe'] ?? 'N/A'),
                const Divider(height: 24),
                _buildInfoRow(Icons.nfc, 'Tag RFID',
                    _animalInfo!['tag_rfid'] ?? 'N/A'),
                if (_animalInfo!['date_naissance'] != null) ...[
                  const Divider(height: 24),
                  _buildInfoRow(Icons.calendar_today,
                      'Date naissance', _animalInfo!['date_naissance']),
                ],
                if (_animalInfo!['provenance'] != null) ...[
                  const Divider(height: 24),
                  _buildInfoRow(Icons.location_on, 'Provenance',
                      _animalInfo!['provenance']),
                ],
              ],
            ),
          ),
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
                    label: const Text('Voir la fiche de santé'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
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
                          builder: (context) =>
                              NouvelleConsultationPage(
                            animal: _animalInfo!,
                            source: _sourceTable!,
                          ),
                        ),
                      ).then((ok) {
                        if (ok == true) {
                          _showSnackBar(
                              '✅ Consultation enregistrée',
                              Colors.green);
                        }
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Nouvelle Consultation'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue[700],
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
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