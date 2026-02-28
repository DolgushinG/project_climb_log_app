# API асинхронной генерации (Async Generation)

Документация по асинхронным endpoint'ам для генерации планов тренировок и умных тренировок с использованием polling.

## Обзор

Система использует асинхронную генерацию для длительных операций (генерация плана, умная тренировка). Вместо ожидания синхронного ответа, клиент:

1. Запускает задачу через `*/async` endpoint
2. Получает `task_id`
3. Опрашивает статус через `*/{task_id}/status` (polling)
4. Получает результат когда задача завершена

Преимущества:
- Нет таймаутов на стороне клиента
- Пользователь видит прогресс
- Можно отображать статус (pending, processing, completed, failed)
- Более стабильная работа с долгими запросами

---

## Эндпоинты

### 1. Генерация плана тренировок (асинхронная)

#### Запуск задачи

```
POST /api/climbing-logs/plans/async
```

**Заголовки:** `Authorization: Bearer <token>`

**Тело:** аналогично синхронному `POST /api/climbing-logs/plans`

```json
{
  "template_key": "amateur",
  "duration_weeks": 4,
  "start_date": "2026-02-17",
  "scheduled_weekdays": [1, 3, 5],
  "has_fingerboard": true,
  "injuries": ["elbow_pain"],
  "preferred_style": "both",
  "experience_months": 12,
  "available_minutes": 45,
  "ofp_sfp_focus": "balanced",
  "ofp_weekdays": [1, 5],
  "sfp_weekdays": [3]
}
```

**Ответ (202):**
```json
{
  "task_id": "abc123def456",
  "status": "pending",
  "message": "Генерация запущена. Опрашивайте статус каждые 2-3 секунды."
}
```

#### Проверка статуса

```
GET /api/climbing-logs/plans/async/{task_id}/status
```

**Ответ (200):**
```json
{
  "task_id": "abc123def456",
  "status": "processing"
}
```

или при завершении:

```json
{
  "task_id": "abc123def456",
  "status": "completed",
  "result": {
    "id": 123,
    "template_key": "amateur",
    "start_date": "2026-02-17",
    "end_date": "2026-03-16",
    "scheduled_weekdays": [1, 3, 5],
    "scheduled_weekdays_labels": ["Пн", "Ср", "Пт"],
    "include_climbing_in_days": true,
    "ofp_sfp_focus": "balanced"
  }
}
```

при ошибке:

```json
{
  "task_id": "abc123def456",
  "status": "failed",
  "error": "Ошибка генерации: не удалось подобрать упражнения"
}
```

**Статусы задач:**
- `pending` - задача в очереди
- `processing` - задача выполняется
- `completed` - задача завершена, результат в поле `result`
- `failed` - задача завершилась с ошибкой, детали в поле `error`

---

### 2. Генерация умной тренировки (асинхронная)

#### Запуск задачи

```
POST /api/climbing-logs/workout/generate/async
```

**Заголовки:** `Authorization: Bearer <token>`

**Тело:** аналогично синхронному `POST /api/climbing-logs/workout/generate`

```json
{
  "user_level": 2,
  "goal": "max_strength",
  "injuries": [],
  "available_time_minutes": 75,
  "experience_months": 12,
  "min_pullups": 10,
  "user_profile": {
    "bodyweight": 72,
    "preferred_style": "lead"
  },
  "performance_metrics": {
    "max_pullups": 18,
    "dead_hang_seconds": 75,
    "lsit_seconds": 40
  },
  "recent_climbing_data": {
    "sessions_last_7_days": 3,
    "dominant_categories": ["overhang", "endurance_routes"],
    "average_grade": "7b"
  },
  "fatigue_data": {
    "weekly_fatigue_sum": 28,
    "fatigue_trend": "stable"
  },
  "current_phase": "build",
  "day_offset": 5,
  "generate_ai_comment": true
}
```

**Ответ (202):**
```json
{
  "task_id": "xyz789uvw012",
  "status": "pending",
  "message": "Генерация запущена. Опрашивайте статус каждые 2-3 секунды."
}
```

#### Проверка статуса

```
GET /api/climbing-logs/workout/generate/{task_id}/status
```

**Ответ (200):**
```json
{
  "task_id": "xyz789uvw012",
  "status": "processing"
}
```

