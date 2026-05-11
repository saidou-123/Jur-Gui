import 'package:depart/Veterinaires/FichesSante.dart';
import 'package:depart/Veterinaires/Scanveterinaire/ScanRFIDVeterinaireB.dart';
import 'package:depart/Veterinaires/Vaccinations.dart';
import 'package:depart/Veterinaires/features/collaboration/notes_eleveur_page.dart';
import 'package:depart/Veterinaires/features/dashboard/dashboard_veterinaire.dart';
import 'package:flutter/material.dart';


/// Point d'entrée principal du module vétérinaire.
/// Navigation par BottomNavigationBar avec 5 sections.
class VeterinaireHome extends StatefulWidget {
  const VeterinaireHome({super.key});

  @override
  State<VeterinaireHome> createState() => _VeterinaireHomeState();
}

class _VeterinaireHomeState extends State<VeterinaireHome> {
  int _index = 0;

  static const _pages = [
    DashboardVeterinaire(),
    ScanRFIDVeterinaireBluetooth(),
    FichesSante(),
    Vaccinations(),
    NotesEleveurPage(),
  ];

  static const _items = [
    BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Tableau de bord'),
    BottomNavigationBarItem(icon: Icon(Icons.nfc), label: 'Scan RFID'),
    BottomNavigationBarItem(icon: Icon(Icons.folder_shared), label: 'Fiches santé'),
    BottomNavigationBarItem(icon: Icon(Icons.vaccines), label: 'Vaccinations'),
    BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Éleveur'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green[700],
        unselectedItemColor: Colors.grey[500],
        selectedFontSize: 11,
        unselectedFontSize: 10,
        items: _items,
      ),
    );
  }
}