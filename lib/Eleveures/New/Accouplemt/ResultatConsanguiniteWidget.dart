// ============================================================
// WIDGET RÉSULTAT CONSANGUINITÉ — v2 (Enrichi)
// Fichier: lib/Eleveures/New/Accouplemt/ResultatConsanguiniteWidget.dart
//
// Affiche : F%, relation, ancêtres communs, niveau de confiance,
// méthode utilisée (Wright exact / partiel / ML seul)
// ============================================================

import 'package:depart/Eleveures/New/Accouplemt/ResultatConsanguinite.dart';
import 'package:flutter/material.dart';

class ResultatConsanguiniteWidget extends StatelessWidget {
  final ResultatConsanguinite resultat;
  final VoidCallback? onContinuer;
  final VoidCallback? onAnnuler;

  const ResultatConsanguiniteWidget({
    super.key,
    required this.resultat,
    this.onContinuer,
    this.onAnnuler,
  });

  // ── Couleurs selon niveau ─────────────────────────────────
  Color get _couleur {
    switch (resultat.couleur) {
      case 'vert'  : return Colors.green;
      case 'orange': return Colors.orange;
      case 'rouge' : return Colors.red;
      default      : return Colors.grey;
    }
  }

  Color get _couleurFond {
    switch (resultat.couleur) {
      case 'vert'  : return Colors.green.shade50;
      case 'orange': return Colors.orange.shade50;
      case 'rouge' : return Colors.red.shade50;
      default      : return Colors.grey.shade100;
    }
  }

  IconData get _icone {
    switch (resultat.couleur) {
      case 'vert'  : return Icons.check_circle_rounded;
      case 'orange': return Icons.warning_amber_rounded;
      case 'rouge' : return Icons.cancel_rounded;
      default      : return Icons.wifi_off;
    }
  }

  String get _titre {
    switch (resultat.resultat) {
      case 'ACCEPTABLE': return 'Accouplement Acceptable';
      case 'MODÉRÉ'    : return 'Risque Modéré Détecté';
      default          : return 'Risque Élevé Détecté';
    }
  }

