import 'package:depart/pages/connexion.dart';
import 'package:depart/widgets/couleur.dart';
// import 'package:depart/widgets/inputs.dart'; // On n'utilise plus
import 'package:flutter/material.dart';

// 🟢 IMPORTS AJOUTÉS
import 'package:supabase_flutter/supabase_flutter.dart';

class Inscription extends StatefulWidget {
  const Inscription({super.key});

  @override
  State<Inscription> createState() => _InscriptionState();
}

class _InscriptionState extends State<Inscription> {
  // 🟢 STATE AJOUTÉ
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController(); // "Pernom" corrigé en "Prenom"
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final supabase = Supabase.instance.client; // 🟢 Client Supabase

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // 🟢 FONCTION D'INSCRIPTION AJOUTÉE
  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Les mots de passe ne correspondent pas"),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        // 🟢 On peut ajouter des données utilisateur (nom, etc.) ici
        data: {
          'full_name': '${_prenomController.text} ${_nomController.text}',
        },
      );

      if (response.user != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Inscription réussie ! Veuillez vérifier vos e-mails pour confirmer."),
          backgroundColor: Colors.green,
        ));
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const Connexion()), // Renvoie à la page de connexion
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Erreur d'inscription : ${e.toString()}"),
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
                const SizedBox(height: 10),
                // 🟢 UTILISATION D'UN FORM ET DE TEXTFORMFIELDS
                Form(
                  key: _formKey, // 🟢 Clé
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nomController,
                        decoration: InputDecoration(
                          labelText: "Nom",
                          hintText: " Votre Nom ",
                          prefixIcon: Icon(Icons.person, color: Couleur.PremierColor),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (val) => val!.isEmpty ? 'Champ requis' : null,
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _prenomController,
                        decoration: InputDecoration(
                          labelText: "Prénom",
                          hintText: " Votre Prénom",
                          prefixIcon: Icon(Icons.person, color: Couleur.PremierColor),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (val) => val!.isEmpty ? 'Champ requis' : null,
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: "Email",
                          hintText: " Votre Adresse Email ",
                          prefixIcon: Icon(Icons.email, color: Couleur.PremierColor),
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (val) => (val == null || !val.contains('@')) ? 'Email invalide' : null,
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: "Mots De Passe",
                          hintText: "Votre Mots De Passe",
                          prefixIcon: Icon(Icons.lock, color: Couleur.PremierColor),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (val) => (val == null || val.length < 6) ? 'Minimum 6 caractères' : null,
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: "Confirmer",
                          hintText: "Confirme le Mots De Passe",
                          prefixIcon: Icon(Icons.lock, color: Couleur.PremierColor),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (val) => (val == null || val.isEmpty) ? 'Champ requis' : null,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          // 🟢 Logique pour le bouton
                          onPressed: _isLoading ? null : _signUp,
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(
                                  "S'Inscrire",
                                  style: TextStyle(color: Couleur.PremierColor),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Vous avez un compte ?"),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) => const Connexion(), // 🔴 Doit être 'Connect'
                                ),
                              );
                            },
                            child: const Text(
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