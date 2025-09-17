import 'package:flutter/material.dart';

/// Cores por nível de risco (usadas no card, legenda e mapa).
const Map<String, Color> levelColors = {
  "Baixo": Color(0xFF22C55E),     // verde
  "Moderado": Color(0xFFF59E0B),  // amarelo
  "Alto": Color(0xFFEF4444),      // vermelho
  "Crítico": Color(0xFFB91C1C),   // vermelho escuro
};

/// Gradiente da régua (esquerda->direita)
const List<Color> riskGradient = [
  Color(0xFF22C55E), // Baixo
  Color(0xFFF59E0B), // Moderado
  Color(0xFFEF4444), // Alto
];
