// ============================================================
// PAGE DÉCLARATION DE MISE BAS — Étape 8
// Fichier: lib/Eleveures/New/Accouplemt/DeclarationMiseBasPage.dart
//
// Saisie complète en une opération :
//   1. Date et heure de la mise bas
//   2. Nombre d'agneaux (de 1 à 6)
//   3. Pour chaque agneau : sexe, poids, nom (optionnel), état, observations
//   4. Notes globales sur la mise bas
//
// Mise à jour automatique en une transaction :
//   • accouplements : date_mise_bas + nombre_agneaux + statut_gestation
//   • agneaux       : insert N lignes avec généalogie automatique
//   • nouveaux_nee  : insert N animaux (père et mère renseignés)
//   • notifications : annulation rappels agnelage + notification succès
// ============================================================
 
import 'package:depart/Eleveures/New/Notification/NotificationService.dart';
import 'package:depart/Eleveures/New/Reproduction/ReproductionConfig.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
 
class DeclarationMiseBasPage extends StatefulWidget {
  /// Accouplement pour lequel déclarer la mise bas
  final Map<String, dynamic> accouplement;
 
  /// Brebis mère (pour pré-remplir la généalogie)
  final Map<String, dynamic> brebis;
 
  const DeclarationMiseBasPage({
    super.key,
    required this.accouplement,
    required this.brebis,
  });
 
  @override
  State<DeclarationMiseBasPage> createState() =>
      _DeclarationMiseBasPageState();
}
 
class _DeclarationMiseBasPageState extends State<DeclarationMiseBasPage> {
  final _supabase   = Supabase.instance.client;
  final _notif      = NotificationService();
  final _formKey    = GlobalKey<FormState>();
  final _notesCtrl  = TextEditingController();
 
  // ── Date / heure ─────────────────────────────────────────
  DateTime  _dateMiseBas  = DateTime.now();
  TimeOfDay _heureMiseBas = TimeOfDay.now();
 
  // ── Agneaux ───────────────────────────────────────────────
  int _nombreAgneaux = 1;
  late List<_AgneauFormData> _agneaux;
 
  // ── État ──────────────────────────────────────────────────
  bool _isLoading = false;
 
  // ── Couleurs ──────────────────────────────────────────────
  static const Color _vert    = Color(0xFF2E7D32);
  static const Color _violet  = Color(0xFF6A1B9A);
  static const Color _rouge   = Color(0xFFB71C1C);
 
  @override
  void initState() {
    super.initState();
    _agneaux = List.generate(1, (_) => _AgneauFormData());
  }
 
  @override
  void dispose() {
    _notesCtrl.dispose();
    for (final a in _agneaux) {
      a.dispose();
    }
    super.dispose();
  }
 
  // ============================================================
  // MISE À JOUR DU NOMBRE D'AGNEAUX
  // ============================================================
 
  void _setNombreAgneaux(int n) {
    setState(() {
      _nombreAgneaux = n;
      if (n > _agneaux.length) {
        // Ajouter des formulaires
        for (int i = _agneaux.length; i < n; i++) {
          _agneaux.add(_AgneauFormData());
        }
      } else if (n < _agneaux.length) {
        // Supprimer les formulaires en trop
        for (int i = _agneaux.length - 1; i >= n; i--) {
          _agneaux[i].dispose();
          _agneaux.removeAt(i);
        }
      }
    });
  }
 
  // ============================================================
  // ENREGISTREMENT COMPLET
  // ============================================================
 
  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
 
    // Vérifier qu'au moins un agneau a un sexe sélectionné
    for (int i = 0; i < _agneaux.length; i++) {
      if (_agneaux[i].sexe == null) {
        _showSnackBar('Sélectionnez le sexe de l\'agneau ${i + 1}', Colors.orange);
        return;
      }
    }
 
    setState(() => _isLoading = true);
 
