// ============================================================
// ARBRE GÉNÉALOGIQUE - MOUTONS LADOUM
// Fichier: lib/Eleveures/New/genealogique/ArbreGenealogique.dart
// ============================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:depart/widgets/couleur.dart';

// ─────────────────────────────────────────────────────────────
// MODÈLES
// ─────────────────────────────────────────────────────────────

enum StatutGenealogie { complet, pereInconnu, mereInconnue, parentsInconnus }

class AnimalNoeud {
  final String id;
  final String source;
  final String nom;
  final String sexe;
  final String? race;
  final String? imageUrl;
  final StatutGenealogie statutGenealogie;
  final String? pereId;
  final String? sourcePere;
  final String? mereId;
  final String? sourceMere;

  AnimalNoeud({
    required this.id,
    required this.source,
    required this.nom,
    required this.sexe,
    this.race,
    this.imageUrl,
    required this.statutGenealogie,
    this.pereId,
    this.sourcePere,
    this.mereId,
    this.sourceMere,
  });

  factory AnimalNoeud.fromMap(Map<String, dynamic> m, String source) {
    final pereId = m['pere_id']?.toString();
    final mereId = m['mere_id']?.toString();

    StatutGenealogie statut;
    if (pereId != null && mereId != null) {
      statut = StatutGenealogie.complet;
    } else if (pereId == null && mereId != null) {
      statut = StatutGenealogie.pereInconnu;
    } else if (pereId != null && mereId == null) {
      statut = StatutGenealogie.mereInconnue;
    } else {
      statut = StatutGenealogie.parentsInconnus;
    }

    return AnimalNoeud(
      id: m['id']?.toString() ?? '',
      source: source,
      nom: m['nom'] ?? 'Sans nom',
      sexe: m['sexe'] ?? '',
      race: m['race'],
      imageUrl: m['image_url'],
      statutGenealogie: statut,
      pereId: pereId,
      sourcePere: m['source_pere'],
      mereId: mereId,
      sourceMere: m['source_mere'],
    );
  }

  bool get estMale =>
      sexe.toLowerCase() == 'male' || sexe.toLowerCase() == 'mâle';

  String get labelStatut {
    switch (statutGenealogie) {
      case StatutGenealogie.complet:
        return 'Généalogie complète';
      case StatutGenealogie.pereInconnu:
        return 'Père inconnu';
      case StatutGenealogie.mereInconnue:
        return 'Mère inconnue';
      case StatutGenealogie.parentsInconnus:
        return 'Parents inconnus';
    }
  }
}

class ArbreNoeud {
  final AnimalNoeud animal;
  final ArbreNoeud? pere;
  final ArbreNoeud? mere;
  final int generation;

  ArbreNoeud({
    required this.animal,
    this.pere,
    this.mere,
    this.generation = 0,
  });
}

// ─────────────────────────────────────────────────────────────
// SERVICE SUPABASE
// ─────────────────────────────────────────────────────────────

class _GenealogieService {
  final _supabase = Supabase.instance.client;

  Future<AnimalNoeud?> fetchAnimal(String id, String source) async {
    final table = source == 'nee' ? 'nouveaux_nee' : 'animal_acheter';
    try {
      final res = await _supabase
          .from(table)
          .select(
              'id, nom, sexe, race, image_url, pere_id, mere_id, source_pere, source_mere')
          .eq('id', id)
          .maybeSingle();
      if (res == null) return null;
      return AnimalNoeud.fromMap(res, source);
    } catch (e) {
      debugPrint('⚠️ fetchAnimal error: $e');
      return null;
    }
  }

  Future<List<AnimalNoeud>> fetchTousAnimaux(String userId) async {
    try {
      final results = await Future.wait([
        _supabase
            .from('nouveaux_nee')
            .select(
                'id, nom, sexe, race, image_url, pere_id, mere_id, source_pere, source_mere')
            .eq('user_id', userId),
        _supabase
            .from('animal_acheter')
            .select('id, nom, sexe, race, image_url, pere_id, mere_id')
            .eq('user_id', userId),
      ]);

      final animaux = <AnimalNoeud>[];
      for (var a in results[0]) {
        animaux.add(AnimalNoeud.fromMap(a, 'nee'));
      }
      for (var a in results[1]) {
        animaux.add(AnimalNoeud.fromMap(a, 'achete'));
      }
      return animaux;
    } catch (e) {
      debugPrint('⚠️ fetchTousAnimaux error: $e');
      return [];
    }
  }

