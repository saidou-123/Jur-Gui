// import 'package:depart/pages/acceuil.dart';

import 'package:depart/pages/connect.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      color: Colors.white,
      title: "USSEINPAY ",
      home: Connect(),
      debugShowCheckedModeBanner: false,
    );
  }
}
