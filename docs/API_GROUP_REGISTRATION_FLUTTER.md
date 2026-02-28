# API групповой регистрации — Flutter

## 4.4. Реализация для Flutter (по аналогии с веб-версией)

### Условия показа кнопки «Добавить в лист ожидания»

- Участник ещё не в заявке (`!is_participant`)
- Возраст подходит (`!cannot_participate`)
- Есть хотя бы один сет с `list_pending: true`:
  - **YEAR/AGE**: участник имеет дату рождения (сеты запрашиваются при открытии модалки)
  - **MANUAL/RESULT**: из `sets[]` group-register берём сеты с `list_pending: true`

### Фильтрация сетов

| Режим | Источник |
|-------|----------|
| **YEAR/AGE** | `GET available-sets?dob={birthday}` → берём сеты с `list_pending: true` |
| **MANUAL/RESULT** | Из `sets[]` group-register берём сеты с `list_pending: true` |

### Экран/модалка «Лист ожидания»

- Текст-подсказка: «Если все места в интересующих вас сетах заняты, участник будет добавлен в лист ожидания»
- Чекбоксы сетов (только valid sets)
- **Категория**: для MANUAL — select; для YEAR/AGE — вывод по дате рождения (из `available-category?dob=`)
- Дата рождения (отображение из профиля)
- Пол (отображение из профиля)
- Разряд (если `is_need_sport_category`)
- Кнопки: Добавить / Изменить / Удалить

### Валидация

- Выбран минимум один сет
- Категория (для MANUAL)
- Дата рождения (обязательна — из профиля related_user)
- Разряд (если требуется)

### Константы is_auto_categories

| Константа | Значение | Описание |
|-----------|----------|----------|
| `MANUAL_CATEGORIES` | 0 | Категория выбирается вручную |
| `AUTO_CATEGORIES_RESULT` | 1 | Категория по результату |
| `AUTO_CATEGORIES_YEAR` | 2 | Категория по году рождения |
| `AUTO_CATEGORIES_AGE` | 3 | Категория по возрасту |

### Реализация в GroupRegisterScreen

```dart
// Константы
const int _MANUAL_CATEGORIES = 0;
const int _AUTO_CATEGORIES_RESULT = 1;
const int _AUTO_CATEGORIES_YEAR = 2;
const int _AUTO_CATEGORIES_AGE = 3;

// Получить valid list_pending sets (MANUAL/RESULT)
List<Map<String, dynamic>> _getValidListPendingSetsSync() {
  final setsRaw = _data?['sets'];
  final setsList = setsRaw is List ? setsRaw : [];
  return setsList
      .where((s) => s is Map && s['list_pending'] == true)
      .map((s) => Map<String, dynamic>.from(s is Map ? s : {}))
      .toList();
}

// Для YEAR/AGE — загрузить valid sets по dob
Future<List<Map<String, dynamic>>> _fetchValidListPendingSetsForDob(String dob) async {
  final r = await http.get(
    Uri.parse('$DOMAIN/api/event/${eventId}/available-sets?dob=$dob'),
    ...
  );
  final list = body['availableSets'] ?? body['available_sets'] ?? [];
  return sets.where((s) => s['list_pending'] == true).toList();
}

// add-to-list-pending
Future<void> _addToListPending(userId, numberSets, birthday, category, sportCategory, [gender]) async {
  final body = {
    'user_id': userId,
    'number_sets': numberSets,
    'birthday': birthday,
  };
  if (category != null) body['category'] = category;
  if (sportCategory != null) body['sport_category'] = sportCategory;
  if (gender != null) body['gender'] = gender;
  await http.post(Uri.parse('$DOMAIN/api/event/${eventId}/add-to-list-pending'), ...);
}

// remove-from-list-pending
Future<void> _removeFromListPending(userId) async {
  await http.post(
    Uri.parse('$DOMAIN/api/event/${eventId}/remove-from-list-pending'),
    body: jsonEncode({'user_id': userId}),
    ...
  );
}
```

### См. также

- [BACKEND_GROUP_REGISTER_LIST_PENDING.md](BACKEND_GROUP_REGISTER_LIST_PENDING.md) — API листа ожидания для group-register