  Future<ArbreNoeud> buildArbre(
    String animalId,
    String source, {
    int maxGen = 3,
    int genActuelle = 0,
  }) async {
    final animal = await fetchAnimal(animalId, source);
    if (animal == null) {
      return ArbreNoeud(
        animal: AnimalNoeud(
          id: animalId,
          source: source,
          nom: 'Inconnu',
          sexe: '',
          statutGenealogie: StatutGenealogie.parentsInconnus,
        ),
        generation: genActuelle,
      );
    }

    ArbreNoeud? arbrePere;
    ArbreNoeud? arbreMere;

    if (genActuelle < maxGen) {
      // Les deux parents sont chargés en parallèle
      final futures = await Future.wait([
        if (animal.pereId != null && animal.sourcePere != null)
          buildArbre(
            animal.pereId!,
            animal.sourcePere!,
            maxGen: maxGen,
            genActuelle: genActuelle + 1,
          ),
        if (animal.mereId != null && animal.sourceMere != null)
          buildArbre(
            animal.mereId!,
            animal.sourceMere!,
            maxGen: maxGen,
            genActuelle: genActuelle + 1,
          ),
      ]);

      var i = 0;
      if (animal.pereId != null && animal.sourcePere != null) {
        arbrePere = futures[i++];
      }
      if (animal.mereId != null && animal.sourceMere != null) {
        arbreMere = futures[i++];
      }
    }

    return ArbreNoeud(
      animal: animal,
      pere: arbrePere,
      mere: arbreMere,
      generation: genActuelle,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PAGE PRINCIPALE — Point d'entrée depuis interfaceEleveur
// ─────────────────────────────────────────────────────────────

class ArbreGenealogique extends StatefulWidget {
  const ArbreGenealogique({super.key});

  @override
  State<ArbreGenealogique> createState() => _ArbreGeneralogiqueState();
}

class _ArbreGeneralogiqueState extends State<ArbreGenealogique> {
  // Dimensions utilisées pour le calcul de la mise en page de l'arbre
  static const double _largeurRacine = 140.0;
  static const double _largeurNoeud = 118.0;
  static const double _espaceEntreParents = 16.0;
  static const double _hauteurConnecteur = 36.0;
  static const double _hauteurNoeud = 118.0;
  static const double _hauteurRacine = 145.0;
  static const double _paddingArbre = 40.0;

  final _service = _GenealogieService();
  final _supabase = Supabase.instance.client;
  final _transfoCtrl = TransformationController();

  List<AnimalNoeud> _animaux = [];
  AnimalNoeud? _animalSelectionne;
  ArbreNoeud? _arbre;
  bool _loadingListe = true;
  bool _loadingArbre = false;
  bool _doitCentrer = false;
  String? _erreur;
  int _maxGenerations = 3;
  AnimalNoeud? _noeudDetail;
  final _searchCtrl = TextEditingController();
  String _recherche = '';

  @override
  void initState() {
    super.initState();
    _chargerAnimaux();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _transfoCtrl.dispose();
    super.dispose();
  }

  Future<void> _chargerAnimaux() async {
    setState(() => _loadingListe = true);
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _loadingListe = false;
        _erreur = 'Non connecté';
      });
      return;
    }
    final animaux = await _service.fetchTousAnimaux(userId);
    if (!mounted) return;
    setState(() {
      _animaux = animaux;
      _loadingListe = false;
    });
  }

  Future<void> _selectionnerAnimal(AnimalNoeud animal) async {
    setState(() {
      _animalSelectionne = animal;
      _loadingArbre = true;
      _arbre = null;
      _noeudDetail = null;
    });
    final arbre = await _service.buildArbre(
      animal.id,
      animal.source,
      maxGen: _maxGenerations,
    );
    // L'utilisateur a pu quitter la page ou choisir un autre animal
    if (!mounted || _animalSelectionne?.id != animal.id) return;
    setState(() {
      _arbre = arbre;
      _loadingArbre = false;
      _doitCentrer = true;
    });
  }

