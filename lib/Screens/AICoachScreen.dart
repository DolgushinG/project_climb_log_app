import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../models/ChatMessage.dart';
import '../services/AICoachService.dart';
import '../theme/app_theme.dart';
import '../utils/app_constants.dart';
import '../utils/network_error_helper.dart';

class AICoachScreen extends StatefulWidget {
  /// ID чата (из списка). null — новый чат.
  final int? conversationId;
  /// Заголовок для appBar (при открытии существующего чата).
  final String? title;
  /// Контекст упражнения — при открытии с экрана выполнения (спросить про конкретное упражнение).
  final String? exerciseName;
  final String? exerciseDescription;
  /// ID упражнения — для передачи в context и сохранения AI-комментария на бэкенде.
  final String? exerciseId;
  /// Сообщение, которое сразу добавляется в чат и отправляется (например, при тапе на упражнение).
  final String? initialMessage;
  const AICoachScreen({
    super.key,
    this.conversationId,
    this.title,
    this.exerciseName,
    this.exerciseDescription,
    this.exerciseId,
    this.initialMessage,
  });

  @override
  State<AICoachScreen> createState() => _AICoachScreenState();
}

class _AICoachScreenState extends State<AICoachScreen> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver, RouteAware {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  final AICoachService _coachService = AICoachService();

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _loadingHistory = true;
  String? _error;
  /// Текущий ID чата (может обновиться после первого ответа в новом чате).
  int? _conversationId;
  /// Индекс сообщения для retry (не добавляем дубликат).
  int? _lastFailedMessageIndex;
  /// Индекс последнего полученного ответа — подсветка. null = не подсвечивать.
  int? _highlightMessageIndex;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    WidgetsBinding.instance.addObserver(this);
    _loadHistory();
    _inputFocusNode.addListener(_onInputFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.unsubscribe(this);
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    _loadHistory(); // Перезагрузка при возврате на экран
  }

