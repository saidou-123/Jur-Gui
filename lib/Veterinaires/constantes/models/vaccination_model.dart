class VaccinationModel {
  final String id;
  final String animalId;
  final String source;
  final String veterinaireId;
  final String nomVaccin;
  final DateTime dateVaccination;
  final DateTime? dateRappel;
  final String? lot;
  final String? observations;

  const VaccinationModel({
    required this.id,
    required this.animalId,
    required this.source,
    required this.veterinaireId,
    required this.nomVaccin,
    required this.dateVaccination,
    this.dateRappel,
    this.lot,
    this.observations,
  });

  factory VaccinationModel.fromMap(Map<String, dynamic> m) => VaccinationModel(
    id: m['id'] ?? '',
    animalId: m['animal_id'] ?? '',
    source: m['source'] ?? '',
    veterinaireId: m['veterinaire_id'] ?? '',
    nomVaccin: m['nom_vaccin'] ?? '',
    dateVaccination: DateTime.tryParse(m['date_vaccination']?.toString() ?? '') ?? DateTime.now(),
    dateRappel: m['date_rappel'] != null ? DateTime.tryParse(m['date_rappel'].toString()) : null,
    lot: m['lot'],
    observations: m['observations'],
  );

  /// Jours restants avant le rappel (négatif = en retard)
  int? get joursAvantRappel {
    if (dateRappel == null) return null;
    return dateRappel!.difference(DateTime.now()).inDays;
  }

  bool get rappelUrgent => joursAvantRappel != null && joursAvantRappel! <= 7;
  bool get rappelProche => joursAvantRappel != null && joursAvantRappel! <= 30;
  bool get rappelEnRetard => joursAvantRappel != null && joursAvantRappel! < 0;

  String get dateVaccinFormatee => _fmt(dateVaccination);
  String get dateRappelFormatee => dateRappel != null ? _fmt(dateRappel!) : 'Non défini';

  String _fmt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}