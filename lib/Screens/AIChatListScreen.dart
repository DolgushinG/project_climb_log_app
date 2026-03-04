import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/AIConversation.dart';
import '../services/AICoachService.dart';
import 'AICoachScreen.dart';
import '../theme/app_theme.dart';

/// Список чатов с AI-тренером (про силу, ловкость и т.п.) + кнопка «Новый чат».
class AIChatListScreen extends StatefulWidget {
  const AIChatListScreen({super.key});

  @override
  State<AIChatListScreen> createState() => _AIChatListScreenState();
}

class _AIChatListScreenState extends State<AIChatListScreen> {
  final AICoachService _service = AICoachService();
  List<AIConversation> _conversations = [];
  bool _loading = true;
  String? _error;
  bool? _memoryConsent; // null = не спрашивали, true = с памятью, false = без

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initConsentAndLoad());
  }

  Future<void> _initConsentAndLoad() async {
    var consent = await _service.getMemoryConsent();
    if (consent == null) {
      // Синхронизируем с бэкенда (например, при смене устройства)
      final fromServer = await _service.syncMemoryConsentFromProfile();
      if (fromServer != null) consent = fromServer;
    }
    if (!mounted) return;
    if (consent == null) {
      // Память вкл по умолчанию — информируем, изменить можно в настройках
      await _service.setMemoryConsent(true);
      consent = true;
    }
    setState(() => _memoryConsent = consent);
    await _load();
  }

  Future<void> _showConsentDialog() async {
    final granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.security, color: AppColors.mutedGold, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Конфиденциальность',
                style: unbounded(fontSize: 18, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Переписка и факты хранятся в зашифрованном виде. Никто не имеет к ним доступа.',
                style: unbounded(fontSize: 14, color: Colors.white.withOpacity(0.87), height: 1.4),
              ),
              const SizedBox(height: 12),
              Text(
                'Согласны на обработку этих данных для персонализации ответов? Иначе AI будет работать без памяти — как белый лист.',
                style: unbounded(fontSize: 14, color: Colors.white70, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Без памяти', style: unbounded(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.mutedGold, foregroundColor: Colors.black87),
            child: Text('Согласен', style: unbounded(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    await _service.setMemoryConsent(granted ?? false);
    setState(() => _memoryConsent = granted ?? false);
    await _load();
  }

  void _showConsentDialogAgain() async {
    await _showConsentDialog();
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_memoryConsent == false) {
        if (mounted) setState(() {
          _conversations = [];
          _loading = false;
        });
        return;
      }
      final list = await _service.getConversations();
      if (mounted) {
        setState(() {
          _conversations = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  void _openNewChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AICoachScreen(conversationId: null, title: null),
      ),
    ).then((_) => _load());
  }

  void _openChat(AIConversation conv) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AICoachScreen(conversationId: conv.id, title: conv.title),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.anthracite,
      appBar: AppBar(
        backgroundColor: AppColors.cardDark,
        title: Text('AI Тренер', style: unbounded(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          _buildNewChatButton(),
          _buildHint(),
          Expanded(
            child: _loading
                ? _buildLoading()
                : _error != null
                    ? _buildError()
                    : _conversations.isEmpty
                        ? _buildEmpty()
                        : _buildList(),
          ),
          _buildPrivacySettingsButton(),
        ],
      ),
    );
  }

  Widget _buildNewChatButton() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openNewChat,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.mutedGold.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.add_circle_outline, color: AppColors.mutedGold, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Новый чат',
                  style: unbounded(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.mutedGold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHint() {
    // null = ещё не инициализировано, считаем как «память вкл»
    final withMemory = _memoryConsent != false;
    final hintText = withMemory
        ? 'Память включена: AI запоминает уровень, цели, травмы. Изменить можно в настройках конфиденциальности.'
        : 'Режим без памяти: каждый диалог как чистый лист. Включить можно в настройках конфиденциальности.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.cardDark.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.graphite.withOpacity(0.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.psychology_outlined, size: 20, color: AppColors.mutedGold.withOpacity(0.8)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hintText,
                    style: unbounded(fontSize: 12, color: Colors.white70, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySettingsButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showConsentDialogAgain,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.cardDark.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.graphite),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.security_outlined, size: 22, color: AppColors.mutedGold),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'Настройки конфиденциальности',
                        style: unbounded(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.mutedGold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.mutedGold),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: unbounded(fontSize: 14, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _load,
              child: Text('Повторить', style: unbounded(color: AppColors.mutedGold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.mutedGold.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'Нет чатов',
              style: unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Нажмите «Новый чат» выше, чтобы начать диалог',
              style: unbounded(fontSize: 14, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.mutedGold,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _conversations.length,
        itemBuilder: (context, index) {
          final conv = _conversations[index];
          return _buildConversationTile(conv);
        },
      ),
    );
  }

  Widget _buildConversationTile(AIConversation conv) {
    final title = conv.title.isEmpty ? 'Чат #${conv.id}' : conv.title;
    final subtitle = _formatDate(conv.updatedAt);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openChat(conv),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.cardDark.withOpacity(0.6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.graphite),
          ),
          child: Row(
            children: [
              Icon(Icons.chat_bubble_outline, size: 22, color: AppColors.mutedGold.withOpacity(0.9)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: unbounded(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: unbounded(fontSize: 12, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: AppColors.mutedGold),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(dt.year, dt.month, dt.day);
    if (msgDate == today) {
      return 'Сегодня ${DateFormat('HH:mm', 'ru').format(dt)}';
    }
    if (msgDate == today.subtract(const Duration(days: 1))) {
      return 'Вчера ${DateFormat('HH:mm', 'ru').format(dt)}';
    }
    if (now.year == dt.year) {
      return DateFormat('d MMM', 'ru').format(dt);
    }
    return DateFormat('d MMM yyyy', 'ru').format(dt);
  }
}