  List<AnimalNoeud> get _animauxFiltres {
    if (_recherche.isEmpty) return _animaux;
    return _animaux
        .where((a) => a.nom.toLowerCase().contains(_recherche.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 241, 248, 233),
      appBar: _buildAppBar(),
      body: _loadingListe
          ? Center(child: CircularProgressIndicator(color: Couleur.PremierColor))
          : _erreur != null
              ? Center(child: Text(_erreur!))
              : _animalSelectionne == null
                  ? _buildEcranSelection()
                  : _buildEcranArbre(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        _animalSelectionne == null
            ? 'Arbre Généalogique'
            : _animalSelectionne!.nom,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      backgroundColor: Colors.white,
      foregroundColor: Couleur.PremierColor,
      elevation: 2,
      leading: _animalSelectionne != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() {
                _animalSelectionne = null;
                _arbre = null;
                _noeudDetail = null;
              }),
            )
          : null,
      actions: _animalSelectionne != null
          ? [
              PopupMenuButton<int>(
                icon: const Icon(Icons.layers),
                tooltip: 'Générations',
                onSelected: (val) {
                  setState(() => _maxGenerations = val);
                  _selectionnerAnimal(_animalSelectionne!);
                },
                itemBuilder: (_) => [1, 2, 3, 4]
                    .map((g) => PopupMenuItem(
                          value: g,
                          child: Row(
                            children: [
                              Icon(
                                Icons.check,
                                size: 16,
                                color: _maxGenerations == g
                                    ? Couleur.PremierColor
                                    : Colors.transparent,
                              ),
                              const SizedBox(width: 8),
                              Text('$g génération${g > 1 ? 's' : ''}'),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ]
          : null,
    );
  }

  // ── Écran 1 : Sélection de l'animal ─────────────────────────

  Widget _buildEcranSelection() {
    return Column(
      children: [
        // Barre de recherche
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _recherche = v),
            decoration: InputDecoration(
              hintText: 'Rechercher un animal...',
              prefixIcon: Icon(Icons.search, color: Couleur.PremierColor),
              suffixIcon: _recherche.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _recherche = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
            ),
          ),
        ),

        // Compteur
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                '${_animauxFiltres.length} animal(aux)',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const Spacer(),
              Text(
                'Appuyez pour voir l\'arbre',
                style: TextStyle(color: Couleur.PremierColor, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Liste
        Expanded(
          child: _animauxFiltres.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 60, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text('Aucun animal trouvé',
                          style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _animauxFiltres.length,
                  itemBuilder: (_, i) => _buildCarteAnimal(_animauxFiltres[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildCarteAnimal(AnimalNoeud animal) {
    final couleur =
        animal.estMale ? const Color(0xFF1A5276) : const Color(0xFF922B21);
    final couleurStatut = _couleurStatut(animal.statutGenealogie);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: couleur.withOpacity(0.1),
          backgroundImage:
              animal.imageUrl != null ? NetworkImage(animal.imageUrl!) : null,
          child: animal.imageUrl == null
              ? Icon(Icons.pets, color: couleur, size: 24)
              : null,
        ),
        title: Text(
          animal.nom,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${animal.estMale ? "Bélier" : "Brebis"}'
              '${animal.race != null ? " · ${animal.race}" : ""}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: couleurStatut.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: couleurStatut, width: 0.8),
              ),
              child: Text(
                animal.labelStatut,
                style: TextStyle(
                    fontSize: 10,
                    color: couleurStatut,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        trailing: Icon(Icons.account_tree, color: Couleur.PremierColor),
        onTap: () => _selectionnerAnimal(animal),
      ),
    );
  }

  // ── Écran 2 : Arbre généalogique ────────────────────────────

  Widget _buildEcranArbre() {
    return Column(
      children: [
        // Détail nœud sélectionné
        if (_noeudDetail != null) _buildPanneauDetail(_noeudDetail!),

        // Arbre
        Expanded(
          child: _loadingArbre
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Couleur.PremierColor),
                      const SizedBox(height: 12),
                      Text(
                        'Construction de l\'arbre...',
                        style: TextStyle(color: Couleur.PremierColor),
                      ),
                    ],
                  ),
                )
              : _arbre == null
                  ? const Center(child: Text('Aucune donnée'))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        // Centre / ajuste l'arbre une fois après chaque chargement
                        if (_doitCentrer) {
                          _doitCentrer = false;
                          final viewport = constraints.biggest;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) _centrerArbre(viewport);
                          });
                        }

                        return InteractiveViewer(
                          // ✅ CORRECTION PRINCIPALE : l'enfant prend sa taille
                          // naturelle au lieu d'être forcé à la largeur de l'écran
                          constrained: false,
                          transformationController: _transfoCtrl,
                          boundaryMargin: const EdgeInsets.all(300),
                          minScale: 0.1,
                          maxScale: 2.5,
                          child: Padding(
                            padding: const EdgeInsets.all(_paddingArbre),
                            child: _buildNoeudArbre(_arbre!),
                          ),
                        );
                      },
                    ),
        ),

        // Légende
        _buildLegende(),
      ],
    );
  }

