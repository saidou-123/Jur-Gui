import 'package:depart/Veterinaires/Scanveterinaire/NouvelleConsultationPage.dart';
import 'package:depart/Veterinaires/constantes/services/consultation_service.dart';
import 'package:depart/Veterinaires/constantes/services/vaccination_service.dart';
import 'package:depart/Veterinaires/constantes/widgets/animal_card.dart';
import 'package:depart/Veterinaires/features/vaccinations/NouvelleVaccinationForm.dart';
import 'package:flutter/material.dart';

class FicheSanteDetail extends StatefulWidget {
  final Map<String, dynamic> animal;
  final String source;

  const FicheSanteDetail({super.key, required this.animal, required this.source});

  @override
  State<FicheSanteDetail> createState() => _FicheSanteDetailState();
}

class _FicheSanteDetailState extends State<FicheSanteDetail>
    with SingleTickerProviderStateMixin {
  final _consultSvc = ConsultationService();
  final _vaccSvc = VaccinationService();
  late TabController _tabs;

  List<Map<String, dynamic>> _consultations = [];
  List<Map<String, dynamic>> _vaccinations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _charger();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _charger() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final id = widget.animal['id'].toString();
      final src = widget.source;
      final c = await _consultSvc.chargerRaw(id, src);
      final v = await _vaccSvc.chargerRaw(id, src);
      if (mounted) setState(() { _consultations = c; _vaccinations = v; _isLoading = false; });
    } catch (e) {
      debugPrint('Erreur fiche: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nom = widget.animal['nom'] ?? 'Animal';
    return Scaffold(
      appBar: AppBar(
        title: Text('Fiche — $nom'),
        backgroundColor: Colors.green[700],
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _charger)],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'Consultations (${_consultations.length})', icon: const Icon(Icons.medical_services)),
            Tab(text: 'Vaccinations (${_vaccinations.length})', icon: const Icon(Icons.vaccines)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              _buildInfoBanner(),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [_buildConsultations(), _buildVaccinations()],
                ),
              ),
            ]),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'vacc',
            onPressed: _ajouterVaccination,
            backgroundColor: Colors.blue[700],
            child: const Icon(Icons.vaccines),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'consult',
            onPressed: _ajouterConsultation,
            backgroundColor: Colors.green[700],
            icon: const Icon(Icons.add),
            label: const Text('Consultation'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    color: Colors.green[50],
    child: Row(children: [
      if (widget.animal['image_url'] != null)
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(widget.animal['image_url'], width: 50, height: 50, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _avatarIcon()),
        )
      else _avatarIcon(),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.animal['nom'] ?? 'N/A',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text('${widget.animal['race'] ?? 'N/A'} · ${widget.animal['sexe'] ?? 'N/A'}',
              style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          Text('Tag: ${widget.animal['tag_rfid'] ?? 'N/A'}',
              style: TextStyle(fontSize: 11, color: Colors.grey[500], fontFamily: 'monospace')),
        ],
      )),
      // Résumé rapide
      Column(children: [
        _mini('${_consultations.length}', Icons.medical_services, Colors.green),
        const SizedBox(height: 4),
        _mini('${_vaccinations.length}', Icons.vaccines, Colors.blue),
      ]),
    ]),
  );

  Widget _mini(String val, IconData icon, Color c) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 14, color: c),
    const SizedBox(width: 2),
    Text(val, style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 13)),
  ]);

  Widget _avatarIcon() => Container(
    width: 50, height: 50,
    decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(8)),
    child: Icon(Icons.pets, color: Colors.green[700], size: 26),
  );

  Widget _buildConsultations() {
    if (_consultations.isEmpty) return EmptyState(
      icon: Icons.medical_services_outlined,
      message: 'Aucune consultation',
      subMessage: 'Appuyez sur le bouton pour ajouter',
      onAction: _ajouterConsultation,
      actionLabel: 'Nouvelle consultation',
    );
    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _consultations.length,
        itemBuilder: (_, i) => ConsultationItem(consultation: _consultations[i]),
      ),
    );
  }

  Widget _buildVaccinations() {
    if (_vaccinations.isEmpty) return EmptyState(
      icon: Icons.vaccines_outlined,
      message: 'Aucune vaccination',
      subMessage: 'Appuyez sur le bouton bleu pour ajouter',
      onAction: _ajouterVaccination,
      actionLabel: 'Nouvelle vaccination',
      color: Colors.blue[400],
    );
    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _vaccinations.length,
        itemBuilder: (_, i) => VaccinationItem(vaccination: _vaccinations[i]),
      ),
    );
  }

  Future<void> _ajouterConsultation() async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => NouvelleConsultationPage(animal: widget.animal, source: widget.source),
    ));
    if (ok == true) _charger();
  }

  Future<void> _ajouterVaccination() async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => NouvelleVaccinationForm(animal: widget.animal, source: widget.source),
    ));
    if (ok == true) _charger();
  }
}