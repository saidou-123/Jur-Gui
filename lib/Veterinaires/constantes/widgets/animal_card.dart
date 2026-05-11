// ============================================================
// core/widgets/animal_card.dart
// ============================================================
import 'package:depart/Eleveures/Mon%20Troupeau/SupprimerAnimal/Animalmodel.dart';
import 'package:flutter/material.dart';


class AnimalCard extends StatelessWidget {
  final AnimalModel animal;
  final VoidCallback? onTap;
  final Widget? trailing;

  const AnimalCard({super.key, required this.animal, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            // Photo ou avatar
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: animal.imageUrl != null
                  ? Image.network(animal.imageUrl!, width: 60, height: 60, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _avatar())
                  : _avatar(),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(animal.nom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(width: 6),
                  _sourceBadge(),
                ]),
                const SizedBox(height: 2),
                Text('${animal.race ?? 'Race inconnue'} · ${animal.sexe ?? 'N/A'}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                Text('RFID: ${animal.tagRfid}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500], fontFamily: 'monospace')),
              ],
            )),
            trailing ?? const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.green),
          ]),
        ),
      ),
    );
  }

  Widget _avatar() => Container(
    width: 60, height: 60,
    color: Colors.green[50],
    child: Icon(Icons.pets, size: 32, color: Colors.green[300]),
  );

  Widget _sourceBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: animal.source == 'nee' ? Colors.blue[50] : Colors.orange[50],
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      animal.source == 'nee' ? 'Né' : 'Acheté',
      style: TextStyle(
        fontSize: 10, fontWeight: FontWeight.bold,
        color: animal.source == 'nee' ? Colors.blue[700] : Colors.orange[700],
      ),
    ),
  );
}


// ============================================================
// core/widgets/consultation_item.dart
// ============================================================

class ConsultationItem extends StatelessWidget {
  final Map<String, dynamic> consultation;

  const ConsultationItem({super.key, required this.consultation});

  @override
  Widget build(BuildContext context) {
    final date = _fmt(consultation['date_consultation']?.toString() ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          _badge('Consultation', Colors.green),
        ]),
        const Divider(height: 16),
        _ligne('Motif', consultation['motif']),
        if (consultation['diagnostic']?.isNotEmpty == true)
          _ligne('Diagnostic', consultation['diagnostic']),
        if (consultation['traitement']?.isNotEmpty == true)
          _ligne('Traitement', consultation['traitement']),
        // Constantes vitales
        if (consultation['poids_kg'] != null || consultation['temperature_c'] != null ||
            consultation['frequence_cardiaque'] != null) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            if (consultation['poids_kg'] != null)
              _vitalChip('⚖️ ${consultation['poids_kg']} kg', Colors.purple),
            if (consultation['temperature_c'] != null)
              _vitalChip('🌡️ ${consultation['temperature_c']}°C', Colors.orange),
            if (consultation['frequence_cardiaque'] != null)
              _vitalChip('❤️ ${consultation['frequence_cardiaque']} bpm', Colors.red),
          ]),
        ],
      ]),
    );
  }

  Widget _ligne(String label, dynamic val) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: RichText(text: TextSpan(
      style: const TextStyle(color: Colors.black87, fontSize: 13),
      children: [
        TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        TextSpan(text: val?.toString() ?? 'N/A'),
      ],
    )),
  );

  Widget _badge(String txt, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(10)),
    child: Text(txt, style: const TextStyle(color: Colors.white, fontSize: 10)),
  );

  Widget _vitalChip(String txt, Color c) => Chip(
    label: Text(txt, style: TextStyle(fontSize: 11, color: c)),
    backgroundColor: c.withOpacity(0.1),
    side: BorderSide(color: c.withOpacity(0.3)),
    padding: EdgeInsets.zero,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  String _fmt(String iso) {
    try { final d = DateTime.parse(iso); return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}'; }
    catch (_) { return iso; }
  }
}


// ============================================================
// core/widgets/vaccination_item.dart
// ============================================================

class VaccinationItem extends StatelessWidget {
  final Map<String, dynamic> vaccination;

  const VaccinationItem({super.key, required this.vaccination});

  @override
  Widget build(BuildContext context) {
    final dateVacc = _fmt(vaccination['date_vaccination']?.toString() ?? '');
    final dateRappel = vaccination['date_rappel'];
    final rappelStr = dateRappel != null ? _fmt(dateRappel.toString()) : null;

    // Calcul urgence rappel
    bool rappelUrgent = false;
    if (dateRappel != null) {
      final r = DateTime.tryParse(dateRappel.toString());
      if (r != null) rappelUrgent = r.difference(DateTime.now()).inDays <= 7;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(vaccination['nom_vaccin'] ?? 'Vaccin',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(10)),
            child: const Text('Vaccination', style: TextStyle(color: Colors.white, fontSize: 10)),
          ),
        ]),
        const Divider(height: 16),
        _ligne('Date', dateVacc),
        if (vaccination['lot']?.isNotEmpty == true) _ligne('Lot', vaccination['lot']),
        if (rappelStr != null)
          Row(children: [
            Text('Rappel: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: rappelUrgent ? Colors.red : Colors.orange[800])),
            Text(rappelStr, style: TextStyle(fontSize: 13, color: rappelUrgent ? Colors.red : Colors.orange[800], fontWeight: FontWeight.bold)),
            if (rappelUrgent) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(8)),
                child: const Text('URGENT', style: TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ],
          ]),
      ]),
    );
  }

  Widget _ligne(String label, dynamic val) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: RichText(text: TextSpan(
      style: const TextStyle(color: Colors.black87, fontSize: 13),
      children: [
        TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        TextSpan(text: val?.toString() ?? 'N/A'),
      ],
    )),
  );

  String _fmt(String iso) {
    try { final d = DateTime.parse(iso); return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}'; }
    catch (_) { return iso; }
  }
}


// ============================================================
// core/widgets/empty_state.dart
// ============================================================

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subMessage;
  final Color? color;
  final VoidCallback? onAction;
  final String? actionLabel;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.subMessage,
    this.color,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.grey[400]!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 80, color: c),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
              textAlign: TextAlign.center),
          if (subMessage != null) ...[
            const SizedBox(height: 8),
            Text(subMessage!, style: TextStyle(fontSize: 14, color: Colors.grey[500]), textAlign: TextAlign.center),
          ],
          if (onAction != null) ...[
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(backgroundColor: c, foregroundColor: Colors.white),
              child: Text(actionLabel ?? 'Actualiser'),
            ),
          ],
        ]),
      ),
    );
  }
}