import 'package:flutter/material.dart';
import 'package:depart/widgets/couleur.dart';

class OptionCard extends StatelessWidget {
  final String image;
  final String label;
  final Widget route;

  const OptionCard({
    super.key,
    required this.image,
    required this.label,
    required this.route,
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
          color: Couleur.QuatriemeColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            // Ajout de la bordure
            color: Couleur.PremierColor, // Couleur de la bordure
            width: 2.0, // Épaisseur de la bordure
          ),
        ),
        child: Column(
          children: [
            Image.asset(image, height: 80),
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
