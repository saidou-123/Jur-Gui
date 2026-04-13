// ============================================================
// 🐑 AnimalDeletePage — VERSION REFACTORISÉE & OPTIMISÉE
// Architecture : UI → Service → Repository → Supabase
// ============================================================

import 'package:depart/Eleveures/Mon%20Troupeau/SupprimerAnimal/AnimalService.dart';
import 'package:depart/Eleveures/Mon%20Troupeau/SupprimerAnimal/AnimalStatsDashboard.dart';
import 'package:depart/Eleveures/Mon%20Troupeau/SupprimerAnimal/Animalmodel.dart';
import 'package:depart/Eleveures/Mon%20Troupeau/SupprimerAnimal/MotifSelectionSheet.dart';
import 'package:depart/Eleveures/Mon%20Troupeau/SupprimerAnimal/TransfertResult.dart';
import 'package:flutter/material.dart';


class AnimalDeletePage extends StatefulWidget {
  const AnimalDeletePage({super.key});

  @override
  State<AnimalDeletePage> createState() => _AnimalDeletePageState();
}

class _AnimalDeletePageState extends State<AnimalDeletePage> {
  // ----------------------------------------------------------
  // 🧠 État
  // ----------------------------------------------------------
  final _service = AnimalService();
  List<AnimalModel> _animals = [];
  Map<String, int> _stats = {};
  bool _isLoading = true;
  bool _showStats = false;
  String _filtre = 'Tout';

  static const _filtres = ['Tout', 'Nouveau_nee', 'Animal_acheter'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ----------------------------------------------------------
  // 📥 CHARGEMENT DES DONNÉES
  // ----------------------------------------------------------
  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final animals = await _service.getAnimauxActifs(filtre: _filtre);
      final stats = await _service.getStatistiques();

      if (mounted) {
        setState(() {
          _animals = animals;
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Erreur de chargement: ${e.toString()}', isError: true);
      }
    }
  }

  // ----------------------------------------------------------
  // 🗑️ FLUX COMPLET DE SUPPRESSION
  // ----------------------------------------------------------
  Future<void> _startDeleteFlow(AnimalModel animal) async {
    // ÉTAPE 1 : Choisir le motif
    final motif = await showMotifSelectionSheet(context, animal);
    if (motif == null || !mounted) return;

    // ÉTAPE 2 : Cas spécial vente → proposer le transfert
    String? transfertVersUserId;
    if (motif == AnimalStatut.vendu) {
      final transfert = await showTransfertDialog(context, _service);
      if (transfert == null || !mounted) return; // Annulé

      if (transfert.confirme && transfert.eleveurId != null) {
        transfertVersUserId = transfert.eleveurId;
      }
    }

    // ÉTAPE 3 : Confirmer la suppression
    final confirme = await _showConfirmationDialog(animal, motif);
    if (confirme != true || !mounted) return;

    // ÉTAPE 4 : Exécuter la suppression
    await _executerSuppression(
      animal: animal,
      motif: motif,
      transfertVersUserId: transfertVersUserId,
    );
  }

  Future<void> _executerSuppression({
    required AnimalModel animal,
    required AnimalStatut motif,
    String? transfertVersUserId,
  }) async {
    // Afficher le loading
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _LoadingDialog(),
      );
    }

