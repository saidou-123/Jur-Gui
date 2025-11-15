import 'package:depart/Fonctionalite/Ajouter%20Animal/AnimalAchate.dart';
import 'package:flutter/material.dart';
import 'package:depart/Fonctionalite/Ajouter%20Animal/NouveauNee.dart';
import 'package:depart/widgets/optioncard.dart';

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
                  child: OptionCard(
                    image: 'assets/image/img6.png',
                    label: "Nouveau-né",

                    route: const  NouveauNeePage(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OptionCard(
                    image: 'assets/image/img10.png',
                    label: 'Animal acheté',

                    route: const AnimalAchate(),
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
