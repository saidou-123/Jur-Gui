// ============================================================
// 🔄 WIDGET — Dialog de transfert vers un autre éleveur
// ✅ CORRIGÉ : utilise la table 'users' avec nom_complet
// ============================================================

import 'package:depart/Eleveures/Mon%20Troupeau/SupprimerAnimal/AnimalService.dart';
import 'package:flutter/material.dart';


class TransfertResult {
  final bool confirme;
  final String? eleveurId;
  final String? eleveurNom;

  const TransfertResult({
    required this.confirme,
    this.eleveurId,
    this.eleveurNom,
  });
}

/// Affiche un dialog demandant si l'animal doit être transféré.
/// Retourne [TransfertResult] avec les infos de l'éleveur cible.
Future<TransfertResult?> showTransfertDialog(
  BuildContext context,
  AnimalService service,
) async {
  return showDialog<TransfertResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _TransfertDialog(service: service),
  );
}

class _TransfertDialog extends StatefulWidget {
  final AnimalService service;
  const _TransfertDialog({required this.service});

  @override
  State<_TransfertDialog> createState() => _TransfertDialogState();
}

class _TransfertDialogState extends State<_TransfertDialog> {
  bool _rechercheEnCours = false;
  String? _erreur;
  Map<String, dynamic>? _eleveurTrouve;
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------
  // 🔍 Recherche avec validation
  // ----------------------------------------------------------
  Future<void> _rechercherEleveur() async {
    final email = _emailController.text.trim().toLowerCase();

    if (email.isEmpty) {
      setState(() => _erreur = 'Veuillez saisir un email');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _erreur = 'Format email invalide');
      return;
    }

    setState(() {
      _rechercheEnCours = true;
      _erreur = null;
      _eleveurTrouve = null;
    });

    final result = await widget.service.rechercherEleveur(email);

    if (!mounted) return;
    setState(() {
      _rechercheEnCours = false;
      if (result != null) {
        _eleveurTrouve = result;
      } else {
        _erreur =
            'Aucun éleveur enregistré avec cet email.\nVérifiez l\'adresse ou demandez-lui de s\'inscrire.';
      }
    });
  }

  // ----------------------------------------------------------
  // 📛 Construire le nom depuis les colonnes de la table users
  //    Colonnes disponibles : nom, prenom, nom_complet, email
  // ----------------------------------------------------------
  String _getNomEleveur(Map<String, dynamic> e) {
    final nomComplet = (e['nom_complet'] ?? '').toString().trim();
    if (nomComplet.isNotEmpty) return nomComplet;

    final prenom = (e['prenom'] ?? '').toString().trim();
    final nom = (e['nom'] ?? '').toString().trim();
    final full = '$prenom $nom'.trim();
    if (full.isNotEmpty) return full;

    return (e['email'] ?? 'Éleveur').toString();
  }

  // ----------------------------------------------------------
  // 🎨 UI
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icône
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.swap_horiz, color: Colors.green, size: 36),
            ),
            const SizedBox(height: 16),

            // Titre
            const Text(
              'Transférer l\'animal ?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Voulez-vous transférer cet animal à un autre éleveur ?',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // ── Champ email (visible tant qu'aucun éleveur trouvé) ──
            if (_eleveurTrouve == null) ...[
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Email de l\'éleveur destinataire',
                  prefixIcon: const Icon(Icons.email_outlined),
                  suffixIcon: _rechercheEnCours
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.search),
                          tooltip: 'Rechercher',
                          onPressed: _rechercherEleveur,
                        ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!)),
                  // ✅ Message d'erreur multi-ligne
                  errorText: _erreur,
                  errorMaxLines: 3,
                ),
                onSubmitted: (_) => _rechercherEleveur(),
              ),
            ],

            // ── Carte éleveur trouvé ──
            if (_eleveurTrouve != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    // Avatar initiales
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.green.shade200,
                      child: Text(
                        _getNomEleveur(_eleveurTrouve!)
                            .substring(0, 1)
                            .toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[900],
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            // ✅ Utilise nom_complet ou prenom+nom
                            _getNomEleveur(_eleveurTrouve!),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            _eleveurTrouve!['email'] ?? '',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    // Bouton effacer pour relancer la recherche
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Changer',
                      onPressed: () => setState(() {
                        _eleveurTrouve = null;
                        _emailController.clear();
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(
                    context,
                    TransfertResult(
                      confirme: true,
                      eleveurId: _eleveurTrouve!['id']?.toString(),
                      eleveurNom: _getNomEleveur(_eleveurTrouve!),
                    ),
                  ),
                  icon: const Icon(Icons.send),
                  label: const Text('Confirmer le transfert'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // ── Boutons bas ──
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(
                      context,
                      const TransfertResult(confirme: false),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Non, juste vendre'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: Text('Annuler',
                        style: TextStyle(color: Colors.grey[600])),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}