или при завершении:

```json
{
  "task_id": "xyz789uvw012",
  "status": "completed",
  "result": {
    "blocks": {
      "warmup": {
        "exercise_id": "shoulder_mobility",
        "name": "Shoulder Mobility",
        "name_ru": "Мобильность плеч",
        "category": "mobility",
        "sets": 2,
        "reps": "20"
      },
      "main": { ... },
      "antagonist": { ... },
      "core": { ... }
    },
    "warnings": [],
    "session_structure": { ... },
    "intensity_explanation": "Фаза набора: постепенное повышение интенсивности...",
    "why_this_session": "Фаза набора: комбинируем интенсивность и объём...",
    "progression_hint": "Увеличь время виса или уменьши отдых...",
    "load_distribution": {
      "finger": 30,
      "endurance": 40,
      "strength": 20,
      "mobility": 10
    },
    "coach_comment": "Сегодня фокус на аэробной ёмкостью...",
    "ai_coach_available": true
  }
}
```

при ошибке:

```json
{
  "task_id": "xyz789uvw012",
  "status": "failed",
  "error": "Ошибка генерации: не удалось получить рекомендации от AI"
}
```

---

## Flutter Implementation

### Модели

```dart
class AsyncTaskResponse {
  final String taskId;
  final String status; // pending, processing, completed, failed
  final dynamic result; // ActivePlan или WorkoutGenerateResponse
  final String? error;

  bool get isPending => status == 'pending';
  bool get isProcessing => status == 'processing';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';

  factory AsyncTaskResponse.fromJson(Map<String, dynamic> json);
}
```

### Сервисы

#### TrainingPlanApiService

```dart
// Запуск асинхронной генерации плана
Future<String?> createPlanAsync(Map<String, dynamic> params);

// Проверка статуса
Future<AsyncTaskResponse?> getPlanTaskStatus(String taskId);

// Polling с колбэком на обновление статуса
Future<AsyncTaskResponse?> pollPlanGeneration(
  String taskId, {
  Duration? interval, // по умолчанию 2 секунды
  Duration? timeout, // по умолчанию 60 секунд
  void Function(String status)? onStatusUpdate,
});
```

#### StrengthTestApiService

```dart
// Запуск асинхронной генерации тренировки
Future<String?> generateWorkoutAsync(Map<String, dynamic> params);

// Проверка статуса
Future<AsyncTaskResponse?> getWorkoutTaskStatus(String taskId);

// Polling с колбэком на обновление статуса
Future<AsyncTaskResponse?> pollWorkoutGeneration(
  String taskId, {
  Duration? interval, // по умолчанию 2 секунды
  Duration? timeout, // по умолчанию 60 секунд
  void Function(String status)? onStatusUpdate,
});
```

### Использование в UI

#### Пример для WorkoutGenerateScreen

```dart
Future<void> _generate() async {
  setState(() {
    _loading = true;
    _error = null;
  });

  try {
    // 1. Запускаем задачу
    final taskId = await api.generateWorkoutAsync(req.toJson());
    
    if (taskId == null) {
      setState(() {
        _loading = false;
        _error = 'Не удалось запустить генерацию тренировки';
      });
      return;
    }

    // 2. Опрашиваем статус
    final response = await api.pollWorkoutGeneration(
      taskId,
      interval: const Duration(seconds: 2),
      timeout: const Duration(seconds: 60),
      onStatusUpdate: (status) {
        // Обновляем UI для отображения текущего статуса
        if (mounted) setState(() {});
      },
    );

    setState(() => _loading = false);

    if (response == null) {
      setState(() => _error = 'Таймаут генерации тренировки');
      return;
    }

    if (response.isFailed) {
      setState(() => _error = response.error ?? 'Ошибка генерации');
      return;
    }

    if (response.isCompleted && response.result != null) {
      final workout = response.result as WorkoutGenerateResponse;
      // Переход на экран результата
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkoutResultScreen(workout: workout),
        ),
      );
    }
  } catch (e) {
    setState(() {
      _loading = false;
      _error = 'Ошибка: ${e.toString()}',
    });
  }
}
```

#### Пример для PlanSelectionScreen

