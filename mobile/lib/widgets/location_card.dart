import 'package:flutter/material.dart';

class LocationCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const LocationCard({super.key, required this.title, required this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.chevron_right, color: cs.primary),
      ),
    );
  }
}