  /// Ajuste le zoom et centre l'arbre dans la zone visible.
  void _centrerArbre(Size viewport) {
    if (_arbre == null) return;

    final contenuW = _largeurArbre(_arbre!) + _paddingArbre * 2;
    final contenuH = _maxGenerations * (_hauteurNoeud + _hauteurConnecteur) +
        _hauteurRacine +
        _paddingArbre * 2;

    final echelle = math
        .min(1.0, math.min(viewport.width / contenuW, viewport.height / contenuH))
        .clamp(0.1, 1.0)
        .toDouble();

    final dx = (viewport.width - contenuW * echelle) / 2;
    final dy = (viewport.height - contenuH * echelle) / 2;

    _transfoCtrl.value = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(echelle);
  }

  // ── Calcul des largeurs (pour aligner les connecteurs) ──────

  double _largeurArbre(ArbreNoeud noeud) {
    final largeurNoeud =
        noeud.generation == 0 ? _largeurRacine : _largeurNoeud;
    if (noeud.generation >= _maxGenerations) return largeurNoeud;

    final total = _largeurCote(noeud.pere) +
        _espaceEntreParents +
        _largeurCote(noeud.mere);
    return math.max(largeurNoeud, total);
  }

  double _largeurCote(ArbreNoeud? arbre) =>
      arbre == null ? _largeurNoeud : _largeurArbre(arbre);

  // ── Construction récursive de l'arbre ───────────────────────

