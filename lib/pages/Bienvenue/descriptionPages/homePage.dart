import 'package:depart/pages/Bienvenue/connexion.dart';
import 'package:depart/pages/Bienvenue/descriptionPages/welcomePage.dart';
import 'package:depart/pages/Bienvenue/descriptionPages/welcomePage2.dart';
import 'package:depart/pages/Bienvenue/descriptionPages/welcomePage3.dart';
import 'package:depart/widgets/couleur.dart';
import 'package:flutter/material.dart';

import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  final _controller = PageController();

  static const int _pageCount = 3;
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLastPage => _currentPage == _pageCount - 1;

  void _goToConnexion() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const Connexion()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      _controller.previousPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: const Icon(Icons.chevron_left, size: 24),
                  ),
                  GestureDetector(
                    onTap: () {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: const Text("Suivant", style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SizedBox(
                    height: 500,
                    child: PageView(
                      controller: _controller,
                      onPageChanged: (index) {
                        setState(() => _currentPage = index);
                      },
                      children: const [
                        Welcomepage(),
                        Welcomepage2(),
                        Welcomepage3(),
                      ],
                    ),
                  ),
                  SmoothPageIndicator(controller: _controller, count: _pageCount),
                ],
              ),
              const SizedBox(height: 24),
              // ★ Le bouton "Commencer" n'apparaît que sur la dernière page.
              //   AnimatedSwitcher évite un saut brutal de mise en page.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _isLastPage
                    ? SizedBox(
                        key: const ValueKey('bouton_commencer'),
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _goToConnexion,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Couleur.PremierColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Commencer",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox(
                        key: ValueKey('espace_vide'),
                        height: 52,
                      ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}