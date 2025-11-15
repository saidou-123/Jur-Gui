import 'package:flutter/material.dart';

class ListeBrebis extends StatelessWidget {
  const ListeBrebis({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top:10),
      decoration: BoxDecoration(
        color: Colors.amber,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        title: Text("Non_animal"),
        subtitle: Text("Race_animal"),
        trailing: Text("Date_animal"), 
      ),
    );
  }
}