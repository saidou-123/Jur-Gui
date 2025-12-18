import 'package:depart/pages/Interface/interfaceElevaur.dart';
import 'package:depart/pages/Interface/interfaceVeterinaire/interfaceVeterinaire.dart';
import 'package:depart/pages/inscription.dart';
import 'package:depart/widgets/couleur.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Connexion extends StatefulWidget {
  const Connexion({super.key});

  @override
  State<Connexion> createState() => _ConnexionState();
}

class _ConnexionState extends State<Connexion> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    try {
      // 1. Authentification
      final response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null) {
        // 2. Récupérer le rôle de l'utilisateur
        final userData = await supabase
            .from('users')
            .select('role')
            .eq('id', response.user!.id)
            .maybeSingle();

        if (userData == null) {
          // Solution de secours : récupérer depuis user_metadata
          final role = response.user!.userMetadata?['role'] as String? ?? 'eleveur';
          
          // Créer l'entrée manquante
          await supabase.from('users').insert({
            'id': response.user!.id,
            'email': response.user!.email,
            'nom': response.user!.userMetadata?['nom'] ?? 'Non renseigné',
            'prenom': response.user!.userMetadata?['prenom'] ?? 'Non renseigné',
            'role': role,
          });
          
          _navigateByRole(role);
        } else {
          final role = userData['role'] as String;
          _navigateByRole(role);
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("❌ ${e.message}"),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("❌ Erreur : ${e.toString()}"),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateByRole(String role) {
    if (!mounted) return;
    
    if (role == 'eleveur') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const interfaceElevaur()),
      );
    } else if (role == 'veterinaire') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const interfaceVeterinaire()),
      );
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
                  "Bienvenue sur Jur Gui 4.0",
                  style: TextStyle(color: Couleur.PremierColor),
                ),
                const SizedBox(height: 20),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: "Email",
                          hintText: "votre.email@example.com",
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
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: "Mot de passe",
                          hintText: "Votre mot de passe",
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
                          onPressed: _isLoading ? null : _signIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Couleur.PremierColor,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  "Se connecter",
                                  style: TextStyle(color: Colors.white, fontSize: 16),
                                ),
                        ),
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
                              " Inscrivez-vous",
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