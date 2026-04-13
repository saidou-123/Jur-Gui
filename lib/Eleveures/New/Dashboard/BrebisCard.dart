// ============================================================
// WIDGET CARTE BREBIS CLIQUABLE
// Fichier: lib/Eleveures/New/Dashboard/BrebisCard.dart
// Utilisable dans ChaleurModule, MonTroupeau, etc.
// ============================================================

import 'package:flutter/material.dart';
import 'BrebisDetailPage.dart';

class BrebisCard extends StatelessWidget {
  final Map<String, dynamic> brebis;
  final String source;

  const BrebisCard({
    super.key,
    required this.brebis,
    required this.source,
  });

  static const Color _couleurPrimaire = Color(0xFF1B5E20);
  static const Color _couleurChaleur = Color(0xFFE53935);
  static const Color _couleurAccouplement = Color(0xFF8E24AA);

  @override
  Widget build(BuildContext context) {
    final estGestante = brebis['estGestante'] == true;
    final derniereChaleur = brebis['derniereChaleur'] as String?;
    final enChaleur = derniereChaleur != null &&
        DateTime.parse(derniereChaleur)
            .isAfter(DateTime.now().subtract(const Duration(hours: 48)));

    Color couleurBord;
    String? badge;
    Color couleurBadge;

    if (estGestante) {
      couleurBord = _couleurAccouplement;
      badge = 'Gestante 🤰';
      couleurBadge = _couleurAccouplement;
    } else if (enChaleur) {
      couleurBord = _couleurChaleur;
      badge = 'En chaleur 🔥';
      couleurBadge = _couleurChaleur;
    } else {
      couleurBord = Colors.grey.shade200;
      badge = null;
      couleurBadge = _couleurPrimaire;
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BrebisDetailPage(brebis: brebis, source: source),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: couleurBord, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Photo
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: brebis['image_url'] != null
                  ? Image.network(
                      brebis['image_url'],
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildAvatarFallback(),
                    )
                  : _buildAvatarFallback(),
            ),
            const SizedBox(width: 14),

            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          brebis['nom'] ?? 'Sans nom',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                      if (badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: couleurBadge.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              color: couleurBadge,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    brebis['race'] ?? 'Race inconnue',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (derniereChaleur != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Dernière chaleur: ${_formatDateCourte(DateTime.parse(derniereChaleur))}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ],
              ),
            ),

            // Flèche
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFF1B5E20), size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarFallback() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: _couleurPrimaire.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.pets_rounded, size: 28, color: _couleurPrimaire),
    );
  }

  String _formatDateCourte(DateTime d) {
    final diff = DateTime.now().difference(d).inDays;
    if (diff == 0) return "Aujourd'hui";
    if (diff == 1) return "Hier";
    if (diff < 7) return "Il y a $diff jours";
    return '${d.day}/${d.month}/${d.year}';
  }
}