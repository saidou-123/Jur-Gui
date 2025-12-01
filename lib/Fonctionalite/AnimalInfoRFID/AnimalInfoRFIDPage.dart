import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnimalInfoRFIDPage extends StatefulWidget {
  const AnimalInfoRFIDPage({super.key});

  @override
  State<AnimalInfoRFIDPage> createState() => _AnimalInfoRFIDPageState();
}

class _AnimalInfoRFIDPageState extends State<AnimalInfoRFIDPage> {
  RealtimeChannel? _rfidChannel;
  bool _realtimeConnected = false;
  bool _isSearching = false;
  String? _lastScannedUID;
  Map<String, dynamic>? _animalInfo;
  String? _sourceTable;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeRealtime();
    });
  }

  @override
  void dispose() {
    _unsubscribeRealtime();
    super.dispose();
  }

  // ----------------------------------------------------------
  // 🟢 REALTIME SUPABASE
  // ----------------------------------------------------------
  Future<void> _initializeRealtime() async {
    if (!mounted) return;

    try {
      debugPrint("🔌 Initialisation du canal Realtime...");

      await Future.delayed(const Duration(milliseconds: 500));

      final channelName = 'rfid_info_${DateTime.now().millisecondsSinceEpoch}';
      
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
  // 🔍 DÉTECTION DU TAG ET RECHERCHE DE L'ANIMAL
  // ----------------------------------------------------------
  Future<void> _onTagDetected(String uid) async {
    if (!mounted) return;

    debugPrint("════════════════════════════════════");
    debugPrint("🏷️  TAG DÉTECTÉ : $uid");
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
      debugPrint("🔍 Recherche dans nouveaux_nee...");
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
          });
          _showSnackBar("✅ Animal trouvé !", Colors.green);
        }
        return;
      }

      // 🔍 Rechercher dans la table animal_acheter
      debugPrint("🔍 Recherche dans animal_acheter...");
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
          });
          _showSnackBar("✅ Animal trouvé !", Colors.green);
        }
        return;
      }

      // ❌ Animal non trouvé
      debugPrint("❌ Aucun animal trouvé avec ce tag RFID");
      if (mounted) {
        setState(() {
          _isSearching = false;
          _animalInfo = null;
          _sourceTable = null;
        });
        _showSnackBar("❌ Aucun animal trouvé avec ce tag RFID", Colors.red);
      }
    } catch (e, stackTrace) {
      debugPrint("❌ Erreur lors de la recherche: $e");
      debugPrint("Stack trace: $stackTrace");
      if (mounted) {
        setState(() => _isSearching = false);
        _showSnackBar("Erreur: ${e.toString()}", Colors.red);
      }
    }
  }

  // ----------------------------------------------------------
  // RECONNEXION MANUELLE
  // ----------------------------------------------------------
  Future<void> _reconnectRealtime() async {
    if (!mounted) return;

    _showSnackBar("Reconnexion en cours...", Colors.orange);
    
    setState(() => _isSearching = true);
    
    _unsubscribeRealtime();
    await Future.delayed(const Duration(milliseconds: 500));
    await _initializeRealtime();

    if (mounted) {
      setState(() => _isSearching = false);
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
        title: const Text("Info Animal - Scan RFID"),
        backgroundColor: Colors.blue[700],
        actions: [
          IconButton(
            icon: Icon(
              _realtimeConnected ? Icons.wifi : Icons.wifi_off,
              color: _realtimeConnected ? Colors.white : Colors.orange,
            ),
            tooltip: _realtimeConnected 
                ? "RFID connecté" 
                : "RFID déconnecté - Appuyez pour reconnecter",
            onPressed: _reconnectRealtime,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Section de scan
            _buildScanSection(),
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

  Widget _buildScanSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[700]!, Colors.blue[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            _realtimeConnected ? Icons.nfc : Icons.nfc_outlined,
            size: 80,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          Text(
            _realtimeConnected 
                ? "Prêt à scanner" 
                : "Connexion en cours...",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _realtimeConnected
                ? "Approchez un tag RFID du lecteur"
                : "Veuillez patienter",
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
            "Scannez un tag RFID pour afficher les informations de l'animal",
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