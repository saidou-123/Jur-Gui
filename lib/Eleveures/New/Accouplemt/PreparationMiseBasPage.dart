// ============================================================
// PAGE PRÉPARATION MISE BAS — Étape 7
// Fichier: lib/Eleveures/New/Accouplemt/PreparationMiseBasPage.dart
//
// Affiche en temps réel :
//   • Compte à rebours jours/heures/minutes jusqu'à la mise bas
//   • Palier actif parmi : J-30, J-15, J-7, J-3, J-1, Jour J
//   • Conseils adaptés à chaque palier
//   • Checklist matériel par palier
//   • Barre de progression vers la mise bas
//
// Paliers et conseils métier :
//   J-30 : Isolation progressive, préparation loge, vaccination
//   J-15 : Vérification matériel, alimentation légère
//   J-7  : Surveillance quotidienne, signe précurseurs
//   J-3  : Présence renforcée, loge propre et sèche
//   J-1  : Surveillance permanente, vétérinaire prévenu
//   J0+  : Mise bas imminente ou dépassée
// ============================================================
 
import 'dart:async';
import 'package:depart/Eleveures/New/Reproduction/ReproductionConfig.dart';
import 'package:flutter/material.dart';
 
class PreparationMiseBasPage extends StatefulWidget {
  final Map<String, dynamic> accouplement;
  final Map<String, dynamic> brebis;
 
  const PreparationMiseBasPage({
    super.key,
    required this.accouplement,
    required this.brebis,
  });
 
  @override
  State<PreparationMiseBasPage> createState() =>
      _PreparationMiseBasPageState();
}
 
