import 'package:depart/Eleveures/Ajouter%20Animal/AnimalAchate.dart';
import 'package:depart/Eleveures/Ajouter%20Animal/NouveauNee.dart';
import 'package:depart/widgets/optioncardEleveur.dart';
import 'package:flutter/material.dart';



class AjouterAnimal extends StatelessWidget {
  const AjouterAnimal({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ajouter un animal"), centerTitle: true),
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
                    route: const  NouveauNeePage(),
                    backgroundColor: Color(0xFFE8F5E9), // Vert très clair
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: optioncardEleveur(
                    image: 'assets/image/img10.png',
                    label: 'Animal acheté',
                    route: const AnimalAchate(),
                    backgroundColor: Color(0xFFFFF3E0), // Orange très clair
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

