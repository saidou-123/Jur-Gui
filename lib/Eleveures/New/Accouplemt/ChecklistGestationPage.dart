// ============================================================
// PAGE CHECKLIST HEBDOMADAIRE GESTATION — Étape 6
// Fichier: lib/Eleveures/New/Accouplemt/ChecklistGestationPage.dart
//
// Affiche pour une semaine donnée :
//   • Barre de progression de gestation (Mois X/5)
//   • Score de probabilité mis à jour en temps réel
//   • 5 indicateurs cliniques (toggle OUI/NON/Non observé)
//   • Champ visite vétérinaire + notes
//   • Conseils adaptés à la semaine
//   • Bouton confirmation J+45 si éligible
// ============================================================
 
import 'package:depart/Eleveures/New/Accouplemt/SuiviGestationService.dart';
import 'package:depart/Eleveures/New/Reproduction/ReproductionConfig.dart';
import 'package:flutter/material.dart';
 
class ChecklistGestationPage extends StatefulWidget {
  final Map<String, dynamic> accouplement;
  final Map<String, dynamic> brebis;
 
  const ChecklistGestationPage({
    super.key,
    required this.accouplement,
    required this.brebis,
  });
 
  @override
  State<ChecklistGestationPage> createState() =>
      _ChecklistGestationPageState();
}
 
class _ChecklistGestationPageState extends State<ChecklistGestationPage> {
  final _service    = SuiviGestationService();
  final _notesCtrl  = TextEditingController();
 
  // ── Données gestation ────────────────────────────────────
  late DateTime _dateAccouplement;
  late int      _semaine;
  late int      _mois;
  late double   _progression;
 
  // ── Checklist courante ────────────────────────────────────
  bool?  _mammaire;
  bool?  _prisePoids;
  bool?  _appetitNormal;
  bool?  _comportementOk;
  bool?  _pasSigneChaleur;
  bool   _visiteVeto = false;
 
  // ── Score calculé en temps réel ───────────────────────────
  double _scoreGlobal = 0.65;
  double _scoreSemaine = 0.65;
 
  // ── Historique checklists ────────────────────────────────
  List<ChecklistGestation> _historique = [];
 
  // ── États ────────────────────────────────────────────────
  bool _isLoading   = true;
  bool _isSaving    = false;
  bool _j45Atteint  = false;
  bool _dejaConfirme = false;
 
  // ── Couleurs ─────────────────────────────────────────────
  static const Color _vert   = Color(0xFF2E7D32);
  static const Color _violet = Color(0xFF6A1B9A);
 
