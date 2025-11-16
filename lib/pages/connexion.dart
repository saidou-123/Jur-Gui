// 🔴 NOUVEAU NOM DE CLASSE POUR CORRESPONDRE À main.dart
import 'package:depart/pages/connect.dart';
import 'package:depart/pages/inscription.dart' show Inscription;
import 'package:depart/widgets/carre.dart' show Carre;
import 'package:depart/widgets/couleur.dart';
import 'package:flutter/material.dart';

// 🟢 IMPORTS AJOUTÉS
import 'package:supabase_flutter/supabase_flutter.dart';
// Assurez-vous que le chemin est correct

// 🔴 J'ai renommé la classe en 'Connect' pour correspondre à votre main.dart
class Connexion extends StatefulWidget {
  const Connexion({super.key});

  @override
  State<Connexion> createState() => _ConnectState();
}

// 🔴 J'ai renommé la classe en '_ConnectState'
class _ConnectState extends State<Connexion> {
  // 🟢 STATE AJOUTÉ
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final supabase = Supabase.instance.client; // 🟢 Client Supabase

  @override
  void dispose() {
    // 🟢 Bonne pratique
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 🟢 FONCTION DE CONNEXION AJOUTÉE
  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Si la connexion réussit, on navigue
      if (response.user != null && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const Connect()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Erreur de connexion : ${e.toString()}"),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.only(top: 10),
            margin: const EdgeInsets.all(30),
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
                const SizedBox(height: 10),
                // 🟢 UTILISATION D'UN FORM ET DE TEXTFORMFIELDS
                Form(
                  key: _formKey, // 🟢 Clé de formulaire
                  child: Column(
                    children: [
                      // 🟢 Remplacement de Inputs par TextFormField
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: "Email",
                          hintText: " Votre Adresse Email ",
                          prefixIcon: Icon(Icons.email, color: Couleur.PremierColor),
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty || !value.contains('@')) {
                            return 'Veuillez entrer un email valide';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      // 🟢 Remplacement de Inputs par TextFormField
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true, // 🟢 Gère le mot de passe
                        decoration: InputDecoration(
                          labelText: "Mots De Passe",
                          hintText: "Votre Mots De Passe",
                          prefixIcon: Icon(Icons.lock, color: Couleur.PremierColor),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer votre mot de passe';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          // 🟢 Logique pour le bouton
                          onPressed: _isLoading ? null : _signIn,
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(
                                  "Se Connecter",
                                  style: TextStyle(color: Couleur.PremierColor),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: const [
                          Expanded(child: Divider(thickness: 0.5)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text("Ou continuer avec "),
                          ),
                          Expanded(child: Divider(thickness: 0.5)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Carre(path: "assets/image/img13.png"),
                          SizedBox(width: 10),
                          Carre(path: "assets/image/img13.png"),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Pas de compte ?"),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) => const Inscription(),
                                ),
                              );
                            },
                            child: const Text(
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