// ============================================================
// DIALOG QUESTION J+21 — Étape 5
// Fichier: lib/Eleveures/New/Accouplemt/RetourChaleurDialog.dart
//
// Affiché automatiquement quand J+21 est atteint après un accouplement.
// Pose la question : "Avez-vous observé un retour en chaleur ?"
//
// Retourne un [ReponseRetourChaleur] :
//   • ReponseRetourChaleur.retourObserve  → OUI  (non fécondée)
//   • ReponseRetourChaleur.pasDeRetour    → NON  (gestation suspectée)
//   • null                               → Dialog fermé sans réponse
//
// Usage depuis ChaleurModule ou main.dart :
//   final reponse = await showRetourChaleurDialog(context, suivi);
//   if (reponse == ReponseRetourChaleur.retourObserve) { ... }
// ============================================================
 
import 'package:depart/Eleveures/New/Accouplemt/RetourChaleurService.dart';
import 'package:flutter/material.dart';
 
// ── Enum réponse ─────────────────────────────────────────────
enum ReponseRetourChaleur { retourObserve, pasDeRetour }
 
// ── Fonction d'entrée ─────────────────────────────────────────
/// Affiche le dialog J+21 et retourne la réponse de l'éleveur.
/// Retourne null si l'éleveur ferme le dialog sans répondre.
Future<ReponseRetourChaleur?> showRetourChaleurDialog(
  BuildContext context,
  SuiviRetourChaleur suivi,
) async {
  return showDialog<ReponseRetourChaleur>(
    context           : context,
    barrierDismissible: false, // Obliger une réponse explicite
    builder           : (_) => RetourChaleurDialog(suivi: suivi),
  );
}
 
// ============================================================
// WIDGET DIALOG
// ============================================================
 
class RetourChaleurDialog extends StatefulWidget {
  final SuiviRetourChaleur suivi;
 
  const RetourChaleurDialog({super.key, required this.suivi});
 
  @override
  State<RetourChaleurDialog> createState() => _RetourChaleurDialogState();
}
 
