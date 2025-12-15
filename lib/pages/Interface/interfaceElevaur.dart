import 'package:depart/Fonctionalite/Ajouter%20Animal/AjouterAnimal.dart';
import 'package:depart/Fonctionalite/AnimalInfoRFID/AnimalInfoRFIDPage.dart';
import 'package:depart/Fonctionalite/Chaleur/Chaleur.dart';
import 'package:depart/Fonctionalite/Accouplemaent/Accouplement.dart';
import 'package:depart/Fonctionalite/Mon%20Troupeau/modfierAnimal/AnimalListPage.dart';
import 'package:depart/widgets/OptionCercle.dart';
import 'package:depart/widgets/optioncard.dart';
import 'package:flutter/material.dart';
import 'package:depart/widgets/couleur.dart';

class interfaceElevaur extends StatelessWidget {
  const interfaceElevaur({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text(
            "USSEINPAY",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Couleur.PremierColor,
              fontSize: 20,
            ),
          ),
        ),
        // iconTheme: IconThemeData(color: Colors.white),
        // actions: [
        //   IconButton(onPressed: () {}, icon: Icon(Icons.search, size: 35)),
        // ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: "Search here",
                    isDense: true,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.yellow),
                      borderRadius: const BorderRadius.all(Radius.circular(99)),
                    ),
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 15),
          Text(
            'Choisir une option parmi les suivantes:',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
          SizedBox(height: 15),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              // mainAxisAlignment n'est plus nécessaire ici.
              // Nous allons gérer l'espacement manuellement.
              children: [
                // Ajoutez un peu d'espace au début si nécessaire
                SizedBox(width: 16),
                OptionCercle(
                  image: 'assets/image/img6.png',
                  label: "Mon Troupeau",
                  route: const AnimalListPage(),
                ),
                // Ajoute un espacement fixe entre les cartes
                SizedBox(width: 12),
                OptionCercle(
                  image: 'assets/image/img10.png',
                  label: 'Logement',
                  route: const Accouplement(),
                ),
                SizedBox(width: 12),
                OptionCercle(
                  image: 'assets/image/img10.png',
                  label: 'Hôtel', // J'ai changé le label pour l'exemple
                  route: const Accouplement(),
                ),

                SizedBox(width: 16),
                OptionCercle(
                  image: 'assets/image/img10.png',
                  label: 'Hôtel', // J'ai changé le label pour l'exemple
                  route: const Accouplement(),
                ),

                SizedBox(width: 16),
              ],
            ),
          ),

          Text(
            'Choisir une option parmi les suivantes:',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
          SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: Card(
              color: Couleur.PremierColor,
              elevation: 0.1,
              shadowColor: Couleur.DeuxiemeColor,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Flexible(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Free consultation",
                            style: TextStyle(color: Colors.amber),
                          ),
                          Text(("Get free support from pour custer service")),
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AjouterAnimal(),
                                ),
                              );
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.yellow, // Fond jaune
                              foregroundColor: Colors
                                  .white, // Couleur du texte et icône (noir pour contraster)
                            ),
                            icon: Icon(Icons.add),
                            label: Text("Ajouter un animal"),
                          ),
                        ],
                      ),
                    ),
                    Image.asset("assets/image/img10.png", width: 100),
                  ],
                ),
              ),
            ),
          ),

          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OptionCard(
                image: 'assets/image/img6.png',
                label: "Mon Troupea",
                route: const AnimalListPage (),
              ),
              OptionCard(
                image: 'assets/image/img10.png',
                label: 'Periode Chaleur ',
                route: const Chaleur(),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OptionCard(
                image: 'assets/image/img5.png',
                label: "Transport",
                route:  const Chaleur(),
              ),
              OptionCard(
                image: 'assets/image/img14.png',
                label: 'Scan ',
                route: const AnimalInfoRFIDPage(),
              ),
            ],
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: Icon(Icons.add),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.blue,
        elevation: 2.5,
      ),
    );
  }
}