  @override
  void initState() {
    super.initState();
    _initialiser();
  }
 
  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }
 
  Future<void> _initialiser() async {
    final dateStr = widget.accouplement['date_accouplement']?.toString();
    if (dateStr == null) {
      setState(() => _isLoading = false);
      return;
    }
 
    _dateAccouplement = DateTime.parse(dateStr);
    _semaine          = _service.calculerSemaine(_dateAccouplement) ?? 1;
    _mois             = _service.calculerMois(_dateAccouplement);
    _progression      = _service.calculerProgression(_dateAccouplement);
 
    final joursDepuis = DateTime.now().difference(_dateAccouplement).inDays;
    _j45Atteint = joursDepuis >= 45;
 
    // Score initial depuis la BD
    _scoreGlobal = (widget.accouplement['probabilite_gestation'] as num?)
            ?.toDouble() ??
        ReproductionConfig.probabiliteGestationBase;
 
    // Charger checklist existante de cette semaine
    final accouplementId = widget.accouplement['id']?.toString() ?? '';
    final existante = await _service.chargerChecklist(
      accouplementId: accouplementId,
      semaine       : _semaine,
    );
    _historique = await _service.chargerHistoriqueChecklists(accouplementId);
 
    // Vérifier si déjà confirmé
    _dejaConfirme =
        widget.accouplement['statut_gestation'] == 'gestation_confirmee';
 
    if (existante != null) {
      setState(() {
        _mammaire       = existante.mammaire;
        _prisePoids     = existante.prisePoids;
        _appetitNormal  = existante.appetitNormal;
        _comportementOk = existante.comportementOk;
        _pasSigneChaleur = existante.pasSigneChaleur;
        _visiteVeto     = existante.visiteVeto;
        _notesCtrl.text = existante.notesVeto ?? '';
        _scoreSemaine   = existante.scoreSemaine;
        _isLoading      = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
 
    _recalculerScore();
  }
 
  void _recalculerScore() {
    final checklist = _buildChecklistCourante();
    final service   = SuiviGestationService();
    // Score semaine en temps réel (méthode publique simplifiée)
    int nbOui = 0; int nbRep = 0;
    for (final b in [_mammaire, _prisePoids, _appetitNormal,
                     _comportementOk, _pasSigneChaleur]) {
      if (b != null) { nbRep++; if (b) nbOui++; }
    }
    if (_visiteVeto) nbOui++;
 
    final ratio = nbRep > 0 ? nbOui / (nbRep + (nbRep < 5 ? 0 : 0)) : 0.5;
    setState(() {
      _scoreSemaine = (ratio * 0.60 + ReproductionConfig.probabiliteGestationBase * 0.40)
          .clamp(0.20, 0.99);
    });
  }
 
  ChecklistGestation _buildChecklistCourante() {
    return ChecklistGestation(
      id             : '',
      accouplementId : widget.accouplement['id']?.toString() ?? '',
      semaine        : _semaine,
      mammaire       : _mammaire,
      prisePoids     : _prisePoids,
      appetitNormal  : _appetitNormal,
      comportementOk : _comportementOk,
      pasSigneChaleur: _pasSigneChaleur,
      visiteVeto     : _visiteVeto,
      notesVeto      : _notesCtrl.text.trim().isEmpty
          ? null : _notesCtrl.text.trim(),
      scoreSemaine   : _scoreSemaine,
      dateSaisie     : DateTime.now(),
    );
  }
 
  Future<void> _sauvegarder() async {
    setState(() => _isSaving = true);
    try {
      final scoreGlobal = await _service.sauvegarderChecklist(
        accouplementId  : widget.accouplement['id']?.toString() ?? '',
        semaine         : _semaine,
        checklist       : _buildChecklistCourante(),
        dateAccouplement: _dateAccouplement,
      );
      setState(() {
        _scoreGlobal = scoreGlobal;
        _isSaving    = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text('Semaine $_semaine enregistrée — Score : '
                  '${(scoreGlobal * 100).round()}%'),
            ]),
            backgroundColor : _vert,
            behavior        : SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }
 
  // ============================================================
  // BUILD
  // ============================================================
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3E5F5),
      appBar: AppBar(
        title: Text('Suivi gestation — S$_semaine'),
        backgroundColor: _violet,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                _buildEnTeteBrebis(),
                const SizedBox(height: 16),
                _buildProgressionGestation(),
                const SizedBox(height: 16),
                _buildScoreCard(),
                const SizedBox(height: 16),
                _buildChecklistCard(),
                const SizedBox(height: 16),
                _buildVisiteVeto(),
                const SizedBox(height: 16),
                _buildConseilsSemaine(),
                if (_historique.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildHistoriqueScores(),
                ],
                if (_j45Atteint && !_dejaConfirme) ...[
                  const SizedBox(height: 16),
                  _buildConfirmationJ45(),
                ],
                const SizedBox(height: 24),
                _buildBoutonSauvegarder(),
              ],
            ),
    );
  }
 
  // ============================================================
  // WIDGETS
  // ============================================================
 
  Widget _buildEnTeteBrebis() {
    return Container(
      padding   : const EdgeInsets.all(14),
      decoration: _deco(Colors.white, Colors.grey.shade200),
      child: Row(
        children: [
          _avatar(widget.brebis['image_url']),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.brebis['nom'] ?? 'Brebis',
                  style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  widget.brebis['race'] ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _violet.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Mois $_mois / 5 — Semaine $_semaine',
                    style: TextStyle(
                      fontSize: 11, color: _violet,
                      fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
 
  Widget _buildProgressionGestation() {
    final moisLabels = ['M1', 'M2', 'M3', 'M4', 'M5'];
    return Container(
      padding   : const EdgeInsets.all(16),
      decoration: _deco(Colors.white, Colors.grey.shade200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Progression de gestation',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text(
                '${_progression.toStringAsFixed(0)}%',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold,
                    color: _violet),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value          : _progression / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor     : AlwaysStoppedAnimation<Color>(_violet),
              minHeight      : 14,
            ),
          ),
          const SizedBox(height: 8),
          // Indicateurs mois
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (i) {
              final actif = i < _mois;
              final courant = i + 1 == _mois;
              return Column(
                children: [
                  Container(
                    width : 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: courant
                          ? _violet
                          : actif
                              ? _violet.withOpacity(0.4)
                              : Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        moisLabels[i],
                        style: TextStyle(
                          fontSize  : 10,
                          fontWeight: FontWeight.bold,
                          color     : courant || actif
                              ? Colors.white
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('S1-4', style: TextStyle(fontSize: 9, color: Colors.grey)),
              Text('S5-8', style: TextStyle(fontSize: 9, color: Colors.grey)),
              Text('S9-12', style: TextStyle(fontSize: 9, color: Colors.grey)),
              Text('S13-16', style: TextStyle(fontSize: 9, color: Colors.grey)),
              Text('S17-20', style: TextStyle(fontSize: 9, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
 
  Widget _buildScoreCard() {
    final scoreAffiche = _scoreGlobal;
    Color couleur;
    String niveau;
    IconData icone;
 
    if (scoreAffiche >= ReproductionConfig.probabiliteGestationElevee) {
      couleur = _vert;
      niveau  = 'Élevée';
      icone   = Icons.check_circle_rounded;
    } else if (scoreAffiche >= ReproductionConfig.probabiliteGestationModeree) {
      couleur = Colors.orange;
      niveau  = 'Modérée';
      icone   = Icons.info_rounded;
    } else {
      couleur = const Color(0xFFE53935);
      niveau  = 'Faible';
      icone   = Icons.warning_rounded;
    }
 
    return Container(
      padding   : const EdgeInsets.all(16),
      decoration: _deco(couleur.withOpacity(0.06), couleur.withOpacity(0.25)),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icone, color: couleur, size: 22),
              const SizedBox(width: 10),
              const Text('Probabilité de gestation',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: couleur.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${(scoreAffiche * 100).round()}% — $niveau',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold,
                    color: couleur),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value          : scoreAffiche,
              backgroundColor: Colors.grey.shade200,
              valueColor     : AlwaysStoppedAnimation<Color>(couleur),
              minHeight      : 12,
            ),
          ),
          const SizedBox(height: 8),
          // Score semaine en cours
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Score semaine $_semaine : ${(_scoreSemaine * 100).round()}%',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              Text(
                _j45Atteint
                    ? 'Confirmation J+45 disponible'
                    : '${45 - DateTime.now().difference(_dateAccouplement).inDays} jours avant J+45',
                style: TextStyle(
                  fontSize: 10,
                  color: _j45Atteint ? _vert : Colors.grey[500],
                  fontWeight: _j45Atteint ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
 
  Widget _buildChecklistCard() {
    return Container(
      decoration: _deco(Colors.white, Colors.grey.shade200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: BoxDecoration(
              color: _violet.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(Icons.checklist_rounded, color: _violet, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Observations cliniques — Semaine $_semaine',
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold,
                    color: _violet),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _buildIndicateur(
                  icone    : Icons.pregnant_woman_rounded,
                  label    : 'Développement mammaire visible',
                  sous     : 'Gonflements du pis observables',
                  valeur   : _mammaire,
                  onChange : (v) => setState(() {
                    _mammaire = v;
                    _recalculerScore();
                  }),
                  poids: '30%',
                ),
                const Divider(height: 1),
                _buildIndicateur(
                  icone    : Icons.monitor_weight_rounded,
                  label    : 'Prise de poids visible',
                  sous     : 'Abdomen plus large qu\'avant',
                  valeur   : _prisePoids,
                  onChange : (v) => setState(() {
                    _prisePoids = v;
                    _recalculerScore();
                  }),
                  poids: '20%',
                ),
                const Divider(height: 1),
                _buildIndicateur(
                  icone    : Icons.restaurant_rounded,
                  label    : 'Appétit normal ou augmenté',
                  sous     : 'Mange bien, pas de refus',
                  valeur   : _appetitNormal,
                  onChange : (v) => setState(() {
                    _appetitNormal = v;
                    _recalculerScore();
                  }),
                  poids: '15%',
                ),
                const Divider(height: 1),
                _buildIndicateur(
                  icone    : Icons.spa_rounded,
                  label    : 'Comportement calme',
                  sous     : 'Pas d\'agitation, pas d\'agressivité',
                  valeur   : _comportementOk,
                  onChange : (v) => setState(() {
                    _comportementOk = v;
                    _recalculerScore();
                  }),
                  poids: '15%',
                ),
                const Divider(height: 1),
                _buildIndicateur(
                  icone    : Icons.block_rounded,
                  label    : 'Aucun signe de retour en chaleur',
                  sous     : 'Pas d\'agitation, mucus, chevauchement',
                  valeur   : _pasSigneChaleur,
                  onChange : (v) => setState(() {
                    _pasSigneChaleur = v;
                    _recalculerScore();
                  }),
                  poids: '20%',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
 
  Widget _buildIndicateur({
    required IconData icone,
    required String   label,
    required String   sous,
    required bool?    valeur,
    required void Function(bool?) onChange,
    required String   poids,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 20, color: _violet.withOpacity(0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(label,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(poids,
                          style: const TextStyle(
                              fontSize: 9, color: Colors.grey)),
                    ),
                  ],
                ),
                Text(sous,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                const SizedBox(height: 6),
                // Toggle OUI / NON / Non observé
                Row(
                  children: [
                    _toggleBtn('OUI', true,  valeur, onChange, _vert),
                    const SizedBox(width: 8),
                    _toggleBtn('NON', false, valeur, onChange,
                        const Color(0xFFE53935)),
                    const SizedBox(width: 8),
                    _toggleBtn('?', null, valeur, onChange, Colors.grey),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
 
  Widget _toggleBtn(
    String label, bool? cible, bool? valeur,
    void Function(bool?) onChange, Color couleur,
  ) {
    final selectionne = valeur == cible;
    return GestureDetector(
      onTap: () => onChange(cible),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selectionne ? couleur : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selectionne ? couleur : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize  : 12,
            fontWeight: FontWeight.w600,
            color     : selectionne ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
    );
  }
 
  Widget _buildVisiteVeto() {
    return Container(
      padding   : const EdgeInsets.all(14),
      decoration: _deco(Colors.white, Colors.grey.shade200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toggle visite vétérinaire
          Row(
            children: [
              Icon(Icons.medical_services_rounded,
                  color: Colors.teal, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Visite vétérinaire cette semaine',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              Switch(
                value         : _visiteVeto,
                onChanged     : (v) => setState(() {
                  _visiteVeto = v;
                  _recalculerScore();
                }),
                activeColor   : Colors.teal,
              ),
            ],
          ),
          // Notes véto (visible si visite = true)
          if (_visiteVeto) ...[
            const SizedBox(height: 10),
            TextFormField(
              controller : _notesCtrl,
              maxLines   : 3,
              decoration : const InputDecoration(
                labelText  : 'Notes de la visite',
                hintText   : 'Diagnostic, prescriptions, observations...',
                prefixIcon : Icon(Icons.notes_rounded, color: Colors.teal),
                border     : OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
    );
  }
 
  Widget _buildConseilsSemaine() {
    final conseil = ResumeGestationSemaine.calculer(
      dateAccouplement: _dateAccouplement,
      scoreGlobal     : _scoreGlobal,
      aChecklist      : true,
      confirmee       : _dejaConfirme,
    );
 
    return Container(
      padding   : const EdgeInsets.all(14),
      decoration: _deco(
        const Color(0xFFE8F5E9), const Color(0xFFA5D6A7)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_rounded, color: _vert, size: 18),
              const SizedBox(width: 8),
              const Text('Conseils de la semaine',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32))),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            conseil.conseilsSemaine,
            style: TextStyle(
                fontSize: 12, color: Colors.grey[700], height: 1.5),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.schedule_rounded,
                  size: 13, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                conseil.rappelSuivant,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }
 
  Widget _buildHistoriqueScores() {
    return Container(
      padding   : const EdgeInsets.all(14),
      decoration: _deco(Colors.white, Colors.grey.shade200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline_rounded, color: _violet, size: 18),
              const SizedBox(width: 8),
              const Text('Historique des scores',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          // Barres de scores par semaine
          ..._historique.map((c) => _buildLigneHistorique(c)),
        ],
      ),
    );
  }
 
  Widget _buildLigneHistorique(ChecklistGestation c) {
    final couleur = c.couleurScore;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text('S${c.semaine}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value          : c.scoreSemaine,
                backgroundColor: Colors.grey.shade100,
                valueColor     : AlwaysStoppedAnimation<Color>(couleur),
                minHeight      : 10,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(c.scoreSemaine * 100).round()}%',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: couleur),
          ),
        ],
      ),
    );
  }
 
  Widget _buildConfirmationJ45() {
    return Container(
      padding   : const EdgeInsets.all(16),
      decoration: _deco(
        const Color(0xFFF3E5F5), const Color(0xFFCE93D8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_rounded, color: _violet, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Confirmation formelle disponible (J+45)',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold,
                      color: Color(0xFF6A1B9A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'La gestation peut maintenant être confirmée officiellement '
            'par échographie ou rapport vétérinaire.',
            style: TextStyle(
                fontSize: 12, color: Colors.grey[700], height: 1.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _confirmerGestation('echographie'),
                  icon : const Icon(Icons.biotech_rounded, size: 16),
                  label: const Text('Échographie'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _violet,
                    side: BorderSide(color: _violet),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _confirmerGestation('rapport_veto'),
                  icon : const Icon(Icons.medical_services_rounded, size: 16),
                  label: const Text('Rapport véto'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _violet,
                    side: BorderSide(color: _violet),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
 
  Widget _buildBoutonSauvegarder() {
    return SizedBox(
      width : double.infinity,
      height: 52,
      child : ElevatedButton.icon(
        onPressed: _isSaving ? null : _sauvegarder,
        icon: _isSaving
            ? const SizedBox(
                width : 18, height: 18,
                child : CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.save_rounded),
        label: Text(
          _isSaving ? 'Enregistrement...' : 'Sauvegarder la semaine $_semaine',
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _violet,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
 
  // ── Confirmation J+45 ────────────────────────────────────
  Future<void> _confirmerGestation(String type) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la gestation'),
        content: Text(
          'Confirmez-vous la gestation de ${widget.brebis['nom']} '
          'par ${type == 'echographie' ? 'échographie' : 'rapport vétérinaire'} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _vert,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmer ✅'),
          ),
        ],
      ),
    );
 
    if (result != true || !mounted) return;
 
    try {
      await _service.confirmerGestationJ45(
        accouplementId   : widget.accouplement['id']?.toString() ?? '',
        typeConfirmation : type,
        resultat         : 'confirmee',
      );
      setState(() {
        _dejaConfirme = true;
        _scoreGlobal  = 0.99;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Gestation confirmée officiellement !'),
            backgroundColor: _vert,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }
 
  // ── Utilitaires ──────────────────────────────────────────
  Widget _avatar(String? url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: url != null
          ? Image.network(url,
              width: 48, height: 48, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _avatarFallback())
          : _avatarFallback(),
    );
  }
 
  Widget _avatarFallback() => Container(
    width: 48, height: 48,
    decoration: BoxDecoration(
      color: _violet.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(Icons.pets_rounded, color: _violet, size: 24),
  );
 
  BoxDecoration _deco(Color bg, Color border) => BoxDecoration(
    color: bg,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: border),
    boxShadow: [
      BoxShadow(color: Colors.black.withOpacity(0.04),
          blurRadius: 8, offset: const Offset(0, 2))
    ],
  );
}