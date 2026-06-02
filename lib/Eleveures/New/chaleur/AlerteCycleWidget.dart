// ============================================================
// WIDGET ALERTE CYCLE — Jur-Gui 4.0
// Fichier: lib/Eleveures/New/chaleur/AlerteCycleWidget.dart
// Affiche les alertes de cycle anormal avec suggestion vétérinaire
// ============================================================

import 'package:depart/Eleveures/New/chaleur/AlerteCycleService.dart';
import 'package:flutter/material.dart';

class AlerteCycleWidget extends StatelessWidget {
  final ResultatAnalyseCycle alerte;
  final VoidCallback? onVoirVeterinaire;
  final VoidCallback? onIgnorer;

  const AlerteCycleWidget({
    super.key,
    required this.alerte,
    this.onVoirVeterinaire,
    this.onIgnorer,
  });

  @override
  Widget build(BuildContext context) {
    if (alerte.estNormal) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: alerte.couleur.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: alerte.couleur, width: 2),
        boxShadow: [
          BoxShadow(
            color: alerte.couleur.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: alerte.couleur.withOpacity(0.15),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(alerte.icone, color: alerte.couleur, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    alerte.titreNotification,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: alerte.couleur,
                    ),
                  ),
                ),
                if (alerte.intervalleJours != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: alerte.couleur,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${alerte.intervalleJours}j',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Message ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alerte.message,
                  style: TextStyle(
                    fontSize: 14,
                    color: alerte.couleur.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),

                // ── Suggestion vétérinaire ────────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: alerte.couleur.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.medical_services,
                        color: alerte.couleur,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Conseil vétérinaire',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: alerte.couleur,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              alerte.suggestion,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── Boutons d'action ──────────────────────
                Row(
                  children: [
                    if (onIgnorer != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onIgnorer,
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Ignorer'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey,
                            side: BorderSide(
                                color: Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(
                                vertical: 10),
                          ),
                        ),
                      ),
                    if (onIgnorer != null && onVoirVeterinaire != null)
                      const SizedBox(width: 10),
                    if (onVoirVeterinaire != null)
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: onVoirVeterinaire,
                          icon: const Icon(Icons.medical_services,
                              size: 16),
                          label: const Text('Consulter vétérinaire'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: alerte.couleur,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 10),
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
}

// ============================================================
// BANNER COMPACT — pour afficher dans les listes
// ============================================================

class AlerteCycleBanner extends StatelessWidget {
  final ResultatAnalyseCycle alerte;
  final VoidCallback? onTap;

  const AlerteCycleBanner({
    super.key,
    required this.alerte,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (alerte.estNormal) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: alerte.couleur.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: alerte.couleur.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Icon(alerte.icone, color: alerte.couleur, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                alerte.titreNotification,
                style: TextStyle(
                  fontSize: 13,
                  color: alerte.couleur,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right,
                color: alerte.couleur, size: 18),
          ],
        ),
      ),
    );
  }
}