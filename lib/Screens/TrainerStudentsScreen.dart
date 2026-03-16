import 'package:flutter/material.dart';

import '../main.dart';
import '../models/TrainerStudent.dart';
import '../models/TrainerInvitation.dart';
import '../theme/app_theme.dart';
import '../services/TrainerService.dart';
import '../utils/app_snackbar.dart';
import '../utils/network_error_helper.dart';
import 'TrainerStudentDetailScreen.dart';
import 'TrainerCreateExerciseScreen.dart';

class TrainerStudentsScreen extends StatefulWidget {
  const TrainerStudentsScreen({super.key});

  @override
  State<TrainerStudentsScreen> createState() => _TrainerStudentsScreenState();
}

class _TrainerStudentsScreenState extends State<TrainerStudentsScreen> {
  bool _isLoading = true;
  String? _error;
  List<TrainerStudent> _students = [];
  List<TrainerInvitation> _invitations = [];
  final TrainerService _service = TrainerService(baseUrl: DOMAIN);
  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.getStudents(context),
        _service.getInvitations(context),
      ]);
      if (mounted) {
        setState(() {
          _students = results[0] as List<TrainerStudent>;
          _invitations = results[1] as List<TrainerInvitation>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = networkErrorMessage(e, 'Не удалось загрузить список');
          _isLoading = false;
        });
      }
    }
  }

  void _showAddStudentDialog() {
    _emailController.clear();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddStudentSheet(
        emailController: _emailController,
        onSubmit: (email) async {
          final ok = await _service.addStudent(context, email: email);
          if (mounted && ok) {
            _loadData();
            showAppSuccess(context, 'Приглашение отправлено. Ученик появится в списке после принятия.');
          }
          return ok;
        },
      ),
    );
  }

  void _showRevokeConfirm(TrainerInvitation inv) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: Text('Отозвать приглашение', style: unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
        content: Text(
          'Отменить приглашение для ${inv.email ?? '—'}? Слот освободится, вы сможете пригласить другого.',
          style: unbounded(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Отмена', style: unbounded(color: AppColors.mutedGold)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await _service.revokeInvitation(context, inv.id);
              if (ok && mounted) {
                _loadData();
                showAppSuccess(context, 'Приглашение отозвано');
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: Text('Отозвать', style: unbounded(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  void _showRemoveConfirm(TrainerStudent student) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: Text('Удалить из группы', style: unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
        content: Text(
          'Удалить ${student.displayName} из списка учеников? Данные пользователя в системе не будут затронуты.',
          style: unbounded(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Отмена', style: unbounded(color: AppColors.mutedGold)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await _service.removeStudent(context, student.id);
              if (ok && mounted) {
                _loadData();
                showAppSuccess(context, 'Ученик удалён из группы');
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Удалить', style: unbounded(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Мои ученики', style: unbounded(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white)),
        backgroundColor: AppColors.cardDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: AppColors.mutedGold),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TrainerCreateExerciseScreen()),
              );
            },
            tooltip: 'Создать упражнение',
          ),
          IconButton(
            icon: Icon(Icons.person_add, color: AppColors.mutedGold),
            onPressed: _showAddStudentDialog,
            tooltip: 'Пригласить ученика',
          ),
        ],
      ),
      body: Container(
        color: AppColors.anthracite,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.mutedGold));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: unbounded(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mutedGold,
                  foregroundColor: AppColors.anthracite,
                ),
                child: Text('Повторить', style: unbounded(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      );
    }
    if (_students.isEmpty && _invitations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school_outlined, size: 64, color: Colors.grey.shade600),
              const SizedBox(height: 16),
              Text(
                'Пока нет учеников',
                textAlign: TextAlign.center,
                style: unbounded(fontSize: 18, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                'Нажмите + чтобы пригласить ученика по email. Он появится после принятия.',
                textAlign: TextAlign.center,
                style: unbounded(fontSize: 14, color: Colors.white54),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _showAddStudentDialog,
                icon: const Icon(Icons.person_add),
                label: Text('Пригласить ученика', style: unbounded(fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.mutedGold,
                  foregroundColor: AppColors.anthracite,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final items = <Widget>[];
    if (_invitations.isNotEmpty) {
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(Icons.schedule, size: 16, color: AppColors.mutedGold),
            const SizedBox(width: 6),
            Text('Ожидают подтверждения', style: unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.mutedGold)),
          ],
        ),
      ));
      for (final inv in _invitations) {
        items.add(_buildInvitationCard(inv));
      }
      items.add(const SizedBox(height: 16));
    }
    if (_students.isNotEmpty) {
      if (_invitations.isNotEmpty) {
        items.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(Icons.people, size: 16, color: Colors.white70),
              const SizedBox(width: 6),
              Text('Ученики', style: unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70)),
            ],
          ),
        ));
      }
      for (final student in _students) {
        items.add(_buildStudentCard(student));
      }
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.mutedGold,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: items,
      ),
    );
  }

  Widget _buildInvitationCard(TrainerInvitation inv) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppColors.cardDark.withOpacity(0.8),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.hourglass_empty, color: AppColors.mutedGold, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    inv.email ?? '—',
                    style: unbounded(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white),
                  ),
                  Text(
                    'Приглашение отправлено',
                    style: unbounded(fontSize: 12, color: Colors.white54),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.cancel_outlined, color: Colors.orange.shade400),
              onPressed: () => _showRevokeConfirm(inv),
              tooltip: 'Отозвать приглашение',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(TrainerStudent student) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppColors.cardDark,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TrainerStudentDetailScreen(student: student),
            ),
          ).then((_) => _loadData());
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.rowAlt,
                backgroundImage: student.avatar != null && student.avatar!.isNotEmpty
                    ? NetworkImage(student.avatar!)
                    : null,
                child: student.avatar == null || student.avatar!.isEmpty
                    ? Text(
                        (student.firstname.isNotEmpty ? student.firstname[0] : '?').toUpperCase(),
                        style: unbounded(
                          color: AppColors.mutedGold,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.displayName,
                      style: unbounded(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    if (student.email != null && student.email!.trim().isNotEmpty)
                      Text(
                        student.email!,
                        style: unbounded(fontSize: 13, color: Colors.white70),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: AppColors.mutedGold),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TrainerStudentDetailScreen(student: student),
                    ),
                  ).then((_) => _loadData());
                },
              ),
              IconButton(
                icon: Icon(Icons.person_remove, color: Colors.red.shade400),
                onPressed: () => _showRemoveConfirm(student),
                tooltip: 'Удалить из группы',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddStudentSheet extends StatefulWidget {
  final TextEditingController emailController;
  final Future<bool> Function(String email) onSubmit;

  const _AddStudentSheet({
    required this.emailController,
    required this.onSubmit,
  });

  @override
  State<_AddStudentSheet> createState() => _AddStudentSheetState();
}

class _AddStudentSheetState extends State<_AddStudentSheet> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Пригласить ученика',
            style: unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            'Ученик появится в списке после принятия приглашения',
            style: unbounded(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: widget.emailController,
            enabled: !_loading,
            style: unbounded(color: Colors.white),
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              labelStyle: unbounded(color: AppColors.graphite),
              filled: true,
              fillColor: AppColors.rowAlt,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _loading ? null : () => Navigator.pop(context),
                  child: Text('Отмена', style: unbounded(color: Colors.white70)),
                ),
              ),
              Expanded(
                child: FilledButton(
                  onPressed: _loading
                      ? null
                      : () async {
                          final email = widget.emailController.text.trim();
                          if (email.isEmpty) {
                            showAppError(context, 'Введите email');
                            return;
                          }
                          setState(() => _loading = true);
                          final ok = await widget.onSubmit(email);
                          if (!mounted) return;
                          setState(() => _loading = false);
                          Navigator.pop(context);
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.mutedGold,
                    foregroundColor: AppColors.anthracite,
                  ),
                  child: _loading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.anthracite),
                        )
                      : Text('Отправить приглашение', style: unbounded(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
