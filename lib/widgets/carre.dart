import 'package:flutter/material.dart';

class Carre extends StatelessWidget {
  final String path;
  const Carre({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(16),
        color: Colors.grey[200],
      ),
      child: Image.asset(path, height: 20),
    );
  }
}

class Cercle extends StatelessWidget {
  final String path;
  const Cercle({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // On définit la forme comme étant un cercle
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey),
        color: Colors.grey[200],
        // ATTENTION : On ne peut pas utiliser 'borderRadius' en même temps que 'shape: BoxShape.circle'.
        // Il faut donc supprimer la ligne 'borderRadius: BorderRadius.circular(16)'.
      ),
      child: Image.asset(path, height: 20),
    );
  }
}
