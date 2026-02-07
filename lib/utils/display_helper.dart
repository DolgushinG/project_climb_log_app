/// Возвращает отображаемое значение.
/// Для null, пустой строки или строки "null" возвращает "Нет данных".
String displayValue(String? value) {
  if (value == null || value.isEmpty || value.trim().toLowerCase() == 'null') {
    return 'Нет данных';
  }
  return value;
}
