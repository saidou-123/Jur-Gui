import 'package:depart/Eleveures/Accouplemaent/Accouplement.dart';
import 'package:depart/Eleveures/Ajouter%20Animal/AjouterAnimal.dart';
import 'package:depart/Eleveures/AnimalInfoRFID/AnimalInfoRFIDPage.dart';
import 'package:depart/Eleveures/Chaleur/Chaleur.dart';
import 'package:depart/Eleveures/Mon%20Troupeau/HistoriqueMedicalEleveur.dart';
import 'package:depart/Eleveures/Mon%20Troupeau/SupprimerAnimal/RappelsVaccinationEleveur.dart';
import 'package:depart/Eleveures/Mon%20Troupeau/ModfierAnimal/AnimalListPage.dart';
import 'package:depart/widgets/optioncard.dart';
import 'package:flutter/material.dart';
import 'package:depart/widgets/couleur.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// INTERFACE ÉLEVEUR - DASHBOARD PRINCIPAL
// ============================================================
class interfaceElevaur extends StatefulWidget {
  const interfaceElevaur({super.key});

  @override
  State<interfaceElevaur> createState() => _interfaceElevaureState();
}

class _interfaceElevaureState extends State<interfaceElevaur> {
  final supabase = Supabase.instance.client;
  int _totalAnimaux = 0;
  int _nombreMales = 0;
  int _nombreFemelles = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _chargerStatistiques();
  }

  Future<void> _chargerStatistiques() async {
    try {
      // Compter tous les animaux
      final nouveauxNes = await supabase.from('nouveaux_nee').select('id, sexe').count();
      final achetes = await supabase.from('animal_acheter').select('id, sexe').count();
      
      // Récupérer les données pour compter par sexe
      final nouveauxNesData = await supabase.from('nouveaux_nee').select('sexe');
      final achetesData = await supabase.from('animal_acheter').select('sexe');
      
      int males = 0;
      int femelles = 0;
      
      // Compter les mâles et femelles dans nouveaux_nee
      for (var animal in nouveauxNesData) {
        if (animal['sexe']?.toString().toLowerCase() == 'male' || 
            animal['sexe']?.toString().toLowerCase() == 'mâle') {
          males++;
        } else if (animal['sexe']?.toString().toLowerCase() == 'femelle') {
          femelles++;
        }
      }
      
      // Compter les mâles et femelles dans animal_acheter
      for (var animal in achetesData) {
        if (animal['sexe']?.toString().toLowerCase() == 'male' || 
            animal['sexe']?.toString().toLowerCase() == 'mâle') {
          males++;
        } else if (animal['sexe']?.toString().toLowerCase() == 'femelle') {
          femelles++;
        }
      }
      
      setState(() {
        _totalAnimaux = nouveauxNes.count + achetes.count;
        _nombreMales = males;
        _nombreFemelles = femelles;
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
            "JUR GUI - Éleveur",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Couleur.PremierColor,
              fontSize: 20,
            ),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: Icon(Icons.person, color: Couleur.PremierColor),
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
                // Statistiques du troupeau
                _buildStatistiques(),
                const SizedBox(height: 24),

                // Carte Ajouter Animal
                _buildAjouterAnimalCard(),
                const SizedBox(height: 20),

                // Section Gestion du troupeau
                const Text(
                  'Gestion du troupeau:',
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
            MaterialPageRoute(builder: (context) => AjouterAnimal()),
          );
        },
        backgroundColor: Colors.amber,
        foregroundColor: Colors.blue,
        child: const Icon(Icons.add),
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
            icon: Icons.male,
            label: "Mâles",
            value: "$_nombreMales",
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.female,
            label: "Femelles",
            value: "$_nombreFemelles",
            color: Colors.pink,
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

  Widget _buildAjouterAnimalCard() {
    return SizedBox(
      height: 200,
      child: Card(
        color: Couleur.PremierColor,
        elevation: 4,
        shadowColor: Couleur.DeuxiemeColor,
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
                      "Agrandissez votre troupeau",
                      style: TextStyle(
                        color: Colors.amber[300],
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      "Ajoutez facilement de nouveaux animaux à votre élevage",
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>AnimalInfoRFIDPage(),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Couleur.PremierColor,
                      ),
                      icon: const Icon(Icons.nfc),
                      label: const Text("Scanner"),
                    ),
                  ],
                ),
              ),
              Image.asset("assets/image/img10.png", width: 100),
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
              image: 'assets/image/img6.png',
              label: "Mon Troupeau",
              route: const AnimalListPage(),
              backgroundColor: Color(0xFFE8F5E9), // Vert très clair
            ),
            OptionCard(
              image: 'assets/image/img10.png',
              label: 'Période Chaleur',
              route: const Chaleur(),
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
              route: const RappelsVaccinationEleveur(),
              backgroundColor: Color(0xFFFCE4EC), // Rose très clair
            ),
            OptionCard(
              image: 'assets/image/img14.png',
              label: 'Scan RFID',
              route: const AjouterAnimal(),
              backgroundColor: Color(0xFFFFF9C4), // Jaune très clair
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            OptionCard(
              image: 'assets/image/img5.png',
              label: "Transport",
              route: const HistoriqueMedicalEleveur(),
              backgroundColor: Color(0xFFE3F2FD), // Bleu très clair
            ),
            // Espace vide pour garder la symétrie
            Expanded(child: SizedBox()),
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
                leading: const Icon(Icons.refresh),
                title: const Text("Actualiser les données"),
                onTap: () {
                  Navigator.pop(context);
                  _chargerStatistiques();
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text("Déconnexion",
                    style: TextStyle(color: Colors.red)),
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