  Widget _buildNoeudArbre(ArbreNoeud noeud) {
    final estRacine = noeud.generation == 0;
    final afficherParents = noeud.generation < _maxGenerations;

    // Dernière génération : on affiche juste le nœud
    if (!afficherParents) {
      return _buildNoeud(noeud.animal, estRacine: estRacine);
    }

    final largeurPere = _largeurCote(noeud.pere);
    final largeurMere = _largeurCote(noeud.mere);
    final largeurTotale = largeurPere + _espaceEntreParents + largeurMere;

    // Position (en x) du centre de chaque parent dans la rangée
    final xPere = largeurPere / 2;
    final xMere = largeurPere + _espaceEntreParents + largeurMere / 2;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Rangée parents
        SizedBox(
          width: largeurTotale,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildCote(arbre: noeud.pere, estPere: true),
              const SizedBox(width: _espaceEntreParents),
              _buildCote(arbre: noeud.mere, estPere: false),
            ],
          ),
        ),

        // Connecteur : s'aligne exactement sur le centre de chaque parent
        SizedBox(
          width: largeurTotale,
          height: _hauteurConnecteur,
          child: CustomPaint(
            painter: _ConnecteurPainter(
              couleur: Couleur.PremierColor,
              xParents: [xPere, xMere],
            ),
          ),
        ),

        // Nœud courant
        _buildNoeud(noeud.animal, estRacine: estRacine),
      ],
    );
  }

  Widget _buildCote({ArbreNoeud? arbre, required bool estPere}) {
    if (arbre != null) return _buildNoeudArbre(arbre);
    return _buildNoeudInconnu(estPere ? 'Père inconnu' : 'Mère inconnue');
  }

  Widget _buildNoeud(AnimalNoeud animal, {bool estRacine = false}) {
    final estSelectionne = _noeudDetail?.id == animal.id;
    final couleur =
        animal.estMale ? const Color(0xFF1A5276) : const Color(0xFF922B21);
    final largeur = estRacine ? _largeurRacine : _largeurNoeud;

    return GestureDetector(
      onTap: () =>
          setState(() => _noeudDetail = estSelectionne ? null : animal),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: largeur,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: estSelectionne ? Colors.amber : couleur,
            width: estSelectionne ? 3 : (estRacine ? 2.5 : 1.5),
          ),
          boxShadow: [
            BoxShadow(
              color: couleur.withOpacity(estRacine ? 0.25 : 0.12),
              blurRadius: estRacine ? 12 : 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // En-tête
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: couleur,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    animal.estMale ? Icons.male : Icons.female,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      animal.nom,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: estRacine ? 13 : 11,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Corps
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: estRacine ? 24 : 18,
                    backgroundColor: couleur.withOpacity(0.1),
                    backgroundImage: animal.imageUrl != null
                        ? NetworkImage(animal.imageUrl!)
                        : null,
                    child: animal.imageUrl == null
                        ? Icon(Icons.pets,
                            color: couleur, size: estRacine ? 24 : 18)
                        : null,
                  ),
                  const SizedBox(height: 4),
                  if (animal.race != null)
                    Text(
                      animal.race!,
                      style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  _buildPastilleStatut(animal.statutGenealogie),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoeudInconnu(String label) {
    return Container(
      width: _largeurNoeud,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[400]!, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Text(
              label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey[200],
                  child: Icon(Icons.help_outline,
                      color: Colors.grey[500], size: 20),
                ),
                const SizedBox(height: 4),
                Text(
                  'Non identifié',
                  style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPastilleStatut(StatutGenealogie statut) {
    if (statut == StatutGenealogie.complet) return const SizedBox.shrink();
    final couleur = statut == StatutGenealogie.parentsInconnus
        ? Colors.red
        : Colors.orange;
    final texte = statut == StatutGenealogie.parentsInconnus
        ? 'Parents ?'
        : statut == StatutGenealogie.pereInconnu
            ? 'Père ?'
            : 'Mère ?';
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: couleur.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: couleur, width: 0.8),
      ),
      child: Text(
        texte,
        style: TextStyle(
            fontSize: 8, color: couleur, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildPanneauDetail(AnimalNoeud animal) {
    final couleur =
        animal.estMale ? const Color(0xFF1A5276) : const Color(0xFF922B21);
    return Container(
      color: couleur,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white24,
            backgroundImage: animal.imageUrl != null
                ? NetworkImage(animal.imageUrl!)
                : null,
            child: animal.imageUrl == null
                ? const Icon(Icons.pets, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  animal.nom,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                Text(
                  '${animal.estMale ? "Bélier" : "Brebis"}'
                  '${animal.race != null ? " · ${animal.race}" : ""}'
                  ' · ${animal.labelStatut}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => setState(() => _noeudDetail = null),
          ),
        ],
      ),
    );
  }

  Widget _buildLegende() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _legendeItem(const Color(0xFF1A5276), Icons.male, 'Bélier'),
          _legendeItem(const Color(0xFF922B21), Icons.female, 'Brebis'),
          _legendeItem(Colors.grey, Icons.help_outline, 'Inconnu'),
          _legendeItem(Colors.orange, Icons.warning_amber, 'Partiel'),
          _legendeItem(Colors.amber, Icons.touch_app, 'Sélectionné'),
        ],
      ),
    );
  }

  Widget _legendeItem(Color couleur, IconData icone, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, color: couleur, size: 18),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

  Color _couleurStatut(StatutGenealogie s) {
    switch (s) {
      case StatutGenealogie.complet:
        return Colors.green;
      case StatutGenealogie.pereInconnu:
      case StatutGenealogie.mereInconnue:
        return Colors.orange;
      case StatutGenealogie.parentsInconnus:
        return Colors.red;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// PAINTER : lignes de connexion (père + mère → enfant)
// ─────────────────────────────────────────────────────────────

class _ConnecteurPainter extends CustomPainter {
  final Color couleur;

  /// Positions x (centre) de chaque parent, relatives à la largeur du connecteur
  final List<double> xParents;

  _ConnecteurPainter({required this.couleur, required this.xParents});

  @override
  void paint(Canvas canvas, Size size) {
    if (xParents.isEmpty) return;

    final paint = Paint()
      ..color = couleur.withOpacity(0.4)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final cy = size.height / 2;
    final cx = size.width / 2; // l'enfant est centré sous la rangée

    // Traits verticaux depuis chaque parent
    for (final x in xParents) {
      canvas.drawLine(Offset(x, 0), Offset(x, cy), paint);
    }

    // Trait horizontal reliant les parents
    if (xParents.length > 1) {
      canvas.drawLine(
        Offset(xParents.first, cy),
        Offset(xParents.last, cy),
        paint,
      );
    }

    // Trait vertical vers l'enfant
    canvas.drawLine(Offset(cx, cy), Offset(cx, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _ConnecteurPainter old) =>
      old.couleur != couleur || old.xParents.join() != xParents.join();
}