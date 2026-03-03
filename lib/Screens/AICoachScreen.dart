import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/ChatMessage.dart';
import '../services/AICoachService.dart';
import '../theme/app_theme.dart';
import '../utils/network_error_helper.dart';

class AICoachScreen extends StatefulWidget {
  const AICoachScreen({super.key});

  @override
  State<AICoachScreen> createState() => _AICoachScreenState();
}

class _AICoachScreenState extends State<AICoachScreen> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  final AICoachService _coachService = AICoachService();

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _error;
  String? _lastFailedMessage; // для retry
  /// Индекс последнего полученного ответа — подсветка. null = не подсвечивать.
  int? _highlightMessageIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadHistory();
    _inputFocusNode.addListener(_onInputFocusChanged);
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
    _inputFocusNode.removeListener(_onInputFocusChanged);
    WidgetsBinding.instance.removeObserver(this);
    _inputFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _messages.isNotEmpty) {
      _scrollToBottom();
    }
  }

  Future<void> _loadHistory() async {
    try {
      final history = await _coachService.getHistory();
      if (mounted) {
        setState(() {
          _messages = history;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages = [];
          _error = networkErrorMessage(e, 'Не удалось загрузить историю чата.');
        });
      }
    }
  }

  /// Отправка сообщения. Ответ сохраняется в SharedPreferences в сервисе — при свёрнутом
  /// приложении или закрытом экране чата пользователь получит ответ при следующем открытии.
  Future<void> _sendMessage([String? prefilled]) async {
    final text = (prefilled ?? _controller.text).trim();
    if (text.isEmpty) return;

    // Сбрасываем фокус при отправке — предотвращает iOS-баг с «взлётом» поля ввода
    // при повторном открытии клавиатуры (связано с flutter/flutter#140501).
    FocusScope.of(context).unfocus();

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _lastFailedMessage = null;
    });

    final userMessage = ChatMessage(role: 'user', content: text);
    if (!mounted) return;
    setState(() => _messages.add(userMessage));
    if (prefilled == null) {
      _controller.clear();
    }
    await _scrollToBottom();

    try {
      final reply = await _coachService.sendMessage(text);
      if (!mounted) return;
      setState(() {
        _messages.add(reply);
        _error = null;
        _highlightMessageIndex = _messages.length - 1;
      });
      await _scrollToBottom();
      _clearHighlightAfterDelay();
    } catch (e) {
      final friendlyMsg = _exceptionToUserMessage(e);
      if (!mounted) return;
      setState(() {
        _error = friendlyMsg;
        _lastFailedMessage = text;
      });
      await _scrollToBottom();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _exceptionToUserMessage(Object e) {
    final str = e.toString();
    if (str.startsWith('Exception: ')) {
      return str.substring(11);
    }
    return networkErrorMessage(e, 'Не удалось получить ответ. Повторите попытку.');
  }

  void _retryLastMessage() {
    if (_lastFailedMessage != null) {
      _sendMessage(_lastFailedMessage);
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

  Future<void> _clearHistory() async {
    try {
      await _coachService.clearHistory();
      if (mounted) {
        setState(() {
          _messages.clear();
          _error = null;
          _lastFailedMessage = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Не удалось очистить историю.');
      }
    }
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
        title: Text('AI Тренер', style: unbounded(fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.mutedGold),
            tooltip: 'Очистить историю',
            onPressed: _messages.isEmpty ? null : () => _clearHistory(),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Column(
            children: [
              Expanded(
                child: _buildMessageList(
                  context,
                  horizontalPadding: 12,
                  topPadding: 12,
                ),
              ),
            if (_error != null) _buildErrorCard(theme),
            if (_isLoading) _buildLoadingIndicator(),
            _buildInputBar(),
            ],
          ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.mutedGold),
          ),
          const SizedBox(width: 10),
          Text('Думаю...', style: unbounded(fontSize: 13, color: Colors.white54)),
        ],
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
                hintText: 'Спросите о тренировках, планах, силе...',
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
    return _messages.isEmpty && _error == null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.psychology_outlined, size: 64, color: AppColors.mutedGold.withOpacity(0.5)),
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
                            child: isUser
                                ? Text(
                                    msg.content,
                                    style: unbounded(color: Colors.black87, fontSize: 15),
                                  )
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
                          ),
                        ),
                      );
                    },
                  );
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
            if (_lastFailedMessage != null) ...[
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
