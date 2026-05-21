import 'package:flutter/material.dart';

class Inputs extends StatefulWidget {
  final String label;
  final String hint;
  final IconData? icon;
  final Color? iconColor;
  final bool
  isPassword; // Nouveau paramètre pour indiquer si c'est un champ mot de passe

  const Inputs({
    super.key,
    required this.label,
    required this.hint,
    this.icon,
    this.isPassword = false,
    this.iconColor, // Par défaut à false
  });

  @override
  State<Inputs> createState() => _InputsState();
}

class _InputsState extends State<Inputs> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.iconColor ?? Theme.of(context).primaryColor;

    return Container(
      margin: EdgeInsets.only(top: 10),
      child: TextFormField(
        obscureText: widget.isPassword ? _obscureText : false,
        style: TextStyle(fontSize: 15),
        decoration: InputDecoration(
          label: Text(widget.label),
          hintText: widget.hint,
          prefixIcon: widget.icon != null
              ? Icon(widget.icon, color: iconColor)
              : null,

          suffixIcon: widget.isPassword
              ? IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility : Icons.visibility_off,
                    color: iconColor,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureText = !_obscureText;
                    });
                  },
                )
              : null,

          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return "Veuiller saisir votre " + widget.label;
          }
          return null;
        },
      ),
    );
  }
}