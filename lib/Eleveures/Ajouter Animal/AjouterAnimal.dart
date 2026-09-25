// ============================================================
// AJOUTER ANIMAL - VERSION REDESIGN
// Fichier: lib/pages/AjouterAnimal/AjouterAnimal.dart
// ============================================================

import 'package:depart/Eleveures/Ajouter%20Animal/AnimalAchateBluetooth.dart';
import 'package:depart/Eleveures/Ajouter%20Animal/NouveauNeeBluetooth.dart';
import 'package:depart/widgets/couleur.dart';
import 'package:flutter/material.dart';

class AjouterAnimal extends StatelessWidget {
  const AjouterAnimal({super.key});

  static const Color _vert = const Color.fromARGB(255, 5, 87, 46); 
  static const Color _vertClair =const Color.fromARGB(255, 0, 149, 75);
  static const Color _fond = Color(0xFFF5F8F4);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Couleur.TroisciemeColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          " Enrigistrer un animal",
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3,color:Colors.white ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const _Header(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Comment souhaitez-vous\najouter un animal ?",
                    style: TextStyle(
                      fontSize: 22,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B2A1C),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Choisissez l'origine de l'animal pour continuer.",
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  _OptionCard(
                    image: 'assets/image/img6.png',
                    titre: "Nouveau-né",
                    sousTitre: "Un agneau né dans votre élevage",
                    couleur: const Color(0xFFE8F5E9),
                    accent: _vert,
                    icone: Icons.child_care_rounded,
                    page: const NouveauNeeBluetooth(),
                  ),
                  const SizedBox(height: 16),
                  _OptionCard(
                    image: 'assets/image/img10.png',
                    titre: "Animal acheté",
                    sousTitre: "Un animal acquis à l'extérieur",
                    couleur: const Color(0xFFFFF3E0),
                    accent: const Color(0xFFEF6C00),
                    icone: Icons.shopping_bag_rounded,
                    page: const AnimalAchateBluetooth(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// En-tête avec dégradé et image
// ------------------------------------------------------------
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + kToolbarHeight,
        bottom: 32,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AjouterAnimal._vert, AjouterAnimal._vertClair],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Cercle décoratif en arrière-plan
          Container(
            width: 230,
            height: 230,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x26FFFFFF),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                "assets/image/img6.png",
                height: 170,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Carte d'option
// ------------------------------------------------------------
class _OptionCard extends StatelessWidget {
  final String image;
  final String titre;
  final String sousTitre;
  final Color couleur;
  final Color accent;
  final IconData icone;
  final Widget page;

  const _OptionCard({
    required this.image,
    required this.titre,
    required this.sousTitre,
    required this.couleur,
    required this.accent,
    required this.icone,
    required this.page,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => page),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: couleur, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // Vignette image
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: couleur,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(image, fit: BoxFit.contain),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Textes
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icone, size: 18, color: accent),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            titre,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1B2A1C),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      sousTitre,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // Flèche
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: couleur,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 15,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}