import 'package:flutter/material.dart';

import '../main.dart';
import '../models/TrainerInvitation.dart';
import '../theme/app_theme.dart';
import '../services/TrainerService.dart';
import '../utils/app_snackbar.dart';
import '../utils/network_error_helper.dart';

/// Экран входящих приглашений от тренеров (для ученика).
class TrainerInvitationsScreen extends StatefulWidget {
  const TrainerInvitationsScreen({super.key});

  @override
  State<TrainerInvitationsScreen> createState() => _TrainerInvitationsScreenState();
}

class _TrainerInvitationsScreenState extends State<TrainerInvitationsScreen> {
  bool _loading = true;
  String? _error;
  List<TrainerInvitation> _invitations = [];
  final TrainerService _service = TrainerService(baseUrl: DOMAIN);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.getProfileTrainerInvitations(context);
      if (mounted) {
        setState(() {
          _invitations = list.where((i) => i.isPending).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = networkErrorMessage(e, 'Не удалось загрузить');
          _loading = false;
        });
      }
    }
  }

  Future<void> _accept(TrainerInvitation inv) async {
    final ok = await _service.acceptInvitation(context, inv.id);
    if (ok && mounted) {
      showAppSuccess(context, 'Приглашение принято');
      _load();
    }
  }

  Future<void> _reject(TrainerInvitation inv) async {
    final ok = await _service.rejectInvitation(context, inv.id);
    if (ok && mounted) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Приглашения от тренеров', style: unbounded(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white)),
        backgroundColor: AppColors.cardDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        color: AppColors.anthracite,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.mutedGold))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_error!, textAlign: TextAlign.center, style: unbounded(color: Colors.white70)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _load,
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.mutedGold, foregroundColor: AppColors.anthracite),
                            child: Text('Повторить', style: unbounded(fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  )
                : _invitations.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.mail_outline, size: 64, color: Colors.grey.shade600),
                              const SizedBox(height: 16),
                              Text(
                                'Нет приглашений',
                                style: unbounded(fontSize: 18, color: Colors.white70),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Когда тренер пригласит вас в группу, приглашение появится здесь',
                                textAlign: TextAlign.center,
                                style: unbounded(fontSize: 14, color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.mutedGold,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: _invitations.map((inv) => _buildInvitationCard(inv)).toList(),
                        ),
                      ),
      ),
    );
  }

  Widget _buildInvitationCard(TrainerInvitation inv) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppColors.cardDark,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.school, color: AppColors.mutedGold, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    inv.trainerName ?? 'Тренер',
                    style: unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Приглашает вас в свою группу учеников',
              style: unbounded(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _reject(inv),
                  child: Text('Отклонить', style: unbounded(color: Colors.white54)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _accept(inv),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.mutedGold, foregroundColor: AppColors.anthracite),
                  child: Text('Принять', style: unbounded(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
