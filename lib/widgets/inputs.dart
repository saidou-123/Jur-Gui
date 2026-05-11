import 'package:depart/widgets/couleur.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
/// Champ de saisie réutilisable avec support :
/// - mot de passe (toggle visibilité)
/// - numérique (clavier adapté)
/// - validation personnalisée
/// - controller externe
class Inputs extends StatefulWidget {
  final String label;
  final String hint;
  final IconData? icon;
  final Color? iconColor;
  final bool isPassword;
  final bool isNumeric;
  final bool isRequired;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final bool enabled;

  const Inputs({
    super.key,
    required this.label,
    required this.hint,
    this.icon,
    this.iconColor,
    this.isPassword = false,
    this.isNumeric = false,
    this.isRequired = true,
    this.controller,
    this.validator,
    this.onChanged,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.enabled = true,
  });

  @override
  State<Inputs> createState() => _InputsState();
}

class _InputsState extends State<Inputs> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final color = widget.iconColor ?? Couleur.premierColor;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      child: TextFormField(
        controller: widget.controller,
        obscureText: widget.isPassword ? _obscure : false,
        enabled: widget.enabled,
        maxLines: widget.isPassword ? 1 : widget.maxLines,
        onChanged: widget.onChanged,
        keyboardType: widget.isNumeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : widget.keyboardType,
        inputFormatters: widget.inputFormatters ??
            (widget.isNumeric ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))] : null),
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          prefixIcon: widget.icon != null ? Icon(widget.icon, color: color) : null,
          suffixIcon: widget.isPassword
              ? IconButton(
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off, color: color),
                  onPressed: () => setState(() => _obscure = !_obscure),
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: color, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.red, width: 1.5),
          ),
          filled: !widget.enabled,
          fillColor: widget.enabled ? null : Colors.grey[100],
        ),
        validator: widget.validator ??
            (widget.isRequired
                ? (v) => (v == null || v.trim().isEmpty) ? 'Veuillez saisir ${widget.label.toLowerCase()}' : null
                : null),
      ),
    );
  }
}


// ─── Champ email ──────────────────────────────────────────────
class EmailInput extends StatelessWidget {
  final TextEditingController? controller;
  final void Function(String)? onChanged;

  const EmailInput({super.key, this.controller, this.onChanged});

  @override
  Widget build(BuildContext context) => Inputs(
    label: 'Email',
    hint: 'exemple@email.com',
    icon: Icons.email_outlined,
    controller: controller,
    onChanged: onChanged,
    keyboardType: TextInputType.emailAddress,
    validator: (v) {
      if (v == null || v.isEmpty) return 'Veuillez saisir votre email';
      final re = RegExp(r'^[\w.-]+@[\w.-]+\.\w+$');
      return re.hasMatch(v) ? null : 'Email invalide';
    },
  );
}


// ─── Champ mot de passe ────────────────────────────────────────
class PasswordInput extends StatelessWidget {
  final TextEditingController? controller;
  final String label;

  const PasswordInput({super.key, this.controller, this.label = 'Mot de passe'});

  @override
  Widget build(BuildContext context) => Inputs(
    label: label,
    hint: '••••••••',
    icon: Icons.lock_outline,
    isPassword: true,
    controller: controller,
    validator: (v) {
      if (v == null || v.isEmpty) return 'Veuillez saisir votre mot de passe';
      if (v.length < 6) return 'Minimum 6 caractères';
      return null;
    },
  );
}