import 'package:depart/Eleveures/Chaleur/FicheBrebisPage.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// PARTIE 1/3 : MODULE PRINCIPAL + LISTE DES BREBIS
// ============================================================

class Chaleur extends StatefulWidget {
  const Chaleur({super.key});

  @override
  State<Chaleur> createState() => _ChaleurModuleState();
}

class _ChaleurModuleState extends State<Chaleur> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _brebis = [];
  bool _isLoading = true;
  String? _saisonActuelle;
  String? _indicateurSaison;
  Color? _couleurSaison;

  @override
  void initState() {
    super.initState();
    _initModule();
  }

  Future<void> _initModule() async {
    await _determinerSaison();
    await _chargerBrebis();
  }

  Future<void> _determinerSaison() async {
    final now = DateTime.now();
    final mois = now.month;

    if (mois >= 9 || mois <= 2) {
      _saisonActuelle = "Saison active de reproduction";
      _indicateurSaison = "🟢 Période favorable pour les chaleurs";
      _couleurSaison = Colors.green;
    } else if (mois >= 3 && mois <= 5) {
      _saisonActuelle = "Période de transition";
      _indicateurSaison = "🟡 Activité reproductive modérée";
      _couleurSaison = Colors.orange;
    } else {
      _saisonActuelle = "Anœstrus saisonnier";
      _indicateurSaison = "🔴 Période défavorable - Chaleurs rares";
      _couleurSaison = Colors.red;
    }
  }

  Future<void> _chargerBrebis() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        debugPrint("❌ Utilisateur non connecté");
        throw Exception("Utilisateur non connecté");
      }

      debugPrint("🔍 Chargement des brebis pour user_id: $userId");

      List<Map<String, dynamic>> toutesLesBrebis = [];

      try {
        debugPrint("🔍 Requête animal_acheter...");
        final achetes = await supabase
            .from('animal_acheter')
            .select('id, nom, race, sexe, tag_rfid, image_url, provenance')
            .eq('sexe', 'Femelle')
            .eq('user_id', userId)
            .order('nom');

        debugPrint("✅ animal_acheter: ${achetes.length} brebis trouvées");
        
        for (var animal in achetes) {
          animal['source'] = 'achete';
          toutesLesBrebis.add(animal);
        }
      } catch (e) {
        debugPrint("⚠️ Erreur animal_acheter: $e");
      }

      try {
        debugPrint("🔍 Requête nouveaux_nee...");
        final nees = await supabase
            .from('nouveaux_nee')
            .select('id, nom, race, sexe, tag_rfid, image_url, date_naissance')
            .eq('sexe', 'Femelle')
            .eq('user_id', userId)
            .order('nom');

        debugPrint("✅ nouveaux_nee: ${nees.length} brebis trouvées");
        
        for (var animal in nees) {
          animal['source'] = 'nee';
          toutesLesBrebis.add(animal);
        }
      } catch (e) {
        debugPrint("⚠️ Erreur nouveaux_nee: $e");
      }

      debugPrint("📊 Total brebis chargées: ${toutesLesBrebis.length}");

      if (mounted) {
        setState(() {
          _brebis = toutesLesBrebis;
          _isLoading = false;
        });

        if (toutesLesBrebis.isEmpty) {
          _showSnackBar("Aucune brebis femelle trouvée", Colors.orange);
        } else {
          _showSnackBar("${toutesLesBrebis.length} brebis chargées", Colors.green);
        }
      }
    } catch (e, stackTrace) {
      debugPrint("❌ Erreur chargement brebis: $e");
      debugPrint("Stack trace: $stackTrace");
      if (mounted) {
        _showSnackBar("Erreur de chargement", Colors.red);
        setState(() => _isLoading = false);
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Jur Gui 4.0 - Module Chaleur"),
        backgroundColor: Colors.pink[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initModule,
            tooltip: "Actualiser",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildIndicateurSaison(),
                Expanded(child: _buildListeBrebis()),
              ],
            ),
    );
  }

  Widget _buildIndicateurSaison() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _couleurSaison?.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _couleurSaison ?? Colors.grey, width: 2),
      ),
      child: Column(
        children: [
          Icon(Icons.wb_sunny, size: 40, color: _couleurSaison),
          const SizedBox(height: 8),
          Text(
            _saisonActuelle ?? "",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            _indicateurSaison ?? "",
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildListeBrebis() {
    if (_brebis.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pets, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text("Aucune brebis trouvée", 
                style: TextStyle(fontSize: 18, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text("Ajoutez des brebis dans le module Animaux",
                style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _brebis.length,
      itemBuilder: (context, index) => _buildBrebiCard(_brebis[index]),
    );
  }

  Widget _buildBrebiCard(Map<String, dynamic> brebis) {
    final source = brebis['source'] == 'achete' ? '🛒 Acheté' : '🐑 Nouveau-né';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: brebis['image_url'] != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  brebis['image_url'],
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[300],
                      child: const Icon(Icons.pets, size: 30),
                    );
                  },
                ),
              )
            : Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.pink[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.pets, size: 30, color: Colors.pink[300]),
              ),
        title: Text(
          brebis['nom'] ?? 'Sans nom',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text("Race: ${brebis['race'] ?? 'N/A'}"),
            Text(source, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic)),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.pink),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FicheBrebisPage(
                brebis: brebis,
                source: brebis['source'],
              ),
            ),
          ).then((_) => _chargerBrebis());
        },
      ),
    );
  }
}