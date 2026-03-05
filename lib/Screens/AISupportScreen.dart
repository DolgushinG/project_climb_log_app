import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../models/ChatMessage.dart';
import '../models/SuggestedAction.dart';
import '../models/SupportChatResponse.dart';
import '../services/AISupportService.dart';
import '../theme/app_theme.dart';
import '../utils/network_error_helper.dart';

class AISupportScreen extends StatefulWidget {
  final int? eventId;
  final String page;
  final String? pathname;
  final String? pageTitle;

  const AISupportScreen({
    super.key,
    this.eventId,
    required this.page,
    this.pathname,
    this.pageTitle,
  });

  @override
  State<AISupportScreen> createState() => _AISupportScreenState();
}

class _AISupportScreenState extends State<AISupportScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  final AISupportService _supportService = AISupportService();

  List<ChatMessage> _messages = [];
  Map<int, List<SuggestedAction>> _suggestedActionsByIndex = {};
  Set<int> _feedbackSentForIndex = {};
  bool _isLoading = false;
  String? _error;
  int? _lastFailedMessageIndex;
  int? _highlightMessageIndex;

  @override
  void initState() {
    super.initState();
    _supportService.trackEvent('modal_open', eventId: widget.eventId, page: widget.page);
  }

  @override
  void dispose() {
    _supportService.trackEvent('session_end', eventId: widget.eventId, page: widget.page);
    _controller.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendMessage({int? retryIndex}) async {
    final isRetry = retryIndex != null;
    final text = isRetry
        ? _messages[retryIndex].content
        : _controller.text.trim();
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
        _controller.clear();
      }
    });
    await _scrollToBottom();

    final idx = isRetry ? retryIndex : _messages.length - 1;

    _isLoading = true;
    if (mounted) setState(() {});

    final historyToSend = isRetry
        ? _messages.sublist(0, retryIndex!)
        : _messages.sublist(0, _messages.length - 1);
    try {
      final response = await _supportService.sendMessage(
        text,
        eventId: widget.eventId,
        page: widget.page,
        pathname: widget.pathname,
        pageTitle: widget.pageTitle,
        history: historyToSend,
      );

      if (!mounted) return;
      _messages = response.history;
      for (var i = _messages.length - 1; i >= 0; i--) {
        if (_messages[i].role == 'user') {
          _messages[i] = _messages[i].copyWith(status: MessageStatus.delivered);
          break;
        }
      }
      if (response.suggestedActions.isNotEmpty && _messages.isNotEmpty) {
        final lastIdx = _messages.length - 1;
        _suggestedActionsByIndex[lastIdx] = response.suggestedActions;
      }
      setState(() {
        _highlightMessageIndex = _messages.length - 1;
        _error = null;
      });
      await _scrollToBottom();
      _clearHighlightAfterDelay();
    } catch (e) {
      if (!mounted) return;
      final friendlyMsg = e.toString().startsWith('Exception: ')
          ? e.toString().substring(11)
          : networkErrorMessage(e, 'Не удалось получить ответ. Повторите попытку.');
      setState(() {
        _messages[idx] = _messages[idx].copyWith(status: MessageStatus.failed);
        _error = friendlyMsg;
        _lastFailedMessageIndex = idx;
      });
      await _scrollToBottom();
    } finally {
      if (mounted) {
        _isLoading = false;
        setState(() {});
      }
    }
  }

  void _clearHighlightAfterDelay() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _highlightMessageIndex != null) {
        setState(() => _highlightMessageIndex = null);
      }
    });
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

  void _onSuggestedActionTap(SuggestedAction action) async {
    _supportService.trackEvent('action_clicked', eventId: widget.eventId, page: widget.page);
    if (action.isLink && action.url != null) {
      try {
        final uri = Uri.parse(action.url!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Не удалось открыть ссылку', style: unbounded(fontSize: 14))),
          );
        }
      }
      return;
    }
    if (action.isCancelRegistration && action.eventId != null) {
      try {
        await _supportService.cancelRegistration(action.eventId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Регистрация отменена', style: unbounded(fontSize: 14))),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e.toString().replaceFirst('Exception: ', ''),
                style: unbounded(fontSize: 14),
              ),
            ),
          );
        }
      }
    }
  }

  void _sendFeedback(int msgIndex, String rating) async {
    if (_feedbackSentForIndex.contains(msgIndex)) return;
    final msg = _messages[msgIndex];
    if (msg.role != 'assistant') return;
    String? question;
    for (var i = msgIndex - 1; i >= 0; i--) {
      if (_messages[i].role == 'user') {
        question = _messages[i].content;
        break;
      }
    }
    question ??= '';

    _feedbackSentForIndex.add(msgIndex);
    setState(() {});

    await _supportService.sendFeedback(
      question: question,
      responsePreview: msg.content.length > 500 ? msg.content.substring(0, 500) : msg.content,
      responseFull: msg.content,
      rating: rating,
      eventId: widget.eventId,
    );
  }

  void _retryLastMessage() {
    if (_lastFailedMessageIndex != null && !_isLoading) {
      _sendMessage(retryIndex: _lastFailedMessageIndex);
    }
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
      SnackBar(content: Text('Скопировано', style: unbounded(fontSize: 14)), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.anthracite,
      appBar: AppBar(
        backgroundColor: AppColors.cardDark,
        title: Text('Поддержка', style: unbounded(fontSize: 18, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            if (_isLoading) _buildTypingIndicator(),
            Expanded(child: _buildMessageList()),
            if (_error != null) _buildErrorCard(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

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
            Icon(Icons.support_agent, size: 20, color: AppColors.mutedGold),
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
              decoration: InputDecoration(
                hintText: 'Задайте вопрос...',
                hintStyle: unbounded(color: Colors.white38, fontSize: 14),
                filled: true,
                fillColor: AppColors.rowAlt,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
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

  Widget _buildMessageList() {
    return _messages.isEmpty && _error == null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.support_agent, size: 64, color: AppColors.mutedGold.withOpacity(0.5)),
                  const SizedBox(height: 20),
                  Text(
                    'Поддержка',
                    style: unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Задайте вопрос — AI подскажет.',
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msgIndex = _messages.length - 1 - index;
              final msg = _messages[msgIndex];
              final isUser = msg.role == 'user';
              final isHighlighted = msgIndex == _highlightMessageIndex && !isUser;
              final actions = _suggestedActionsByIndex[msgIndex] ?? [];
              final feedbackSent = _feedbackSentForIndex.contains(msgIndex);

              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onLongPress: () => _copyMessage(context, msg.content),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isUser ? AppColors.mutedGold : AppColors.cardDark,
                          borderRadius: BorderRadius.circular(16),
                          border: isUser
                              ? null
                              : Border.all(
                                  color: isHighlighted ? AppColors.mutedGold.withOpacity(0.6) : AppColors.rowAlt,
                                  width: isHighlighted ? 2 : 1,
                                ),
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                          child: Column(
                            crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              isUser
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(msg.content, style: unbounded(color: Colors.black87, fontSize: 15)),
                                        ),
                                        const SizedBox(width: 6),
                                        msg.status == MessageStatus.failed
                                            ? Icon(Icons.error_outline, size: 16, color: Colors.red.shade700)
                                            : Icon(Icons.done_all, size: 16, color: Colors.black54),
                                      ],
                                    )
                                  : MarkdownBody(
                                      data: msg.content,
                                      styleSheet: MarkdownStyleSheet(
                                        p: unbounded(color: Colors.white, fontSize: 15, height: 1.5),
                                        strong: unbounded(color: Colors.white, fontWeight: FontWeight.w600),
                                        listBullet: unbounded(color: AppColors.mutedGold, fontSize: 15),
                                      ),
                                      softLineBreak: true,
                                      shrinkWrap: true,
                                    ),
                              const SizedBox(height: 4),
                              Text(
                                _formatMessageTime(msg.timestamp),
                                style: unbounded(fontSize: 11, color: isUser ? Colors.black45 : Colors.white38),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (!isUser && actions.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: actions.map((a) {
                          return OutlinedButton(
                            onPressed: () => _onSuggestedActionTap(a),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.mutedGold,
                              side: BorderSide(color: AppColors.mutedGold),
                            ),
                            child: Text(a.label, style: unbounded(fontSize: 13)),
                          );
                        }).toList(),
                      ),
                    ],
                    if (!isUser && !feedbackSent) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.thumb_up_outlined, size: 18, color: Colors.white54),
                            onPressed: () => _sendFeedback(msgIndex, 'positive'),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          IconButton(
                            icon: Icon(Icons.thumb_down_outlined, size: 18, color: Colors.white54),
                            onPressed: () => _sendFeedback(msgIndex, 'negative'),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          );
  }

  Widget _buildErrorCard() {
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
            Expanded(child: Text(_error!, style: unbounded(fontSize: 13, color: Colors.red.shade200))),
            if (_lastFailedMessageIndex != null)
              TextButton(
                onPressed: _isLoading ? null : _retryLastMessage,
                child: Text('Повторить', style: unbounded(fontSize: 12, color: AppColors.mutedGold)),
              ),
          ],
        ),
      ),
    );
  }
}
