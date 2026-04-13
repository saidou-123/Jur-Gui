// ============================================================
// 🎨 WIDGET — Sélection du motif de suppression (BottomSheet)
// ============================================================

import 'package:depart/Eleveures/Mon%20Troupeau/SupprimerAnimal/Animalmodel.dart';
import 'package:flutter/material.dart';

/// Affiche un BottomSheet pour choisir le motif de suppression.
/// Retourne [AnimalStatut] si confirmé, null si annulé.
Future<AnimalStatut?> showMotifSelectionSheet(
  BuildContext context,
  AnimalModel animal,
) async {
  return showModalBottomSheet<AnimalStatut>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _MotifSelectionSheet(animal: animal),
  );
}

class _MotifSelectionSheet extends StatefulWidget {
  final AnimalModel animal;

  const _MotifSelectionSheet({required this.animal});

  @override
  State<_MotifSelectionSheet> createState() => _MotifSelectionSheetState();
}

class _MotifSelectionSheetState extends State<_MotifSelectionSheet> {
  AnimalStatut? _selected;

  static const _motifs = [
    _MotifOption(
      statut: AnimalStatut.mort,
      label: 'Mort (Maladie)',
      icon: Icons.coronavirus_outlined,
      color: Color(0xFF6B7280),
      description: 'L\'animal est décédé suite à une maladie',
    ),
    _MotifOption(
      statut: AnimalStatut.vendu,
      label: 'Vendu',
      icon: Icons.sell_outlined,
      color: Color(0xFF059669),
      description: 'L\'animal a été vendu à un tiers',
    ),
    _MotifOption(
      statut: AnimalStatut.tue,
      label: 'Tué / Abattu',
      icon: Icons.cut_outlined,
      color: Color(0xFFDC2626),
      description: 'L\'animal a été abattu',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Titre
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.pets, color: Colors.red[700], size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Motif de retrait',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.animal.nom ?? 'Animal sans nom',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Options
          ...(_motifs.map((motif) => _buildMotifTile(motif))),
          const SizedBox(height: 24),

          // Bouton confirmer
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selected == null
                  ? null
                  : () => Navigator.pop(context, _selected),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[200],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Confirmer le retrait',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Bouton annuler
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(
                'Annuler',
                style: TextStyle(color: Colors.grey[600], fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMotifTile(_MotifOption motif) {
    final isSelected = _selected == motif.statut;

    return GestureDetector(
      onTap: () => setState(() => _selected = motif.statut),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? motif.color.withOpacity(0.08) : Colors.grey[50],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? motif.color : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: motif.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(motif.icon, color: motif.color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    motif.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? motif.color : Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    motif.description,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: motif.color, size: 22),
          ],
        ),
      ),
    );
  }
}

class _MotifOption {
  final AnimalStatut statut;
  final String label;
  final IconData icon;
  final Color color;
  final String description;

  const _MotifOption({
    required this.statut,
    required this.label,
    required this.icon,
    required this.color,
    required this.description,
  });
}