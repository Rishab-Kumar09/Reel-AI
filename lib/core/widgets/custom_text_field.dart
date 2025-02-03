import 'package:flutter/material.dart';
import 'package:flutter_firebase_app_new/core/theme/app_theme.dart';

class CustomTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final Widget? prefix;
  final Widget? suffix;
  final int? maxLines;
  final int? maxLength;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;
  final void Function(String)? onChanged;
  final bool enabled;

  const CustomTextField({
    super.key,
    required this.label,
    this.hint,
    required this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.prefix,
    this.suffix,
    this.maxLines = 1,
    this.maxLength,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.textSecondaryColor,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          maxLines: maxLines,
          maxLength: maxLength,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          onChanged: onChanged,
          enabled: enabled,
          style: AppTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefix,
            suffixIcon: suffix,
            hintStyle: AppTheme.bodyLarge.copyWith(
              color: AppTheme.textSecondaryColor.withOpacity(0.5),
            ),
          ),
        ),
      ],
    );
  }
} 