// ============================================================
// NOUVEAU-NÉ - VERSION BLE CORRIGÉE (v2)
// Fichier: lib/Eleveures/Ajouter Animal/NouveauNeeBluetooth.dart
// Communication BLE avec ESP32 + RFID
//
// CORRECTIONS APPLIQUÉES :
//  [C1] dispose() : ordre correct — BLE async d'abord, controllers ensuite
//  [C2] _startBLEScan() : annulation de l'abonnement existant avant tout nouveau scan
//  [C3] UUID : comparaison complète insensible à la casse (plus de .contains partiel)
//  [C4] discoverServices() : timeout 10 s pour éviter les blocages Android
//  [C5] Suppression du flag firstEvent fragile → filtre sur l'état disconnected
//  [C6] _raceController supprimé (inutilisé)
//  [C7] Rechargement des parents après enregistrement réussi
//  [C8] Calcul d'âge en mois robuste (basé sur DateTime, pas modulo)
//  [C9] _handleDisconnection() : remise à null des subscriptions
//  [C10] Permissions demandées une seule fois, mises en cache
//  [C11] Validators.rfid() appelé avant le null-check (_tagRFID != null garanti)
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

// ---------------------------------------------------------------------------
// Modèle léger pour les animaux parents
// ---------------------------------------------------------------------------
class _AnimalParent {
  final String  id;
  final String  nom;
  final String  race;
  final String  tagRfid;
  final String? imageUrl;
  final String  sexe;
  final String  source;

  const _AnimalParent({
    required this.id,
    required this.nom,
    required this.race,
    required this.tagRfid,
    this.imageUrl,
    required this.sexe,
    required this.source,
  });

  factory _AnimalParent.fromMap(Map<String, dynamic> map, String source) {
    return _AnimalParent(
      id      : map['id']?.toString()       ?? '',
      nom     : map['nom']?.toString()      ?? '',
      race    : map['race']?.toString()     ?? '',
      tagRfid : map['tag_rfid']?.toString() ?? '',
      imageUrl: map['image_url']?.toString(),
      sexe    : map['sexe']?.toString()     ?? '',
      source  : source,
    );
  }

  bool matches(String query) {
    final q = query.toLowerCase();
    return nom.toLowerCase().contains(q) ||
        race.toLowerCase().contains(q)   ||
        tagRfid.toLowerCase().contains(q);
  }
}

// ---------------------------------------------------------------------------
// [C8] Calcul d'âge en mois robuste
//      Évite les erreurs en fin de mois (ex. 31 jan → 28 fév = 0 mois avec
//      le modulo naïf).
// ---------------------------------------------------------------------------
int _ageEnMois(DateTime naissance, DateTime reference) {
  int mois = (reference.year - naissance.year) * 12
           + (reference.month - naissance.month);
  if (reference.day < naissance.day) mois--;
  return mois < 0 ? 0 : mois;
}

class NouveauNeeBluetooth extends StatefulWidget {
  const NouveauNeeBluetooth({super.key});

  @override
  State<NouveauNeeBluetooth> createState() => _NouveauNeeBluetoothState();
}

class _NouveauNeeBluetoothState extends State<NouveauNeeBluetooth> {
  // ===== CONTROLLERS =====
  final _nomController  = TextEditingController();
  final _dateController = TextEditingController();
  final _uidController  = TextEditingController();

  // ===== ÉTAT UI =====
  String? _selectedSexe;
  String? _selectedRace;
  XFile?  _pickedFile;
  bool    _isLoading = false;
  String? _tagRFID;

  // ===== PARENTS =====
  List<_AnimalParent> _animauxDisponibles = [];
  _AnimalParent?      _pereSelectionne;
  _AnimalParent?      _mereSelectionnee;
  bool                _loadingParents = false;

  // ===== BLUETOOTH BLE =====
  BluetoothDevice?         _connectedDevice;
  BluetoothCharacteristic? _rfidCharacteristic;
  StreamSubscription?      _scanSubscription;
  StreamSubscription?      _deviceStateSubscription;
  StreamSubscription?      _characteristicSubscription;
  bool _isScanning  = false;
  bool _isConnected = false;

  // [C10] Cache permissions BLE
  bool _permissionsGranted = false;

  // [C3] UUIDs complets pour comparaison exacte
  static const String _serviceUuid        = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String _characteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  String?   _lastReceivedUID;
  DateTime? _lastScanTime;
  static const Duration _antiSpamDelay = Duration(seconds: 2);

