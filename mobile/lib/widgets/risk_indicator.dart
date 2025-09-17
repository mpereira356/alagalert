import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:alagalert/theme/levels.dart';

class RiskIndicator extends StatelessWidget {
  final double score; // 0..1
  final String level;
  final double height;
  const RiskIndicator({super.key, required this.score, required this.level, this.height = 14});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width - 64;
    final filled = width * score;
    final colors = const [
      Color(0xFF2C7BE5), // baixo
      Color(0xFF48C1BF),
      Color(0xFFF4C542),
      Color(0xFFF28B2B),
      Color(0xFFE53935),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(children: [
          Container(
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(colors: colors),
            )),
          Positioned(
            left: filled.clamp(0, width - 18),
            top: -3,
            child: Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                color: levelColors[level] ?? Colors.black,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          )
        ]),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(level, style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: levelColors[level] ?? Colors.black, fontWeight: FontWeight.w800)),
            Text("${(score*100).round()}%", style: Theme.of(context).textTheme.headlineMedium)
          ],
        ),
      ],
    );
  }
}
