import 'package:depart/pages/connexion.dart';
import 'package:depart/widgets/couleur.dart';
import 'package:depart/widgets/inputs.dart';
import 'package:flutter/material.dart';

class Inscription extends StatefulWidget {
  const Inscription({super.key});

  @override
  State<Inscription> createState() => _InscriptionState();
}

class _InscriptionState extends State<Inscription> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.only(top: 10),
            margin: EdgeInsets.all(30),
            child: Column(
              children: [
                Image.asset("assets/image/img3.png", width: 200),
                Text(
                  "Inscription",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Couleur.PremierColor,
                  ),
                ),
                Text(
                  "Bienvenue sur votre application ",
                  style: TextStyle(color: Couleur.PremierColor),
                ),
                SizedBox(height: 10),
                Form(
                  child: Column(
                    children: [
                      Inputs(
                        label: "Nom",
                        hint: " Votre Nom ",
                        icon: Icons.person,
                        iconColor: Couleur.PremierColor,
                      ),

                      Inputs(
                        label: "Pernom",
                        hint: " Votre Pernom",
                        icon: Icons.person,
                        iconColor: Couleur.PremierColor,
                      ),

                      Inputs(
                        label: "Email",
                        hint: " Votre Adresse Email ",
                        icon: Icons.email,
                        iconColor: Couleur.PremierColor,
                      ),

                      Inputs(
                        label: "Mots De Passe",
                        hint: "Votre Mots De Passe",
                        icon: Icons.lock,
                        iconColor: Couleur.PremierColor,
                        isPassword: true, // Active le mode mot de passe
                      ),
                      Inputs(
                        label: "Confirmer",
                        hint: "Confirme le Mots De Passe",
                        icon: Icons.lock,
                        iconColor: Couleur.PremierColor,
                        isPassword: true, // Active le mode mot de passe
                      ),

                      SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {},
                          child: Text(
                            "S'Inscrire",
                            style: TextStyle(color: Couleur.PremierColor),
                          ),
                        ),
                      ),

                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Vous avez un compte ?"),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) => Connexion(),
                                ),
                              );
                            },
                            child: Text(
                              " Connectez Vous",
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
