// ============================================================
// 📦 MODÈLE ANIMAL — avec statut, soft delete et motif
// ============================================================

enum AnimalStatut {
  actif,
  mort,
  vendu,
  tue,
  enAttenteTransfert;

  String get label {
    switch (this) {
      case AnimalStatut.actif:
        return 'Actif';
      case AnimalStatut.mort:
        return 'Mort (Maladie)';
      case AnimalStatut.vendu:
        return 'Vendu';
      case AnimalStatut.tue:
        return 'Tué';
      case AnimalStatut.enAttenteTransfert:
        return 'En attente de transfert';
    }
  }

  String get dbValue {
    switch (this) {
      case AnimalStatut.actif:
        return 'actif';
      case AnimalStatut.mort:
        return 'mort';
      case AnimalStatut.vendu:
        return 'vendu';
      case AnimalStatut.tue:
        return 'tue';
      case AnimalStatut.enAttenteTransfert:
        return 'en_attente_transfert';
    }
  }

  static AnimalStatut fromString(String? value) {
    switch (value) {
      case 'mort':
        return AnimalStatut.mort;
      case 'vendu':
        return AnimalStatut.vendu;
      case 'tue':
        return AnimalStatut.tue;
      case 'en_attente_transfert':
        return AnimalStatut.enAttenteTransfert;
      default:
        return AnimalStatut.actif;
    }
  }
}

class AnimalModel {
  final String id;
  final String? nom;
  final String? race;
  final String? sexe;
  final String? imageUrl;
  final String? tagRfid;
  final String? dateNaissance;
  final String? provenance;
  final String userId;
  final String tableSource; // 'nouveaux_nee' ou 'animal_acheter'
  final AnimalStatut statut;
  final String? motifSuppression;
  final String? deletedAt;
  final String? transfertVersUserId;
  final DateTime? createdAt;

  const AnimalModel({
    required this.id,
    this.nom,
    this.race,
    this.sexe,
    this.imageUrl,
    this.tagRfid,
    this.dateNaissance,
    this.provenance,
    required this.userId,
    required this.tableSource,
    this.statut = AnimalStatut.actif,
    this.motifSuppression,
    this.deletedAt,
    this.transfertVersUserId,
    this.createdAt,
  });

  factory AnimalModel.fromMap(Map<String, dynamic> map, String tableSource) {
    return AnimalModel(
      id: map['id']?.toString() ?? '',
      nom: map['nom'],
      race: map['race'],
      sexe: map['sexe'],
      imageUrl: map['image_url'],
      tagRfid: map['tag_rfid'],
      dateNaissance: map['date_naissance'],
      provenance: map['provenance'],
      userId: map['user_id'] ?? '',
      tableSource: tableSource,
      statut: AnimalStatut.fromString(map['statut']),
      motifSuppression: map['motif_suppression'],
      deletedAt: map['deleted_at'],
      transfertVersUserId: map['transfert_vers_user_id'],
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'])
          : null,
    );
  }

  bool get isActif => statut == AnimalStatut.actif;
  bool get isDeleted => deletedAt != null;
}