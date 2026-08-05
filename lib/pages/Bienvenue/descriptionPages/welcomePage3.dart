import 'package:depart/widgets/couleur.dart';
import 'package:flutter/material.dart';

class Welcomepage3 extends StatelessWidget {
  const Welcomepage3({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          const SizedBox(height: 50),
          Column(
            children: [
               Text(
                   "JUR GUI",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 40,
                            color: Couleur.PremierColor,
                            letterSpacing: 2,
                          ),
                        ),

                        // Sous-titre
                        Text(
                          "Gestion d'Élevage Intelligente",
                          style: TextStyle(
                            fontSize: 18,
                            color: Couleur.PremierColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                  const SizedBox(height:8),
            Image.asset('assets/image/img22.png'),
              const SizedBox(height: 24),
              Text(
                "Toujours connecté",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Couleur.PremierColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                "Accédez à votre troupeau depuis n'importe où, à tout moment",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ],
          ),
        ],
      ),
    );
  }
}