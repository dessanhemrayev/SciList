import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/utils/issn_input_formatter.dart';
import '../../../core/utils/issn_validator.dart';

class IssnInputField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final String? Function(String?)? validator;
  final bool autofocus;
  final String hintText;

  const IssnInputField({
    super.key,
    required this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.autofocus = false,
    this.hintText = 'XXXX-XXXX',
  });

  @override
  State<IssnInputField> createState() => _IssnInputFieldState();
}

class _IssnInputFieldState extends State<IssnInputField> {
  String? _errorText;
  bool _hasValidFormat = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final formatted = widget.controller.text;

    final isValidFormat = IssnValidator.isValidFormat(formatted);
    final isValidCheckDigit = isValidFormat ? IssnValidator.isValidCheckDigit(formatted) : false;

    setState(() {
      _hasValidFormat = isValidFormat;
      if (formatted.isEmpty) {
        _errorText = null;
      } else if (!isValidFormat) {
        _errorText = 'Формат: XXXX-XXXX';
      } else if (!isValidCheckDigit) {
        _errorText = 'Неверный контрольный номер';
      } else {
        _errorText = null;
      }
    });

    widget.onChanged?.call(formatted);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final borderColor = _errorText != null
        ? colorScheme.error
        : _hasValidFormat
            ? colorScheme.primary
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          keyboardType: TextInputType.number,
          inputFormatters: const [IssnInputFormatter()],
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: Icon(
              Icons.badge_rounded,
              color: _errorText != null
                  ? colorScheme.error
                  : _hasValidFormat
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
            ),
            suffixIcon: widget.controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear_rounded, color: colorScheme.onSurfaceVariant),
                    onPressed: () {
                      widget.controller.clear();
                      widget.onChanged?.call('');
                    },
                  )
                : null,
            errorText: _errorText,
            errorStyle: TextStyle(color: colorScheme.error),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: borderColor ?? colorScheme.outline.withValues(alpha: 0.3),
                width: borderColor != null ? 2 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: borderColor ?? colorScheme.primary,
                width: 2.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colorScheme.error, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colorScheme.error, width: 2.5),
            ),
            filled: true,
            fillColor: _errorText != null
                ? colorScheme.errorContainer.withValues(alpha: 0.3)
                : _hasValidFormat
                    ? colorScheme.primaryContainer.withValues(alpha: 0.2)
                    : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          ),
          onFieldSubmitted: (_) => widget.onSubmitted?.call(),
          validator: widget.validator ??
              (value) {
                if (value == null || value.isEmpty) return 'Введите ISSN';
                if (!IssnValidator.isValid(value)) return 'Неверный ISSN';
                return null;
              },
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
        if (_errorText != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                _hasValidFormat ? Icons.info_outline_rounded : Icons.error_outline_rounded,
                size: 14,
                color: _hasValidFormat ? colorScheme.primary : colorScheme.error,
              ),
              const SizedBox(width: 6),
              Text(
                _errorText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _hasValidFormat ? colorScheme.primary : colorScheme.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ).animate().fadeIn().slideY(begin: -0.1),
        ],
      ],
    );
  }
}