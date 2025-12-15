
import 'package:flutter/material.dart';
import 'package:depart/widgets/couleur.dart';
class interfaceVeterinaire extends StatelessWidget {
  const interfaceVeterinaire({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text(
            "USSEINPAY",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Couleur.PremierColor,
              fontSize: 20,
            ),
          ),
        ),
      )
    );
  }
}
    