import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../services/RustorePushService.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  PackageInfo? _packageInfo;
  String? _pushToken;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _packageInfo = info);
    });
    RustorePushService.getStoredToken().then((token) {
      if (mounted) setState(() => _pushToken = token);
    });
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось открыть ссылку', style: unbounded()),
            backgroundColor: AppColors.graphite,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.anthracite,
      appBar: AppBar(
        backgroundColor: AppColors.anthracite,
        title: Text(
          'О приложении',
          style: unbounded(fontWeight: FontWeight.w500, fontSize: 18, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: AppColors.mutedGold),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.mutedGold.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.emoji_events_rounded,
                size: 56,
                color: AppColors.mutedGold,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Climbing-events',
              textAlign: TextAlign.center,
              style: unbounded(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _packageInfo != null
                  ? 'Версия ${_packageInfo!.version}+${_packageInfo!.buildNumber}'
                  : 'Версия ...',
              textAlign: TextAlign.center,
              style: AppTypography.secondary(),
            ),
            const SizedBox(height: 24),
            Text(
              'Приложение для учёта участия в соревнованиях по скалолазанию.',
              textAlign: TextAlign.center,
              style: AppTypography.secondary().copyWith(fontSize: 14),
            ),
            const SizedBox(height: 32),
            Text(
              'Контакты',
              style: unbounded(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedGold,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 12),
            _ContactTile(
              icon: Icons.email_outlined,
              label: 'Email',
              value: 'Dolgushinzh@gmail.com',
              onTap: () => _launchUrl(context, 'mailto:Dolgushinzh@gmail.com'),
            ),
            _ContactTile(
              icon: Icons.telegram,
              label: 'Telegram',
              value: 't.me/gdolgushin',
              onTap: () => _launchUrl(context, 'https://t.me/gdolgushin'),
            ),
            _ContactTile(
              icon: Icons.language,
              label: 'Сайт',
              value: 'climbing-events.ru',
              onTap: () => _launchUrl(context, 'https://climbing-events.ru'),
            ),
            if (kDebugMode && _pushToken != null) ...[
              const SizedBox(height: 28),
              Text(
                'Тест пушей RuStore',
                style: unbounded(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedGold,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Токен для тестовой отправки в RuStore Консоль:',
                style: AppTypography.secondary(),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.graphite.withOpacity(0.5), width: 0.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        _pushToken!,
                        style: unbounded(fontSize: 11, color: Colors.white70, height: 1.4),
                        maxLines: 3,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.copy_rounded, color: AppColors.mutedGold, size: 20),
                      onPressed: () {
                        final token = _pushToken;
                        if (token != null) Clipboard.setData(ClipboardData(text: token));
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Токен скопирован', style: unbounded()),
                              backgroundColor: AppColors.cardDark,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _ContactTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.graphite.withOpacity(0.5), width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.mutedGold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.mutedGold, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: unbounded(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: AppTypography.athleteName().copyWith(fontSize: 14),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.4), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
