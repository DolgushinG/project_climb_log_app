import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Премиальная монохромная палитра — «тихая роскошь».
/// Эстетика Hodinkee / премиальных фитнес-приложений.
class AppColors {
  /// Глубокий антрацит — основной тёмный цвет (не чистый чёрный)
  static const Color anthracite = Color(0xFF0A0A0C);

  /// Фон с оттенком слоновой кости
  static const Color ivoryBackground = Color(0xFFF8F6F3);

  /// Приглушённое золото — акцент
  static const Color mutedGold = Color(0xFFB59D7E);

  /// Благородный графит
  static const Color graphite = Color(0xFF2A2A2E);

  /// Светлый графит для вторичного текста
  static const Color graphiteLight = Color(0xFF6B6B70);

  /// Плашечный серый для badge/баллов
  static const Color badgeGray = Color(0xFFE8E6E3);

  /// Для тёмной темы — слегка светлее антрацита
  static const Color surfaceDark = Color(0xFF121214);

  /// Карточка на тёмном фоне
  static const Color cardDark = Color(0xFF141416);

  /// Альтернативный ряд для чередования
  static const Color rowAlt = Color(0xFF0E0E10);

  /// Приглушённый зелёный для успеха/подтверждения
  static const Color successMuted = Color(0xFF4A5D4A);

  /// Приглушённый синий для ссылок (вместо яркого)
  static const Color linkMuted = Color(0xFF8B9A8B);
}

/// Форматирование порядкового номера: 01, 02, 03
String formatPlace(int place) {
  if (place >= 1 && place <= 99) {
    return place.toString().padLeft(2, '0');
  }
  return place.toString();
}

/// Форматирование даты: 20 DEC 2025
String formatDatePremium(DateTime date) {
  const months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
  ];
  final day = date.day.toString().padLeft(2, '0');
  final month = months[date.month - 1];
  return '$day $month ${date.year}';
}

/// Стили типографики — минимализм, крупные тонкие цифры.
/// Приложение использует тёмную тему.
class AppTypography {
  /// Крупные тонкие цифры ранга (background) — задают ритм
  static TextStyle rankNumber() {
    return GoogleFonts.unbounded(
      fontSize: 48,
      fontWeight: FontWeight.w200,
      color: Colors.white.withOpacity(0.06),
      letterSpacing: -1,
    );
  }

  /// Имя спортсмена — жирный, с трекингом
  static TextStyle athleteName() {
    return GoogleFonts.unbounded(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      color: Colors.white,
    );
  }

  /// Badge/баллы — тонкий гротеск
  static TextStyle scoreBadge() {
    return GoogleFonts.unbounded(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Colors.white.withOpacity(0.9),
    );
  }

  /// Город/категория — вторичный текст
  static TextStyle secondary() {
    return GoogleFonts.unbounded(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: Colors.white.withOpacity(0.55),
    );
  }

  /// Заголовки секций
  static TextStyle sectionTitle() {
    return GoogleFonts.unbounded(
      fontSize: 20,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
      color: Colors.white,
    );
  }

  /// Маленькие метки (T, Z, маршруты)
  static TextStyle smallLabel() {
    return GoogleFonts.unbounded(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      color: Colors.white.withOpacity(0.5),
    );
  }
}
