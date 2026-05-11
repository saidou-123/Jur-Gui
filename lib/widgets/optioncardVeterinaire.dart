import 'package:flutter/material.dart';

/// Carte de menu principal utilisée dans le dashboard vétérinaire.
/// Supporte image asset OU icône Material, badge de notification optionnel.
class OptionCardVeterinaire extends StatelessWidget {
  final String label;
  final Widget route;
  final Color backgroundColor;
  final Color? borderColor;
  final Color? labelColor;

  // Image ou icône (l'un ou l'autre)
  final String? image;
  final IconData? icon;
  final Color? iconColor;

  // Badge optionnel (ex: nombre de rappels urgents)
  final int? badgeCount;

  const OptionCardVeterinaire({
    super.key,
    required this.label,
    required this.route,
    required this.backgroundColor,
    this.image,
    this.icon,
    this.iconColor,
    this.borderColor,
    this.labelColor,
    this.badgeCount,
  }) : assert(image != null || icon != null, 'Fournir image ou icon');

  @override
  Widget build(BuildContext context) {
    final border = borderColor ?? Colors.blue[700]!;
    final txtColor = labelColor ?? Colors.blue[700]!;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => route)),
      child: Container(
        constraints: const BoxConstraints(minHeight: 120, maxHeight: 145),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 2.0),
          boxShadow: [
            BoxShadow(
              color: border.withOpacity(0.12),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => route)),
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  // Contenu principal
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Image ou icône
                        Flexible(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 62, maxWidth: 62),
                            child: _buildVisual(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 36,
                          child: Center(
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: txtColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Badge notification
                  if (badgeCount != null && badgeCount! > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: Text(
                          '$badgeCount',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVisual() {
    if (icon != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (iconColor ?? Colors.blue).withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 32, color: iconColor ?? Colors.blue[700]),
      );
    }
    return Image.asset(
      image!,
      fit: BoxFit.contain,
      color: iconColor,
      errorBuilder: (_, __, ___) => Icon(Icons.image_not_supported, size: 40, color: Colors.grey[400]),
    );
  }
}