
import 'package:flutter/material.dart';
import 'package:depart/widgets/OptionCercle.dart';
import 'package:depart/widgets/optioncard.dart';
import 'package:depart/Veterinaires/FichesSante.dart';
import 'package:depart/Veterinaires/HistoriqueMedical.dart';
import 'package:depart/Veterinaires/Scanveterinaire/ScanRFIDVeterinaire.dart';
import 'package:depart/Veterinaires/Vaccinations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// INTERFACE VÉTÉRINAIRE - DASHBOARD PRINCIPAL
// ============================================================
class interfaceVeterinaire extends StatefulWidget {
  const interfaceVeterinaire({super.key});

  @override
  State<interfaceVeterinaire> createState() => _interfaceVeterinaireState();
}

class _interfaceVeterinaireState extends State<interfaceVeterinaire> {
  final supabase = Supabase.instance.client;
  int _totalAnimaux = 0;
  int _consultationsEnCours = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _chargerStatistiques();
  }

  Future<void> _chargerStatistiques() async {
    try {
      // Compter tous les animaux (toutes sources confondues)
      final nouveauxNes = await supabase.from('nouveaux_nee').select('id').count();
      final achetes = await supabase.from('animal_acheter').select('id').count();
      
      setState(() {
        _totalAnimaux = nouveauxNes.count + achetes.count;
        _consultationsEnCours = 0; // À implémenter selon vos besoins
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Erreur chargement stats: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text(
            "USSEINPAY - Vétérinaire",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
              fontSize: 20,
            ),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: Icon(Icons.person, color: Colors.blue[700]),
            onPressed: () {
              _showProfileMenu();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Barre de recherche
              

                // Statistiques
                _buildStatistiques(),
                const SizedBox(height: 24),

                // Section Options Cercles
                

                const SizedBox(height: 24),

                // Carte Scan RFID
                _buildScanCard(),

                const SizedBox(height: 20),

                // Section Grille Options
                const Text(
                  'Gestion médicale:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildOptionsGrid(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ScanRFIDVeterinaire()),
          );
        },
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        child: const Icon(Icons.nfc),
      ),
    );
  }



  Widget _buildStatistiques() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.pets,
            label: "Total Animaux",
            value: "$_totalAnimaux",
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.medical_services,
            label: "Consultations",
            value: "$_consultationsEnCours",
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required MaterialColor color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color[200]!, width: 2),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: color[700]),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color[900],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsCircles() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const SizedBox(width: 16),
          OptionCercle(
            image: 'assets/image/img14.png',
            label: "Scan RFID",
            route: const ScanRFIDVeterinaire(),
            backgroundColor: Colors.blue[700],
          ),
          const SizedBox(width: 12),
          OptionCercle(
            image: 'assets/image/img10.png',
            label: 'Fiches Santé',
            route: const FichesSante(),
            backgroundColor: Colors.green[700],
          ),
          const SizedBox(width: 12),
          OptionCercle(
            image: 'assets/image/img6.png',
            label: 'Historique',
            route: const HistoriqueMedical(),
            backgroundColor: Colors.orange[700],
          ),
          const SizedBox(width: 12),
          OptionCercle(
            image: 'assets/image/img5.png',
            label: 'Vaccinations',
            route: const Vaccinations(),
            backgroundColor: Colors.purple[700],
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildScanCard() {
    return SizedBox(
      height: 200,
      child: Card(
        color: Colors.blue[700],
        elevation: 4,
        shadowColor: Colors.blue[200],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Scan RFID Rapide",
                      style: TextStyle(
                        color: Colors.amber[300],
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      "Accédez instantanément aux dossiers médicaux en scannant le tag RFID",
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ScanRFIDVeterinaire(),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue[700],
                      ),
                      icon: const Icon(Icons.nfc),
                      label: const Text("Scanner"),
                    ),
                  ],
                ),
              ),
              Image.asset("assets/image/img14.png", width: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionsGrid() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            OptionCard(
              image: 'assets/image/img10.png',
              label: "Fiches de Santé",
              route: const FichesSante(),
              backgroundColor: Color(0xFFE8F5E9), // Vert très clair
            ),
            OptionCard(
              image: 'assets/image/img6.png',
              label: 'Historique Médical',
              route: const HistoriqueMedical(),
              backgroundColor: Color(0xFFFFF3E0), // Orange très clair
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            OptionCard(
              image: 'assets/image/img5.png',
              label: "Vaccinations",
              route: const Vaccinations(),
              backgroundColor: Color(0xFFFCE4EC), // Rose très clair
            ),
            OptionCard(
              image: 'assets/image/img14.png',
              label: 'Scan RFID',
              route: const ScanRFIDVeterinaire(),
              backgroundColor: Color(0xFFFFF9C4), // Jaune très clair
            ),
          ],
        ),
      ],
    );
  }

  void _showProfileMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [ 
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text("Mon Profil"),
                onTap: () {
                  Navigator.pop(context);
                  // Naviguer vers profil
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text("Paramètres"),
                onTap: () {
                  Navigator.pop(context);
                  // Naviguer vers paramètres
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text("Déconnexion", style: TextStyle(color: Colors.red)),
                onTap: () async {
                  await supabase.auth.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed('/connexion');
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}