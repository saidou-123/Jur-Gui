class ConsultationModel {
  final String id;
  final String animalId;
  final String source;
  final String veterinaire_id;
  final DateTime dateConsultation;
  final String motif;
  final String? examenClinique;
  final String? diagnostic;
  final String? traitement;
  final String? observations;
  final double? poidsKg;
  final double? temperatureC;
  final int? frequenceCardiaque;
  final DateTime createdAt;

  const ConsultationModel({
    required this.id,
    required this.animalId,
    required this.source,
    required this.veterinaire_id,
    required this.dateConsultation,
    required this.motif,
    this.examenClinique,
    this.diagnostic,
    this.traitement,
    this.observations,
    this.poidsKg,
    this.temperatureC,
    this.frequenceCardiaque,
    required this.createdAt,
  });

  factory ConsultationModel.fromMap(Map<String, dynamic> m) => ConsultationModel(
    id: m['id'] ?? '',
    animalId: m['animal_id'] ?? '',
    source: m['source'] ?? '',
    veterinaire_id: m['veterinaire_id'] ?? '',
    dateConsultation: DateTime.tryParse(m['date_consultation']?.toString() ?? '') ?? DateTime.now(),
    motif: m['motif'] ?? '',
    examenClinique: m['examen_clinique'],
    diagnostic: m['diagnostic'],
    traitement: m['traitement'],
    observations: m['observations'],
    poidsKg: (m['poids_kg'] as num?)?.toDouble(),
    temperatureC: (m['temperature_c'] as num?)?.toDouble(),
    frequenceCardiaque: m['frequence_cardiaque'] as int?,
    createdAt: DateTime.tryParse(m['created_at']?.toString() ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toInsertMap() => {
    'animal_id': animalId,
    'source': source,
    'veterinaire_id': veterinaire_id,
    'date_consultation': dateConsultation.toIso8601String(),
    'motif': motif,
    if (examenClinique != null) 'examen_clinique': examenClinique,
    if (diagnostic != null) 'diagnostic': diagnostic,
    if (traitement != null) 'traitement': traitement,
    if (observations != null) 'observations': observations,
    if (poidsKg != null) 'poids_kg': poidsKg,
    if (temperatureC != null) 'temperature_c': temperatureC,
    if (frequenceCardiaque != null) 'frequence_cardiaque': frequenceCardiaque,
  };

  String get dateFormatee {
    final d = dateConsultation;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}