import 'package:depart/pages/Bienvenue/connexion.dart';
import 'package:depart/pages/Bienvenue/descriptionPages/welcomePage.dart';
import 'package:depart/pages/Bienvenue/descriptionPages/welcomePage2.dart';
import 'package:depart/pages/Bienvenue/descriptionPages/welcomePage3.dart';
import 'package:depart/widgets/couleur.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:smooth_page_indicator/smooth_page_indicator.dart';


class Homepage extends StatelessWidget {

  final _controller=PageController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          padding:EdgeInsets.symmetric(horizontal:12 ),
          child: Column(
            children: [
             SizedBox(height: 30,),

                 Row(
                  mainAxisAlignment:MainAxisAlignment.spaceBetween ,
                  children: [
                    Icon(Icons.chevron_left, size: 38,),
                    Text("Suivant", style: TextStyle(fontSize: 24),)
                  ],
                ),
              SizedBox(height: 30,),
              Column(
                
                mainAxisAlignment:MainAxisAlignment.spaceEvenly ,
                children: [
                 
                  SizedBox(
                    height:500 ,
                    child: PageView(
                      controller: _controller,
                      children: [
                    Welcomepage(),
                    Welcomepage2(),
                    Welcomepage3(),
                      ],
                    ),
                  ),
                  SmoothPageIndicator(controller: _controller, count: 3),
              
              
              
                 
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}