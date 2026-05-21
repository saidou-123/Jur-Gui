import 'package:flutter/material.dart';


class optioncardVeterinaire extends StatelessWidget {
  final String image;
  final String label;
  final Widget route;
  final Color backgroundColor;
  final Color? iconColor;

  const optioncardVeterinaire({
    super.key,
    required this.image,
    required this.label,
    required this.route,
    required this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => route)),
      child: Container(
        constraints: const BoxConstraints(
          minHeight: 120,
          maxHeight: 140,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.blue[700]!,
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => route),
              ),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Image avec contraintes
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
                          errorBuilder: (context, error, stackTrace) {
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
                    // Label avec hauteur fixe pour éviter l'overflow
                    SizedBox(
                      height: 34,
                      child: Center(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.blue[700],
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
        ),
      ),
    );
  }
}