import 'package:login_app/models/NumberSets.dart';

/// Возвращает отображаемое значение.
/// Для null, пустой строки или строки "null" возвращает "Нет данных".
String displayValue(String? value) {
  if (value == null || value.isEmpty || value.trim().toLowerCase() == 'null') {
    return 'Нет данных';
  }
  return value;
}

const Map<String, String> _dayToRu = {
  'mon': 'Пн', 'monday': 'Пн', 'пн': 'Пн',
  'tue': 'Вт', 'tuesday': 'Вт', 'вт': 'Вт',
  'wed': 'Ср', 'wednesday': 'Ср', 'ср': 'Ср',
  'thu': 'Чт', 'thursday': 'Чт', 'чт': 'Чт',
  'fri': 'Пт', 'friday': 'Пт', 'пт': 'Пт',
  'sat': 'Сб', 'saturday': 'Сб', 'сб': 'Сб',
  'sun': 'Вс', 'sunday': 'Вс', 'вс': 'Вс',
  '1': 'Пн', '2': 'Вт', '3': 'Ср', '4': 'Чт', '5': 'Пт', '6': 'Сб', '7': 'Вс',
};

String _dayOfWeekToRu(String day) {
  final key = day.trim().toLowerCase();
  return _dayToRu[key] ?? day.trim();
}

/// Извлекает только время из строки (убирает дату, если есть).
/// Примеры: "12.02.2025 10:00" → "10:00"; "10:00-11:00" → "10:00-11:00"; "10:00" → "10:00"
String extractSetTimeOnly(String timeStr) {
  final t = timeStr.trim();
  if (t.isEmpty) return '';
  final parts = t.split(RegExp(r'\s+'));
  for (var i = parts.length - 1; i >= 0; i--) {
    final p = parts[i];
    if (RegExp(r'^\d{1,2}:\d{2}(-\d{1,2}:\d{2})?$').hasMatch(p)) return p;
  }
  if (RegExp(r'^\d{1,2}:\d{2}(-\d{1,2}:\d{2})?$').hasMatch(t)) return t;
  return t;
}

/// Склонение «место»: 1 место, 2 места, 5 мест
String placeWord(int n) {
  final mod10 = n.abs() % 10;
  final mod100 = n.abs() % 100;
  if (mod10 == 1 && mod100 != 11) return 'место';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) return 'места';
  return 'мест';
}

/// Компактный формат сета: номер, день недели (рус.), время
String formatSetCompact(NumberSets s) {
  final parts = <String>['№${s.number_set}'];
  if (s.day_of_week.trim().isNotEmpty) parts.add(_dayOfWeekToRu(s.day_of_week));
  if (s.time.trim().isNotEmpty) parts.add(s.time.trim());
  return parts.join(' · ');
}
