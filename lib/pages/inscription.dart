import 'package:depart/pages/connexion.dart';
import 'package:depart/widgets/couleur.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// 1. PAGE D'INSCRIPTION AVEC SÉLECTION DU RÔLE
// ============================================================
class Inscription extends StatefulWidget {
  const Inscription({super.key});

  @override
  State<Inscription> createState() => _InscriptionState();
}

class _InscriptionState extends State<Inscription> {
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  String? _roleSelectionne; // "eleveur" ou "veterinaire"
  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (_roleSelectionne == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("⚠️ Veuillez sélectionner votre rôle (Éleveur ou Vétérinaire)"),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("❌ Les mots de passe ne correspondent pas"),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      // ✅ CORRECTION: Stocker les données dans user_metadata
      final response = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {
          'nom': _nomController.text.trim(),
          'prenom': _prenomController.text.trim(),
          'role': _roleSelectionne,
        },
      );

      if (response.user != null && mounted) {
        // ✅ Le trigger va automatiquement insérer dans la table users
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("✅ Inscription réussie ! Vérifiez votre email pour confirmer votre compte."),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 10),
        ));
        
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const Connexion()),
        );
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
                  "Bienvenue sur Jur Gui 4.0",
                  style: TextStyle(color: Couleur.PremierColor),
                ),
                const SizedBox(height: 20),
                
                // ===== SÉLECTION DU RÔLE =====
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "👤 Sélectionnez votre rôle :",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildRoleCard(
                              role: 'eleveur',
                              titre: '🐑 Éleveur',
                              description: 'Gérer mon troupeau',
                              icone: Icons.agriculture,
                              couleur: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildRoleCard(
                              role: 'veterinaire',
                              titre: '⚕️ Vétérinaire',
                              description: 'Gérer la santé',
                              icone: Icons.medical_services,
                              couleur: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nomController,
                        decoration: InputDecoration(
                          labelText: "Nom",
                          hintText: "Votre nom",
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
                          hintText: "Votre prénom",
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
                          hintText: "votre.email@example.com",
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
                          labelText: "Mot de passe",
                          hintText: "Minimum 6 caractères",
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
                          labelText: "Confirmer le mot de passe",
                          hintText: "Retapez votre mot de passe",
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
                          onPressed: _isLoading ? null : _signUp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Couleur.PremierColor,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  "S'inscrire",
                                  style: TextStyle(color: Colors.white, fontSize: 16),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Vous avez déjà un compte ?"),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (context) => const Connexion()),
                              );
                            },
                            child: const Text(
                              " Connectez-vous",
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

  Widget _buildRoleCard({
    required String role,
    required String titre,
    required String description,
    required IconData icone,
    required Color couleur,
  }) {
    final estSelectionne = _roleSelectionne == role;
    
    return GestureDetector(
      onTap: () => setState(() => _roleSelectionne = role),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: estSelectionne ? couleur.withOpacity(0.2) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: estSelectionne ? couleur : Colors.grey.shade300,
            width: estSelectionne ? 3 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icone, size: 40, color: couleur),
            const SizedBox(height: 8),
            Text(
              titre,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: couleur,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
            if (estSelectionne)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Icon(Icons.check_circle, color: couleur, size: 24),
              ),
          ],
        ),
      ),
    );
  }
}
