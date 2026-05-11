class AnimalModel {
  final String id;
  final String tagRfid;
  final String nom;
  final String? race;
  final String? sexe;
  final String? imageUrl;
  final String? dateNaissance;
  final String? provenance;
  final String statut;
  final String source; // 'nee' | 'achete'
  final String? userId;

  const AnimalModel({
    required this.id,
    required this.tagRfid,
    required this.nom,
    this.race,
    this.sexe,
    this.imageUrl,
    this.dateNaissance,
    this.provenance,
    this.statut = 'actif',
    required this.source,
    this.userId,
  });

  factory AnimalModel.fromMap(Map<String, dynamic> m, {required String source}) =>
      AnimalModel(
        id: m['id']?.toString() ?? '',
        tagRfid: m['tag_rfid'] ?? '',
        nom: m['nom'] ?? 'Sans nom',
        race: m['race'],
        sexe: m['sexe'],
        imageUrl: m['image_url'],
        dateNaissance: m['date_naissance']?.toString(),
        provenance: m['provenance'],
        statut: m['statut'] ?? 'actif',
        source: source,
        userId: m['user_id']?.toString(),
      );

  /// Retourne la map brute enrichie de la source, pour compatibilité
  /// avec les pages qui attendent un Map<String, dynamic>
  Map<String, dynamic> toMap() => {
    'id': id,
    'tag_rfid': tagRfid,
    'nom': nom,
    'race': race,
    'sexe': sexe,
    'image_url': imageUrl,
    'date_naissance': dateNaissance,
    'provenance': provenance,
    'statut': statut,
    'source': source,
    'user_id': userId,
  };

  bool get estActif => statut == 'actif';

  String get sourceLabel => source == 'nee' ? '🐑 Nouveau-né' : '🛒 Acheté';

  String get dateNaissanceFormatee {
    if (dateNaissance == null) return 'N/A';
    try {
      final d = DateTime.parse(dateNaissance!);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) { return dateNaissance!; }
  }
}