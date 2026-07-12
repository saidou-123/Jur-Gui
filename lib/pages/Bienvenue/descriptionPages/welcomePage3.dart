import 'package:depart/pages/Bienvenue/connexion.dart';
import 'package:depart/widgets/couleur.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class Welcomepage3  extends StatelessWidget {
  const Welcomepage3 ({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          children: [
            Container(
              child: Column(
                children: [
                  Container(
      
                    height: 250,
                    width: 250,
                     color: Colors.amber,
                  ),
                  SizedBox(height: 24,),
            
                  Text("Elevge inteligente",
                  textAlign:TextAlign.center ,
                  style: TextStyle(color: Couleur.PremierColor, fontSize: 28, fontWeight: FontWeight.bold),),
                  SizedBox(height: 18,),
      
                  Text("avoir les information a temps reel de vos animaux pour une intervantion rappide",
                  textAlign:TextAlign.center ,
                  style: TextStyle(
                    
                  ), ),
      
      
      
      
                    
                    
                ],
              ),
            )
          ],
        ),
      ) ;
  }
}