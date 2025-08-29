import 'package:depart/pages/inscription.dart' show Inscription;
import 'package:depart/widgets/carre.dart' show Carre;
import 'package:depart/widgets/inputs.dart';
import 'package:flutter/material.dart';
import 'package:depart/widgets/couleur.dart';

class Connexion extends StatefulWidget {
  const Connexion({super.key});

  @override
  State<Connexion> createState() => _ConnexionState();
}

class _ConnexionState extends State<Connexion> {
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
                  "Connexion",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Couleur.PremierColor,
                  ),
                ),
                Text(
                  "Bienvenue a nouveau sur votre application ",
                  style: TextStyle(color: Couleur.PremierColor),
                ),
                SizedBox(height: 10),
                Form(
                  child: Column(
                    children: [
                      Inputs(
                        label: "Email",
                        hint: " Votre Adresse Email ",
                        iconColor: Couleur.PremierColor,
                        icon: Icons.email,
                      ),

                      Inputs(
                        label: "Mots De Passe",
                        hint: "Votre Mots De Passe",
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
                            "Se Connecter",
                            style: TextStyle(color: Couleur.PremierColor),
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: Divider(thickness: 0.5)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text("Ou continuer avec "),
                          ),
                          Expanded(child: Divider(thickness: 0.5)),
                        ],
                      ),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Carre(path: "assets/image/img13.png"),
                          SizedBox(width: 10),
                          Carre(path: "assets/image/img13.png"),
                        ],
                      ),

                      SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Pas de compte ?"),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) => Inscription(),
                                ),
                              );
                            },
                            child: Text(
                              "Inscrivez Vous",
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
