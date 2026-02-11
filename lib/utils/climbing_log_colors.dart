import 'package:flutter/material.dart';

/// Гармоничная палитра градиентов для грейдов: от лёгких (бирюза) к сложным (янтарь).
const List<String> orderedGrades = [
  '5', '6A', '6A+', '6B', '6B+', '6C', '6C+',
  '7A', '7A+', '7B', '7B+', '7C', '7C+', '8A+'
];

const List<List<Color>> gradeGradients = [
  [Color(0xFF14B8A6), Color(0xFF06B6D4)], // 5, 6A
  [Color(0xFF06B6D4), Color(0xFF3B82F6)], // 6A+, 6B
  [Color(0xFF3B82F6), Color(0xFF6366F1)], // 6B+, 6C
  [Color(0xFF6366F1), Color(0xFF8B5CF6)], // 6C+, 7A
  [Color(0xFF8B5CF6), Color(0xFFA855F7)], // 7A+, 7B
  [Color(0xFFD946EF), Color(0xFFF43F5E)], // 7B+, 7C
  [Color(0xFFF97316), Color(0xFFEAB308)], // 7C+, 8A+
];

List<Color> gradientForGrade(String grade) {
  final i = orderedGrades.indexOf(grade);
  if (i < 0) return gradeGradients.first;
  final groupIndex = (i / 2).floor().clamp(0, gradeGradients.length - 1);
  return gradeGradients[groupIndex];
}
