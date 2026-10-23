import 'package:flutter/material.dart';

/// Long provenance strings stay on one line and truncate with an ellipsis;
/// the full value remains available through a tooltip.
class SourceChip extends StatelessWidget {
  const SourceChip({super.key, required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String trimmed = source.trim();
    final String label = trimmed.isEmpty
        ? 'Sumber: tidak tersedia'
        : 'Sumber: $trimmed';

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Tooltip(
        message: label,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.link_rounded,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
