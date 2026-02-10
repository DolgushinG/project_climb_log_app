# Бэкенд: не отдавать текст исключения в ответе API (WebAuthn delete)

**Проблема (Low Severity):** В обработчике удаления Passkey (`webauthnDeletePasskey` или аналог) в `catch` в JSON-ответ клиенту попадает `$e->getMessage()`. Текст исключения может раскрывать внутренние детали (таблицы, запросы, пути).

**Рекомендация:** В ответах API при ошибке возвращать только общее сообщение, без подстановки `$e->getMessage()` (и без `$e->getTraceAsString()` и т.п.).

**Было (плохо):**
```php
} catch (\Throwable $e) {
    return response()->json(['error' => 'WebAuthn delete failed: ' . $e->getMessage()], 500);
}
```

**Стало (хорошо):**
```php
} catch (\Throwable $e) {
    // Логировать полный $e для отладки на сервере (лог не отдавать клиенту)
    \Log::warning('WebAuthn delete failed', ['exception' => $e->getMessage(), 'trace' => $e->getTraceAsString()]);
    return response()->json(['error' => 'WebAuthn delete failed'], 500);
}
```

Или по аналогии с другими обработчиками в проекте — единое сообщение вроде `'message' => 'Не удалось удалить Passkey.'` без деталей исключения.

То же самое стоит проверить для остальных WebAuthn-эндпоинтов (register, login, options): в ответе клиенту не должно быть `$e->getMessage()`.