  // Couleurs des champs principaux
  static const Color _couleurNom  = Color(0xFF2E7D32);
  static const Color _couleurSexe = Color(0xFF6A1B9A);
  static const Color _couleurRace = Color(0xFF00838F);
  static const Color _couleurDate = Color(0xFFE65100);

  // ====================================================================
  // CYCLE DE VIE
  // ====================================================================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeBluetooth();
      _loadAnimauxDisponibles();
    });
  }

  @override
  void dispose() {
    _disconnectBLE();
    _nomController.dispose();
    _dateController.dispose();
    _uidController.dispose();
    super.dispose();
  }

  // ====================================================================
  // CHARGEMENT DES PARENTS
  // ====================================================================

  Future<void> _loadAnimauxDisponibles() async {
    if (!mounted) return;
    setState(() => _loadingParents = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final results = await Future.wait([
        Supabase.instance.client
            .from('animal_acheter')
            .select('id, nom, race, tag_rfid, image_url, sexe')
            .eq('user_id', userId)
            .order('nom'),
        Supabase.instance.client
            .from('nouveaux_nee')
            .select('id, nom, race, tag_rfid, image_url, sexe, date_naissance')
            .eq('user_id', userId)
            .order('nom'),
        Supabase.instance.client
            .from('accouplements')
            .select('brebis_id, source_brebis')
            .eq('user_id', userId)
            .isFilter('date_mise_bas', null),
      ]);

      final Set<String> brebisNeeEnAccouplement    = {};
      final Set<String> brebisAcheteEnAccouplement = {};
      for (final acc in results[2] as List<dynamic>) {
        final map    = acc as Map<String, dynamic>;
        final source = map['source_brebis']?.toString() ?? '';
        final id     = map['brebis_id']?.toString() ?? '';
        if (id.isEmpty) continue;
        if (source == 'nee')    brebisNeeEnAccouplement.add(id);
        if (source == 'achete') brebisAcheteEnAccouplement.add(id);
      }

      final List<_AnimalParent> tous = [];

      for (final animal in results[0] as List<dynamic>) {
        final map  = animal as Map<String, dynamic>;
        final id   = map['id']?.toString() ?? '';
        final sexe = map['sexe']?.toString().toLowerCase() ?? '';
        if (sexe == 'femelle' && brebisAcheteEnAccouplement.contains(id)) continue;
        tous.add(_AnimalParent.fromMap(map, 'achete'));
      }

      final aujourd = DateTime.now();
      for (final animal in results[1] as List<dynamic>) {
        final map          = animal as Map<String, dynamic>;
        final id           = map['id']?.toString() ?? '';
        final sexe         = map['sexe']?.toString().toLowerCase() ?? '';
        final dateNaissStr = map['date_naissance']?.toString();

        if (dateNaissStr == null) continue;
        final dateNaiss = DateTime.tryParse(dateNaissStr);
        if (dateNaiss == null) continue;

        final ageMois    = _ageEnMois(dateNaiss, aujourd);
        final estFemelle = sexe == 'femelle';
        final estMale    = sexe == 'mâle' || sexe == 'male';

        if (estFemelle) {
          if (ageMois < 15) continue;
          if (brebisNeeEnAccouplement.contains(id)) continue;
          tous.add(_AnimalParent.fromMap(map, 'nee'));
        } else if (estMale) {
          if (ageMois < 18) continue;
          tous.add(_AnimalParent.fromMap(map, 'nee'));
        }
      }

      tous.sort((a, b) => a.nom.compareTo(b.nom));
      if (mounted) setState(() => _animauxDisponibles = tous);
    } catch (e, st) {
      ErrorHandler.log(e, st, context: 'Chargement animaux parents');
      if (mounted) _showSnackBar("⚠️ Impossible de charger les parents", Colors.orange);
    } finally {
      if (mounted) setState(() => _loadingParents = false);
    }
  }

  // ====================================================================
  // BLUETOOTH BLE
  // ====================================================================

  Future<bool> _ensurePermissions() async {
    if (_permissionsGranted) return true;

    final permissions = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    final allGranted = permissions.values.every((s) => s.isGranted);
    if (allGranted) _permissionsGranted = true;
    return allGranted;
  }

  Future<void> _initializeBluetooth() async {
    if (!mounted) return;
    try {
      final granted = await _ensurePermissions();
      if (!granted) {
        if (mounted) _showSnackBar("❌ Permissions BLE refusées", Colors.red);
        return;
      }

      if (await FlutterBluePlus.isSupported == false) {
        if (mounted) _showSnackBar("❌ Bluetooth non supporté", Colors.red);
        return;
      }

      final state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        if (mounted) _showSnackBar("⚠️ Activez le Bluetooth", Colors.orange);
        return;
      }

      _startBLEScan();
    } catch (e, st) {
      ErrorHandler.log(e, st, context: 'Init Bluetooth');
      if (mounted) ErrorHandler.show(context, e, customMessage: 'Erreur Bluetooth');
    }
  }

  Future<void> _startBLEScan() async {
    if (_isConnected) return;

    await _stopBLEScan();

    if (mounted) setState(() => _isScanning = true);
    _showSnackBar("🔍 Recherche du lecteur RFID...", Colors.blue);

    try {
      final bonded = await FlutterBluePlus.bondedDevices;
      for (final d in bonded) {
        if (_isEsp32Device(d.platformName)) {
          if (mounted) setState(() => _isScanning = false);
          _connectToDevice(d);
          return;
        }
      }

      _scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
        for (final r in results) {
          if (_isEsp32Device(r.device.platformName)) {
            _stopBLEScan().then((_) => _connectToDevice(r.device));
            return;
          }
        }
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 30),
        androidUsesFineLocation: false,
      );

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

  bool _isEsp32Device(String name) =>
      name.contains("Jur-Gui") ||
      name.contains("JUR-GUI") ||
      name.contains("ESP32")   ||
      name.contains("RFID");

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await _stopBLEScan();
      _showSnackBar("🔗 Connexion au lecteur...", Colors.blue);
      await device.connect(
        timeout    : const Duration(seconds: 15),
        autoConnect: false,
      );

      if (mounted) setState(() { _connectedDevice = device; _isConnected = true; });
      _showSnackBar("✅ Lecteur RFID connecté", Colors.green);

      _deviceStateSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected && mounted) {
          _handleDisconnection();
        }
      });

      await _discoverServices(device);
    } catch (e) {
      debugPrint("❌ Erreur connexion: $e");
      if (mounted) {
        _showSnackBar("❌ Échec de connexion", Colors.red);
        setState(() { _connectedDevice = null; _isConnected = false; });
        Future.delayed(const Duration(seconds: 2), _startBLEScan);
      }
    }
  }

  Future<void> _discoverServices(BluetoothDevice device) async {
    try {
      await Future.delayed(const Duration(milliseconds: 800));

      final List<BluetoothService> services = await device
          .discoverServices()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException(
              'discoverServices() timeout après 10 s',
            ),
          );

      BluetoothService? targetService;
      for (final s in services) {
        if (s.uuid.toString().toLowerCase() == _serviceUuid.toLowerCase()) {
          targetService = s;
          break;
        }
      }
      if (targetService == null) {
        if (mounted) _showSnackBar("❌ Service RFID non trouvé", Colors.red);
        return;
      }

      BluetoothCharacteristic? targetChar;
      for (final c in targetService.characteristics) {
        if (c.uuid.toString().toLowerCase() == _characteristicUuid.toLowerCase()) {
          targetChar = c;
          break;
        }
      }
      if (targetChar == null) {
        if (mounted) _showSnackBar("❌ Caractéristique RFID non trouvée", Colors.red);
        return;
      }

      _rfidCharacteristic = targetChar;
      await _subscribeToRFID(targetChar);
    } on TimeoutException catch (e) {
      debugPrint("❌ Timeout discoverServices: $e");
      if (mounted) _showSnackBar("❌ Timeout communication BLE", Colors.red);
    } catch (e) {
      debugPrint("❌ Erreur discoverServices: $e");
      if (mounted) _showSnackBar("❌ Erreur de communication", Colors.red);
    }
  }

  Future<void> _stopBLEScan() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await FlutterBluePlus.stopScan();
    if (mounted) setState(() => _isScanning = false);
  }

  Future<void> _subscribeToRFID(BluetoothCharacteristic characteristic) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      await characteristic.setNotifyValue(true);
      if (mounted) _showSnackBar("✅ Système RFID prêt", Colors.green);

      _characteristicSubscription = characteristic.onValueReceived.listen(
        (value) { if (value.isNotEmpty) _onRFIDDataReceived(value); },
        onError: (e) => debugPrint("❌ Erreur notification: $e"),
      );
    } catch (e) {
      debugPrint("❌ Erreur souscription: $e");
      if (mounted) _showSnackBar("❌ Échec d'activation RFID", Colors.red);
    }
  }

  void _onRFIDDataReceived(List<int> value) {
    try {
      final uid = utf8.decode(value).trim();
      final now = DateTime.now();
      if (_lastReceivedUID == uid &&
          _lastScanTime != null &&
          now.difference(_lastScanTime!) < _antiSpamDelay) return;
      _lastReceivedUID = uid;
      _lastScanTime    = now;
      if (mounted) _onTagDetected(uid);
    } catch (e) {
      debugPrint("❌ Erreur décodage UID: $e");
    }
  }

  Future<void> _onTagDetected(String uid) async {
    if (!mounted) return;

    final validation = Validators.rfid(uid);
    if (validation != null) {
      _showSnackBar("⚠️ Format RFID invalide: $validation", Colors.orange);
      return;
    }

    setState(() { _tagRFID = uid; _uidController.text = uid; });
    _showSnackBar("Tag RFID détecté : $uid", Colors.blue);

    try {
      final result = await Supabase.instance.client
          .from('nouveaux_nee')
          .select('id, nom, race, sexe, date_naissance, tag_rfid')
          .eq('tag_rfid', uid);
      if (result.isNotEmpty) {
        final existing = result.first;
        if (mounted) {
          _showSnackBar("⚠️ Tag déjà utilisé par: ${existing['nom']}", Colors.orange);
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) _showDuplicateDialog(existing);
          });
        }
      }
    } catch (e, st) {
      ErrorHandler.log(e, st, context: 'Vérification doublon RFID');
    }
  }

  Future<void> _disconnectBLE() async {
    try {
      await _characteristicSubscription?.cancel();
      await _deviceStateSubscription?.cancel();
      await _scanSubscription?.cancel();
      if (_connectedDevice != null) await _connectedDevice!.disconnect();
    } catch (e) {
      debugPrint("⚠️ Erreur déconnexion: $e");
    } finally {
      _characteristicSubscription = null;
      _deviceStateSubscription    = null;
      _scanSubscription           = null;
      _connectedDevice            = null;
      _rfidCharacteristic         = null;
      if (mounted) setState(() => _isConnected = false);
    }
  }

  void _handleDisconnection() {
    _characteristicSubscription?.cancel();
    _characteristicSubscription = null;
    _deviceStateSubscription?.cancel();
    _deviceStateSubscription = null;

    if (mounted) {
      _showSnackBar("🔴 Lecteur RFID déconnecté", Colors.red);
      setState(() {
        _isConnected        = false;
        _connectedDevice    = null;
        _rfidCharacteristic = null;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && !_isConnected) {
          _showSnackBar("🔄 Tentative de reconnexion...", Colors.blue);
          _startBLEScan();
        }
      });
    }
  }

  Future<void> _reconnectBLE() async {
    await _disconnectBLE();
    await Future.delayed(const Duration(milliseconds: 500));
    _initializeBluetooth();
  }

  // ====================================================================
  // DIALOGUE DOUBLON
  // ====================================================================

  Future<void> _showDuplicateDialog(Map<String, dynamic> existing) async {
    return showDialog(
      context           : context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon : const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 64),
        title: const Text(
          "⚠️ Tag RFID déjà utilisé",
          style    : TextStyle(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Ce tag est déjà attribué à:"),
            const SizedBox(height: 16),
            Container(
              padding   : const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color       : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border      : Border.all(color: Colors.orange.shade200, width: 2),
              ),
              child: Column(
                children: [
                  _buildInfoRow(Icons.pets,           "Nom",  existing['nom']            ?? 'N/A'),
                  _buildInfoRow(Icons.agriculture,    "Race", existing['race']           ?? 'N/A'),
                  _buildInfoRow(Icons.wc,             "Sexe", existing['sexe']           ?? 'N/A'),
                  _buildInfoRow(Icons.nfc,            "Tag",  existing['tag_rfid']       ?? 'N/A'),
                  _buildInfoRow(Icons.calendar_today, "Date", existing['date_naissance'] ?? 'N/A'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              setState(() { _tagRFID = null; _uidController.clear(); });
            },
            icon : const Icon(Icons.nfc),
            label: const Text("Scanner autre tag"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style    : ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child    : const Text("OK"),
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
              style   : const TextStyle(color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // IMAGE
  // ====================================================================

  Future<void> _showImageSourceDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title  : const Text("Choisir une source"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title  : const Text("Caméra"),
              onTap  : () { Navigator.pop(context); _pickImage(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title  : const Text("Galerie"),
              onTap  : () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await ImagePicker().pickImage(
        source      : source,
        maxWidth    : 1920,
        maxHeight   : 1080,
        imageQuality: 85,
      );
      if (image != null) setState(() => _pickedFile = image);
    } catch (e, st) {
      ErrorHandler.log(e, st, context: 'Sélection image');
      if (mounted) ErrorHandler.show(context, e);
    }
  }

  Future<String?> _uploadImage(XFile file) async {
    try {
      final bytes    = await file.readAsBytes();
      final fileExt  = file.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'nouveaux_nee/$fileName';

      await Supabase.instance.client.storage
          .from('uploads')
          .uploadBinary(filePath, bytes);

      return Supabase.instance.client.storage
          .from('uploads')
          .getPublicUrl(filePath);
    } catch (e, st) {
      ErrorHandler.log(e, st, context: 'Upload image');
      return null;
    }
  }

  // ====================================================================
  // ENREGISTREMENT
  // ====================================================================

  Future<void> _enregistrer() async {
    if (_nomController.text.trim().isEmpty) {
      ErrorHandler.show(context, "Le nom est requis"); return;
    }
    if (_selectedRace == null) {
      ErrorHandler.show(context, "La race est requise"); return;
    }
    if (_dateController.text.trim().isEmpty) {
      ErrorHandler.show(context, "La date de naissance est requise"); return;
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
    final rfidValidation = Validators.rfid(_tagRFID!);
    if (rfidValidation != null) {
      ErrorHandler.show(context, rfidValidation); return;
    }

    setState(() => _isLoading = true);

    try {
      final existing = await Supabase.instance.client
          .from('nouveaux_nee')
          .select('id, nom')
          .eq('tag_rfid', _tagRFID!)
          .maybeSingle();

      if (existing != null) {
        setState(() => _isLoading = false);
        await _showDuplicateDialog(existing);
        return;
      }

      final url = await _uploadImage(_pickedFile!);
      if (url == null) throw Exception("Erreur upload image");

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception("Utilisateur non connecté");

      await Supabase.instance.client.from('nouveaux_nee').insert({
        'nom'            : Validators.sanitize(_nomController.text),
        'race'           : Validators.sanitize(_selectedRace!),
        'date_naissance' : _dateController.text.trim(),
        'sexe'           : _selectedSexe,
        'image_url'      : url,
        'tag_rfid'       : _tagRFID,
        'user_id'        : userId,
        'created_at'     : DateTime.now().toIso8601String(),
        'pere_id'        : _pereSelectionne?.id,
        'source_pere'    : _pereSelectionne?.source,
        'pere_nom'       : _pereSelectionne?.nom,
        'mere_id'        : _mereSelectionnee?.id,
        'source_mere'    : _mereSelectionnee?.source,
        'mere_nom'       : _mereSelectionnee?.nom,
      });

      if (mounted) {
        ErrorHandler.showSuccess(context, "✅ Nouveau-né enregistré avec succès!");
        _resetForm();
        _loadAnimauxDisponibles();
      }
    } catch (error, st) {
      ErrorHandler.log(error, st, context: 'Enregistrement nouveau-né');
      if (mounted) ErrorHandler.show(context, error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    _nomController.clear();
    _dateController.clear();
    _uidController.clear();
    setState(() {
      _selectedSexe     = null;
      _selectedRace     = null;
      _pickedFile       = null;
      _tagRFID          = null;
      _pereSelectionne  = null;
      _mereSelectionnee = null;
    });
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content        : Text(message),
        backgroundColor: color,
        duration       : const Duration(seconds: 2),
      ),
    );
  }

  // ====================================================================
  // BUILD
  // ====================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title          : const Text("Jur Gui 4.0 - Nouveau-né"),
        backgroundColor: Colors.green[700],
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
                  : _isScanning ? Colors.blue : Colors.orange,
            ),
            onPressed: _isConnected ? null : _reconnectBLE,
            tooltip  : _isConnected
                ? "Connecté"
                : _isScanning ? "Recherche..." : "Reconnecter",
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
                    label      : "Nom",
                    icone      : Icons.pets,
                    couleur    : _couleurNom,
                    valeur     : _nomController.text.trim().isEmpty ? null : _nomController.text.trim(),
                    resume     : _nomController.text.trim().isEmpty ? null : _nomController.text.trim(),
                    champSaisie: TextFormField(
                      controller: _nomController,
                      onChanged : (_) => setState(() {}),
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
                    label      : "Sexe",
                    icone      : Icons.wc,
                    couleur    : _couleurSexe,
                    valeur     : _selectedSexe,
                    resume     : _selectedSexe,
                    champSaisie: _buildSexeDropdownStyled(),
                  ),
                  const SizedBox(height: 12),

                  _buildChampStyleParent(
                    label      : "Race",
                    icone      : Icons.agriculture,
                    couleur    : _couleurRace,
                    valeur     : _selectedRace,
                    resume     : _selectedRace,
                    champSaisie: _buildRaceDropdownStyled(),
                  ),
                  const SizedBox(height: 12),

                  _buildChampStyleParent(
                    label      : "Date de naissance",
                    icone      : Icons.calendar_today,
                    couleur    : _couleurDate,
                    valeur     : _dateController.text.trim().isEmpty ? null : _dateController.text.trim(),
                    resume     : _dateController.text.trim().isEmpty ? null : _dateController.text.trim(),
                    champSaisie: _buildDateFieldStyled(),
                  ),
                  const SizedBox(height: 12),

                  _buildChampStyleParent(
                    label      : "UID RFID",
                    icone      : Icons.nfc,
                    couleur    : _tagRFID != null ? Colors.teal : Colors.grey,
                    valeur     : _tagRFID,
                    resume     : _tagRFID != null ? "Tag détecté : $_tagRFID" : null,
                    champSaisie: _buildUidFieldStyled(),
                  ),
                  const SizedBox(height: 24),

                  _buildParentAutocomplete(
                    label      : "Père",
                    sexeFiltre : "mâle",
                    icone      : Icons.male,
                    couleur    : Colors.blue,
                    selectionne: _pereSelectionne,
                    onSelected : (a) => setState(() => _pereSelectionne = a),
                    onCleared  : ()  => setState(() => _pereSelectionne = null),
                  ),
                  const SizedBox(height: 16),

                  _buildParentAutocomplete(
                    label      : "Mère",
                    sexeFiltre : "femelle",
                    icone      : Icons.female,
                    couleur    : Colors.pink,
                    selectionne: _mereSelectionnee,
                    onSelected : (a) => setState(() => _mereSelectionnee = a),
                    onCleared  : ()  => setState(() => _mereSelectionnee = null),
                  ),
                  const SizedBox(height: 28),

                  _buildSaveButton(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // ====================================================================
  // WIDGETS CHAMPS GÉNÉRIQUES
  // ====================================================================

  Widget _buildChampStyleParent({
    required String   label,
    required IconData icone,
    required Color    couleur,
    required String?  valeur,
    required String?  resume,
    required Widget   champSaisie,
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
                  fontSize  : 14,
                  color     : couleur,
                ),
              ),
            ],
          ),
        ),
        champSaisie,
        if (valeur != null && valeur.isNotEmpty)
          AnimatedContainer(
            duration  : const Duration(milliseconds: 250),
            margin    : const EdgeInsets.only(top: 8),
            padding   : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color       : couleur.withOpacity(0.07),
              border      : Border.all(color: couleur.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width : 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color       : couleur.withOpacity(0.15),
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
                      color     : couleur,
                      fontSize  : 13,
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
      hintText     : hint,
      border       : OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide  : BorderSide(color: couleur.withOpacity(0.5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide  : BorderSide(color: couleur.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide  : BorderSide(color: couleur, width: 2),
      ),
      prefixIcon: Icon(prefixIcon, color: couleur),
      suffixIcon: suffixClear && onClear != null
          ? IconButton(
              icon     : const Icon(Icons.close, size: 18),
              tooltip  : "Effacer",
              onPressed: onClear,
            )
          : null,
    );
  }

  Widget _buildSexeDropdownStyled() {
    return DropdownButtonFormField<String>(
      value     : _selectedSexe,
      decoration: _inputDeco("Choisir le sexe…", Icons.wc, _couleurSexe),
      items: const [
        DropdownMenuItem(value: "Mâle",    child: Text("Mâle")),
        DropdownMenuItem(value: "Femelle", child: Text("Femelle")),
      ],
      onChanged: (v) => setState(() => _selectedSexe = v),
    );
  }

  Widget _buildRaceDropdownStyled() {
    return DropdownButtonFormField<String>(
      value     : _selectedRace,
      decoration: _inputDeco("Choisir la race…", Icons.agriculture, _couleurRace),
      items: const [
        DropdownMenuItem(value: "Ladoum",      child: Text("Ladoum")),
        DropdownMenuItem(value: "Peulh Peulh", child: Text("Peulh Peulh")),
        DropdownMenuItem(value: "Touabire",    child: Text("Touabire")),
      ],
      onChanged: (v) => setState(() => _selectedRace = v),
    );
  }

  Widget _buildDateFieldStyled() {
    return TextFormField(
      controller: _dateController,
      readOnly  : true,
      decoration: _inputDeco(
        "Sélectionner la date…",
        Icons.calendar_today,
        _couleurDate,
        suffixClear: _dateController.text.isNotEmpty,
        onClear: () { _dateController.clear(); setState(() {}); },
      ),
      onTap: () async {
        final date = await showDatePicker(
          context    : context,
          initialDate: DateTime.now(),
          firstDate  : DateTime(2020),
          lastDate   : DateTime.now(),
        );
        if (date != null && mounted) {
          setState(() {
            _dateController.text =
                "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
          });
        }
      },
    );
  }

  // ====================================================================
  // AUTOCOMPLETE PARENTS
  // ====================================================================

  Widget _buildParentAutocomplete({
    required String          label,
    required String          sexeFiltre,
    required IconData        icone,
    required Color           couleur,
    required _AnimalParent?  selectionne,
    required ValueChanged<_AnimalParent> onSelected,
    required VoidCallback    onCleared,
  }) {
    final candidats = _animauxDisponibles.where((a) {
      final s = a.sexe.toLowerCase();
      if (sexeFiltre == 'mâle') return s == 'mâle' || s == 'male';
      return s == sexeFiltre.toLowerCase();
    }).toList();

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
                label,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: couleur),
              ),
              if (_loadingParents) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width : 12,
                  height: 12,
                  child : CircularProgressIndicator(strokeWidth: 2, color: couleur),
                ),
              ],
              const Spacer(),
              Text(
                candidats.isEmpty
                    ? "Aucune disponible"
                    : "${candidats.length} disponible(s)",
                style: TextStyle(
                  fontSize  : 11,
                  color     : candidats.isEmpty ? Colors.red[400] : Colors.grey[500],
                  fontWeight: candidats.isEmpty ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),

        if (candidats.isEmpty && !_loadingParents)
          Container(
            margin    : const EdgeInsets.only(bottom: 8),
            padding   : const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color       : Colors.orange.shade50,
              border      : Border.all(color: Colors.orange.shade200),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    sexeFiltre == 'femelle'
                        ? 'Aucune brebis disponible comme mère.\n'
                          'Raisons : en accouplement, trop jeunes (< 15 mois) ou non enregistrées.'
                        : 'Aucun bélier disponible comme père.\n'
                          'Raisons : trop jeunes (< 18 mois) ou non encore enregistrés.',
                    style: TextStyle(
                      fontSize: 12,
                      color   : Colors.orange[800],
                      height  : 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

        Autocomplete<_AnimalParent>(
          displayStringForOption: (a) => a.nom,
          optionsBuilder: (TextEditingValue tv) {
            if (tv.text.trim().isEmpty) return candidats;
            return candidats.where((a) => a.matches(tv.text.trim()));
          },
          onSelected: onSelected,
          fieldViewBuilder: (ctx, controller, focusNode, onFieldSubmitted) {
            if (selectionne != null && controller.text.isEmpty) {
              controller.text = selectionne.nom;
            }
            return TextFormField(
              controller: controller,
              focusNode : focusNode,
              decoration: InputDecoration(
                hintText     : "Rechercher par nom, race ou RFID…",
                border       : OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide  : BorderSide(color: couleur.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide  : BorderSide(color: couleur, width: 2),
                ),
                prefixIcon: Icon(Icons.search, color: couleur),
                suffixIcon: (selectionne != null || controller.text.isNotEmpty)
                    ? IconButton(
                        icon     : const Icon(Icons.close, size: 18),
                        tooltip  : "Effacer",
                        onPressed: () { controller.clear(); onCleared(); },
                      )
                    : null,
              ),
              onFieldSubmitted: (_) => onFieldSubmitted(),
            );
          },
          optionsViewBuilder: (ctx, onOptionSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation    : 6,
                borderRadius : BorderRadius.circular(10),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 280,
                    maxWidth : MediaQuery.of(ctx).size.width - 32,
                  ),
                  child: ListView.separated(
                    padding         : EdgeInsets.zero,
                    shrinkWrap      : true,
                    itemCount       : options.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                    itemBuilder     : (_, index) {
                      final animal    = options.elementAt(index);
                      final estChoisi = selectionne?.id == animal.id;
                      return ListTile(
                        leading: SizedBox(
                          width : 44,
                          height: 44,
                          child : ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: animal.imageUrl != null
                                ? Image.network(
                                    animal.imageUrl!,
                                    fit          : BoxFit.cover,
                                    loadingBuilder: (_, child, progress) =>
                                        progress == null
                                            ? child
                                            : const Center(
                                                child: SizedBox(
                                                  width : 16,
                                                  height: 16,
                                                  child : CircularProgressIndicator(strokeWidth: 2),
                                                ),
                                              ),
                                    errorBuilder: (_, __, ___) => _avatarIcon(couleur),
                                  )
                                : _avatarIcon(couleur),
                          ),
                        ),
                        title: Text(
                          animal.nom,
                          style: TextStyle(
                            fontWeight: estChoisi ? FontWeight.bold : FontWeight.w500,
                            color     : estChoisi ? couleur : null,
                          ),
                        ),
                        subtitle: Text(
                          "${animal.race}  ·  ${animal.tagRfid}",
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        tileColor: estChoisi ? couleur.withOpacity(0.08) : null,
                        trailing : estChoisi
                            ? Icon(Icons.check_circle, color: couleur, size: 20)
                            : null,
                        onTap: () => onOptionSelected(animal),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),

        if (selectionne != null)
          AnimatedContainer(
            duration  : const Duration(milliseconds: 250),
            margin    : const EdgeInsets.only(top: 8),
            padding   : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color       : couleur.withOpacity(0.07),
              border      : Border.all(color: couleur.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                SizedBox(
                  width : 36,
                  height: 36,
                  child : ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: selectionne.imageUrl != null
                        ? Image.network(
                            selectionne.imageUrl!,
                            fit         : BoxFit.cover,
                            errorBuilder: (_, __, ___) => _avatarIcon(couleur, size: 36),
                          )
                        : _avatarIcon(couleur, size: 36),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectionne.nom,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color     : couleur,
                          fontSize  : 13,
                        ),
                      ),
                      Text(
                        "${selectionne.race}  ·  ${selectionne.tagRfid}",
                        style: TextStyle(fontSize: 11, color: couleur.withOpacity(0.75)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.check_circle, color: couleur, size: 20),
              ],
            ),
          ),
      ],
    );
  }

  Widget _avatarIcon(Color couleur, {double size = 44}) {
    return Container(
      width     : size,
      height    : size,
      decoration: BoxDecoration(
        color       : couleur.withOpacity(0.1),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Icon(Icons.pets, size: size * 0.5, color: couleur),
    );
  }

  // ====================================================================
  // WIDGETS UI GÉNÉRIQUES
  // ====================================================================

  Widget _buildBLEStatusCard() {
    final String   statusText;
    final Color    statusColor;
    final IconData statusIcon;

    if (_isConnected) {
      statusText  = "✅ Lecteur RFID connecté";
      statusColor = Colors.green;
      statusIcon  = Icons.bluetooth_connected;
    } else if (_isScanning) {
      statusText  = "🔍 Recherche du lecteur...";
      statusColor = Colors.blue;
      statusIcon  = Icons.bluetooth_searching;
    } else {
      statusText  = "❌ Lecteur non connecté";
      statusColor = Colors.orange;
      statusIcon  = Icons.bluetooth_disabled;
    }

    return Container(
      padding   : const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color       : statusColor.withOpacity(0.1),
        border      : Border.all(color: statusColor, width: 2),
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
                color     : statusColor,
                fontWeight: FontWeight.bold,
                fontSize  : 16,
              ),
            ),
          ),
          if (!_isConnected && !_isScanning)
            IconButton(
              icon     : const Icon(Icons.refresh),
              onPressed: _reconnectBLE,
              color    : statusColor,
              tooltip  : "Reconnecter",
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Container(
      padding   : const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color       : Colors.grey[100],
        border      : Border.all(color: Colors.grey.shade400),
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
                    width : 150,
                    fit   : BoxFit.cover,
                  ),
                )
              : const Icon(Icons.camera_alt, size: 80, color: Colors.grey),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _showImageSourceDialog,
            icon : const Icon(Icons.add_a_photo),
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

  Widget _buildUidFieldStyled() {
    final couleur = _tagRFID != null ? Colors.teal : Colors.grey;
    return TextFormField(
      controller: _uidController,
      readOnly  : true,
      enabled   : false,
      decoration: InputDecoration(
        hintText     : "En attente du scan RFID…",
        border       : OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide  : BorderSide(color: couleur.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide  : BorderSide(color: couleur.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide  : BorderSide(color: couleur, width: 2),
        ),
        prefixIcon : Icon(Icons.nfc, color: couleur),
        suffixIcon : _tagRFID != null
            ? const Icon(Icons.check_circle, color: Colors.teal)
            : const Icon(Icons.pending, color: Colors.orange),
        helperText : _tagRFID == null
            ? "Approchez le tag du lecteur BLE"
            : "Tag détecté via BLE",
        helperStyle: TextStyle(
          color     : _tagRFID == null ? Colors.grey : Colors.teal,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width : double.infinity,
      height: 52,
      child : ElevatedButton.icon(
        onPressed: _isLoading ? null : _enregistrer,
        icon: _isLoading
            ? const SizedBox(
                width : 20,
                height: 20,
                child : CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
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