# Flutter Web — типичные предупреждения и ошибки при разработке

## 1. `flutter.js.map` — SyntaxError: JSON Parse error: Unrecognized token '<'

**Что происходит:**  
В `flutter.js` есть ссылка `//# sourceMappingURL=flutter.js.map`. Браузер запрашивает этот файл, получает 404 (HTML-страницу), пытается распарсить как JSON и выдаёт ошибку.

**Причина:**  
Flutter в dev-режиме (`flutter run -d chrome`) не генерирует `flutter.js.map`. В **production** это решается скриптом `scripts/web_strip_sourcemaps.sh`, который выполняется перед деплоем.

**В dev-режиме:** предупреждение безопасно, на работу приложения не влияет.

**Как уменьшить шум в консоли (по желанию):**
- В Chrome DevTools → Settings → Sources: снять галочку «Enable JavaScript source maps»
- Или просто игнорировать предупреждение при разработке

---

## 2. Error: Bad state: Not connected to an application

**Что происходит:**  
Ошибка DWDS (Dart Web Dev Server), когда DevTools теряет связь с приложением.

**Типичные причины:**
- Полный перезапуск приложения (Hot Restart)
- Обновление страницы в браузере (F5)
- Открытие приложения во второй вкладке
- Краш приложения

**Что делать:**
1. В терминале: нажать `R` (Hot Restart) или Ctrl+C и снова `flutter run -d chrome`
2. Закрыть лишние вкладки с приложением
3. Использовать Hot Reload (`r`) вместо полного перезапуска, когда возможно

Ошибка связана с состоянием dev-сервера, а не с кодом приложения.