  String get _badgeMethode {
    switch (resultat.methode) {
      case 'wright_exact'  : return 'WRIGHT ✓';
      case 'wright_partiel': return 'WRIGHT ~';
      default              : return 'IA ML';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (resultat.estErreur) return _buildCarteErreur();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: _couleurFond,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _couleur, width: 2),
        boxShadow: [
          BoxShadow(
            color: _couleur.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildEnTete(),
          _buildCorps(),
        ],
      ),
    );
  }

  // ── En-tête coloré ────────────────────────────────────────
  Widget _buildEnTete() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: _couleur,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Row(
        children: [
          Icon(_icone, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _titre,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Analyse IA — ${resultat.methode == 'wright_exact'
                    ? 'Pedigree complet (95%+)'
                    : resultat.methode == 'wright_partiel'
                        ? 'Pedigree partiel (~70%)'
                        : 'Modèle ML (~69%)'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          // Badge méthode
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _badgeMethode,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Corps ─────────────────────────────────────────────────
  Widget _buildCorps() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score F
          _buildScoreF(),
          const SizedBox(height: 12),

          // Relation & ancêtres
          _buildRelation(),
          const SizedBox(height: 12),

          // Badge confiance
          _buildBadgeConfiance(),
          const SizedBox(height: 12),

          // Message principal
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _couleur.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              resultat.message,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: _couleur,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Avertissement bélier inconnu
          if (resultat.belierInconnu) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade300),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: Colors.blue, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pedigree du bélier incomplet. Renseignez ses parents pour améliorer l\'analyse.',
                      style: TextStyle(fontSize: 11, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Danger consanguinité
          if (resultat.estRisque) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Les accouplements consanguins peuvent causer des malformations, '
                      'des maladies génétiques et réduire la productivité du troupeau.',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Jauge ML si pedigree partiel ou ML seul
          if (resultat.methode != 'wright_exact') ...[
            const SizedBox(height: 12),
            _buildJaugeML(),
          ],

          // Boutons
          if (onContinuer != null || onAnnuler != null) ...[
            const SizedBox(height: 16),
            _buildBoutons(),
          ],
        ],
      ),
    );
  }

  // ── Score F principal ─────────────────────────────────────
  Widget _buildScoreF() {
    return Row(
      children: [
        // Cercle F%
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _couleurFond,
            border: Border.all(color: _couleur, width: 3),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${resultat.fPourcent.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: _couleur,
                ),
              ),
              Text(
                'coeff. F',
                style: TextStyle(fontSize: 9, color: _couleur),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Coefficient de consanguinité',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (resultat.fPourcent / 50).clamp(0.0, 1.0),
                  backgroundColor: Colors.grey.shade200,
                  color: _couleur,
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('0%', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Text('15% seuil', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Text('50%', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
              if (resultat.fWright > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'Wright brut: ${(resultat.fWright * 100).toStringAsFixed(2)}% '
                  '→ ajusté: ${(resultat.fAjuste * 100).toStringAsFixed(2)}%',
                  style: const TextStyle(fontSize: 10, color: Colors.black38),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Relation & ancêtres ───────────────────────────────────
  Widget _buildRelation() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.family_restroom, size: 16, color: _couleur),
              const SizedBox(width: 6),
              const Text(
                'Relation généalogique',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Chip relation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _couleur.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _couleur.withOpacity(0.5)),
            ),
            child: Text(
              resultat.relation,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _couleur,
              ),
            ),
          ),
          // Ancêtres communs
          if (resultat.ancetresCommuns.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Ancêtres communs :',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: resultat.ancetresCommuns
                  .map((a) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _couleur.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _couleur.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pets, size: 11, color: _couleur),
                            const SizedBox(width: 4),
                            Text(
                              a,
                              style: TextStyle(
                                fontSize: 12,
                                color: _couleur,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Aucun ancêtre commun détecté',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Badge confiance ───────────────────────────────────────
  Widget _buildBadgeConfiance() {
    Color c;
    IconData icone;
    switch (resultat.confiance) {
      case 'ÉLEVÉE'  : c = Colors.green.shade700; icone = Icons.verified; break;
      case 'MODÉRÉE' : c = Colors.blue.shade600;  icone = Icons.check_circle_outline; break;
      case 'FAIBLE'  : c = Colors.orange.shade700;icone = Icons.info_outline; break;
      default        : c = Colors.red.shade600;   icone = Icons.warning_amber_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(icone, size: 16, color: c),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fiabilité : ${resultat.confiance}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: c,
                  ),
                ),
                if (resultat.confianceMessage.isNotEmpty)
                  Text(
                    resultat.confianceMessage,
                    style: TextStyle(fontSize: 11, color: c.withOpacity(0.8)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Jauge ML complémentaire ───────────────────────────────
  Widget _buildJaugeML() {
    final pctR = (resultat.confianceRisque * 100).round();
    final pctA = (resultat.confianceAcceptable * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.psychology, size: 14, color: Colors.purple.shade400),
            const SizedBox(width: 4),
            Text(
              'Confiance du modèle IA',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Colors.purple.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 14),
            const SizedBox(width: 4),
            const Text('Acceptable', style: TextStyle(fontSize: 11)),
            const Spacer(),
            Text('$pctA%',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: resultat.confianceAcceptable,
            backgroundColor: Colors.grey.shade200,
            color: Colors.green,
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.warning, color: Colors.red, size: 14),
            const SizedBox(width: 4),
            const Text('Risque', style: TextStyle(fontSize: 11)),
            const Spacer(),
            Text('$pctR%',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: resultat.confianceRisque,
            backgroundColor: Colors.grey.shade200,
            color: Colors.red,
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  // ── Boutons d'action ──────────────────────────────────────
  Widget _buildBoutons() {
    return Row(
      children: [
        if (onAnnuler != null)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onAnnuler,
              icon: const Icon(Icons.cancel),
              label: const Text('Annuler'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        if (onAnnuler != null && onContinuer != null) const SizedBox(width: 12),
        if (onContinuer != null)
          Expanded(
            child: onAnnuler != null
                ? OutlinedButton.icon(
                    onPressed: onContinuer,
                    icon: const Icon(Icons.warning),
                    label: const Text('Continuer quand même'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: onContinuer,
                    icon: const Icon(Icons.check_circle),
                    label: const Text("Continuer l'enregistrement"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
          ),
      ],
    );
  }

  // ── Carte erreur ──────────────────────────────────────────
  Widget _buildCarteErreur() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Colors.grey, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Analyse IA indisponible',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  resultat.message,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}