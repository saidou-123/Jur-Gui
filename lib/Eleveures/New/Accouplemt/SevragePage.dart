// ============================================================
// PAGE SEVRAGE & RELANCE DU CYCLE — Étape 10
// Fichier: lib/Eleveures/New/Accouplemt/SevragePage.dart
//
// Affiche :
//   • Informations sur la mise bas et les agneaux
//   • Âge des agneaux (barre de progression 0→4 mois)
//   • Sélection des futurs reproducteurs parmi les agneaux
//   • Analyse des performances génétiques
//   • Bouton "Enregistrer le sevrage" → relance cycle mère
// ============================================================
 
import 'package:depart/Eleveures/New/Accouplemt/SevrageService.dart';
import 'package:depart/Eleveures/New/Reproduction/ReproductionConfig.dart';
import 'package:flutter/material.dart';
 
class SevragePage extends StatefulWidget {
  final SevrageEnAttente sevrage;
  final Map<String, dynamic> brebis;
 
  const SevragePage({
    super.key,
    required this.sevrage,
    required this.brebis,
  });
 
  @override
  State<SevragePage> createState() => _SevragePageState();
}
 
class _SevragePageState extends State<SevragePage> {
  final _service   = SevrageService();
  final _notesCtrl = TextEditingController();
 
  List<Map<String, dynamic>>  _agneaux          = [];
  PerformancesGenetiques?     _performances;
  Set<String>                 _reproducteursSel = {};
  bool _isLoading = true;
  bool _isSaving  = false;
 
