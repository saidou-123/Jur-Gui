import 'package:flutter/material.dart';
import 'package:depart/widgets/couleur.dart';

class OptionCercle extends StatelessWidget {
  final String image;
  final String label;
  final Widget route;
  final Color? backgroundColor;
  final Color? textColor;
  final double size;
  final bool showShadow;

  const OptionCercle({
    super.key,
    required this.image,
    required this.label,
    required this.route,
    this.backgroundColor,
    this.textColor,
    this.size = 70,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => route)),
      child: Container(
        width: size,
        height: size + 40, // Extra space for the label
        child: Column(
          children: [
            Container(
              width: size,
              height: size,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: backgroundColor ?? Couleur.PremierColor,
                shape: BoxShape.circle,
                boxShadow: showShadow
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Image.asset(
                image,
                height: size * 0.5,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Couleur.PremierColor,
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