    try {
      final userId = _supabase.auth.currentUser!.id;
      final accouplementId = widget.accouplement['id']?.toString();
 
      // Date complète mise bas
      final dateMiseBas = DateTime(
        _dateMiseBas.year,
        _dateMiseBas.month,
        _dateMiseBas.day,
        _heureMiseBas.hour,
        _heureMiseBas.minute,
      );
 
      // ── ÉTAPE 1 : Mettre à jour l'accouplement ────────────
      await _supabase.from('accouplements').update({
        'date_mise_bas'    : dateMiseBas.toIso8601String(),
        'nombre_agneaux'   : _nombreAgneaux,
        'notes_mise_bas'   : _notesCtrl.text.trim().isEmpty
            ? null
            : _notesCtrl.text.trim(),
        'statut_gestation' : 'gestation_confirmee',
      }).eq('id', accouplementId!);
 
      debugPrint('✅ Accouplement mis à jour: mise bas enregistrée');
 
      // ── ÉTAPE 2 : Insérer chaque agneau ───────────────────
      final List<String> idsAgneaux = [];
 
      for (int i = 0; i < _agneaux.length; i++) {
        final agneau = _agneaux[i];
        final nomAgneau = agneau.nomCtrl.text.trim().isEmpty
            ? '${_nomBrebis()} - Agneau ${i + 1}'
            : agneau.nomCtrl.text.trim();
 
        // ── Insert dans la table agneaux (suivi détaillé) ──
        final insertAgneau = await _supabase.from('agneaux').insert({
          'accouplement_id' : accouplementId,
          'user_id'         : userId,
          'nom'             : nomAgneau,
          'sexe'            : agneau.sexe!,
          'poids_naissance' : agneau.poidsCtrl.text.trim().isEmpty
              ? null
              : double.tryParse(agneau.poidsCtrl.text.trim()),
          'pere_id'         : widget.accouplement['belier_id']?.toString(),
          'source_pere'     : widget.accouplement['source_belier'],
          'mere_id'         : widget.brebis['id']?.toString(),
          'source_mere'     : widget.brebis['source'],
          'race'            : widget.brebis['race'],
          'observations'    : agneau.obsCtrl.text.trim().isEmpty
              ? null
              : agneau.obsCtrl.text.trim(),
          'etat_naissance'  : agneau.etat,
          'date_naissance'  : dateMiseBas.toIso8601String(),
          'created_at'      : DateTime.now().toIso8601String(),
        }).select('id').single();
 
        idsAgneaux.add(insertAgneau['id'].toString());
 
        // ── Insert dans nouveaux_nee (animal dans le troupeau) ──
        // Seulement si l'état est 'vivant' ou 'faible'
        if (agneau.etat != 'mort_ne') {
          await _supabase.from('nouveaux_nee').insert({
            'nom'          : nomAgneau,
            'race'         : widget.brebis['race'],
            'date_naissance': dateMiseBas.toIso8601String().substring(0, 10),
            'sexe'         : agneau.sexe!,
            'user_id'      : userId,
            'created_at'   : DateTime.now().toIso8601String(),
            // ── Généalogie automatique ──────────────────────
            'pere_id'      : widget.accouplement['belier_id']?.toString(),
            'source_pere'  : widget.accouplement['source_belier'],
            'mere_id'      : widget.brebis['id']?.toString(),
            'source_mere'  : widget.brebis['source'],
          });
          debugPrint('✅ Agneau $nomAgneau ajouté au troupeau (nouveaux_nee)');
        }
      }
 
      // ── ÉTAPE 3 : Annuler les rappels agnelage ────────────
      await _notif.annulerRappelsBrebis(
        brebisId: widget.brebis['id'],
        source  : widget.brebis['source'],
      );
 
      // ── ÉTAPE 4 : Notification de succès ──────────────────
      final vivants = _agneaux.where((a) => a.etat != 'mort_ne').length;
      final mortsNes = _agneaux.where((a) => a.etat == 'mort_ne').length;
 
      await _notif.afficherNotificationImmediateLocal(
        titre  : '🎉 Mise bas réussie — ${_nomBrebis()}',
        corps  : '$vivants agneau${vivants > 1 ? 'x' : ''} né${vivants > 1 ? 's' : ''}'
                 '${mortsNes > 0 ? ' ($mortsNes mort-né${mortsNes > 1 ? 's' : ''})' : ''}. '
                 'Généalogie enregistrée automatiquement.',
        type   : 'mise_bas',
      );
 
      debugPrint(
        '✅ Mise bas complète : ${_agneaux.length} agneaux, '
        '$vivants vivants, $mortsNes mort-nés',
      );
 
      if (mounted) {
        await _showSuccessDialog(
          dateMiseBas: dateMiseBas,
          vivants    : vivants,
          mortsNes   : mortsNes,
        );
      }
    } catch (e, stack) {
      debugPrint('❌ Erreur enregistrement mise bas: $e\n$stack');
      if (mounted) {
        _showSnackBar('Erreur : ${e.toString()}', Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
 
  // ============================================================
  // BUILD
  // ============================================================
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        title: const Text('Déclarer une mise bas'),
        backgroundColor: _vert,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF2E7D32)),
                  SizedBox(height: 16),
                  Text('Enregistrement en cours...'),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  _buildSectionBrebis(),
                  const SizedBox(height: 16),
                  _buildSectionDateTime(),
                  const SizedBox(height: 16),
                  _buildSectionNombreAgneaux(),
                  const SizedBox(height: 16),
                  // Formulaire pour chaque agneau
                  ...List.generate(
                    _agneaux.length,
                    (i) => _buildFormulaireAgneau(i),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionNotes(),
                  const SizedBox(height: 24),
                  _buildBoutonEnregistrer(),
                ],
              ),
            ),
    );
  }
 
  // ============================================================
  // SECTION — RÉCAP BREBIS
  // ============================================================
 
  Widget _buildSectionBrebis() {
    final dateAgnelage = widget.accouplement['date_prevue_agnelage'] != null
        ? DateTime.parse(widget.accouplement['date_prevue_agnelage'])
        : null;
 
    return Container(
      padding   : const EdgeInsets.all(16),
      decoration: _boxDeco(_vert.withOpacity(0.08), _vert.withOpacity(0.3)),
      child: Row(
        children: [
          _buildAvatar(widget.brebis['image_url'], _vert, Icons.female_rounded),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nomBrebis(),
                  style: const TextStyle(
                    fontSize  : 17,
                    fontWeight: FontWeight.w700,
                    color     : Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  widget.brebis['race'] ?? 'Race inconnue',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                if (dateAgnelage != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.event_rounded, size: 13, color: _vert),
                      const SizedBox(width: 4),
                      Text(
                        'Prévu : ${_formatDate(dateAgnelage)}',
                        style: TextStyle(
                          fontSize  : 12,
                          color     : _vert,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Badge père
          if (widget.accouplement['belier_id'] != null) ...[
            Column(
              children: [
                Icon(Icons.male_rounded, size: 18, color: Colors.blue[700]),
                Text(
                  'Bélier',
                  style: TextStyle(fontSize: 10, color: Colors.blue[700]),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
 
  // ============================================================
  // SECTION — DATE ET HEURE
  // ============================================================
 
  Widget _buildSectionDateTime() {
    return Column(
      children: [
        _buildCard(
          'Date de la mise bas',
          Icons.calendar_today_rounded,
          _vert,
          _formatDate(_dateMiseBas),
          onTap: () async {
            final d = await showDatePicker(
              context    : context,
              initialDate: _dateMiseBas,
              firstDate  : DateTime.now().subtract(const Duration(days: 3)),
              lastDate   : DateTime.now(),
              builder    : (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: ColorScheme.light(primary: _vert),
                ),
                child: child!,
              ),
            );
            if (d != null && mounted) setState(() => _dateMiseBas = d);
          },
        ),
        const SizedBox(height: 10),
        _buildCard(
          'Heure de la mise bas',
          Icons.access_time_rounded,
          _vert,
          '${_heureMiseBas.hour.toString().padLeft(2, '0')}h'
          '${_heureMiseBas.minute.toString().padLeft(2, '0')}',
          onTap: () async {
            final t = await showTimePicker(
              context    : context,
              initialTime: _heureMiseBas,
            );
            if (t != null && mounted) setState(() => _heureMiseBas = t);
          },
        ),
      ],
    );
  }
 
  // ============================================================
  // SECTION — NOMBRE D'AGNEAUX
  // ============================================================
 
  Widget _buildSectionNombreAgneaux() {
    return Container(
      padding   : const EdgeInsets.all(16),
      decoration: _boxDeco(Colors.white, Colors.grey.shade200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pets_rounded, color: _violet, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Nombre d\'agneaux nés',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (i) {
              final n = i + 1;
              final selectionne = _nombreAgneaux == n;
              return GestureDetector(
                onTap: () => _setNombreAgneaux(n),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width : 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color       : selectionne ? _violet : Colors.grey.shade100,
                    shape       : BoxShape.circle,
                    border      : Border.all(
                      color: selectionne ? _violet : Colors.grey.shade300,
                      width: selectionne ? 2 : 1,
                    ),
                    boxShadow: selectionne
                        ? [BoxShadow(
                            color     : _violet.withOpacity(0.3),
                            blurRadius: 8,
                            offset    : const Offset(0, 2),
                          )]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$n',
                      style: TextStyle(
                        fontSize  : 16,
                        fontWeight: FontWeight.bold,
                        color     : selectionne ? Colors.white : Colors.grey[700],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              '$_nombreAgneaux agneau${_nombreAgneaux > 1 ? 'x' : ''}',
              style: TextStyle(
                fontSize  : 13,
                color     : _violet,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
 
  // ============================================================
  // FORMULAIRE POUR CHAQUE AGNEAU
  // ============================================================
 
  Widget _buildFormulaireAgneau(int index) {
    final agneau = _agneaux[index];
    final couleur = agneau.sexe == 'Mâle'
        ? Colors.blue[700]!
        : agneau.sexe == 'Femelle'
            ? _rouge
            : _violet;
 
    return Container(
      margin    : const EdgeInsets.only(bottom: 12),
      decoration: _boxDeco(Colors.white, couleur.withOpacity(0.2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête agneau ──
          Container(
            padding   : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color        : couleur.withOpacity(0.08),
              borderRadius : const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(Icons.pets_rounded, color: couleur, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Agneau ${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize  : 15,
                    color     : couleur,
                  ),
                ),
                const Spacer(),
                // Badge état
                _buildBadgeEtat(agneau.etat, () {
                  _showEtatPicker(index);
                }),
              ],
            ),
          ),
 
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                // ── Sexe (obligatoire) ──
                Row(
                  children: [
                    Expanded(
                      child: _buildChoixSexe(
                        label     : '♂ Mâle',
                        selectionne: agneau.sexe == 'Mâle',
                        couleur   : Colors.blue[700]!,
                        onTap     : () => setState(() => agneau.sexe = 'Mâle'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildChoixSexe(
                        label     : '♀ Femelle',
                        selectionne: agneau.sexe == 'Femelle',
                        couleur   : _rouge,
                        onTap     : () => setState(() => agneau.sexe = 'Femelle'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
 
                // ── Poids ──
                TextFormField(
                  controller   : agneau.poidsCtrl,
                  keyboardType : const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    labelText  : 'Poids à la naissance (kg)',
                    hintText   : 'Ex: 3.5',
                    prefixIcon : Icon(Icons.monitor_weight_rounded, color: couleur),
                    border     : const OutlineInputBorder(),
                    suffixText : 'kg',
                  ),
                ),
                const SizedBox(height: 12),
 
                // ── Nom (optionnel) ──
                TextFormField(
                  controller : agneau.nomCtrl,
                  decoration : InputDecoration(
                    labelText : 'Nom (optionnel)',
                    hintText  : 'Laissez vide pour un nom automatique',
                    prefixIcon: Icon(Icons.badge_rounded, color: couleur),
                    border    : const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
 
                // ── Observations ──
                TextFormField(
                  controller : agneau.obsCtrl,
                  maxLines   : 2,
                  decoration : InputDecoration(
                    labelText : 'Observations (optionnel)',
                    hintText  : 'Anomalies, comportement, allaitement...',
                    prefixIcon: Icon(Icons.notes_rounded, color: couleur),
                    border    : const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
 
  // ============================================================
  // SECTION — NOTES GLOBALES
  // ============================================================
 
  Widget _buildSectionNotes() {
    return Container(
      decoration: _boxDeco(Colors.white, Colors.grey.shade200),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: TextFormField(
          controller : _notesCtrl,
          maxLines   : 3,
          decoration : const InputDecoration(
            labelText  : 'Notes sur la mise bas (optionnel)',
            hintText   : 'Durée du travail, difficultés, intervention véto...',
            prefixIcon : Icon(Icons.notes_rounded, color: Color(0xFF2E7D32)),
            border     : OutlineInputBorder(),
          ),
        ),
      ),
    );
  }
 
  // ============================================================
  // BOUTON ENREGISTRER
  // ============================================================
 
  Widget _buildBoutonEnregistrer() {
    return SizedBox(
      width : double.infinity,
      height: 54,
      child : ElevatedButton.icon(
        onPressed: _isLoading ? null : _enregistrer,
        icon     : _isLoading
            ? const SizedBox(
                width : 20,
                height: 20,
                child : CircularProgressIndicator(
                  color      : Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.check_circle_rounded),
        label: Text(
          _isLoading ? 'Enregistrement...' : 'Enregistrer la mise bas',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _vert,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 2,
        ),
      ),
    );
  }
 
  // ============================================================
  // DIALOG SUCCÈS
  // ============================================================
 
  Future<void> _showSuccessDialog({
    required DateTime dateMiseBas,
    required int vivants,
    required int mortsNes,
  }) async {
    await showDialog(
      context          : context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── En-tête vert ──
            Container(
              width    : double.infinity,
              padding  : const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color       : _vert.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    padding   : const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color : _vert.withOpacity(0.15),
                      shape : BoxShape.circle,
                    ),
                    child: const Icon(Icons.celebration_rounded,
                        color: Color(0xFF2E7D32), size: 40),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Mise bas enregistrée !',
                    style: TextStyle(
                      fontSize  : 20,
                      fontWeight: FontWeight.bold,
                      color     : Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            ),
            // ── Détails ──
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildLigneInfo(
                    Icons.pets_rounded, _violet,
                    '$vivants agneau${vivants > 1 ? 'x' : ''} vivant${vivants > 1 ? 's' : ''}',
                  ),
                  if (mortsNes > 0)
                    _buildLigneInfo(
                      Icons.info_rounded, Colors.grey,
                      '$mortsNes mort-né${mortsNes > 1 ? 's' : ''}',
                    ),
                  _buildLigneInfo(
                    Icons.calendar_today_rounded, _vert,
                    _formatDate(dateMiseBas),
                  ),
                  _buildLigneInfo(
                    Icons.family_restroom_rounded, Colors.blue[700]!,
                    'Généalogie enregistrée automatiquement',
                  ),
                  _buildLigneInfo(
                    Icons.notifications_off_rounded, Colors.orange,
                    'Rappels agnelage annulés',
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).pop(true); // retourner true = mise à jour nécessaire
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _vert,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Terminer', style: TextStyle(fontSize: 16)),
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
 
  // ============================================================
  // SÉLECTEUR D'ÉTAT DE L'AGNEAU
  // ============================================================
 
  void _showEtatPicker(int index) {
    showModalBottomSheet(
      context           : context,
      backgroundColor   : Colors.transparent,
      isScrollControlled: false,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color       : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width : 40,
              height: 4,
              decoration: BoxDecoration(
                color       : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'État à la naissance',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...{
              'vivant'  : ('✅ Vivant et en bonne santé', Colors.green),
              'faible'  : ('⚠️ Vivant mais faible', Colors.orange),
              'mort_ne' : ('💀 Mort-né', Colors.grey),
            }.entries.map((e) => ListTile(
              leading: CircleAvatar(
                backgroundColor: e.value.$2.withOpacity(0.15),
                child: Text(
                  e.value.$1.substring(0, 1),
                  style: TextStyle(color: e.value.$2),
                ),
              ),
              title: Text(
                e.value.$1,
                style: TextStyle(
                  fontWeight: _agneaux[index].etat == e.key
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: e.value.$2,
                ),
              ),
              trailing: _agneaux[index].etat == e.key
                  ? Icon(Icons.check_circle, color: e.value.$2)
                  : null,
              onTap: () {
                setState(() => _agneaux[index].etat = e.key);
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }
 
  // ============================================================
  // WIDGETS UTILITAIRES
  // ============================================================
 
  Widget _buildChoixSexe({
    required String label,
    required bool   selectionne,
    required Color  couleur,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding : const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color       : selectionne ? couleur.withOpacity(0.12) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border      : Border.all(
            color: selectionne ? couleur : Colors.grey.shade300,
            width: selectionne ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize  : 15,
              fontWeight: selectionne ? FontWeight.bold : FontWeight.normal,
              color     : selectionne ? couleur : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }
 
  Widget _buildBadgeEtat(String etat, VoidCallback onTap) {
    final map = {
      'vivant'  : ('Vivant', Colors.green),
      'faible'  : ('Faible', Colors.orange),
      'mort_ne' : ('Mort-né', Colors.grey),
    };
    final (label, couleur) = map[etat] ?? ('Vivant', Colors.green);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color       : couleur.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border      : Border.all(color: couleur.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize  : 11,
                fontWeight: FontWeight.w600,
                color     : couleur,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit_rounded, size: 11, color: couleur),
          ],
        ),
      ),
    );
  }
 
  Widget _buildCard(
    String label, IconData icone, Color couleur, String valeur, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding   : const EdgeInsets.all(14),
        decoration: _boxDeco(Colors.white, Colors.grey.shade200),
        child: Row(
          children: [
            Icon(icone, color: couleur, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  Text(valeur,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: couleur, size: 22),
          ],
        ),
      ),
    );
  }
 
  Widget _buildLigneInfo(IconData icone, Color couleur, String texte) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icone, size: 18, color: couleur),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texte, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
 
  Widget _buildAvatar(String? url, Color couleur, IconData fallback) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: url != null
          ? Image.network(url,
              width: 52, height: 52, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  _avatarFallback(couleur, fallback))
          : _avatarFallback(couleur, fallback),
    );
  }
 
  Widget _avatarFallback(Color couleur, IconData icone) {
    return Container(
      width : 52,
      height: 52,
      decoration: BoxDecoration(
        color       : couleur.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icone, color: couleur, size: 26),
    );
  }
 
  BoxDecoration _boxDeco(Color bg, Color border) {
    return BoxDecoration(
      color       : bg,
      borderRadius: BorderRadius.circular(14),
      border      : Border.all(color: border, width: 1),
      boxShadow   : [
        BoxShadow(
          color     : Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset    : const Offset(0, 2),
        ),
      ],
    );
  }
 
  void _showSnackBar(String msg, Color couleur) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content        : Text(msg),
        backgroundColor: couleur,
        behavior       : SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
 
  String _nomBrebis() => widget.brebis['nom']?.toString() ?? 'Brebis';
 
  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}
 
// ============================================================
// MODÈLE DONNÉES FORMULAIRE AGNEAU
// ============================================================
 
class _AgneauFormData {
  String? sexe;
  String  etat = 'vivant';
  final TextEditingController nomCtrl   = TextEditingController();
  final TextEditingController poidsCtrl = TextEditingController();
  final TextEditingController obsCtrl   = TextEditingController();
 
  void dispose() {
    nomCtrl.dispose();
    poidsCtrl.dispose();
    obsCtrl.dispose();
  }
}
 