  static const Color _vert   = Color(0xFF2E7D32);
  static const Color _violet = Color(0xFF6A1B9A);
  static const Color _orange = Color(0xFFE65100);
 
  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }
 
  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }
 
  Future<void> _chargerDonnees() async {
    final agneaux = await _service.getAgneauxAccouplement(
        widget.sevrage.accouplementId);
    final perf = await _service.analyserPerformances(
        widget.sevrage.accouplementId);
    if (mounted) {
      setState(() {
        _agneaux      = agneaux;
        _performances = perf;
        _isLoading    = false;
      });
    }
  }
 
  Future<void> _enregistrerSevrage() async {
    setState(() => _isSaving = true);
    try {
      await _service.enregistrerSevrage(
        accouplementId : widget.sevrage.accouplementId,
        brebisId       : widget.sevrage.brebisId,
        sourceBrebis   : widget.sevrage.sourceBrebis,
        nomBrebis      : widget.sevrage.nomBrebis,
        notes          : _notesCtrl.text.trim().isEmpty
            ? null : _notesCtrl.text.trim(),
      );
 
      if (mounted) {
        await _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
 
  // ============================================================
  // BUILD
  // ============================================================
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: AppBar(
        title: Text('Sevrage — ${widget.sevrage.nomBrebis}'),
        backgroundColor: _vert,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                _buildEnTeteBrebis(),
                const SizedBox(height: 16),
                _buildAgeAgneaux(),
                const SizedBox(height: 16),
                if (_performances != null) _buildPerformancesCard(),
                const SizedBox(height: 16),
                if (_agneaux.isNotEmpty) _buildSelectionReproducteurs(),
                const SizedBox(height: 16),
                _buildRelanceCycle(),
                const SizedBox(height: 16),
                _buildNotesSevrage(),
                const SizedBox(height: 24),
                _buildBoutonEnregistrer(),
              ],
            ),
    );
  }
 
  // ── En-tête brebis ───────────────────────────────────────
  Widget _buildEnTeteBrebis() {
    final sv = widget.sevrage;
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
                Text(sv.nomBrebis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                Text(widget.brebis['race'] ?? '',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8, runSpacing: 4,
                  children: [
                    _badge('🍼 ${sv.nombreAgneaux} agneau${sv.nombreAgneaux > 1 ? 'x' : ''}',
                        _violet),
                    _badge('📅 Nés le ${_fmt(sv.dateMiseBas)}', _vert),
                    _badge('⏰ ${sv.labelAge}',
                        sv.estUrgent ? _orange : Colors.grey[600]!),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
 
  // ── Âge des agneaux ──────────────────────────────────────
  Widget _buildAgeAgneaux() {
    final sv         = widget.sevrage;
    final ageJours   = sv.ageAgneauxJours;
    final dureeMax   = ReproductionConfig.dureeLactationJours +
                       ReproductionConfig.periodeSevrageJours;
    final progression = (ageJours / dureeMax).clamp(0.0, 1.0);
 
    Color couleurBarre;
    String conseil;
    if (ageJours < ReproductionConfig.dureeLactationJours) {
      couleurBarre = _vert;
      conseil = 'Sevrage pas encore recommandé. Attendez au moins 3 mois.';
    } else if (ageJours <=
        ReproductionConfig.dureeLactationJours +
        ReproductionConfig.periodeSevrageJours) {
      couleurBarre = _orange;
      conseil = '✅ Période de sevrage optimale (3 à 4 mois).';
    } else {
      couleurBarre = Colors.red;
      conseil = '⚠️ Sevrage en retard — à effectuer dès que possible.';
    }
 
    return Container(
      padding   : const EdgeInsets.all(16),
      decoration: _deco(Colors.white, Colors.grey.shade200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Âge des agneaux',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text('$ageJours jours (${sv.ageAgneauxSemaines} sem.)',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold,
                      color: couleurBarre)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value          : progression,
              backgroundColor: Colors.grey.shade100,
              valueColor     : AlwaysStoppedAnimation<Color>(couleurBarre),
              minHeight      : 12,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Naissance', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              Text('J+90 (sevrage)', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              Text('J+120', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color       : couleurBarre.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border      : Border.all(color: couleurBarre.withOpacity(0.25)),
            ),
            child: Text(conseil,
                style: TextStyle(fontSize: 12, color: couleurBarre)),
          ),
        ],
      ),
    );
  }
 
  // ── Performances génétiques ───────────────────────────────
  Widget _buildPerformancesCard() {
    final p = _performances!;
    if (p.nbAgneauxTotal == 0) return const SizedBox.shrink();
 
    return Container(
      padding   : const EdgeInsets.all(14),
      decoration: _deco(Colors.white, Colors.grey.shade200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_rounded, color: _violet, size: 18),
              const SizedBox(width: 8),
              const Text('Performances de la mise bas',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _statCard('Total', '${p.nbAgneauxTotal}', Icons.pets_rounded, _violet),
              const SizedBox(width: 8),
              _statCard('Vivants', '${p.nbVivants}', Icons.favorite_rounded, _vert),
              const SizedBox(width: 8),
              _statCard('♀', '${p.nbFemelles}', Icons.female_rounded,
                  const Color(0xFFE53935)),
              const SizedBox(width: 8),
              _statCard('♂', '${p.nbMales}', Icons.male_rounded,
                  Colors.blue[700]!),
            ],
          ),
          if (p.poidsMoyenKg != null) ...[
            const SizedBox(height: 10),
            _ligneStat('Poids moyen naissance',
                '${p.poidsMoyenKg!.toStringAsFixed(1)} kg',
                Icons.monitor_weight_rounded),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.trending_up_rounded,
                  size: 14, color: p.couleurTauxSurvie),
              const SizedBox(width: 6),
              Text('Taux de survie : ${p.tauxSurvieLabel}',
                  style: TextStyle(
                      fontSize: 13, color: p.couleurTauxSurvie,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          if (p.fPourcent != null) ...[
            const SizedBox(height: 6),
            _ligneStat(
              'Consanguinité parents',
              'F = ${p.fPourcent!.toStringAsFixed(1)}%'
              '${p.relation != null ? ' (${p.relation})' : ''}',
              Icons.device_hub_rounded,
            ),
          ],
        ],
      ),
    );
  }
 
  // ── Sélection futurs reproducteurs ───────────────────────
  Widget _buildSelectionReproducteurs() {
    final candidats = _agneaux
        .where((a) => a['etat_naissance'] != 'mort_ne')
        .toList();
 
    if (candidats.isEmpty) return const SizedBox.shrink();
 
    // Identifier ceux qui seront éligibles à 8 mois
    final dateSeuil = DateTime.now().subtract(
      Duration(days: ReproductionConfig.ageMinimumReproductionMois * 30),
    );
    // Les agneaux de 90j → éligibles dans ~5 mois
 
    return Container(
      decoration: _deco(Colors.white, Colors.grey.shade200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            decoration: BoxDecoration(
              color: _violet.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(Icons.stars_rounded, color: _violet, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sélection des futurs reproducteurs',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                      Text('Identifiez les agneaux à garder pour la reproduction',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: candidats.map((agneau) {
                final id      = agneau['id']?.toString() ?? '';
                final nom     = agneau['nom'] ?? 'Agneau';
                final sexe    = agneau['sexe'] ?? '';
                final poids   = agneau['poids_naissance'];
                final selectionne = _reproducteursSel.contains(id);
                final couleurSexe = sexe == 'Femelle'
                    ? const Color(0xFFE53935) : Colors.blue[700]!;
 
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selectionne) {
                      _reproducteursSel.remove(id);
                    } else {
                      _reproducteursSel.add(id);
                    }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: selectionne
                          ? _violet.withOpacity(0.08) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selectionne ? _violet : Colors.grey.shade200,
                        width: selectionne ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color : couleurSexe.withOpacity(0.12),
                            shape : BoxShape.circle,
                          ),
                          child: Icon(
                            sexe == 'Femelle'
                                ? Icons.female_rounded : Icons.male_rounded,
                            color: couleurSexe, size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nom,
                                  style: const TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w600)),
                              Text(
                                '$sexe${poids != null ? ' · ${poids.toStringAsFixed(1)} kg à la naissance' : ''}',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                        if (selectionne)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _violet.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Reproducteur',
                                style: TextStyle(
                                    fontSize: 10, color: _violet,
                                    fontWeight: FontWeight.bold)),
                          )
                        else
                          Icon(Icons.add_circle_outline_rounded,
                              color: Colors.grey[300], size: 20),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
 
  // ── Relance du cycle ─────────────────────────────────────
  Widget _buildRelanceCycle() {
    return Container(
      padding   : const EdgeInsets.all(14),
      decoration: _deco(
        const Color(0xFFE8F5E9), const Color(0xFFA5D6A7)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.loop_rounded, color: _vert, size: 18),
              const SizedBox(width: 8),
              const Text('Relance automatique du cycle',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32))),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Après le sevrage, le cycle de ${widget.sevrage.nomBrebis} sera '
            'automatiquement réactivé dans le module Chaleur. '
            'Un rappel sera envoyé dans 3 semaines pour surveiller '
            'le retour en chaleur.',
            style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.5),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 6,
            children: [
              _badge('🔥 Retour chaleur : ~J+21', _vert),
              _badge('📅 Prochain accouplement possible', Colors.blue[700]!),
              _badge('🔔 Notification automatique', _orange),
            ],
          ),
        ],
      ),
    );
  }
 
  // ── Notes sevrage ─────────────────────────────────────────
  Widget _buildNotesSevrage() {
    return Container(
      decoration: _deco(Colors.white, Colors.grey.shade200),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: TextFormField(
          controller : _notesCtrl,
          maxLines   : 2,
          decoration : const InputDecoration(
            labelText  : 'Notes sur le sevrage (optionnel)',
            hintText   : 'État des agneaux, observations, poids...',
            prefixIcon : Icon(Icons.notes_rounded, color: Color(0xFF2E7D32)),
            border     : OutlineInputBorder(),
          ),
        ),
      ),
    );
  }
 
  // ── Bouton enregistrer ────────────────────────────────────
  Widget _buildBoutonEnregistrer() {
    return SizedBox(
      width : double.infinity,
      height: 52,
      child : ElevatedButton.icon(
        onPressed: _isSaving ? null : _enregistrerSevrage,
        icon: _isSaving
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.check_circle_rounded),
        label: Text(
          _isSaving
              ? 'Enregistrement...'
              : 'Enregistrer le sevrage',
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _vert,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
 
  // ── Dialog succès ─────────────────────────────────────────
  Future<void> _showSuccessDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _vert.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _vert.withOpacity(0.12), shape: BoxShape.circle),
                    child: const Icon(Icons.loop_rounded,
                        color: Color(0xFF2E7D32), size: 36),
                  ),
                  const SizedBox(height: 12),
                  const Text('Sevrage enregistré !',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _ligneSucces(Icons.check_circle_rounded, _vert,
                      'Sevrage enregistré'),
                  _ligneSucces(Icons.loop_rounded, Colors.blue[700]!,
                      'Cycle de ${widget.sevrage.nomBrebis} réactivé'),
                  _ligneSucces(Icons.notifications_rounded, _orange,
                      'Rappel retour en chaleur planifié (J+21)'),
                  if (_reproducteursSel.isNotEmpty)
                    _ligneSucces(Icons.stars_rounded, _violet,
                        '${_reproducteursSel.length} futur${_reproducteursSel.length > 1 ? 's' : ''} reproducteur${_reproducteursSel.length > 1 ? 's' : ''} sélectionné${_reproducteursSel.length > 1 ? 's' : ''}'),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).pop(true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _vert, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Terminer',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
 
  // ── Utilitaires ──────────────────────────────────────────
 
  Widget _statCard(String label, String valeur, IconData icone, Color couleur) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: couleur.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: couleur.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icone, size: 18, color: couleur),
            const SizedBox(height: 4),
            Text(valeur,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: couleur)),
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: couleur.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }
 
  Widget _ligneStat(String label, String valeur, IconData icone) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icone, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 6),
          Text('$label : ',
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Text(valeur,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
 
  Widget _ligneSucces(IconData icone, Color couleur, String texte) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icone, size: 18, color: couleur),
          const SizedBox(width: 10),
          Expanded(child: Text(texte, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
 
  Widget _badge(String label, Color couleur) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: couleur.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: couleur.withOpacity(0.25)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: couleur, fontWeight: FontWeight.w500)),
    );
  }
 
  Widget _avatar(String? url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: url != null
          ? Image.network(url, width: 48, height: 48, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _avatarFallback())
          : _avatarFallback(),
    );
  }
 
  Widget _avatarFallback() => Container(
    width: 48, height: 48,
    decoration: BoxDecoration(
      color: _vert.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(Icons.pets_rounded, color: _vert, size: 24),
  );
 
  BoxDecoration _deco(Color bg, Color border) => BoxDecoration(
    color: bg, borderRadius: BorderRadius.circular(14),
    border: Border.all(color: border),
    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
        blurRadius: 8, offset: const Offset(0, 2))],
  );
 
  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}