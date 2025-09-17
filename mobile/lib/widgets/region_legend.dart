import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:alagalert/theme/levels.dart';

class RegionLegend extends StatelessWidget {
  const RegionLegend({super.key});

  Widget box(String label, Color c) => Row(children: [
    Container(width: 14, height: 14, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
    const SizedBox(width: 6),
    Text(label)
  ]);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(spacing: 16, runSpacing: 8, children: [
          box("Baixo", levelColors["Baixo"]!),
          box("Moderado", levelColors["Moderado"]!),
          box("Alto", levelColors["Alto"]!),
          box("Crítico", levelColors["Crítico"]!),
        ]),
      ),
    );
  }
}
