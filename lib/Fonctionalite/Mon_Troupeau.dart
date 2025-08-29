import 'package:flutter/material.dart';

class Restaurant extends StatelessWidget {
  const Restaurant({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Jur Gui 4.0 - Nouvel Animal"),
        backgroundColor: Colors.green[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre
            const Center(
              child: Text(
                "Ajouter un nouvel animal",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),

            // Photo de l'animal
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Icon(Icons.camera_alt, size: 50, color: Colors.grey),
                  const SizedBox(height: 10),
                  const Text("Aucune photo"),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.camera),
                    label: const Text("Prendre une photo"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Formulaire
            Form(
              child: Column(
                children: [
                  // Nom
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: "Nom",
                      hintText: "Ex: Amina",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.pets),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Date de naissance
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: "Date de naissance",
                      hintText: "Sélectionner une date",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () {},
                  ),
                  const SizedBox(height: 15),

                  // Sexe
                  DropdownButtonFormField(
                    decoration: const InputDecoration(
                      labelText: "Sexe",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.female),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: "Femelle",
                        child: Text("Femelle"),
                      ),
                      DropdownMenuItem(value: "Mâle", child: Text("Mâle")),
                    ],
                    onChanged: (value) {},
                  ),
                  const SizedBox(height: 15),

                  // Race
                  DropdownButtonFormField(
                    decoration: const InputDecoration(
                      labelText: "Race",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.agriculture),
                    ),
                    items: const [
                      DropdownMenuItem(value: "Ladoum", child: Text("Ladoum")),
                      DropdownMenuItem(value: "Peulh", child: Text("Peulh")),
                      DropdownMenuItem(
                        value: "Touabire",
                        child: Text("Touabire"),
                      ),
                    ],
                    onChanged: (value) {},
                  ),
                  const SizedBox(height: 15),

                  // Père
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: "Père",
                      hintText: "Sélectionner le père",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.male, color: Colors.blue),
                    ),
                    readOnly: true,
                    onTap: () {},
                  ),
                  const SizedBox(height: 15),

                  // Mère
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: "Mère",
                      hintText: "Sélectionner la mère",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.female, color: Colors.pink),
                    ),
                    readOnly: true,
                    onTap: () {},
                  ),
                  const SizedBox(height: 15),

                  // Tag RFID
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.nfc, size: 40, color: Colors.blue),
                        const SizedBox(height: 10),
                        const Text("Aucun tag RFID associé"),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.nfc),
                          label: const Text("Associer un Tag RFID"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),

                  // Bouton d'enregistrement
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Action d'enregistrement
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Animal enregistré avec succès!"),
                            backgroundColor: Colors.green,
                          ),
                        );
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check_circle),
                      label: const Text(
                        "Enregistrer l'animal",
                        style: TextStyle(fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
