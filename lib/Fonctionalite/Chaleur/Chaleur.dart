import 'package:flutter/material.dart';

class Chaleur extends StatefulWidget {
  const Chaleur({super.key});

  @override
  State<Chaleur> createState() => _AjouteranimalState();
}

class _AjouteranimalState extends State<Chaleur> {
  String? _selectedliste;
  DateTime? _selectedDate;
  final TextEditingController _dateController = TextEditingController();

  // Fonction pour afficher le Date Picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.green,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

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
                "Enregistrer les cycles de chaleurs",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),

            // Le reste de votre formulaire reste inchangé...
            Form(
              child: Column(
                children: [
                  //  brebis en chaleurs
                  DropdownButtonFormField(
                    decoration: const InputDecoration(
                      labelText: "Sélectionner une brebis en chaleurs",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.list),
                    ),
                    value: _selectedliste,
                    items: const [
                      DropdownMenuItem(value: "Ladoum", child: Text("Ladoum")),
                      DropdownMenuItem(value: "Peulh", child: Text("Peulh")),
                      DropdownMenuItem(
                        value: "Touabire",
                        child: Text("Touabire"),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedliste = value;
                      });
                    },
                  ),
                  const SizedBox(height: 15),

                  // Date de naissance avec Date Picker
                  TextFormField(
                    controller: _dateController,
                    decoration: const InputDecoration(
                      labelText: "Date de Chaleur du Brebi",
                      hintText: "Sélectionner une date de Chaleur",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () {
                      _selectDate(context);
                    },
                  ),
                  const SizedBox(height: 15),

                  // Bouton d'enregistrement
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Action d'enregistrement
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "La brebis est enregistrée comme étant en chaleurs",
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check_circle),
                      label: const Text(
                        "Enregistrer la Chaleur",
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
