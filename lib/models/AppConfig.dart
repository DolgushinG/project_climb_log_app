/// Конфиг приложения и фича-флаги с бэкенда.
/// GET /api/app/config — вызывается при входе, кэшируется.
class AppConfig {
  /// AI Тренер доступен (иначе вкладка скрыта).
  final bool aiCoachEnabled;

  const AppConfig({
    this.aiCoachEnabled = true,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    final features = (json['features'] ?? data?['features']) as Map<String, dynamic>?;
    final root = data ?? json;
    final aiCoach = features?['ai_coach_enabled'] ??
        features?['aiCoachEnabled'] ??
        root['ai_coach_enabled'] ??
        root['aiCoachEnabled'];
    return AppConfig(
      aiCoachEnabled: _toBool(aiCoach),
    );
  }

  static bool _toBool(dynamic v) {
    if (v == true) return true;
    if (v == false) return false;
    if (v == 'true' || v == '1') return true;
    if (v == 'false' || v == '0') return false;
    return true; // по умолчанию включено
  }

  /// Дефолт при отсутствии конфига или ошибке — скрываем AI Тренер.
  static const AppConfig fallback = AppConfig(aiCoachEnabled: false);
}
