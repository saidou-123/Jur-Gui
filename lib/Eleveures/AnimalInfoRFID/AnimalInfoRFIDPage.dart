import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class AnimalInfoRFIDPage extends StatefulWidget {
  const AnimalInfoRFIDPage({super.key});

  @override
  State<AnimalInfoRFIDPage> createState() => _AnimalInfoRFIDPageState();
}

class _AnimalInfoRFIDPageState extends State<AnimalInfoRFIDPage> {
  RealtimeChannel? _rfidChannel;
  bool _realtimeConnected = false;
  bool _isSearching = false;
  bool _scanAuthorized = false;
  String? _lastScannedUID;
  Map<String, dynamic>? _animalInfo;
  String? _sourceTable;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _isReconnecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeRealtime();
    });
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _unsubscribeRealtime();
    super.dispose();
  }

  // ----------------------------------------------------------
  // 🟢 REALTIME SUPABASE - VERSION ROBUSTE
  // ----------------------------------------------------------
  Future<void> _initializeRealtime() async {
    if (!mounted) return;

    try {
      debugPrint("🔌 Initialisation du canal Realtime (tentative ${_reconnectAttempts + 1})...");

      // Nettoyer l'ancien canal si existant
      await _unsubscribeRealtime();
      
      await Future.delayed(const Duration(milliseconds: 500));

      // Créer un nouveau canal avec un nom unique
      final channelName = 'rfid_info_ animal';
      
      _rfidChannel = Supabase.instance.client.channel(
        channelName,
        opts: const RealtimeChannelConfig(
          ack: true, // Activer les accusés de réception
        ),
      );

      _rfidChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'rfid_scans',
            callback: (payload) {
              debugPrint("⚡ PAYLOAD REÇU = $payload");
              debugPrint("🔑 État scan autorisé: $_scanAuthorized");

              // Vérifier si le scan est autorisé
              if (!_scanAuthorized) {
                debugPrint("🚫 Scan non autorisé - ignoré");
                debugPrint("❗ ACTION REQUISE: L'utilisateur doit appuyer sur 'AUTORISER LE SCAN'");
                if (mounted) {
                  _showSnackBar("⚠️ Veuillez d'abord autoriser le scan", Colors.orange);
                }
                return;
              }

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
              debugPrint("🔍 Lancement de la recherche pour UID: $uid");

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

            // Gérer les différents statuts
            switch (status) {
              case RealtimeSubscribeStatus.subscribed:
                debugPrint("✅ Canal Realtime connecté avec succès");
                setState(() {
                  _realtimeConnected = true;
                  _isReconnecting = false;
                  _reconnectAttempts = 0;
                });
                _reconnectTimer?.cancel();
                _showSnackBar("✅ Système RFID connecté", Colors.green);
                break;

              case RealtimeSubscribeStatus.closed:
                debugPrint("🔴 Canal Realtime fermé");
                setState(() {
                  _realtimeConnected = false;
                });
                _showSnackBar("⚠️ Connexion RFID perdue", Colors.orange);
                
                // Tenter une reconnexion automatique
                _scheduleReconnect();
                break;

              case RealtimeSubscribeStatus.channelError:
                debugPrint("❌ Erreur du canal Realtime");
                setState(() {
                  _realtimeConnected = false;
                });
                _showSnackBar("❌ Erreur de connexion RFID", Colors.red);
                _scheduleReconnect();
                break;

              case RealtimeSubscribeStatus.timedOut:
                debugPrint("⏱️ Timeout de connexion Realtime");
                setState(() {
                  _realtimeConnected = false;
                });
                _showSnackBar("⏱️ Timeout de connexion", Colors.orange);
                _scheduleReconnect();
                break;

              default:
                debugPrint("⚠️ Statut inconnu: $status");
            }

            if (error != null) {
              debugPrint("❌ Erreur Realtime : $error");
            }
          });

      _reconnectAttempts++;
    } catch (e, stackTrace) {
      debugPrint("❌ ERREUR Realtime : $e");
      debugPrint("Stack trace: $stackTrace");
      
      if (mounted) {
        setState(() {
          _realtimeConnected = false;
        });
        _showSnackBar("❌ Erreur: ${e.toString()}", Colors.red);
        _scheduleReconnect();
      }
    }
  }

  // Planifier une reconnexion automatique
  void _scheduleReconnect() {
    if (_isReconnecting || _reconnectAttempts >= 5) {
      if (_reconnectAttempts >= 5) {
        debugPrint("❌ Nombre maximum de tentatives de reconnexion atteint");
        _showSnackBar("❌ Reconnexion échouée. Utilisez le bouton WiFi.", Colors.red);
      }
      return;
    }

    _isReconnecting = true;
    _reconnectTimer?.cancel();

    // Délai progressif: 2s, 4s, 6s, 8s, 10s
    final delay = Duration(seconds: 2 + (_reconnectAttempts * 2));
    
    debugPrint("🔄 Reconnexion planifiée dans ${delay.inSeconds}s...");
    
    _reconnectTimer = Timer(delay, () {
      if (mounted && !_realtimeConnected) {
        debugPrint("🔄 Tentative de reconnexion automatique...");
        _initializeRealtime();
      }
    });
  }

  Future<void> _unsubscribeRealtime() async {
    try {
      if (_rfidChannel != null) {
        await Supabase.instance.client.removeChannel(_rfidChannel!);
        _rfidChannel = null;
        debugPrint("🔴 Canal Realtime désabonné");
      }
    } catch (e) {
      debugPrint("⚠️ Erreur désabonnement : $e");
    }
  }

  // ----------------------------------------------------------
  // 🔑 GESTION DE L'AUTORISATION DE SCAN
  // ----------------------------------------------------------
  void _toggleScanAuthorization() {
    if (!_realtimeConnected) {
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
            _scanAuthorized = false;
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
            _scanAuthorized = false;
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
          _scanAuthorized = false;
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

  // ----------------------------------------------------------
  // RECONNEXION MANUELLE
  // ----------------------------------------------------------
  Future<void> _reconnectRealtime() async {
    if (!mounted) return;

    _showSnackBar("🔄 Reconnexion en cours...", Colors.orange);
    
    setState(() {
      _isSearching = true;
      _reconnectAttempts = 0; // Réinitialiser le compteur
    });
    
    _reconnectTimer?.cancel();
    await _unsubscribeRealtime();
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
          // Indicateur de reconnexion
          if (_isReconnecting)
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
              _realtimeConnected ? Icons.wifi : Icons.wifi_off,
              color: _realtimeConnected ? Colors.white : Colors.orange,
            ),
            tooltip: _realtimeConnected 
                ? "RFID connecté" 
                : "RFID déconnecté - Appuyez pour reconnecter",
            onPressed: _isReconnecting ? null : _reconnectRealtime,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
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

  Widget _buildScanSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _scanAuthorized 
              ? [Colors.green[700]!, Colors.green[500]!]
              : (_realtimeConnected 
                  ? [Colors.blue[700]!, Colors.blue[500]!]
                  : [Colors.grey[700]!, Colors.grey[500]!]),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (_scanAuthorized ? Colors.green : (_realtimeConnected ? Colors.blue : Colors.grey))
                .withOpacity(0.3),
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
                _scanAuthorized 
                    ? Icons.nfc 
                    : (_realtimeConnected ? Icons.nfc_outlined : Icons.nfc_outlined),
                size: 80,
                color: Colors.white,
              ),
              if (_isReconnecting)
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
            _scanAuthorized 
                ? "SCAN AUTORISÉ" 
                : (_realtimeConnected 
                    ? "Scan désactivé" 
                    : (_isReconnecting ? "Reconnexion..." : "Déconnecté")),
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
                : (_realtimeConnected 
                    ? "Appuyez sur le bouton ci-dessous pour autoriser"
                    : (_isReconnecting 
                        ? "Tentative de reconnexion (${_reconnectAttempts}/5)..."
                        : "Appuyez sur l'icône WiFi pour reconnecter")),
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
        onPressed: _realtimeConnected && !_isReconnecting 
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

