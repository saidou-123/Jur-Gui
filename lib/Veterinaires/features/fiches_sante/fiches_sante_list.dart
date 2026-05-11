import 'package:depart/Eleveures/Mon%20Troupeau/SupprimerAnimal/AnimalService.dart';
import 'package:depart/Eleveures/Mon%20Troupeau/SupprimerAnimal/Animalmodel.dart';
import 'package:depart/Veterinaires/constantes/widgets/animal_card.dart';
import 'package:depart/Veterinaires/features/fiches_sante/fiche_sante_detail.dart';
import 'package:flutter/material.dart';


class FichesSante extends StatefulWidget {
  const FichesSante({super.key});

  @override
  State<FichesSante> createState() => _FichesSanteState();
}

class _FichesSanteState extends State<FichesSante> {
  final _animalSvc = AnimalService();
  List<AnimalModel> _animaux = [];
  bool _isLoading = true;
  String _search = '';
  String _filtreSource = 'Tous'; // Tous | Né | Acheté

  @override
  void initState() { super.initState(); _charger(); }

  Future<void> _charger() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final animaux = await _animalSvc.chargerAnimaux();
      if (mounted) setState(() { _animaux = animaux; _isLoading = false; });
    } catch (e) {
      debugPrint('Erreur: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<AnimalModel> get _filtrés {
    return _animaux.where((a) {
      final q = _search.toLowerCase();
      final matchSearch = q.isEmpty ||
          a.nom.toLowerCase().contains(q) ||
          (a.race?.toLowerCase().contains(q) ?? false) ||
          a.tagRfid.toLowerCase().contains(q);
      final matchSource = _filtreSource == 'Tous' ||
          (_filtreSource == 'Né' && a.source == 'nee') ||
          (_filtreSource == 'Acheté' && a.source == 'achete');
      return matchSearch && matchSource;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Fiches Santé (${_animaux.length})'),
        backgroundColor: Colors.green[700],
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _charger)],
      ),
      body: Column(children: [
        _buildSearchBar(),
        _buildFiltreChips(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filtrés.isEmpty
                  ? EmptyState(
                      icon: Icons.folder_open,
                      message: _search.isEmpty ? 'Aucun animal enregistré' : 'Aucun résultat',
                      subMessage: _search.isEmpty ? 'Les animaux apparaîtront ici' : 'Modifiez votre recherche',
                      onAction: _search.isEmpty ? null : () => setState(() => _search = ''),
                      actionLabel: 'Effacer la recherche',
                    )
                  : RefreshIndicator(
                      onRefresh: _charger,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filtrés.length,
                        itemBuilder: (_, i) {
                          final a = _filtrés[i];
                          return AnimalCard(
                            animal: a,
                            onTap: () => _ouvrirFiche(a),
                          );
                        },
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _buildSearchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: TextField(
      onChanged: (v) => setState(() => _search = v),
      decoration: InputDecoration(
        hintText: 'Rechercher par nom, race, RFID...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _search.isNotEmpty
            ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _search = ''))
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
      ),
    ),
  );

  Widget _buildFiltreChips() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(children: ['Tous', 'Né', 'Acheté'].map((f) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(f),
        selected: _filtreSource == f,
        onSelected: (_) => setState(() => _filtreSource = f),
        selectedColor: Colors.green[200],
        checkmarkColor: Colors.green[900],
      ),
    )).toList()),
  );

  Future<void> _ouvrirFiche(AnimalModel a) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => FicheSanteDetail(animal: a.toMap(), source: a.source),
    ));
    _charger();
  }
}