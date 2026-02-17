import 'dart:html' as html;

/// Текущий URL страницы (только для web).
Uri? get currentPageUri => Uri.parse(html.window.location.href);

/// Убирает токен из URL (только для web).
void clearTokenFromUrl() {
  try {
    final uri = Uri.parse(html.window.location.href);
    final cleaned = uri.removeFragment().replace(
      queryParameters: Map.from(uri.queryParameters)
        ..removeWhere((k, _) => ['token', 'api_token', 'access_token'].contains(k)),
    );
    html.window.history.replaceState(null, '', cleaned.toString());
  } catch (_) {}
}
