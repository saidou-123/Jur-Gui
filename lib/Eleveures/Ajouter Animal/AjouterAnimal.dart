// ============================================================
// AJOUTER ANIMAL - VERSION CORRIGÉE
// Fichier: lib/pages/AjouterAnimal/AjouterAnimal.dart
// Corrections:
//   ✅ 1. Séparé de main.dart dans son propre fichier
//   ✅ 2. const ajouté aux Color() pour meilleures performances
// ============================================================

import 'package:depart/Eleveures/Ajouter%20Animal/AnimalAchateBluetooth.dart';
import 'package:depart/Eleveures/Ajouter%20Animal/NouveauNeeBluetooth.dart';
import 'package:depart/widgets/optioncardEleveur.dart';
import 'package:flutter/material.dart';

class AjouterAnimal extends StatelessWidget {
  const AjouterAnimal({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ajouter un animal"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            // Image d'en-tête
            Image.asset(
              "assets/image/img6.png",
              height: 250,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),

            // Titre section
            const Text(
              "Comment souhaitez-vous ajouter un animal ?",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Options d'ajout
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: optioncardEleveur(
                    image: 'assets/image/img6.png',
                    label: "Nouveau-né",
                    route: const NouveauNeeBluetooth(),
                    // ✅ CORRECTION: const ajouté à Color()
                    backgroundColor: const Color(0xFFE8F5E9),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: optioncardEleveur(
                    image: 'assets/image/img10.png',
                    label: 'Animal acheté',
                    route: const AnimalAchateBluetooth(),
                    // ✅ CORRECTION: const ajouté à Color()
                    backgroundColor: const Color(0xFFFFF3E0),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}