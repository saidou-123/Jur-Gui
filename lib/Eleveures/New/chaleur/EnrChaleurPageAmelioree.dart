// ============================================================
// ENREGISTRER CHALEUR - VERSION CORRIGÉE
// Fix: Gestion correcte des IDs mixtes (int pour nee, UUID pour achete)
// ============================================================
import 'package:depart/Eleveures/New/Accouplemt/Accouplement..dart';
import 'package:depart/Eleveures/New/Accouplemt/ConsanguiniteService.dart';
import 'package:depart/Eleveures/New/Notification/NotificationService.dart';
import 'package:depart/Eleveures/New/Reproduction/ReproductionBusinessService.dart';
import 'package:depart/Eleveures/New/Reproduction/ReproductionConfig.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class EnregistrerChaleurPageAmelioree extends StatefulWidget {
  final Map<String, dynamic> brebis;
  final String source;

  const EnregistrerChaleurPageAmelioree({
    super.key,
    required this.brebis,
    required this.source,
  });

  @override
  State<EnregistrerChaleurPageAmelioree> createState() => 
      _EnregistrerChaleurPageAmelioreeState();
}

class _EnregistrerChaleurPageAmelioreeState 
    extends State<EnregistrerChaleurPageAmelioree> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _businessService = ReproductionBusinessService();
  final _notificationService = NotificationService();

  DateTime _dateSelectionnee = DateTime.now();
  TimeOfDay _heureSelectionnee = TimeOfDay.now();
  String? _intensite;
  final _signesController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;
  
  // Données enrichies
  bool _estGestante = false;
  bool _enLactation = false;
  Map<String, dynamic>? _derniereChaleur;
  int? _intervalleJours;
  
  // Validation
  ValidationResult? _validationResult;

  // CORRECTION: Garder l'ID dans son format original (int ou String)
  dynamic get _brebisId => widget.brebis['id'];

  // CORRECTION: Conversion sécurisée pour les APIs qui nécessitent int
  int get _brebisIdAsInt {
    final id = widget.brebis['id'];
    if (id is int) return id;
    if (id is String) {
      // Si c'est un UUID, on ne peut pas le convertir en int
      // On utilise hashCode comme ID temporaire
      return id.hashCode.abs();
    }
    throw Exception('ID invalide: $id');
  }

  @override
  void initState() {
    super.initState();
    _chargerDonneesInitiales();
  }

  @override
  void dispose() {
    _signesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _chargerDonneesInitiales() async {
    try {
      // Vérifier si gestante
      try {
        final accouplement = await supabase
            .from('accouplements')
            .select('date_prevue_agnelage, date_mise_bas')
            .eq('brebis_id', _brebisId)
            .eq('source_brebis', widget.source)
            .isFilter('date_mise_bas', null)
            .limit(1)
            .maybeSingle();

        _estGestante = accouplement != null;
      } catch (e) {
        debugPrint("⚠️ Erreur vérification gestation: $e");
        _estGestante = false;
      }

      // Vérifier lactation
      try {
        final derniereMiseBas = await supabase
            .from('accouplements')
            .select('date_mise_bas')
            .eq('brebis_id', _brebisId)
            .eq('source_brebis', widget.source)
            .not('date_mise_bas', 'is', null)
            .order('date_mise_bas', ascending: false)
            .limit(1)
            .maybeSingle();

        if (derniereMiseBas != null) {
          final dateMiseBas = DateTime.parse(derniereMiseBas['date_mise_bas']);
          final joursDepuis = DateTime.now().difference(dateMiseBas).inDays;
          _enLactation = joursDepuis < ReproductionConfig.dureeLactationJours && joursDepuis > 0;
        }
      } catch (e) {
        debugPrint("⚠️ Erreur vérification lactation: $e");
        _enLactation = false;
      }

      // Récupérer dernière chaleur
      _derniereChaleur = await supabase
          .from('chaleurs')
          .select('*')
          .eq('animal_id', _brebisId)
          .eq('source', widget.source)
          .order('date_chaleur', ascending: false)
          .limit(1)
          .maybeSingle();

      if (_derniereChaleur != null) {
        final derniere = DateTime.parse(_derniereChaleur!['date_chaleur']);
        _intervalleJours = DateTime.now().difference(derniere).inDays;
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("❌ Erreur chargement données: $e");
    }
  }

  Future<void> _validerEtEnregistrer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Construire date complète
      final dateComplete = DateTime(
        _dateSelectionnee.year,
        _dateSelectionnee.month,
        _dateSelectionnee.day,
        _heureSelectionnee.hour,
        _heureSelectionnee.minute,
      );

      // 2. Validation métier basique
      if (_estGestante) {
        if (mounted) {
          _showErrorDialog(
            "Enregistrement impossible",
            ReproductionConfig.messageGestante,
          );
        }
        return;
      }

      // Vérifier l'intervalle avec la dernière chaleur
      if (_intervalleJours != null) {
        if (_intervalleJours! < ReproductionConfig.cycleMinJours) {
          final confirmer = await _showConfirmationDialog(
            "Attention",
            ReproductionConfig.messageIntervalleCourtChaleur,
          );
          
          if (confirmer != true) {
            return;
          }
        } else if (_intervalleJours! > ReproductionConfig.cycleMaxJours) {
          final confirmer = await _showConfirmationDialog(
            "Attention",
            ReproductionConfig.messageIntervalleLongChaleur,
          );
          
          if (confirmer != true) {
            return;
          }
        }
      }

      // 3. Enregistrer dans la base
      await supabase.from('chaleurs').insert({
        'animal_id': _brebisId, // Garder le format original
        'source': widget.source,
        'date_chaleur': dateComplete.toIso8601String(),
        'intensite': _intensite,
        'signes': _signesController.text.trim(),
        'notes': _notesController.text.trim(),
        'user_id': supabase.auth.currentUser!.id,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint("✅ Chaleur enregistrée avec succès");

      // 4. Calculer prédiction prochaine chaleur (si possible)
      PredictionChaleur? prediction;
      try {
        prediction = await _businessService.calculerProchaineChaleur(
          brebisId: _brebisIdAsInt, // Utiliser la version int pour le calcul
          source: widget.source,
          derniereChaleur: dateComplete,
        );
      } catch (e) {
        debugPrint("⚠️ Impossible de calculer la prédiction: $e");
        // Créer une prédiction par défaut
        prediction = PredictionChaleur(
          dateMin: dateComplete.add(Duration(days: ReproductionConfig.cycleMoyenJours - 2)),
          dateMax: dateComplete.add(Duration(days: ReproductionConfig.cycleMoyenJours + 2)),
          cycleMoyen: ReproductionConfig.cycleMoyenJours,
          niveauConfiance: "Faible",
          cycleIrregulier: false,
          estAnoestrus: DateTime.now().month >= 6 && DateTime.now().month <= 8,
          enLactation: _enLactation,
        );
      }

      // 5. Planifier notifications (si possible)
      try {
        if (!prediction.estAnoestrus) {
          await _notificationService.planifierRappelProchaineChaleur(
            brebisId: _brebisIdAsInt,
            nomBrebis: widget.brebis['nom'] ?? 'Sans nom',
            datePrevue: prediction.dateMin,
            source: widget.source,
          );
        }

        await _notificationService.planifierRappelFenetreFertile(
          brebisId: _brebisIdAsInt,
          nomBrebis: widget.brebis['nom'] ?? 'Sans nom',
          dateChaleur: dateComplete,
          source: widget.source,
        );
      } catch (e) {
        debugPrint("⚠️ Erreur planification notifications: $e");
        // Continuer même si les notifications échouent
      }

      // 6. Calculer fenêtre fertile
      final debutFenetre = dateComplete.add(
        Duration(hours: ReproductionConfig.debutFenetileHeures),
      );
      final finFenetre = dateComplete.add(
        Duration(hours: ReproductionConfig.dureeChaleurHeures),
      );

      // 7. Afficher résumé
      if (mounted) {
        await _showSuccessDialog(
          dateComplete: dateComplete,
          debutFenetre: debutFenetre,
          finFenetre: finFenetre,
          prediction: prediction,
        );
      }
    } catch (e) {
      debugPrint("❌ Erreur enregistrement: $e");
      if (mounted) {
        _showSnackBar("❌ Erreur: ${e.toString()}", Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // DIALOGUE DE SUCCÈS AVEC NAVIGATION
  Future<void> _showSuccessDialog({
    required DateTime dateComplete,
    required DateTime debutFenetre,
    required DateTime finFenetre,
    required PredictionChaleur prediction,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        title: const Text(
          "✅ Chaleur enregistrée",
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoBox(
                "🎯 Fenêtre d'accouplement optimale",
                "Du ${_formatDateTime(debutFenetre)}\n"
                "au ${_formatDateTime(finFenetre)}\n\n"
                "C'est le moment idéal pour l'accouplement !",
                Colors.green,
              ),
              const SizedBox(height: 12),
              _buildInfoBox(
                "📅 Prochaine chaleur prévue",
                !prediction.estAnoestrus
                    ? "Entre le ${_formatDate(prediction.dateMin)}\n"
                      "et le ${_formatDate(prediction.dateMax)}\n\n"
                      "Niveau de confiance: ${prediction.niveauConfiance}"
                    : "Période d'anœstrus saisonnier\n"
                      "Prédiction peu fiable durant cette période",
                _getColorForConfiance(prediction.niveauConfiance),
              ),
              const SizedBox(height: 12),
              const Text(
                "📲 Vous recevrez des notifications de rappel",
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Fermer dialogue
              Navigator.pop(context, true); // Retourner au module avec succès
            },
            child: const Text("Terminer"),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context); // Fermer dialogue
              // Navigation vers accouplement
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EnregistrerAccouplement(),
                ),
              );
              // Retourner au module avec le résultat
              if (mounted) {
                Navigator.pop(context, result ?? true);
              }
            },
            icon: const Icon(Icons.favorite),
            label: const Text("Accoupler maintenant"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(ReproductionConfig.colorPrimary),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(String titre, String contenu, Color couleur) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: couleur.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: couleur.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titre,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: couleur,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            contenu,
            style: TextStyle(fontSize: 13, color: couleur.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }

  Color _getColorForConfiance(String confiance) {
    switch (confiance) {
      case "Élevé":
        return Colors.green;
      case "Modéré":
        return Colors.orange;
      case "Faible":
      case "Très faible":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _showErrorDialog(String titre, String message) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error, color: Colors.red, size: 64),
        title: Text(titre),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showConfirmationDialog(String titre, String message) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning, color: Colors.orange, size: 64),
        title: Text(titre),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text("Continuer"),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    return "${date.day}/${date.month}/${date.year} à ${date.hour}h${date.minute.toString().padLeft(2, '0')}";
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Enregistrer une chaleur"),
        backgroundColor: Color(ReproductionConfig.colorPrimary),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // CARTE INFORMATION BREBIS
                    Card(
                      color: Color(ReproductionConfig.colorPrimary).withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.pets),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.brebis['nom'] ?? 'Sans nom',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text("Race: ${widget.brebis['race'] ?? 'N/A'}"),
                            if (_intervalleJours != null)
                              Text("Dernière chaleur: il y a $_intervalleJours jours"),
                            if (_estGestante)
                              const Text(
                                "🤰 Gestante",
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            if (_enLactation)
                              const Text(
                                "🍼 En lactation",
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),

                    // DATE ET HEURE
                    const Text(
                      "📅 Date et heure de la chaleur",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _dateSelectionnee,
                                firstDate: DateTime.now().subtract(const Duration(days: 7)),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setState(() => _dateSelectionnee = date);
                              }
                            },
                            icon: const Icon(Icons.calendar_today),
                            label: Text(_formatDate(_dateSelectionnee)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final heure = await showTimePicker(
                                context: context,
                                initialTime: _heureSelectionnee,
                              );
                              if (heure != null) {
                                setState(() => _heureSelectionnee = heure);
                              }
                            },
                            icon: const Icon(Icons.access_time),
                            label: Text(
                              "${_heureSelectionnee.hour}h${_heureSelectionnee.minute.toString().padLeft(2, '0')}",
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // INTENSITÉ
                    const Text(
                      "🔥 Intensité de la chaleur",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text("Faible"),
                          selected: _intensite == 'Faible',
                          onSelected: (selected) {
                            setState(() => _intensite = selected ? 'Faible' : null);
                          },
                        ),
                        ChoiceChip(
                          label: const Text("Moyenne"),
                          selected: _intensite == 'Moyenne',
                          onSelected: (selected) {
                            setState(() => _intensite = selected ? 'Moyenne' : null);
                          },
                        ),
                        ChoiceChip(
                          label: const Text("Forte"),
                          selected: _intensite == 'Forte',
                          onSelected: (selected) {
                            setState(() => _intensite = selected ? 'Forte' : null);
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // SIGNES OBSERVÉS
                    const Text(
                      "👁️ Signes observés (optionnel)",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    TextFormField(
                      controller: _signesController,
                      decoration: const InputDecoration(
                        hintText: "Ex: Agitation, acceptation du bélier, mucus...",
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),

                    const SizedBox(height: 24),

                    // NOTES
                    const Text(
                      "📝 Notes (optionnel)",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        hintText: "Observations supplémentaires...",
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),

                    const SizedBox(height: 32),

                    // BOUTON ENREGISTRER
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _validerEtEnregistrer,
                        icon: const Icon(Icons.save),
                        label: const Text("Enregistrer la chaleur"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(ReproductionConfig.colorPrimary),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}