```dart
Future<void> _createPlan() async {
  setState(() {
    _generatingPlan = true;
    _error = null;
  });

  final params = {
    'template_key': _selectedTemplate!.key,
    'duration_weeks': _durationWeeks,
    'start_date': startStr,
    // ... остальные параметры
  };

  // Запускаем задачу
  final taskId = await _api.createPlanAsync(params);
  
  if (taskId == null) {
    setState(() {
      _generatingPlan = false;
      _error = 'Не удалось запустить создание плана',
    });
    return;
  }

  // Опрашиваем статус
  final response = await _api.pollPlanGeneration(
    taskId,
    onStatusUpdate: (status) {
      // Обновляем UI
      if (mounted) setState(() {});
    },
  );

  setState(() => _generatingPlan = false);

  if (response?.isCompleted == true && response?.result != null) {
    final planData = response!.result as Map<String, dynamic>;
    final plan = ActivePlan.fromJson(planData);
    Navigator.pop(context, plan);
  } else {
    setState(() => _error = response?.error ?? 'Ошибка создания плана');
  }
}
```

---

## Рекомендации по UI

### Состояния для отображения

1. **pending** - "Задача поставлена в очередь..."
2. **processing** - "Генерация плана..." / "Создание тренировки..."
3. **completed** - переход к результату
4. **failed** - показать ошибку с кнопкой "Повторить"

### Таймауты

- **Интервал опроса:** 2 секунды (рекомендуется)
- **Общий таймаут:** 60 секунд (можно настроить)
- После таймаута показывать сообщение: "Таймаут. Попробуйте снова."

### Кэширование

Статусы задач кэшируются на 5 секунд (`_asyncTaskCache`) для снижения количества запросов.

---

## Миграция с синхронного API

### Что изменилось

**Было (синхронно):**
```dart
final plan = await api.createPlan(params);
// Ждали 2.5 секунды искусственно для UX
```

**Стало (асинхронно с polling):**
```dart
final taskId = await api.createPlanAsync(params);
final response = await api.pollPlanGeneration(taskId);
final plan = response.result as ActivePlan;
```

### Преимущества миграции

- Нет искусственных задержек
- Реальная скорость генерации
- Возможность отмены (прерывание polling)
- Лучший UX - пользователь видит, что происходит
- Безопасность - нет долгих HTTP соединений

---

## Обработка ошибок

### Возможные ошибки

1. **taskId == null** - ошибка запуска задачи (сеть, валидация)
2. **polling вернул null** - таймаут
3. **response.isFailed** - ошибка на стороне бэкенда
4. **response.result == null** - неожиданный формат ответа

### Рекомендации

- Всегда показывать пользователю понятное сообщение
- Предлагать "Повторить" при ошибках
- Логировать ошибки на клиенте
- При network ошибках - показывать соответствующий UI

---

## Производительность

### Оптимизации

1. **Кэширование статусов** - 5 секунд
2. **Интервал опроса** - 2 секунды (не чаще)
3. **Таймаут** - 60 секунд (достаточно для генерации)
4. **Отмена** - можно прервать polling, вернувшись на предыдущий экран

### Мониторинг

- Логируйте время генерации (от запуска до завершения)
- Считайте количество retry при ошибках
- Отслеживайте таймауты

---

## Тестирование

### Unit тесты

- Тест успешного polling (status: pending → processing → completed)
- Тест ошибки (status: failed)
- Тест таймаута
- Тест отмены polling

### Integration тесты

- Полный цикл: запуск → polling → результат
- Ошибки сети во время polling
- Невалидный task_id

---

## Безопасность

- task_id должен быть криптографически случайным (32 символа)
- Проверка принадлежности задачи пользователю на бэкенде
- task_id одноразовые (после completed/failed не переиспользуются)
- Очистка кэша при завершении задачи

---

## Известные ограничения

1. **Нет отмены задачи** - polling можно прервать на клиенте, но задача продолжит выполняться на сервере. Для отмены нужен отдельный endpoint `DELETE /async/{task_id}`.

2. **Один активный polling** - не запускать несколько polling для одного task_id одновременно.

3. **Кэш 5 секунд** - может показывать устаревший статус если опрашивать чаще.

---

## Ссылки

- [Бэкенд документация: AsyncGenerationTask](backend/docs/) (нужно добавить)
- [API Training Plans](API_PLANS_FLUTTER.md)
- [API Smart Workout](API_SMART_WORKOUT.md)