class _PreparationMiseBasPageState extends State<PreparationMiseBasPage>
    with SingleTickerProviderStateMixin {
 
  // ── Timer compte à rebours ───────────────────────────────
  Timer? _timer;
  Duration _tempsRestant = Duration.zero;
  late DateTime _dateAgnelage;
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulse;
 
  // ── Couleurs ─────────────────────────────────────────────
  static const Color _vert   = Color(0xFF2E7D32);
  static const Color _orange = Color(0xFFE65100);
  static const Color _rouge  = Color(0xFFB71C1C);
  static const Color _bleu   = Color(0xFF1565C0);
 
  @override
  void initState() {
    super.initState();
 
    // Récupérer la date d'agnelage
    final dateStr = widget.accouplement['date_prevue_agnelage']?.toString();
    _dateAgnelage = dateStr != null
        ? DateTime.parse(dateStr)
        : DateTime.now().add(
            Duration(days: ReproductionConfig.gestationMoyenneJours));
 
    // Animation pulsation pour le compte à rebours urgent
    _pulseCtrl = AnimationController(
      vsync   : this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
 
    _calculerTempsRestant();
    // Mise à jour toutes les minutes
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) _calculerTempsRestant();
    });
  }
 
  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }
 
  void _calculerTempsRestant() {
    final maintenant = DateTime.now();
    final diff = _dateAgnelage.difference(maintenant);
    setState(() {
      _tempsRestant = diff.isNegative ? Duration.zero : diff;
    });
  }
 
  // ── Palier actif ─────────────────────────────────────────
  _Palier get _palierActif {
    final jours = _dateAgnelage.difference(DateTime.now()).inDays;
    if (jours > 30)  return _paliers[0]; // avant J-30 → même conseils J-30
    if (jours > 15)  return _paliers[0]; // J-30
    if (jours > 7)   return _paliers[1]; // J-15
    if (jours > 3)   return _paliers[2]; // J-7
    if (jours > 1)   return _paliers[3]; // J-3
    if (jours >= 0)  return _paliers[4]; // J-1
    return _paliers[5];                  // Jour J passé
  }
 
  // ── Progression vers la mise bas ─────────────────────────
  double get _progression {
    final total = ReproductionConfig.gestationMoyenneJours.toDouble();
    final joursEcoules = total -
        _dateAgnelage.difference(DateTime.now()).inDays.toDouble();
    return (joursEcoules / total).clamp(0.0, 1.0);
  }
 
  // ============================================================
  // BUILD
  // ============================================================
 
  @override
  Widget build(BuildContext context) {
    final palier = _palierActif;
    final jours  = _dateAgnelage.difference(DateTime.now()).inDays;
 
    return Scaffold(
      backgroundColor: palier.couleurFond,
      appBar: AppBar(
        title          : const Text('Préparation mise bas'),
        backgroundColor: palier.couleurPrimaire,
        foregroundColor: Colors.white,
        elevation      : 0,
      ),
      body: ListView(
        padding : const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          _buildEnTeteBrebis(),
          const SizedBox(height: 16),
          _buildCompteARebours(palier, jours),
          const SizedBox(height: 16),
          _buildBarreProgression(),
          const SizedBox(height: 16),
          _buildNavigateurPaliers(jours),
          const SizedBox(height: 16),
          _buildCardConseils(palier),
          const SizedBox(height: 16),
          _buildChecklistMateriel(palier),
          const SizedBox(height: 16),
          _buildSignesPrecurseurs(),
        ],
      ),
    );
  }
 
  // ============================================================
  // WIDGET — En-tête brebis
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
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 12, color: _vert),
                    const SizedBox(width: 4),
                    Text(
                      'Agnelage prévu : ${_formatDate(_dateAgnelage)}',
                      style: TextStyle(
                        fontSize: 12, color: _vert,
                        fontWeight: FontWeight.w500),
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
 
  // ============================================================
  // WIDGET — Compte à rebours principal
  // ============================================================
 
  Widget _buildCompteARebours(_Palier palier, int jours) {
    final urgent = jours <= 3;
    final depasse = jours < 0;
 
    final heures   = _tempsRestant.inHours % 24;
    final minutes  = _tempsRestant.inMinutes % 60;
    final joursAff = _tempsRestant.inDays;
 
    return ScaleTransition(
      scale: urgent && !depasse ? _pulse : const AlwaysStoppedAnimation(1.0),
      child: Container(
        padding   : const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [palier.couleurPrimaire, palier.couleurPrimaire.withOpacity(0.75)],
            begin : Alignment.topLeft,
            end   : Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color     : palier.couleurPrimaire.withOpacity(0.35),
              blurRadius: 16,
              offset    : const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            // Badge palier
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color       : Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border      : Border.all(color: Colors.white.withOpacity(0.4)),
              ),
              child: Text(
                palier.labelPalier,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13, fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
 
            // Compte à rebours chiffres
            depasse
                ? Column(
                    children: [
                      const Icon(Icons.baby_changing_station_rounded,
                          color: Colors.white, size: 52),
                      const SizedBox(height: 8),
                      const Text(
                        'Mise bas imminente !',
                        style: TextStyle(
                          color: Colors.white, fontSize: 22,
                          fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Date prévue dépassée de ${(-jours)} jour${(-jours) > 1 ? 's' : ''}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85), fontSize: 13),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _chiffreRebours('$joursAff', 'jours'),
                      _separateur(),
                      _chiffreRebours(heures.toString().padLeft(2, '0'), 'heures'),
                      _separateur(),
                      _chiffreRebours(minutes.toString().padLeft(2, '0'), 'min'),
                    ],
                  ),
 
            const SizedBox(height: 12),
            Text(
              palier.sousTitreRebours,
              style: TextStyle(
                color   : Colors.white.withOpacity(0.85),
                fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
 
  Widget _chiffreRebours(String valeur, String label) {
    return Column(
      children: [
        Text(
          valeur,
          style: const TextStyle(
            color: Colors.white, fontSize: 44,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.75), fontSize: 11),
        ),
      ],
    );
  }
 
  Widget _separateur() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      child: Text(
        ':',
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 38, fontWeight: FontWeight.w300),
      ),
    );
  }
 
  // ============================================================
  // WIDGET — Barre de progression gestation
  // ============================================================
 
  Widget _buildBarreProgression() {
    final jours = _dateAgnelage.difference(DateTime.now()).inDays;
    final depasse = jours < 0;
 
    return Container(
      padding   : const EdgeInsets.all(14),
      decoration: _deco(Colors.white, Colors.grey.shade200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Progression gestation',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              Text(
                depasse
                    ? '≥ 100%'
                    : '${(_progression * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold,
                  color: _vert),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value          : _progression,
              backgroundColor: Colors.grey.shade100,
              valueColor     : AlwaysStoppedAnimation<Color>(_vert),
              minHeight      : 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Accouplement',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              Text('Mise bas prévue',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            ],
          ),
        ],
      ),
    );
  }
 
  // ============================================================
  // WIDGET — Navigateur de paliers (timeline)
  // ============================================================
 
  Widget _buildNavigateurPaliers(int jours) {
    final paliersDef = [
      (-30, 'J-30'), (-15, 'J-15'), (-7, 'J-7'),
      (-3, 'J-3'), (-1, 'J-1'), (0, 'J0'),
    ];
 
    return Container(
      padding   : const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: _deco(Colors.white, Colors.grey.shade200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Paliers de préparation',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: paliersDef.map((def) {
              final (seuil, label) = def;
              final atteint  = jours <= (-seuil);
              final actif    = _estPalierActif(jours, seuil);
              final couleur  = actif
                  ? _palierActif.couleurPrimaire
                  : atteint
                      ? _vert
                      : Colors.grey.shade300;
 
              return Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width : actif ? 36 : 28,
                    height: actif ? 36 : 28,
                    decoration: BoxDecoration(
                      color : couleur,
                      shape : BoxShape.circle,
                      boxShadow: actif
                          ? [BoxShadow(
                              color     : couleur.withOpacity(0.4),
                              blurRadius: 8,
                              offset    : const Offset(0, 2),
                            )]
                          : null,
                    ),
                    child: Center(
                      child: Icon(
                        atteint ? Icons.check_rounded : Icons.circle_outlined,
                        size : actif ? 18 : 14,
                        color: atteint || actif ? Colors.white : Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize  : actif ? 11 : 10,
                      fontWeight: actif ? FontWeight.bold : FontWeight.normal,
                      color     : actif ? _palierActif.couleurPrimaire : Colors.grey,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
 
  bool _estPalierActif(int jours, int seuil) {
    if (seuil == 0)  return jours <= 0;
    if (seuil == -1) return jours <= 1 && jours > 0;
    if (seuil == -3) return jours <= 3 && jours > 1;
    if (seuil == -7) return jours <= 7 && jours > 3;
    if (seuil == -15)return jours <= 15 && jours > 7;
    if (seuil == -30)return jours <= 30 && jours > 15;
    return false;
  }
 
  // ============================================================
  // WIDGET — Conseils du palier actif
  // ============================================================
 
  Widget _buildCardConseils(_Palier palier) {
    return Container(
      decoration: _deco(
        palier.couleurPrimaire.withOpacity(0.05),
        palier.couleurPrimaire.withOpacity(0.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: BoxDecoration(
              color       : palier.couleurPrimaire.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(palier.icone, color: palier.couleurPrimaire, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    palier.titreConseils,
                    style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold,
                      color: palier.couleurPrimaire),
                  ),
                ),
              ],
            ),
          ),
          // Conseils
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: palier.conseils.map((conseil) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width : 6, height: 6,
                      decoration: BoxDecoration(
                        color: palier.couleurPrimaire,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        conseil,
                        style: TextStyle(
                          fontSize: 13,
                          color   : Colors.grey[700],
                          height  : 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
 
  // ============================================================
  // WIDGET — Checklist matériel
  // ============================================================
 
  Widget _buildChecklistMateriel(_Palier palier) {
    if (palier.materiel.isEmpty) return const SizedBox.shrink();
 
    return Container(
      decoration: _deco(Colors.white, Colors.grey.shade200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(Icons.checklist_rounded,
                    color: Colors.grey[700], size: 18),
                const SizedBox(width: 8),
                Text(
                  'Matériel à préparer',
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold,
                    color: Colors.grey[800]),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing   : 8,
              runSpacing: 8,
              children  : palier.materiel.map((item) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color       : palier.couleurPrimaire.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border      : Border.all(
                    color: palier.couleurPrimaire.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 14, color: palier.couleurPrimaire),
                    const SizedBox(width: 6),
                    Text(item,
                        style: TextStyle(
                          fontSize: 12, color: Colors.grey[700])),
                  ],
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
 
  // ============================================================
  // WIDGET — Signes précurseurs universels
  // ============================================================
 
  Widget _buildSignesPrecurseurs() {
    final jours = _dateAgnelage.difference(DateTime.now()).inDays;
    if (jours > 7) return const SizedBox.shrink();
 
    final signes = [
      ('Mamelles gonflées et fermes', Icons.pregnant_woman_rounded),
      ('Vulve gonflée et rougeâtre', Icons.warning_amber_rounded),
      ('Comportement agité, tourne en rond', Icons.loop_rounded),
      ('Perd les eaux (liquide clair)', Icons.water_drop_rounded),
      ('Contractions abdominales visibles', Icons.monitor_heart_rounded),
      ('Recherche l\'isolement', Icons.location_off_rounded),
    ];
 
    return Container(
      decoration: _deco(
        const Color(0xFFFFF8E1), const Color(0xFFFFCC02)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF3CD),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                const Icon(Icons.visibility_rounded,
                    color: Color(0xFFF57F17), size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Signes précurseurs à surveiller',
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold,
                    color: Color(0xFFF57F17)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: signes.map((s) {
                final (label, icone) = s;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(icone, size: 16,
                          color: const Color(0xFFF57F17)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13, color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
 
  // ============================================================
  // UTILITAIRES
  // ============================================================
 
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
    color: bg,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: border),
    boxShadow: [
      BoxShadow(color: Colors.black.withOpacity(0.04),
          blurRadius: 8, offset: const Offset(0, 2))
    ],
  );
 
  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}
 
// ============================================================
// MODÈLE PALIER — données et conseils par palier
// ============================================================
 
class _Palier {
  final String        labelPalier;
  final String        sousTitreRebours;
  final String        titreConseils;
  final IconData      icone;
  final Color         couleurPrimaire;
  final Color         couleurFond;
  final List<String>  conseils;
  final List<String>  materiel;
 
  const _Palier({
    required this.labelPalier,
    required this.sousTitreRebours,
    required this.titreConseils,
    required this.icone,
    required this.couleurPrimaire,
    required this.couleurFond,
    required this.conseils,
    required this.materiel,
  });
}
 
// ── Liste des 6 paliers ───────────────────────────────────────
const List<_Palier> _paliers = [
 
  // ── J-30 ──────────────────────────────────────────────────
  _Palier(
    labelPalier      : 'À J-30 de la mise bas',
    sousTitreRebours : 'Préparez la loge d\'agnelage dès maintenant',
    titreConseils    : 'Préparation à 1 mois — Organisation générale',
    icone            : Icons.calendar_month_rounded,
    couleurPrimaire  : Color(0xFF1565C0),
    couleurFond      : Color(0xFFECF3FD),
    conseils: [
      'Isolez progressivement la brebis du reste du troupeau pour réduire le stress.',
      'Préparez et désinfectez la loge d\'agnelage (4m² minimum, litière propre et sèche).',
      'Réalisez la vaccination contre les clostridioses si ce n\'est pas encore fait.',
      'Augmentez légèrement la ration alimentaire : +20% d\'énergie et protéines.',
      'Vérifiez l\'état corporel (score 3 à 3,5 sur 5 est idéal).',
      'Notez le numéro de votre vétérinaire dans votre téléphone en cas d\'urgence.',
    ],
    materiel: [
      'Loge d\'agnelage', 'Désinfectant', 'Litière fraîche',
      'Compléments minéraux', 'Carnet de suivi',
    ],
  ),
 
  // ── J-15 ──────────────────────────────────────────────────
  _Palier(
    labelPalier      : 'À J-15 de la mise bas',
    sousTitreRebours : 'Vérifiez le matériel et l\'alimentation',
    titreConseils    : 'Préparation à 2 semaines — Matériel et alimentation',
    icone            : Icons.inventory_2_rounded,
    couleurPrimaire  : Color(0xFF2E7D32),
    couleurFond      : Color(0xFFEDF7ED),
    conseils: [
      'Vérifiez que tout le matériel d\'agnelage est disponible et propre.',
      'Réduisez les aliments riches en calcium (éviter la fièvre de lait).',
      'Augmentez la ration de foin de qualité et de concentrés énergétiques.',
      'Vérifiez les mamelles : elles doivent commencer à se développer.',
      'Observez le comportement quotidiennement — notez tout changement.',
      'Préparez la trousse d\'agnelage avec tout le matériel nécessaire.',
    ],
    materiel: [
      'Trousse agnelage', 'Iode désinfectant', 'Poire aspirante',
      'Seringues stériles', 'Chaleur artificielle', 'Balance',
    ],
  ),
 
  // ── J-7 ───────────────────────────────────────────────────
  _Palier(
    labelPalier      : 'À J-7 de la mise bas',
    sousTitreRebours : 'Surveillance quotidienne recommandée',
    titreConseils    : 'Dernière semaine — Surveillance accrue',
    icone            : Icons.visibility_rounded,
    couleurPrimaire  : Color(0xFFF57F17),
    couleurFond      : Color(0xFFFFF8F0),
    conseils: [
      'Vérifiez la brebis matin et soir — notez l\'état des mamelles.',
      'La vulve peut commencer à gonfler et changer de couleur (rougeâtre).',
      'Réduisez les déplacements et manipulations inutiles pour limiter le stress.',
      'Assurez-vous que la loge est propre, sèche et à l\'abri des courants d\'air.',
      'Préparez de l\'eau tiède, des serviettes propres et le numéro du véto.',
      'Vérifiez que les trayons sont dégagés (tondre si nécessaire).',
    ],
    materiel: [
      'Eau tiède', 'Serviettes propres', 'Colostrum de secours',
      'Thermomètre', 'Lampe chauffante', 'Numéro véto affiché',
    ],
  ),
 
  // ── J-3 ───────────────────────────────────────────────────
  _Palier(
    labelPalier      : 'À J-3 de la mise bas',
    sousTitreRebours : 'Présence renforcée — Vérification toutes les 4h',
    titreConseils    : '3 derniers jours — Vigilance maximale',
    icone            : Icons.access_alarm_rounded,
    couleurPrimaire  : Color(0xFFD84315),
    couleurFond      : Color(0xFFFFF3EF),
    conseils: [
      'Vérifiez la brebis toutes les 4 heures, y compris la nuit.',
      'Les mamelles doivent être gonflées et chaudes — signe imminent.',
      'Observez la forme de l\'abdomen : il peut descendre légèrement.',
      'Préparez une bouteille de colostrum de secours au réfrigérateur.',
      'Prévenez votre vétérinaire que la mise bas est proche.',
      'Assurez-vous d\'avoir de l\'aide disponible si nécessaire.',
    ],
    materiel: [
      'Colostrum congelé', 'Biberon agneau', 'Gants obstétricaux',
      'Lubrifiant obstétrical', 'Ficelle propre', 'Lampe frontale',
    ],
  ),
 
  // ── J-1 ───────────────────────────────────────────────────
  _Palier(
    labelPalier      : 'Mise bas dans moins de 24h',
    sousTitreRebours : '⚠️ Surveillance permanente requise',
    titreConseils    : 'Dernières 24 heures — Présence obligatoire',
    icone            : Icons.warning_amber_rounded,
    couleurPrimaire  : Color(0xFFB71C1C),
    couleurFond      : Color(0xFFFFF5F5),
    conseils: [
      '🚨 Restez à proximité — la mise bas peut commencer à tout moment.',
      'Vérifiez toutes les heures : contractions, perte des eaux, comportement.',
      'Si vous voyez les pieds ou la tête de l\'agneau sans progression depuis 30 min → appelez le vétérinaire.',
      'Ne forcez jamais sans avis vétérinaire si la progression est bloquée.',
      'Préparez l\'accueil : chaleur, colostrum, lingettes, balance.',
      'Une mise bas normale dure de 30 min à 2h après le début des contractions.',
    ],
    materiel: [
      'TOUT le matériel', 'Vétérinaire prévenu',
      'Accompagnant disponible', 'Téléphone chargé',
    ],
  ),
 
  // ── Jour J ────────────────────────────────────────────────
  _Palier(
    labelPalier      : 'Mise bas imminente',
    sousTitreRebours : 'La date prévue est atteinte — Surveillance permanente',
    titreConseils    : 'Jour J — Procédure agnelage',
    icone            : Icons.baby_changing_station_rounded,
    couleurPrimaire  : Color(0xFF6A1B9A),
    couleurFond      : Color(0xFFF9F0FF),
    conseils: [
      '1. Laissez la brebis accoucher naturellement si tout se passe bien.',
      '2. Après la naissance : dégagez les voies respiratoires de l\'agneau.',
      '3. Séchez l\'agneau avec une serviette propre (stimule la respiration).',
      '4. Assurez-vous que l\'agneau tète dans l\'heure qui suit (colostrum vital).',
      '5. Désinfectez le cordon ombilical avec de l\'iode.',
      '6. Pesez et identifiez chaque agneau, notez le sexe.',
      '7. Surveiller la brebis 2h après : délivrance (placenta) doit sortir.',
      '8. Si la délivrance n\'est pas sortie après 6h → vétérinaire obligatoire.',
    ],
    materiel: [
      'Serviettes', 'Iode cordon', 'Balance', 'Boucles oreilles',
      'Carnet notation', 'Colostrum', 'Biberon', 'Thermomètre',
    ],
  ),
];