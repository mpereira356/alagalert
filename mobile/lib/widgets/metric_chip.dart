import 'package:flutter/material.dart';

class MetricChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  const MetricChip({super.key, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) Icon(icon, size: 16),
        if (icon != null) const SizedBox(width: 6),
        Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: cs.onPrimaryContainer)),
      ]),
    );
  }
}
