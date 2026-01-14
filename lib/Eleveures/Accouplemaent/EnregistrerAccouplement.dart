import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// FORMULAIRE D'ENREGISTREMENT D'ACCOUPLEMENT (VERSION AVEC "AUTRE")
// ============================================================

class EnregistrerAccouplementPage extends StatefulWidget {
  const EnregistrerAccouplementPage({super.key});

  @override
  State<EnregistrerAccouplementPage> createState() => _EnregistrerAccouplementPageState();
}

class _EnregistrerAccouplementPageState extends State<EnregistrerAccouplementPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _brebisDisponibles = [];
  List<Map<String, dynamic>> _beliersDisponibles = [];
  
  Map<String, dynamic>? _brebisSelectionnee;
  Map<String, dynamic>? _belierSelectionne;
  
  // Pour l'option "Autre"
  bool _autreBrebis = false;
  bool _autreBelier = false;
  final _nomAutreBrebisController = TextEditingController();
  final _raceAutreBrebisController = TextEditingController();
  final _nomAutreBelierController = TextEditingController();
  final _raceAutreBelierController = TextEditingController();
  
  DateTime _dateAccouplement = DateTime.now();
  TimeOfDay _heureAccouplement = TimeOfDay.now();
  
  String _methodeAccouplement = 'Naturel';
  final _notesController = TextEditingController();
  
  bool _isLoading = false;
  bool _isLoadingAnimaux = true;

  @override
  void initState() {
    super.initState();
    _chargerAnimaux();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _nomAutreBrebisController.dispose();
    _raceAutreBrebisController.dispose();
    _nomAutreBelierController.dispose();
    _raceAutreBelierController.dispose();
    super.dispose();
  }

  Future<void> _chargerAnimaux() async {
    if (!mounted) return;
    
    setState(() => _isLoadingAnimaux = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception("Utilisateur non connecté");

      // Charger les brebis disponibles (non gestantes)
      List<Map<String, dynamic>> toutesLesBrebis = [];

      // Brebis achetées
      try {
        final brebisAchetees = await supabase
            .from('animal_acheter')
            .select('id, nom, race, image_url, tag_rfid')
            .eq('sexe', 'Femelle')
            .eq('user_id', userId)
            .order('nom');

        for (var b in brebisAchetees) {
          b['source'] = 'achete';
          toutesLesBrebis.add(b);
        }
      } catch (e) {
        debugPrint("⚠️ Erreur chargement brebis achetées: $e");
      }

      // Brebis nées
      try {
        final brebisNees = await supabase
            .from('nouveaux_nee')
            .select('id, nom, race, image_url, tag_rfid')
            .eq('sexe', 'Femelle')
            .eq('user_id', userId)
            .order('nom');

        for (var b in brebisNees) {
          b['source'] = 'nee';
          toutesLesBrebis.add(b);
        }
      } catch (e) {
        debugPrint("⚠️ Erreur chargement brebis nées: $e");
      }

      // Filtrer les brebis gestantes
      List<Map<String, dynamic>> brebisDisponibles = [];
      for (var brebis in toutesLesBrebis) {
        try {
          final accouplement = await supabase
              .from('accouplements')
              .select('id, date_mise_bas')
              .eq('brebis_id', brebis['id'])
              .eq('source_brebis', brebis['source'])
              .order('date_accouplement', ascending: false)
              .limit(1)
              .maybeSingle();

          // Disponible si pas d'accouplement ou si mise bas effectuée
          if (accouplement == null || accouplement['date_mise_bas'] != null) {
            brebisDisponibles.add(brebis);
          }
        } catch (e) {
          debugPrint("⚠️ Erreur vérification gestation pour ${brebis['nom']}: $e");
          brebisDisponibles.add(brebis);
        }
      }

      // Charger les béliers
      List<Map<String, dynamic>> tousLesBeliers = [];

      // Béliers achetés
      try {
        final beliersAchetes = await supabase
            .from('animal_acheter')
            .select('id, nom, race, tag_rfid, image_url')
            .eq('sexe', 'Mâle')
            .eq('user_id', userId)
            .order('nom');

        for (var b in beliersAchetes) {
          b['source'] = 'achete';
          tousLesBeliers.add(b);
        }
      } catch (e) {
        debugPrint("⚠️ Erreur chargement béliers achetés: $e");
      }

      // Béliers nés
      try {
        final beliersNes = await supabase
            .from('nouveaux_nee')
            .select('id, nom, race, tag_rfid, image_url')
            .eq('sexe', 'Mâle')
            .eq('user_id', userId)
            .order('nom');

        for (var b in beliersNes) {
          b['source'] = 'nee';
          tousLesBeliers.add(b);
        }
      } catch (e) {
        debugPrint("⚠️ Erreur chargement béliers nés: $e");
      }

      if (mounted) {
        setState(() {
          _brebisDisponibles = brebisDisponibles;
          _beliersDisponibles = tousLesBeliers;
          _isLoadingAnimaux = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Erreur chargement animaux: $e");
      if (mounted) {
        _showSnackBar("Erreur de chargement", Colors.red);
        setState(() => _isLoadingAnimaux = false);
      }
    }
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;

    // Validation brebis
    if (!_autreBrebis && _brebisSelectionnee == null) {
      _showSnackBar("Veuillez sélectionner une brebis", Colors.orange);
      return;
    }
    
    if (_autreBrebis && _nomAutreBrebisController.text.trim().isEmpty) {
      _showSnackBar("Veuillez entrer le nom de la brebis", Colors.orange);
      return;
    }

    // Validation bélier
    if (!_autreBelier && _belierSelectionne == null) {
      _showSnackBar("Veuillez sélectionner un bélier", Colors.orange);
      return;
    }
    
    if (_autreBelier && _nomAutreBelierController.text.trim().isEmpty) {
      _showSnackBar("Veuillez entrer le nom du bélier", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dateComplete = DateTime(
        _dateAccouplement.year,
        _dateAccouplement.month,
        _dateAccouplement.day,
        _heureAccouplement.hour,
        _heureAccouplement.minute,
      );

      // Calculer la date de mise bas prévue (145-150 jours, moyenne 147)
      final dateMiseBasPrevue = dateComplete.add(const Duration(days: 147));

      // Préparer les données d'accouplement
      final Map<String, dynamic> accouplementData = {
        'date_accouplement': dateComplete.toIso8601String(),
        'methode_accouplement': _methodeAccouplement,
        'date_mise_bas_prevue': dateMiseBasPrevue.toIso8601String(),
        'notes': _notesController.text.trim(),
        'gestation_confirmee': false,
        'user_id': supabase.auth.currentUser!.id,
        'created_at': DateTime.now().toIso8601String(),
      };

      // Gérer la brebis
      if (_autreBrebis) {
        accouplementData['brebis_id'] = null;
        accouplementData['source_brebis'] = 'externe';
        accouplementData['brebis_externe_nom'] = _nomAutreBrebisController.text.trim();
        accouplementData['brebis_externe_race'] = _raceAutreBrebisController.text.trim().isNotEmpty 
            ? _raceAutreBrebisController.text.trim() 
            : 'Non spécifiée';
      } else {
        accouplementData['brebis_id'] = _brebisSelectionnee!['id'];
        accouplementData['source_brebis'] = _brebisSelectionnee!['source'];
      }

      // Gérer le bélier
      if (_autreBelier) {
        accouplementData['belier_id'] = null;
        accouplementData['source_belier'] = 'externe';
        accouplementData['belier_externe_nom'] = _nomAutreBelierController.text.trim();
        accouplementData['belier_externe_race'] = _raceAutreBelierController.text.trim().isNotEmpty 
            ? _raceAutreBelierController.text.trim() 
            : 'Non spécifiée';
      } else {
        accouplementData['belier_id'] = _belierSelectionne!['id'];
        accouplementData['source_belier'] = _belierSelectionne!['source'];
      }

      await supabase.from('accouplements').insert(accouplementData);

      debugPrint("✅ Accouplement enregistré avec succès");

      if (mounted) {
        setState(() => _isLoading = false);
        await _showSuccessDialog(dateComplete, dateMiseBasPrevue);
      }
    } catch (e) {
      debugPrint("❌ Erreur enregistrement: $e");
      if (mounted) {
        _showSnackBar("❌ Erreur: ${e.toString()}", Colors.red);
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showSuccessDialog(
    DateTime dateAccouplement,
    DateTime dateMiseBasPrevue,
  ) async {
    // Obtenir les noms pour l'affichage
    String nomBrebis = _autreBrebis 
        ? _nomAutreBrebisController.text.trim() 
        : _brebisSelectionnee!['nom'];
    String nomBelier = _autreBelier 
        ? _nomAutreBelierController.text.trim() 
        : _belierSelectionne!['nom'];
    
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        title: const Text(
          "✅ Accouplement enregistré !",
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoBox(
                "👥 Couple reproducteur",
                "🐑 $nomBrebis${_autreBrebis ? ' (Externe)' : ''}\n"
                "💙 $nomBelier${_autreBelier ? ' (Externe)' : ''}",
                Colors.purple,
              ),
              const SizedBox(height: 12),
              _buildInfoBox(
                "📅 Date d'accouplement",
                _formatDateTime(dateAccouplement),
                Colors.blue,
              ),
              const SizedBox(height: 12),
              _buildInfoBox(
                "🤰 Mise bas prévue",
                "${_formatDate(dateMiseBasPrevue)}\n(147 jours de gestation)",
                Colors.green,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange, width: 2),
                ),
                child: const Column(
                  children: [
                    Text(
                      "⏰ Prochaines étapes",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "• J+17-21 : Surveiller retour chaleur\n"
                      "• J+30 : Échographie possible\n"
                      "• J+45 : Confirmation gestation\n"
                      "• J+147 : Préparation mise bas",
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text("Terminer"),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(String titre, String contenu, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titre,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(contenu, style: const TextStyle(fontSize: 13)),
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
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  String _formatDateTime(DateTime date) {
    return "${_formatDate(date)} à ${date.hour}h${date.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nouvel Accouplement"),
        backgroundColor: Colors.purple[700],
      ),
      body: _isLoadingAnimaux
          ? const Center(child: CircularProgressIndicator())
          : _isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text("Enregistrement en cours..."),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSelectionBrebis(),
                        const SizedBox(height: 16),
                        _buildSelectionBelier(),
                        const SizedBox(height: 24),
                        const Text(
                          "Informations sur l'accouplement",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _buildDatePicker(),
                        const SizedBox(height: 16),
                        _buildTimePicker(),
                        const SizedBox(height: 16),
                        _buildMethodeDropdown(),
                        const SizedBox(height: 16),
                        _buildNotesField(),
                        const SizedBox(height: 32),
                        _buildSubmitButton(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildSelectionBrebis() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.female, color: Colors.pink[700]),
                const SizedBox(width: 8),
                const Text(
                  "Sélectionner la brebis",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Dropdown avec option "Autre"
            DropdownButtonFormField<String>(
              value: _autreBrebis ? 'autre' : (_brebisSelectionnee?['id']?.toString()),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Choisir une brebis",
              ),
              items: [
                ..._brebisDisponibles.map((brebis) {
                  return DropdownMenuItem(
                    value: brebis['id'].toString(),
                    child: Row(
                      children: [
                        if (brebis['image_url'] != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              brebis['image_url'],
                              width: 30,
                              height: 30,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.pets, size: 30);
                              },
                            ),
                          )
                        else
                          const Icon(Icons.pets, size: 30),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "${brebis['nom']} (${brebis['race']})",
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const DropdownMenuItem(
                  value: 'autre',
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(
                        "Autre (animal externe)",
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  if (value == 'autre') {
                    _autreBrebis = true;
                    _brebisSelectionnee = null;
                  } else {
                    _autreBrebis = false;
                    _brebisSelectionnee = _brebisDisponibles.firstWhere(
                      (b) => b['id'].toString() == value,
                    );
                  }
                });
              },
              validator: (val) => val == null ? 'Sélectionnez une brebis' : null,
            ),
            
            // Champs pour "Autre brebis"
            if (_autreBrebis) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Brebis externe",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nomAutreBrebisController,
                      decoration: const InputDecoration(
                        labelText: "Nom de la brebis *",
                        hintText: "Ex: Brebis du voisin",
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (val) => 
                          _autreBrebis && (val == null || val.trim().isEmpty) 
                              ? 'Nom requis' 
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _raceAutreBrebisController,
                      decoration: const InputDecoration(
                        labelText: "Race (optionnel)",
                        hintText: "Ex: Ladoum, Peul...",
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionBelier() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.male, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  "Sélectionner le bélier",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Dropdown avec option "Autre"
            DropdownButtonFormField<String>(
              value: _autreBelier ? 'autre' : (_belierSelectionne?['id']?.toString()),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Choisir un bélier",
              ),
              items: [
                ..._beliersDisponibles.map((belier) {
                  return DropdownMenuItem(
                    value: belier['id'].toString(),
                    child: Text(
                      "${belier['nom']} (${belier['race']})",
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
                const DropdownMenuItem(
                  value: 'autre',
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(
                        "Autre (animal externe)",
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  if (value == 'autre') {
                    _autreBelier = true;
                    _belierSelectionne = null;
                  } else {
                    _autreBelier = false;
                    _belierSelectionne = _beliersDisponibles.firstWhere(
                      (b) => b['id'].toString() == value,
                    );
                  }
                });
              },
              validator: (val) => val == null ? 'Sélectionnez un bélier' : null,
            ),
            
            // Champs pour "Autre bélier"
            if (_autreBelier) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Bélier externe",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nomAutreBelierController,
                      decoration: const InputDecoration(
                        labelText: "Nom du bélier *",
                        hintText: "Ex: Bélier de location",
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (val) => 
                          _autreBelier && (val == null || val.trim().isEmpty) 
                              ? 'Nom requis' 
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _raceAutreBelierController,
                      decoration: const InputDecoration(
                        labelText: "Race (optionnel)",
                        hintText: "Ex: Ladoum, Peul...",
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.calendar_today, color: Colors.purple),
        title: const Text("Date d'accouplement"),
        subtitle: Text(_formatDate(_dateAccouplement)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: _dateAccouplement,
            firstDate: DateTime.now().subtract(const Duration(days: 30)),
            lastDate: DateTime.now(),
          );
          if (date != null && mounted) {
            setState(() => _dateAccouplement = date);
          }
        },
      ),
    );
  }

  Widget _buildTimePicker() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.access_time, color: Colors.purple),
        title: const Text("Heure"),
        subtitle: Text(
          "${_heureAccouplement.hour}h${_heureAccouplement.minute.toString().padLeft(2, '0')}",
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final time = await showTimePicker(
            context: context,
            initialTime: _heureAccouplement,
          );
          if (time != null && mounted) {
            setState(() => _heureAccouplement = time);
          }
        },
      ),
    );
  }

  Widget _buildMethodeDropdown() {
    return DropdownButtonFormField<String>(
      value: _methodeAccouplement,
      decoration: const InputDecoration(
        labelText: "Méthode d'accouplement",
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.sync, color: Colors.purple),
      ),
      items: const [
        DropdownMenuItem(value: "Naturel", child: Text("Naturel")),
        DropdownMenuItem(value: "Insémination artificielle", child: Text("Insémination artificielle")),
        DropdownMenuItem(value: "Lutte en main", child: Text("Lutte en main")),
      ],
      onChanged: (val) => setState(() => _methodeAccouplement = val!),
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      maxLines: 3,
      decoration: const InputDecoration(
        labelText: "Notes (optionnel)",
        hintText: "Observations, comportement, conditions...",
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.notes, color: Colors.purple),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _enregistrer,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.check_circle),
        label: Text(
          _isLoading ? "Enregistrement..." : "Enregistrer l'accouplement",
          style: const TextStyle(fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple[700],
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey,
        ),
      ),
    );
  }
}