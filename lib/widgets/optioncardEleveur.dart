import 'package:flutter/material.dart';


// ========================================
// CORRECTIONS POUR optioncardEleveur.dart
// ========================================

class optioncardEleveur extends StatelessWidget {
  final String image;
  final String label;
  final Widget route;
  final Color backgroundColor;
  final Color? iconColor;

  const optioncardEleveur({
    super.key,
    required this.image,
    required this.label,
    required this.route,
    required this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 120,
        maxHeight: 140,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color.fromARGB(255, 5, 87, 46), // ✅ Couleur directe
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // ✅ NAVIGATION SÉCURISÉE
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => route),
            ).catchError((error) {
              debugPrint("Erreur navigation: $error");
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Erreur de navigation: $error"),
                  backgroundColor: Colors.red,
                ),
              );
              return null;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ✅ IMAGE AVEC GESTION D'ERREURS
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 70,
                      maxWidth: 70,
                    ),
                    child: Image.asset(
                      image,
                      fit: BoxFit.contain,
                      color: iconColor,
                      // ✅ CACHE D'IMAGE
                      cacheHeight: 70,
                      cacheWidth: 70,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint("Erreur chargement image: $image - $error");
                        return Icon(
                          Icons.image_not_supported,
                          size: 50,
                          color: Colors.grey[400],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // ✅ LABEL OPTIMISÉ
                SizedBox(
                  height: 34,
                  child: Center(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color.fromARGB(255, 5, 87, 46),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ========================================
// CORRECTIONS POUR inputs.dart
// ========================================

class Inputs extends StatefulWidget {
  final String label;
  final String hint;
  final IconData? icon;
  final Color? iconColor;
  final bool isPassword;
  final TextEditingController? controller; // ✅ AJOUT DU CONTROLLER
  final String? Function(String?)? validator; // ✅ VALIDATOR PERSONNALISABLE

  const Inputs({
    super.key,
    required this.label,
    required this.hint,
    this.icon,
    this.isPassword = false,
    this.iconColor,
    this.controller, // ✅ NOUVEAU
    this.validator, // ✅ NOUVEAU
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
      margin: const EdgeInsets.only(top: 10),
      child: TextFormField(
        controller: widget.controller, // ✅ UTILISER LE CONTROLLER
        obscureText: widget.isPassword ? _obscureText : false,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          labelText: widget.label,
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

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        // ✅ VALIDATOR AMÉLIORÉ
        validator: widget.validator ?? (value) {
          if (value == null || value.isEmpty) {
            return "Veuillez saisir votre ${widget.label}";
          }
          return null;
        },
      ),
    );
  }
}

// ========================================
// CORRECTIONS POUR Cercle.dart
// ========================================

class Cercle extends StatelessWidget {
  final String path;
  const Cercle({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        shape: BoxShape.circle, // ✅ Forme circulaire
        border: Border.all(color: Colors.grey),
        color: Colors.grey[200],
        // ❌ NE PAS UTILISER borderRadius avec shape: BoxShape.circle
      ),
      child: Image.asset(
        path,
        height: 20,
        width: 20, // ✅ AJOUT WIDTH pour le cercle
        fit: BoxFit.contain, // ✅ MEILLEUR FIT
        errorBuilder: (context, error, stackTrace) {
          return Icon(Icons.error, size: 20, color: Colors.red);
        },
      ),
    );
  }
}