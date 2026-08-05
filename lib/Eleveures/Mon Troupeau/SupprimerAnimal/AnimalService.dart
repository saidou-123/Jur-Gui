// ============================================================
// ⚙️ SERVICE — Logique métier pure, indépendante de l'UI
// ============================================================


import 'package:depart/Eleveures/Mon%20Troupeau/SupprimerAnimal/AnimalRepository.dart';
import 'package:depart/Eleveures/Mon%20Troupeau/SupprimerAnimal/Animalmodel.dart';

class AnimalService {
  final AnimalRepository _repository;

  AnimalService({AnimalRepository? repository})
      : _repository = repository ?? AnimalRepository();

  // ----------------------------------------------------------
  // 📥 Charger les animaux
  // ----------------------------------------------------------
  Future<List<AnimalModel>> getAnimauxActifs({String filtre = 'Tout'}) {
    return _repository.fetchAnimauxActifs(filtre: filtre);
  }

  // ----------------------------------------------------------
  // 🗑️ Supprimer un animal (soft delete)
  // ----------------------------------------------------------
  Future<void> supprimerAnimal({
    required AnimalModel animal,
    required AnimalStatut motif,
    String? transfertVersUserId,
  }) async {
    if (motif == AnimalStatut.vendu && transfertVersUserId != null) {
      // Cas vente avec transfert : statut spécial
      await _repository.softDeleteAnimal(
        animal: animal,
        statut: AnimalStatut.enAttenteTransfert,
        transfertVersUserId: transfertVersUserId,
      );
    } else {
      await _repository.softDeleteAnimal(
        animal: animal,
        statut: motif,
      );
    }
  }

  // ----------------------------------------------------------
  // 🔄 Répondre à une demande de transfert
  // ----------------------------------------------------------
  Future<void> repondreTransfert({
    required AnimalModel animal,
    required bool accepter,
  }) {
    return _repository.repondreTransfert(animal: animal, accepter: accepter);
  }

  // ----------------------------------------------------------
  // 📊 Statistiques pour tableau de bord
  // ----------------------------------------------------------
  Future<Map<String, int>> getStatistiques() {
    return _repository.fetchStatistiques();
  }

  // ----------------------------------------------------------
  // 🔍 Rechercher un éleveur pour le transfert
  // ----------------------------------------------------------
  Future<Map<String, dynamic>?> rechercherEleveur(String email) {
    return _repository.findEleveurByEmail(email);
  }
}