class _RetourChaleurDialogState extends State<RetourChaleurDialog>
    with SingleTickerProviderStateMixin {
  // Animation d'entrée du dialog
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;
 
  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(
      vsync   : this,
      duration: const Duration(milliseconds: 280),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _ctrl.forward();
  }
 
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
 
  // ── Couleurs et constantes ────────────────────────────────
  static const Color _couleurPrimaire   = Color(0xFF1B5E20);
  static const Color _couleurOui        = Color(0xFFE53935); // Rouge — retour chaleur
  static const Color _couleurNon        = Color(0xFF2E7D32); // Vert  — pas de retour
 
  @override
  Widget build(BuildContext context) {
    final suivi = widget.suivi;
 
    return ScaleTransition(
      scale: _scale,
      child: Dialog(
        shape      : RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child      : ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children    : [
              // ── En-tête coloré (fixe, ne défile pas) ────────
              _buildEntete(suivi),

              // ── Corps (défile si le contenu est trop grand) ──
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  child  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children          : [
                      _buildInfoAccouplement(suivi),
                      const SizedBox(height: 20),
                      _buildExplication(),
                      const SizedBox(height: 24),
                      _buildQuestion(),
                      const SizedBox(height: 20),
                      _buildBoutonsReponse(context),
                      const SizedBox(height: 12),
                      _buildBoutonPlusTard(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
 
  // ── En-tête ───────────────────────────────────────────────
  Widget _buildEntete(SuiviRetourChaleur suivi) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _couleurPrimaire.withOpacity(0.08),
        borderRadius: const BorderRadius.only(
          topLeft : Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Icône centrale
          Container(
            width : 64,
            height: 64,
            decoration: BoxDecoration(
              color : _couleurPrimaire.withOpacity(0.15),
              shape : BoxShape.circle,
              border: Border.all(color: _couleurPrimaire.withOpacity(0.3), width: 2),
            ),
            child: const Icon(
              Icons.query_stats_rounded,
              color : _couleurPrimaire,
              size  : 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Contrôle J+21',
            style: const TextStyle(
              fontSize  : 20,
              fontWeight: FontWeight.bold,
              color     : _couleurPrimaire,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            suivi.nomBrebis,
            style: TextStyle(
              fontSize : 15,
              color    : _couleurPrimaire.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          // Badge "retard" si la question arrive en retard
          if (suivi.joursRetard > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color        : Colors.orange.withOpacity(0.15),
                borderRadius : BorderRadius.circular(12),
                border       : Border.all(color: Colors.orange.withOpacity(0.4)),
              ),
              child: Text(
                'Question en retard de ${suivi.joursRetard} jour${suivi.joursRetard > 1 ? "s" : ""}',
                style: const TextStyle(
                  fontSize  : 11,
                  color     : Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
 
  // ── Info accouplement ─────────────────────────────────────
  Widget _buildInfoAccouplement(SuiviRetourChaleur suivi) {
    final j21Fmt = _formatDate(suivi.dateQuestionJ21);
 
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color       : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border      : Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF5C6BC0)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children          : [
                const Text(
                  'Date de suivi J+21',
                  style: TextStyle(
                    fontSize  : 11,
                    color     : Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  j21Fmt,
                  style: const TextStyle(
                    fontSize  : 14,
                    fontWeight: FontWeight.w600,
                    color     : Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
 
  // ── Explication pédagogique ───────────────────────────────
  Widget _buildExplication() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color       : const Color(0xFF1B5E20).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border      : Border.all(
          color: const Color(0xFF1B5E20).withOpacity(0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children          : [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: Color(0xFF1B5E20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Le cycle normal du mouton Ladoum est de 17 à 21 jours. '
              'Si la brebis revient en chaleur, elle n\'est pas gestante. '
              'Si aucun retour n\'est observé, la gestation est probable.',
              style: TextStyle(
                fontSize  : 13,
                color     : Colors.grey.shade700,
                height    : 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
 
  // ── Question principale ───────────────────────────────────
  Widget _buildQuestion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children          : [
        const Text(
          'Avez-vous observé un retour en chaleur ?',
          style: TextStyle(
            fontSize  : 17,
            fontWeight: FontWeight.bold,
            color     : Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Signes : agitation, chevauche les autres, mucus vulvaire clair',
          style: TextStyle(
            fontSize: 12,
            color   : Colors.grey.shade500,
            height  : 1.4,
          ),
        ),
      ],
    );
  }
 
  // ── Boutons OUI / NON ─────────────────────────────────────
  Widget _buildBoutonsReponse(BuildContext context) {
    return Row(
      children: [
        // ── OUI → retour observé ──
        Expanded(
          child: _BoutonReponse(
            label   : 'OUI\nRetour observé',
            icone   : Icons.replay_rounded,
            couleur : _couleurOui,
            sousTitre: 'Non fécondée',
            onTap   : () => Navigator.pop(
              context,
              ReponseRetourChaleur.retourObserve,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // ── NON → pas de retour ──
        Expanded(
          child: _BoutonReponse(
            label     : 'NON\nPas de retour',
            icone     : Icons.pregnant_woman_rounded,
            couleur   : _couleurNon,
            sousTitre : 'Gestation suspectée',
            onTap     : () => Navigator.pop(
              context,
              ReponseRetourChaleur.pasDeRetour,
            ),
          ),
        ),
      ],
    );
  }
 
  // ── Bouton "Je vérifierai plus tard" ─────────────────────
  Widget _buildBoutonPlusTard(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: () => Navigator.pop(context, null),
        child: Text(
          'Je vérifierai plus tard',
          style: TextStyle(
            color   : Colors.grey.shade500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
 
  // ── Formatage date ────────────────────────────────────────
  String _formatDate(DateTime d) {
    const mois = [
      '', 'jan', 'fév', 'mars', 'avr', 'mai', 'juin',
      'juil', 'août', 'sep', 'oct', 'nov', 'déc',
    ];
    return '${d.day} ${mois[d.month]} ${d.year}';
  }
}
 
// ============================================================
// WIDGET BOUTON DE RÉPONSE (OUI / NON)
// ============================================================
 
class _BoutonReponse extends StatefulWidget {
  final String   label;
  final IconData icone;
  final Color    couleur;
  final String   sousTitre;
  final VoidCallback onTap;
 
  const _BoutonReponse({
    required this.label,
    required this.icone,
    required this.couleur,
    required this.sousTitre,
    required this.onTap,
  });
 
  @override
  State<_BoutonReponse> createState() => _BoutonReponseState();
}
 
class _BoutonReponseState extends State<_BoutonReponse> {
  bool _appuye = false;
 
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown  : (_) => setState(() => _appuye = true),
      onTapUp    : (_) {
        setState(() => _appuye = false);
        widget.onTap();
      },
      onTapCancel: ()  => setState(() => _appuye = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding : const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        transform: _appuye
            ? (Matrix4.identity()..scale(0.96))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color       : widget.couleur.withOpacity(_appuye ? 0.18 : 0.10),
          borderRadius: BorderRadius.circular(16),
          border      : Border.all(
            color : widget.couleur.withOpacity(0.5),
            width : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color     : widget.couleur.withOpacity(0.12),
              blurRadius: 8,
              offset    : const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(widget.icone, color: widget.couleur, size: 32),
            const SizedBox(height: 8),
            Text(
              widget.label,
              textAlign: TextAlign.center,
              style    : TextStyle(
                color     : widget.couleur,
                fontSize  : 14,
                fontWeight: FontWeight.bold,
                height    : 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color       : widget.couleur.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                widget.sousTitre,
                style: TextStyle(
                  fontSize  : 10,
                  color     : widget.couleur,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
 
// ============================================================
// WIDGET RÉSULTAT — affiché après la réponse
// Peut être utilisé en remplacement du dialog ou après fermeture
// ============================================================
 
class ResultatRetourChaleurWidget extends StatelessWidget {
  final ReponseRetourChaleur reponse;
  final ResultatSuspicionGestation? suspicion; // null si reponse = retourObserve
  final String nomBrebis;
  final VoidCallback? onNouvelAccouplement; // bouton si non fécondée
  final VoidCallback? onVoirGestation;     // bouton si gestation suspectée
 
  const ResultatRetourChaleurWidget({
    super.key,
    required this.reponse,
    required this.nomBrebis,
    this.suspicion,
    this.onNouvelAccouplement,
    this.onVoirGestation,
  });
 
  @override
  Widget build(BuildContext context) {
    final estRetour = reponse == ReponseRetourChaleur.retourObserve;
 
    final couleur  = estRetour ? const Color(0xFFE53935) : const Color(0xFF2E7D32);
    final icone    = estRetour ? Icons.replay_rounded    : Icons.pregnant_woman_rounded;
    final titre    = estRetour ? 'Non fécondée'          : 'Gestation suspectée';
    final message  = estRetour
        ? '$nomBrebis est revenue en chaleur. Elle n\'est pas gestante.\n'
          'Planifiez un nouvel accouplement lors de sa prochaine chaleur.'
        : '$nomBrebis n\'a pas montré de signe de retour. '
          'La gestation est probable.';
 
    return Container(
      margin     : const EdgeInsets.symmetric(vertical: 12),
      padding    : const EdgeInsets.all(16),
      decoration : BoxDecoration(
        color        : couleur.withOpacity(0.06),
        borderRadius : BorderRadius.circular(16),
        border       : Border.all(color: couleur.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children          : [
          // ── En-tête résultat ──
          Row(
            children: [
              Container(
                padding   : const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color : couleur.withOpacity(0.12),
                  shape : BoxShape.circle,
                ),
                child: Icon(icone, color: couleur, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                titre,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize  : 16,
                  color     : couleur,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
 
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              color   : Colors.grey.shade700,
              height  : 1.5,
            ),
          ),
 
          // ── Probabilité de gestation (si suspicion) ──
          if (suspicion != null) ...[
            const SizedBox(height: 14),
            _buildProbabiliteBar(suspicion!),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color       : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border      : Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                suspicion!.messageConseils,
                style: TextStyle(
                  fontSize: 12,
                  color   : Colors.grey.shade700,
                  height  : 1.5,
                ),
              ),
            ),
          ],
 
          const SizedBox(height: 14),
 
          // ── Bouton d'action ──
          if (estRetour && onNouvelAccouplement != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onNouvelAccouplement,
                icon     : const Icon(Icons.add, size: 16),
                label    : const Text('Planifier un nouvel accouplement'),
                style    : ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          if (!estRetour && onVoirGestation != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onVoirGestation,
                icon     : const Icon(Icons.monitor_heart_outlined, size: 16),
                label    : const Text('Voir le suivi de gestation'),
                style    : ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
 
  // ── Barre de probabilité ──────────────────────────────────
  Widget _buildProbabiliteBar(ResultatSuspicionGestation s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children          : [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children         : [
            Text(
              'Probabilité de gestation',
              style: TextStyle(
                fontSize  : 12,
                fontWeight: FontWeight.w500,
                color     : Colors.grey.shade700,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color       : s.couleurConfiance.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${s.probabilitePourcent} — ${s.niveauConfiance}',
                style: TextStyle(
                  fontSize  : 11,
                  fontWeight: FontWeight.bold,
                  color     : s.couleurConfiance,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value           : s.probabilite,
            backgroundColor : Colors.grey.shade200,
            valueColor      : AlwaysStoppedAnimation<Color>(s.couleurConfiance),
            minHeight       : 10,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Date agnelage prévue : ${_formatDate(s.dateAgnelage)}',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }
 
  String _formatDate(DateTime d) {
    const mois = [
      '', 'jan', 'fév', 'mars', 'avr', 'mai', 'juin',
      'juil', 'août', 'sep', 'oct', 'nov', 'déc',
    ];
    return '${d.day} ${mois[d.month]} ${d.year}';
  }
}