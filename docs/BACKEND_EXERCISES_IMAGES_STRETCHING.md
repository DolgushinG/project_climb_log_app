# Backend: Картинки упражнений + Растяжка

Спецификация новых требований к API упражнений.

---

## Сводка изменений (сегодня)

| Изменение | Фронт | Бэкенд |
|-----------|-------|--------|
| Картинки упражнений | ✅ Отображение `image_url` | Добавить поле `image_url` в GET /exercises |
| Растяжка после ОФП | ✅ Секция "Растяжка", category=stretching | Добавить category `stretching`, упражнения с `muscle_groups` |
| Связь ОФП ↔ растяжка | ✅ Фильтр по muscle_groups | Добавить `muscle_groups` в OFP и stretching |

---

## 1. Картинки упражнений

### 1.1 Поле в ответе

**`GET /api/climbing-logs/exercises`** — добавить в каждый объект упражнения:

| Поле | Тип | Описание |
|------|-----|----------|
| `image_url` | string \| null | URL картинки. Может быть относительным (`/media/exercises/repeaters.png`) или абсолютным. Приложение дополняет DOMAIN для относительных путей. |

**Пример:**
```json
{
  "id": "repeaters_7_13",
  "name": "Repeaters 7:13",
  "name_ru": "Репитеры 7:13",
  "category": "sfp",
  "level": "intermediate",
  "description": "7 сек вис / 13 сек отдых, 6 повторов.",
  "image_url": "/media/exercises/repeaters_7_13.jpg",
  "default_sets": 3,
  "default_reps": "6",
  "default_rest": "180s",
  "target_weight_optional": true
}
```

### 1.2 Рекомендации по хранению

- Размещать изображения в `/media/exercises/` или CDN
- Именование: `{exercise_id}.jpg` или `{exercise_id}.webp`
- Рекомендуемый размер: 400×400 px, webp для экономии трафика

---

## 2. Растяжка для мышц ОФП

### 2.1 Новая категория

Добавить категорию **`stretching`** (растяжка).

**`GET /api/climbing-logs/exercises?category=stretching`**

### 2.2 Связь с мышцами ОФП

Для маппинга «растяжка после ОФП» нужны поля:

**В упражнении ОФП:**
| Поле | Тип | Описание |
|------|-----|----------|
| `muscle_groups` | string[] | Группы мышц: `back`, `core`, `forearms`, `shoulders`, `chest`, `legs` |

**В упражнении растяжки:**
| Поле | Тип | Описание |
|------|-----|----------|
| `muscle_groups` | string[] | Какие мышцы растягивает |

**Пример ОФП:**
```json
{
  "id": "pull_ups",
  "name": "Pull-ups",
  "name_ru": "Подтягивания",
  "category": "ofp",
  "muscle_groups": ["back", "forearms"],
  "image_url": "/media/exercises/pull_ups.jpg",
  ...
}
```

**Пример растяжки:**
```json
{
  "id": "back_stretch",
  "name": "Back stretch",
  "name_ru": "Растяжка спины",
  "category": "stretching",
  "muscle_groups": ["back"],
  "image_url": "/media/exercises/back_stretch.jpg",
  "default_sets": 2,
  "default_reps": "30s hold",
  "default_rest": "30s",
  ...
}
```

### 2.3 Рекомендуемые упражнения растяжки

| muscle_groups | Упражнение | Описание |
|---------------|------------|----------|
| back | Растяжка спины (вис на перекладине) | Вис 30 сек, расслабление спины |
| forearms | Растяжка предплечий | Сгибание/разгибание запястья с опорой |
| shoulders | Растяжка плеч | Перекрёст рук, круговые движения |
| core | Растяжка пресса | Кобра, мостик лёжа |

---

## 3. Расширенная схема упражнения (итог)

```json
{
  "id": "string",
  "name": "string",
  "name_ru": "string | null",
  "category": "sfp | ofp | stretching",
  "level": "novice | intermediate | pro",
  "description": "string | null",
  "image_url": "string | null",
  "muscle_groups": ["back", "forearms"],
  "default_sets": 3,
  "default_reps": "6",
  "default_rest": "180s",
  "target_weight_optional": true
}
```

---

## 4. Логика во Flutter

1. **Картинки:** если `image_url` не null, показываем CachedNetworkImage. Относительный путь → `$DOMAIN$image_url`.
2. **Растяжка:** после блока ОФП запрашиваем `category=stretching`. Если у ОФП есть `muscle_groups`, фильтруем растяжку по пересечению. Иначе показываем все.
3. **Fallback:** при отсутствии картинки — иконка по категории (fitness_center, stretch и т.п.).

---

## 5. Чеклист для бэкенда

- [ ] Добавить `image_url` в GET /exercises
- [ ] Добавить категорию `stretching`
- [ ] Опционально: `muscle_groups` для маппинга ОФП ↔ растяжка
- [ ] Загрузить картинки для существующих упражнений
