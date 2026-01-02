import 'package:flutter/material.dart';
import 'package:depart/widgets/couleur.dart';

class OptionCard extends StatelessWidget {
  final String image;
  final String label;
  final Widget route;
  final Color backgroundColor; // Nouvelle propriété pour la couleur de fond
  final Color? iconColor; // Couleur optionnelle pour l'icône

  const OptionCard({
    super.key,
    required this.image,
    required this.label,
    required this.route,
    required this.backgroundColor, // Obligatoire maintenant
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => route)),
      child: Container(
        width: 130,
        height: 135,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: backgroundColor, // Utilise la couleur passée en paramètre
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Couleur.PremierColor,
            width: 2.0,
          ),
        ),
        child: Column(
          children: [
            Image.asset(
              image, 
              height: 80,
              color: iconColor, // Applique la couleur à l'icône si fournie
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                color: Couleur.PremierColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}