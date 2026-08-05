// ============================================================
// WIDGET RÉSULTAT CONSANGUINITÉ — v5 (Wright seul décisionnel)
// Fichier: lib/Eleveures/New/Accouplemt/ResultatConsanguiniteWidget.dart
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

  // ── Couleurs selon niveau Wright ─────────────────────────
  Color get _couleurPrincipale {
    switch (resultat.resultat) {
      case 'ÉLEVÉ':      return Colors.red;
      case 'MODÉRÉ':     return Colors.orange;
      case 'ACCEPTABLE': return Colors.green;
      default:           return Colors.grey;
    }
  }

  Color get _couleurFond {
    switch (resultat.resultat) {
      case 'ÉLEVÉ':      return Colors.red.shade50;
      case 'MODÉRÉ':     return Colors.orange.shade50;
      case 'ACCEPTABLE': return Colors.green.shade50;
      default:           return Colors.grey.shade100;
    }
  }

  IconData get _icone {
    switch (resultat.resultat) {
      case 'ÉLEVÉ':      return Icons.dangerous_rounded;
      case 'MODÉRÉ':     return Icons.warning_rounded;
      case 'ACCEPTABLE': return Icons.check_circle_rounded;
      default:           return Icons.wifi_off_rounded;
    }
  }

  String get _titreEntete {
    switch (resultat.resultat) {
      case 'ÉLEVÉ':      return 'Accouplement déconseillé';
      case 'MODÉRÉ':     return 'Risque modéré détecté';
      case 'ACCEPTABLE': return 'Accouplement acceptable';
      default:           return 'Analyse indisponible';
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
        border: Border.all(color: _couleurPrincipale, width: 2),
        boxShadow: [
          BoxShadow(
            color: _couleurPrincipale.withOpacity(0.15),
            blurRadius: 12, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEntete(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBandeauF(context),
                const SizedBox(height: 16),

                if (!resultat.pedigreeInconnu) ...[
                  _buildRelation(),
                  const SizedBox(height: 12),
                ],

                _buildConfiance(),
                const SizedBox(height: 12),

                // Avertissements
                if (resultat.pedigreePartiel) ...[
                  _buildAvertissement(
                    icone: Icons.info_outline,
                    couleur: Colors.amber,
                    texte: resultat.confianceMessage,
                  ),
                  const SizedBox(height: 8),
                ],
                if (resultat.belierInconnu) ...[
                  _buildAvertissementBelierInconnu(),
                  const SizedBox(height: 8),
                ],

                // Message principal
                Text(
                  resultat.message,
                  style: TextStyle(
                    fontSize: 13, height: 1.5,
                    color: _couleurPrincipale.withOpacity(0.85),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                _buildBoutons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── EN-TÊTE ───────────────────────────────────────────────
  Widget _buildEntete() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        color: _couleurPrincipale,
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
                  _titreEntete,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Algorithme de Wright — ${resultat.methodelabel}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── BANDEAU F% ────────────────────────────────────────────
  Widget _buildBandeauF(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _couleurPrincipale.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          const Text('Coefficient de consanguinité (F)',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 6),
          Text(
            resultat.fFormate,
            style: TextStyle(
              fontSize: 44, fontWeight: FontWeight.bold,
              color: _couleurPrincipale,
            ),
          ),
          if (resultat.fWright != resultat.fAjuste) ...[
            const SizedBox(height: 4),
            Text(
              'Wright brut: ${(resultat.fWright * 100).toStringAsFixed(1)}%'
              ' → ajusté: ${resultat.fFormate}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 10),
          _buildBarreF(context),
        ],
      ),
    );
  }

  Widget _buildBarreF(BuildContext context) {
    final position = (resultat.fPourcent / 50).clamp(0.0, 1.0);
    return Column(
      children: [
        LayoutBuilder(
          builder: (ctx, constraints) {
            final w = constraints.maxWidth;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: const LinearGradient(
                      colors: [Colors.green, Colors.orange, Colors.red],
                    ),
                  ),
                ),
                Positioned(
                  left: (w * position - 8).clamp(0.0, w - 16),
                  top: -2,
                  child: Container(
                    width: 16, height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: _couleurPrincipale, width: 2),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('0%',   style: TextStyle(fontSize: 10, color: Colors.green)),
              Text('6%',   style: TextStyle(fontSize: 10, color: Colors.orange)),
              Text('12.5%',style: TextStyle(fontSize: 10, color: Colors.deepOrange)),
              Text('25%+', style: TextStyle(fontSize: 10, color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  // ── RELATION ──────────────────────────────────────────────
  Widget _buildRelation() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.account_tree, size: 18, color: Colors.purple),
            const SizedBox(width: 8),
            const Text('Relation détectée',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ]),
          const SizedBox(height: 8),
          Text(
            resultat.relation,
            style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700,
              color: _couleurPrincipale,
            ),
          ),
          if (resultat.ancetresCommuns.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Ancêtre(s) commun(s) identifié(s) :',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8, runSpacing: 4,
              children: resultat.ancetresCommuns.map((nom) => Chip(
                avatar: const Icon(Icons.pets, size: 14),
                label: Text(nom,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
                backgroundColor: _couleurPrincipale.withOpacity(0.1),
                side: BorderSide(color: _couleurPrincipale),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ── CONFIANCE + MÉTHODE ───────────────────────────────────
  Widget _buildConfiance() {
    Color cc;
    switch (resultat.confiance) {
      case 'ÉLEVÉE':  cc = Colors.green;      break;
      case 'MODÉRÉE': cc = Colors.orange;     break;
      case 'FAIBLE':  cc = Colors.deepOrange; break;
      default:        cc = Colors.grey;
    }
    return Row(children: [
      Expanded(child: _buildChip(
        icone: Icons.verified, couleur: cc,
        label: 'Confiance', valeur: resultat.confiance,
      )),
      const SizedBox(width: 8),
      Expanded(child: _buildChip(
        icone: Icons.calculate, couleur: Colors.purple,
        label: 'Méthode', valeur: resultat.methodelabel,
        fontSize: 10,
      )),
    ]);
  }

  Widget _buildChip({
    required IconData icone, required Color couleur,
    required String label, required String valeur,
    double fontSize = 13,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: couleur.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: couleur.withOpacity(0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icone, size: 14, color: couleur),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
        const SizedBox(height: 2),
        Text(valeur,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: couleur, fontSize: fontSize)),
      ]),
    );
  }

  // ── AVERTISSEMENTS ────────────────────────────────────────
  Widget _buildAvertissement({
    required IconData icone,
    required Color couleur,
    required String texte,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: couleur.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: couleur),
      ),
      child: Row(children: [
        Icon(icone, color: couleur, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(texte,
            style: TextStyle(fontSize: 12, color: couleur.shade800))),
      ]),
    );
  }

  Widget _buildAvertissementBelierInconnu() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade300),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.person_search, color: Colors.blue, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Bélier extérieur — pedigree inconnu',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13)),
          ),
        ]),
        const SizedBox(height: 6),
        const Text(
          "Pour améliorer l'analyse, renseignez le père et la mère "
          "de ce bélier dans sa fiche animal.",
          style: TextStyle(fontSize: 12, color: Colors.blueGrey),
        ),
      ]),
    );
  }

  // ── BOUTONS D'ACTION ──────────────────────────────────────
  Widget _buildBoutons() {
    if (resultat.estAcceptable) {
      return onContinuer == null
          ? const SizedBox.shrink()
          : SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
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
            );
    }

    return Row(children: [
      if (onAnnuler != null)
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onAnnuler,
            icon: const Icon(Icons.cancel),
            label: const Text('Choisir un autre bélier'),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  resultat.estRisque ? Colors.red : Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      if (onAnnuler != null && onContinuer != null)
        const SizedBox(width: 10),
      if (onContinuer != null)
        Expanded(
          child: OutlinedButton.icon(
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
          ),
        ),
    ]);
  }

  // ── CARTE ERREUR ─────────────────────────────────────────
  Widget _buildCarteErreur() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey),
      ),
      child: Row(children: [
        const Icon(Icons.wifi_off, color: Colors.grey, size: 32),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Analyse généalogique indisponible',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(resultat.message,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ]),
    );
  }
}

// Extension utilitaire pour éclaircir/assombrir une couleur
extension ColorShade on Color {
  Color get shade800 => HSLColor.fromColor(this)
      .withLightness(
        (HSLColor.fromColor(this).lightness - 0.2).clamp(0.0, 1.0))
      .toColor();
}