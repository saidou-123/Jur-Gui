import 'package:depart/pages/acceuil.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize( url:"https://oyudfyxlyxggforfxdin.supabase.co",
  anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95dWRmeXhseXhnZ2ZvcmZ4ZGluIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE3NDg1NzAsImV4cCI6MjA3NzMyNDU3MH0.ccVliXQ82DOBGowLMOuzUClekXb9zXUZSUfPGwGPQoA" );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget { 
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      color: Colors.white,
      title: "Jur-Gui ",
      home: Acceuil (),
      debugShowCheckedModeBanner: false,
    );
  }
}
 