    try {
      await _service.supprimerAnimal(
        animal: animal,
        motif: motif,
        transfertVersUserId: transfertVersUserId,
      );

      if (mounted) {
        Navigator.pop(context); // Fermer le loading
        final message = transfertVersUserId != null
            ? '✅ ${animal.nom} marqué en attente de transfert'
            : '✅ ${animal.nom} retiré avec succès (${motif.label})';
        _showSnackBar(message);
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Fermer le loading
        _showSnackBar('Erreur: ${e.toString()}', isError: true);
      }
    }
  }

  // ----------------------------------------------------------
  // 🛑 DIALOG DE CONFIRMATION FINALE
  // ----------------------------------------------------------
  Future<bool?> _showConfirmationDialog(AnimalModel animal, AnimalStatut motif) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Confirmer', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Aperçu animal
            _AnimalPreviewCard(animal: animal),
            const SizedBox(height: 16),
            // Motif sélectionné
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Motif : ${motif.label}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: TextStyle(color: Colors.grey[700])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // 🔔 SNACKBAR
  // ----------------------------------------------------------
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[700] : Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ----------------------------------------------------------
  // 🎨 UI PRINCIPALE
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Bannière info
          _buildBanner(),
          // Stats (collapsible)
          if (_showStats) AnimalStatsDashboard(stats: _stats),
          // Filtres
          _buildFilterChips(),
          // Liste
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text(
        'Gestion des animaux',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      backgroundColor: Colors.red[700],
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(
          icon: Icon(
            _showStats ? Icons.bar_chart : Icons.bar_chart_outlined,
            color: Colors.white,
          ),
          tooltip: 'Statistiques',
          onPressed: () => setState(() => _showStats = !_showStats),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _loadData,
          tooltip: 'Actualiser',
        ),
      ],
    );
  }

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      color: Colors.red.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.touch_app_outlined, color: Colors.red[700], size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Appuyez sur la corbeille pour retirer un animal du troupeau',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final labels = {
      'Tout': 'Tout',
      'Nouveau_nee': 'Nouveau-nés',
      'Animal_acheter': 'Achetés',
    };

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filtres.map((filtre) {
            final isSelected = _filtre == filtre;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(
                  labels[filtre] ?? filtre,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? Colors.red[800] : Colors.grey[700],
                  ),
                ),
                selected: isSelected,
                onSelected: (_) {
                  setState(() => _filtre = filtre);
                  _loadData();
                },
                selectedColor: Colors.red.shade100,
                checkmarkColor: Colors.red[800],
                backgroundColor: Colors.grey[100],
                side: BorderSide(
                  color: isSelected ? Colors.red.shade300 : Colors.grey.shade300,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_animals.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _animals.length,
        itemBuilder: (context, index) => _AnimalCard(
          animal: _animals[index],
          onDelete: () => _startDeleteFlow(_animals[index]),
          onTap: () => _showDetails(_animals[index]),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pets, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Aucun animal actif',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cette catégorie est vide',
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  void _showDetails(AnimalModel animal) {
    showDialog(
      context: context,
      builder: (context) => _AnimalDetailsDialog(
        animal: animal,
        onDelete: () {
          Navigator.pop(context);
          _startDeleteFlow(animal);
        },
      ),
    );
  }
}

// ============================================================
// 🧩 WIDGETS SECONDAIRES (dans le même fichier pour clarté)
// ============================================================

/// Carte d'un animal dans la liste
class _AnimalCard extends StatelessWidget {
  final AnimalModel animal;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _AnimalCard({
    required this.animal,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _AnimalImage(
                  imageUrl: animal.imageUrl,
                  size: 76,
                ),
              ),
              const SizedBox(width: 12),
              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            animal.nom ?? 'Sans nom',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Badge source
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: animal.tableSource == 'nouveaux_nee'
                                ? Colors.blue.shade50
                                : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            animal.tableSource == 'nouveaux_nee'
                                ? 'Né'
                                : 'Acheté',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: animal.tableSource == 'nouveaux_nee'
                                  ? Colors.blue[700]
                                  : Colors.orange[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _InfoRow(icon: Icons.agriculture, text: animal.race ?? 'N/A'),
                    const SizedBox(height: 2),
                    _InfoRow(icon: Icons.wc, text: animal.sexe ?? 'N/A'),
                    if (animal.tagRfid != null) ...[
                      const SizedBox(height: 2),
                      _InfoRow(icon: Icons.nfc, text: animal.tagRfid!),
                    ],
                  ],
                ),
              ),
              // Bouton supprimer
              IconButton(
                icon: Icon(Icons.delete_outline,
                    color: Colors.red[600], size: 28),
                onPressed: onDelete,
                tooltip: 'Retirer l\'animal',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aperçu animal dans le dialog de confirmation
class _AnimalPreviewCard extends StatelessWidget {
  final AnimalModel animal;

  const _AnimalPreviewCard({required this.animal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          _AnimalImage(imageUrl: animal.imageUrl, size: 60),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  animal.nom ?? 'Sans nom',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${animal.race ?? 'N/A'} • ${animal.sexe ?? 'N/A'}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget image animal (avec fallback)
class _AnimalImage extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const _AnimalImage({this.imageUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null) {
      return Image.network(
        imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _Placeholder(size: size),
      );
    }
    return _Placeholder(size: size);
  }
}

class _Placeholder extends StatelessWidget {
  final double size;

  const _Placeholder({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.pets, color: Colors.grey[400], size: size * 0.5),
    );
  }
}

/// Ligne d'info avec icône
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Dialog de détail de l'animal
class _AnimalDetailsDialog extends StatelessWidget {
  final AnimalModel animal;
  final VoidCallback onDelete;

  const _AnimalDetailsDialog({
    required this.animal,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image en-tête
          if (animal.imageUrl != null)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: Image.network(
                animal.imageUrl!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Icon(Icons.pets, size: 60, color: Colors.red[200]),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  animal.nom ?? 'Sans nom',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildDetailRow('Race', animal.race ?? 'N/A', Icons.agriculture),
                _buildDetailRow('Sexe', animal.sexe ?? 'N/A', Icons.wc),
                if (animal.dateNaissance != null)
                  _buildDetailRow(
                      'Naissance', animal.dateNaissance!, Icons.calendar_today),
                if (animal.tagRfid != null)
                  _buildDetailRow('Tag RFID', animal.tagRfid!, Icons.nfc),
                if (animal.provenance != null)
                  _buildDetailRow(
                      'Provenance', animal.provenance!, Icons.location_on),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Fermer'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Retirer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
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
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.red[600]),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dialog de chargement
class _LoadingDialog extends StatelessWidget {
  const _LoadingDialog();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Traitement en cours...'),
            ],
          ),
        ),
      ),
    );
  }
} 