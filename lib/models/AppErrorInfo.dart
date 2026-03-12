/// Контекст ошибки для отчёта: сообщение, стек, доп. данные.
class AppErrorInfo {
  final String message;
  final String? stackTrace;
  final Map<String, dynamic>? extra;

  AppErrorInfo(this.message, {this.stackTrace, this.extra});

  /// Создаёт из исключения. stackTrace передаётся из catch (e, stackTrace).
  factory AppErrorInfo.fromException(Object e, String userMessage, [StackTrace? stackTrace]) {
    return AppErrorInfo(
      userMessage,
      stackTrace: stackTrace?.toString(),
      extra: {
        'exception': e.toString(),
        'type': e.runtimeType.toString(),
      },
    );
  }
}