  void _onInputFocusChanged() {
    if (_inputFocusNode.hasFocus && _messages.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 400), _scrollToBottom);
    }
    // Не делаем setState при потере фокуса — при тапе по галочке над клавиатурой
    // это вызывало глюк; viewInsets обновятся сами через didChangeMetrics
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _inputFocusNode.removeListener(_onInputFocusChanged);
    WidgetsBinding.instance.removeObserver(this);
    _inputFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (ModalRoute.of(context)?.isCurrent == true) {
        _loadHistory(); // Обновить при возврате из фона (ответ мог прийти пока приложение было свёрнуто)
      } else if (_messages.isNotEmpty) {
        _scrollToBottom();
      }
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loadingHistory = true;
      _error = null;
    });
    try {
      if (_conversationId != null) {
        final result = await _coachService.getConversationMessages(_conversationId!);
        if (mounted) {
          setState(() {
            _messages = result.messages;
            _loadingHistory = false;
          });
          if (result.messages.isNotEmpty) _scrollToBottom();
        }
      } else {
        // Новый чат — пустое состояние (не грузим старую локальную историю)
        if (mounted) {
          setState(() {
            _messages = [];
            _loadingHistory = false;
          });
          // Если передан initialMessage — сразу добавляем в чат и отправляем
          final msg = widget.initialMessage?.trim();
          if (msg != null && msg.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _messages.isEmpty && !_isLoading) {
                _sendMessage(initialText: msg);
              }
            });
          }
        }
      }
      if (mounted) await _resumePendingPollingIfNeeded();
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages = [];
          _loadingHistory = false;
          _error = networkErrorMessage(e, 'Не удалось загрузить историю чата.');
        });
      }
    }
  }

  /// Отправка сообщения. Сначала async (polling), при 404 — fallback на sync.
  /// Сообщение сразу с галочкой, вверху «печатает» пока ждём ответ.
  /// [initialText] — при открытии с упражнением: сообщение добавляется в чат и отправляется.
  Future<void> _sendMessage({int? retryIndex, String? initialText}) async {
    final isRetry = retryIndex != null;
    final text = isRetry
        ? _messages[retryIndex].content
        : (initialText ?? _controller.text.trim());
    if (text.isEmpty) return;

    FocusScope.of(context).unfocus();

    if (!mounted) return;
    setState(() {
      _error = null;
      _lastFailedMessageIndex = null;
      if (isRetry) {
        _messages[retryIndex] = _messages[retryIndex].copyWith(status: MessageStatus.sent);
      } else {
        _messages.add(ChatMessage(role: 'user', content: text, status: MessageStatus.sent));
        if (initialText == null) _controller.clear();
      }
    });
    await _scrollToBottom();

    final idx = isRetry ? retryIndex : _messages.length - 1;

    // Сохраняем user-сообщение в локальную историю только при новом чате (без conversation_id)
    if (!isRetry && _conversationId == null) {
      await _coachService.addUserMessageToHistory(text);
    }

    // Пробуем async (без таймаута)
    final apiContext = widget.exerciseId != null ? {'exercise_id': widget.exerciseId} : null;
    String? taskId;
    try {
      taskId = await _coachService.sendMessageAsync(text, explicitConversationId: _conversationId, context: apiContext);
    } catch (e) {
      _handleSendError(e, idx);
      return;
    }

    if (taskId != null) {
      await _coachService.setPendingTaskId(taskId); // для возобновления при возврате в чат
      _isLoading = true;
      if (mounted) setState(() {});
      try {
        final reply = await _coachService.pollChatStatus(
          taskId,
          interval: const Duration(seconds: 2),
          timeout: const Duration(seconds: 180),
        );
        await _coachService.setPendingTaskId(null); // ответ получен или таймаут
        if (reply != null) {
          if (_conversationId == null) await _coachService.addReplyToHistory(reply.message);
          setState(() {
            if (reply.conversationId != null) _conversationId = reply.conversationId;
          });
        }
        if (!mounted) return;
        if (reply != null) {
          setState(() {
            _messages[idx] = _messages[idx].copyWith(status: MessageStatus.delivered);
            _messages.add(reply!.message);
            _error = null;
            _highlightMessageIndex = _messages.length - 1;
          });
          await _scrollToBottom();
          _clearHighlightAfterDelay();
        } else {
          setState(() {
            _messages[idx] = _messages[idx].copyWith(status: MessageStatus.failed);
            _error = 'Превышено время ожидания. Попробуйте ещё раз.';
            _lastFailedMessageIndex = idx;
          });
        }
      } catch (e) {
        await _coachService.setPendingTaskId(null);
        _handleSendError(e, idx);
      } finally {
        if (mounted) {
          _isLoading = false;
          setState(() {});
        }
      }
      return;
    }

    // Fallback: sync (может таймаутить при долгом ответе)
    _isLoading = true;
    if (mounted) setState(() {});
    try {
      final apiContext = widget.exerciseId != null ? {'exercise_id': widget.exerciseId} : null;
      final result = await _coachService.sendMessage(text, explicitConversationId: _conversationId, context: apiContext);
      if (!mounted) return;
      setState(() {
        if (result.conversationId != null) _conversationId = result.conversationId;
        _messages[idx] = _messages[idx].copyWith(status: MessageStatus.delivered);
        _messages.add(result.message);
        _error = null;
        _highlightMessageIndex = _messages.length - 1;
      });
      await _scrollToBottom();
      _clearHighlightAfterDelay();
    } catch (e) {
      _handleSendError(e, idx);
    } finally {
      if (mounted) {
        _isLoading = false;
        setState(() {});
      }
    }
  }

  void _handleSendError(Object e, int msgIndex) {
    if (!mounted) return;
    final friendlyMsg = _exceptionToUserMessage(e);
    setState(() {
      _messages[msgIndex] = _messages[msgIndex].copyWith(status: MessageStatus.failed);
      _error = friendlyMsg;
      _lastFailedMessageIndex = msgIndex;
    });
    _scrollToBottom();
  }

  String _exceptionToUserMessage(Object e) {
    final str = e.toString();
    if (str.startsWith('Exception: ')) {
      return str.substring(11);
    }
    return networkErrorMessage(e, 'Не удалось получить ответ. Повторите попытку.');
  }

  /// Возобновить polling, если вернулись в чат до ответа (есть pending task_id).
  Future<void> _resumePendingPollingIfNeeded() async {
    if (_messages.isEmpty || _messages.last.role != 'user') return;
    final taskId = await _coachService.getPendingTaskId();
    if (taskId == null) return;
    final idx = _messages.length - 1;
    _isLoading = true;
    if (!mounted) return;
    setState(() {});
    try {
      final reply = await _coachService.pollChatStatus(
        taskId,
        interval: const Duration(seconds: 2),
        timeout: const Duration(seconds: 180),
      );
      await _coachService.setPendingTaskId(null);
      if (reply != null) {
        if (_conversationId == null) await _coachService.addReplyToHistory(reply.message);
        setState(() {
          if (reply.conversationId != null) _conversationId = reply.conversationId;
        });
      }
      if (!mounted) return;
      if (reply != null) {
        setState(() {
          _messages[idx] = _messages[idx].copyWith(status: MessageStatus.delivered);
          _messages.add(reply!.message);
          _error = null;
          _highlightMessageIndex = _messages.length - 1;
        });
        _scrollToBottom();
        _clearHighlightAfterDelay();
      } else {
        setState(() {
          _messages[idx] = _messages[idx].copyWith(status: MessageStatus.failed);
          _error = 'Превышено время ожидания. Попробуйте ещё раз.';
          _lastFailedMessageIndex = idx;
        });
      }
    } catch (e) {
      await _coachService.setPendingTaskId(null);
      _handleSendError(e, idx);
    } finally {
      if (mounted) {
        _isLoading = false;
        setState(() {});
      }
    }
  }

  String _appBarTitle() {
    if (widget.title != null && widget.title!.isNotEmpty) {
      return widget.title!.length > 30 ? '${widget.title!.substring(0, 30)}…' : widget.title!;
    }
    return 'AI Тренер';
  }

  void _retryLastMessage() {
    if (_lastFailedMessageIndex != null && !_isLoading) {
      _sendMessage(retryIndex: _lastFailedMessageIndex);
    }
  }

  Future<void> _scrollToBottom() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted && _scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _clearHighlightAfterDelay() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _highlightMessageIndex != null) {
        setState(() => _highlightMessageIndex = null);
      }
    });
  }

  /// Удалить чат, очистить кэш и вернуться к списку.
  Future<void> _deleteChatAndGoBack() async {
    final id = _conversationId;
    if (id != null) {
      try {
        await _coachService.deleteConversation(id);
      } catch (e) {
        if (mounted) {
          setState(() => _error = _exceptionToUserMessage(e));
        }
        return;
      }
    }
    await _coachService.clearHistory();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _showRulesDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.rule, color: AppColors.mutedGold, size: 24),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Правила использования AI-тренера',
                        style: unbounded(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              Text(
                '• Используйте чат по назначению: тренировки, скалолазание, питание, восстановление.',
                style: unbounded(fontSize: 14, color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 8),
              Text(
                '• Не отправляйте оскорбительный, незаконный контент или спам.',
                style: unbounded(fontSize: 14, color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 8),
              Text(
                '• Не пытайтесь обойти ограничения или извлекать технические данные.',
                style: unbounded(fontSize: 14, color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 8),
              Text(
                '• Соблюдайте разумный объём запросов — не перегружайте сервис.',
                style: unbounded(fontSize: 14, color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 12),
              Text(
                'За нарушения доступ может быть заблокирован.',
                style: unbounded(fontSize: 13, color: Colors.white54, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final uri = Uri.parse(AppConstants.aiChatRulesUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: Icon(Icons.open_in_new, size: 16, color: AppColors.mutedGold),
                  label: Text('Подробнее на сайте', style: unbounded(color: AppColors.mutedGold)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  void _onDeletePressed() {
    if (_messages.isEmpty && _conversationId == null) {
      // Пустой новый чат — просто возврат
      Navigator.of(context).pop();
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Удалить чат?', style: unbounded(fontSize: 18)),
        content: Text(
          'Чат будет удалён. Это действие нельзя отменить.',
          style: unbounded(fontSize: 14, color: Colors.white70),
        ),
        backgroundColor: AppColors.cardDark,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Отмена', style: unbounded(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteChatAndGoBack();
            },
            child: Text('Удалить', style: unbounded(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // для AutomaticKeepAlive
    final theme = Theme.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.anthracite,
      appBar: AppBar(
        backgroundColor: AppColors.cardDark,
        title: Text(
          _appBarTitle(),
          style: unbounded(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.rule, color: AppColors.mutedGold),
            tooltip: 'Правила использования',
            onPressed: () => _showRulesDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.mutedGold),
            tooltip: 'Удалить чат',
            onPressed: () => _onDeletePressed(),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Column(
            children: [
              if (_isLoading) _buildTypingIndicator(),
              Expanded(
                child: _buildMessageList(
                  context,
                  horizontalPadding: 12,
                  topPadding: 12,
                ),
              ),
              if (_error != null) _buildErrorCard(theme),
              _buildInputBar(),
            ],
          ),
      ),
    );
  }

  /// «Печатает» — по центру, с иконкой, пока бэк думает и идёт polling.
  Widget _buildTypingIndicator() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cardDark.withOpacity(0.8),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_note, size: 20, color: AppColors.mutedGold),
            const SizedBox(width: 10),
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.mutedGold),
            ),
            const SizedBox(width: 10),
            Text('Думаю...', style: unbounded(fontSize: 13, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AppColors.anthracite),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              focusNode: _inputFocusNode,
              controller: _controller,
              keyboardType: TextInputType.text,
              enableSuggestions: true,
              autocorrect: true,
              scrollPadding: EdgeInsets.zero,
              decoration: InputDecoration(
                hintText: widget.exerciseName != null
                    ? 'Спросите про «${widget.exerciseName}» — технику, дозировку...'
                    : 'Спросите о тренировках, планах, силе...',
                hintStyle: unbounded(color: Colors.white38, fontSize: 14),
                filled: true,
                fillColor: AppColors.rowAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: unbounded(color: Colors.white),
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.send,
              enabled: !_isLoading,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            mini: true,
            backgroundColor: AppColors.mutedGold,
            foregroundColor: AppColors.anthracite,
            onPressed: _isLoading ? null : () => _sendMessage(),
            child: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(
    BuildContext context, {
    required double horizontalPadding,
    required double topPadding,
  }) {
    if (_loadingHistory) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.mutedGold),
      );
    }
    return _messages.isEmpty && _error == null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fitness_center, size: 64, color: AppColors.mutedGold.withOpacity(0.5)),
                  const SizedBox(height: 20),
                  Text(
                    'Начните диалог с AI-тренером',
                    style: unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Спрашивай про скалолазание, фингер, прогресс на маршрутах.',
                    style: unbounded(fontSize: 14, color: Colors.white70, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        : ListView.builder(
            controller: _scrollController,
            reverse: true,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(
              left: horizontalPadding,
              right: horizontalPadding,
              top: topPadding,
              bottom: horizontalPadding,
            ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msgIndex = _messages.length - 1 - index;
                      final msg = _messages[msgIndex];
                      final isUser = msg.role == 'user';
                      final isHighlighted = msgIndex == _highlightMessageIndex && !isUser;
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: GestureDetector(
                          onLongPress: () => _copyMessage(context, msg.content),
                          child: AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isUser ? AppColors.mutedGold : AppColors.cardDark,
                            borderRadius: BorderRadius.circular(16),
                            border: isUser ? null : Border.all(
                              color: isHighlighted ? AppColors.mutedGold.withOpacity(0.6) : AppColors.rowAlt,
                              width: isHighlighted ? 2 : 1,
                            ),
                            boxShadow: isHighlighted
                                ? [BoxShadow(color: AppColors.mutedGold.withOpacity(0.25), blurRadius: 12, spreadRadius: 0)]
                                : null,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.78,
                            ),
                            child: Column(
                              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                isUser
                                    ? _buildUserMessageContent(msg, msgIndex)
                                    : MarkdownBody(
                                        data: msg.content,
                                        styleSheet: MarkdownStyleSheet(
                                          p: unbounded(color: Colors.white, fontSize: 15, height: 1.5),
                                          strong: unbounded(color: Colors.white, fontWeight: FontWeight.w600),
                                          em: unbounded(color: Colors.white70, fontStyle: FontStyle.italic),
                                          listBullet: unbounded(color: AppColors.mutedGold, fontSize: 15),
                                          blockquote: unbounded(color: Colors.white70, fontSize: 14),
                                          h3: unbounded(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                                        ),
                                        softLineBreak: true,
                                        shrinkWrap: true,
                                      ),
                                const SizedBox(height: 4),
                                Text(
                                  isUser
                                      ? 'Отправлено: ${_formatMessageTime(msg.timestamp)}'
                                      : 'Ответ: ${_formatMessageTime(msg.timestamp)}',
                                  style: unbounded(
                                    fontSize: 11,
                                    color: isUser ? Colors.black45 : Colors.white38,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        ),
                      );
                    },
                  );
  }

  String _formatMessageTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(dt.year, dt.month, dt.day);
    if (msgDate == today) {
      return DateFormat('HH:mm', 'ru').format(dt);
    }
    if (msgDate == today.subtract(const Duration(days: 1))) {
      return 'вчера ${DateFormat('HH:mm', 'ru').format(dt)}';
    }
    if (now.year == dt.year) {
      return DateFormat('d MMM, HH:mm', 'ru').format(dt);
    }
    return DateFormat('d MMM yyyy, HH:mm', 'ru').format(dt);
  }

  void _copyMessage(BuildContext context, String text) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Скопировано', style: unbounded(fontSize: 14)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildUserMessageContent(ChatMessage msg, int msgIndex) {
    final status = msg.status;
    final canRetry = status == MessageStatus.failed && !_isLoading;
    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Text(
            msg.content,
            style: unbounded(color: Colors.black87, fontSize: 15),
          ),
        ),
        const SizedBox(width: 6),
        _buildStatusIcon(status),
      ],
    );
    if (canRetry) {
      content = GestureDetector(
        onTap: () => _sendMessage(retryIndex: msgIndex),
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }
    return content;
  }

  Widget _buildStatusIcon(MessageStatus? status) {
    // На золотом bubble — тёмные иконки, иначе не видно
    const iconColor = Colors.black54;
    switch (status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: iconColor,
          ),
        );
      case MessageStatus.sent:
        return Icon(Icons.done, size: 16, color: iconColor);
      case MessageStatus.delivered:
        return Icon(Icons.done_all, size: 16, color: iconColor);
      case MessageStatus.failed:
        return Icon(Icons.error_outline, size: 16, color: Colors.red.shade700);
      case null:
        return Icon(Icons.done_all, size: 16, color: iconColor);
    }
  }

  Widget _buildErrorCard(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _error!,
                style: unbounded(fontSize: 13, color: Colors.red.shade200),
              ),
            ),
            if (_lastFailedMessageIndex != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: _isLoading ? null : _retryLastMessage,
                child: Text('Повторить', style: unbounded(fontSize: 12, color: AppColors.mutedGold)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
