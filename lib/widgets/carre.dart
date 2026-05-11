import 'package:flutter/material.dart';

/// Conteneur carré pour image asset — utilisé dans l'onboarding et les profils.
class Carre extends StatelessWidget {
  final String path;
  final double padding;
  final double? size;
  final Color? borderColor;
  final Color? bgColor;

  const Carre({
    super.key,
    required this.path,
    this.padding = 20,
    this.size,
    this.borderColor,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor ?? Colors.grey.shade300),
        borderRadius: BorderRadius.circular(16),
        color: bgColor ?? Colors.grey[200],
      ),
      child: Image.asset(
        path,
        height: 20,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.image_not_supported, color: Colors.grey[400]),
      ),
    );
  }
}


/// Conteneur circulaire pour image asset — utilisé pour les avatars.
class Cercle extends StatelessWidget {
  final String path;
  final double padding;
  final double? size;
  final Color? borderColor;
  final Color? bgColor;

  const Cercle({
    super.key,
    required this.path,
    this.padding = 20,
    this.size,
    this.borderColor,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor ?? Colors.grey.shade300),
        color: bgColor ?? Colors.grey[200],
      ),
      child: Image.asset(
        path,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.image_not_supported, color: Colors.grey[400]),
      ),
    );
  }
}


/// Avatar circulaire générique : image réseau, asset, ou initiales en fallback.
class AvatarWidget extends StatelessWidget {
  final String? imageUrl;
  final String? assetPath;
  final String? initiales;
  final double radius;
  final Color? bgColor;

  const AvatarWidget({
    super.key,
    this.imageUrl,
    this.assetPath,
    this.initiales,
    this.radius = 30,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(imageUrl!),
        onBackgroundImageError: (_, __) {},
        backgroundColor: bgColor ?? Colors.green[100],
        child: null,
      );
    }
    if (assetPath != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: AssetImage(assetPath!),
        backgroundColor: bgColor ?? Colors.green[100],
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor ?? Colors.green[700],
      child: Text(
        initiales ?? '?',
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.7,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}