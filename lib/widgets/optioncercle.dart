import 'package:flutter/material.dart';

class OptionCercle extends StatefulWidget {
  final String image;
  final String label;
  final Widget route;
  final Color? backgroundColor;

  const OptionCercle({
    super.key,
    required this.image,
    required this.label,
    required this.route,
    this.backgroundColor,
  });

  @override
  State<OptionCercle> createState() => _OptionCercleState();
}

class _OptionCercleState extends State<OptionCercle> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => widget.route),
        );
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Column(
          children: [
            // Cercle avec l'image
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.backgroundColor ?? Colors.blue[700]!,
                    (widget.backgroundColor ?? Colors.blue[700]!)
                        .withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (widget.backgroundColor ?? Colors.blue[700]!)
                        .withOpacity(0.4),
                    blurRadius: _isPressed ? 4 : 8,
                    offset: Offset(0, _isPressed ? 2 : 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Image.asset(
                  widget.image,
                  fit: BoxFit.contain,
                  color: Colors.white,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.image_not_supported,
                      color: Colors.white,
                      size: 36,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Label
            SizedBox(
              width: 90,
              child: Text(
                widget.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: widget.backgroundColor ?? Colors.blue[700],
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
