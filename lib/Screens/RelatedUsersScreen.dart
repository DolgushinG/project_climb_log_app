import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/RelatedUser.dart';
import '../theme/app_theme.dart';
import '../services/RelatedUsersService.dart';
import '../utils/display_helper.dart';
import '../utils/network_error_helper.dart';

class RelatedUsersScreen extends StatefulWidget {
  const RelatedUsersScreen({super.key});

  @override
  State<RelatedUsersScreen> createState() => _RelatedUsersScreenState();
}

class _RelatedUsersScreenState extends State<RelatedUsersScreen> {
  bool _isLoading = true;
  String? _error;
  List<RelatedUser> _users = [];
  List<String> _sportCategories = [];
  final RelatedUsersService _service = RelatedUsersService(baseUrl: DOMAIN);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _service.getRelatedUsers(context);
      if (mounted) {
        setState(() {
          _users = response.users;
          _sportCategories = response.sportCategories.isNotEmpty
              ? response.sportCategories
              : ['б/р', '1 юн.р.', '2 юн.р.', '3 юн.р.', '3 сп.р.', '2 сп.р.', '1 сп.р.', 'КМС', 'МС', 'МСМК', 'ЗМС'];
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

  void _showEditDialog(RelatedUser user) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RelatedUserEditSheet(
        user: user,
        sportCategories: _sportCategories,
        onSave: (updated) async {
          final ok = await _service.editRelatedUser(context, updated);
          if (ok && mounted) {
            Navigator.pop(context);
            _loadData();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Успешно сохранено', style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }

  void _showUnlinkConfirm(RelatedUser user) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Отвязать участника', style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
        content: Text(
          'Подтвердить удаление ${user.firstname} ${user.lastname} из списка заявленных? '
          'Данные пользователя в системе не будут удалены.',
          style: GoogleFonts.unbounded(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена', style: GoogleFonts.unbounded(color: AppColors.mutedGold)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await _service.unlinkRelatedUser(context, user.id);
              if (ok && mounted) {
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Успешная отвязка', style: TextStyle(color: Colors.white)),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Отвязать', style: GoogleFonts.unbounded(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Заявленные', style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white)),
        backgroundColor: AppColors.cardDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        color: AppColors.anthracite,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
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
                style: GoogleFonts.unbounded(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadData,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.mutedGold, foregroundColor: AppColors.anthracite),
                child: Text('Повторить', style: GoogleFonts.unbounded(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      );
    }
    if (_users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline, size: 64, color: Colors.grey.shade600),
              const SizedBox(height: 16),
              Text(
                'Пока вы никого не заявляли',
                textAlign: TextAlign.center,
                style: GoogleFonts.unbounded(fontSize: 18, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                'Участники появятся после групповой регистрации на соревнования',
                textAlign: TextAlign.center,
                style: GoogleFonts.unbounded(fontSize: 14, color: Colors.white54),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          return _buildUserCard(user);
        },
      ),
    );
  }

  Widget _buildUserCard(RelatedUser user) {
    final fullName = [user.lastname, user.firstname, user.middlename]
        .where((s) => s != null && s.toString().trim().isNotEmpty)
        .join(' ');

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppColors.cardDark,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showEditDialog(user),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.rowAlt,
                    child: Text(
                      (user.firstname.isNotEmpty ? user.firstname[0] : '?')
                          .toUpperCase(),
                      style: GoogleFonts.unbounded(
                        color: AppColors.mutedGold,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName.isNotEmpty ? fullName : 'Без имени',
                          style: GoogleFonts.unbounded(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        if (user.email != null && user.email!.trim().isNotEmpty)
                          Text(
                            user.email!,
                            style: GoogleFonts.unbounded(fontSize: 13, color: Colors.white70),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit, color: AppColors.mutedGold),
                    onPressed: () => _showEditDialog(user),
                  ),
                  IconButton(
                    icon: Icon(Icons.link_off, color: Colors.red.shade400),
                    onPressed: () => _showUnlinkConfirm(user),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  if (user.city != null && user.city!.isNotEmpty)
                    _infoChip(Icons.location_city, displayValue(user.city)),
                  if (user.sportCategory != null && user.sportCategory!.isNotEmpty)
                    _infoChip(Icons.sports, displayValue(user.sportCategory)),
                  if (user.gender != null && user.gender!.isNotEmpty)
                    _infoChip(
                      Icons.wc,
                      user.gender == 'male' ? 'М' : user.gender == 'female' ? 'Ж' : user.gender!,
                    ),
                  if (user.birthday != null && user.birthday!.isNotEmpty)
                    _infoChip(Icons.calendar_today, displayValue(user.birthday)),
                  if (user.contact != null && user.contact!.isNotEmpty)
                    _infoChip(Icons.phone, displayValue(user.contact)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.graphite),
        const SizedBox(width: 4),
        Text(text, style: GoogleFonts.unbounded(fontSize: 12, color: Colors.white70)),
      ],
    );
  }
}

class _RelatedUserEditSheet extends StatefulWidget {
  final RelatedUser user;
  final List<String> sportCategories;
  final Future<void> Function(RelatedUser) onSave;

  const _RelatedUserEditSheet({
    required this.user,
    required this.sportCategories,
    required this.onSave,
  });

  @override
  State<_RelatedUserEditSheet> createState() => _RelatedUserEditSheetState();
}

class _RelatedUserEditSheetState extends State<_RelatedUserEditSheet> {
  late TextEditingController _firstnameController;
  late TextEditingController _lastnameController;
  late TextEditingController _emailController;
  late TextEditingController _cityController;
  late TextEditingController _teamController;
  late TextEditingController _contactController;
  late TextEditingController _birthdayController;

  String? _selectedSportCategory;
  String? _selectedGender;
  DateTime? _selectedDate;
  bool _isSaving = false;

  static const Map<String, String> _genderOptions = {
    'Мужской': 'male',
    'Женский': 'female',
  };

  @override
  void initState() {
    super.initState();
    _firstnameController = TextEditingController(text: widget.user.firstname);
    _lastnameController = TextEditingController(text: widget.user.lastname);
    _emailController = TextEditingController(text: widget.user.email ?? '');
    _cityController = TextEditingController(text: widget.user.city ?? '');
    _teamController = TextEditingController(text: widget.user.team ?? '');
    _contactController = TextEditingController(text: widget.user.contact ?? '');
    _birthdayController = TextEditingController();
    _selectedSportCategory = widget.user.sportCategory;
    _selectedGender = widget.user.gender;

    if (widget.user.birthday != null && widget.user.birthday!.trim().isNotEmpty) {
      try {
        _selectedDate = DateTime.parse(widget.user.birthday!);
        _birthdayController.text = DateFormat('dd MMMM yyyy', 'ru').format(_selectedDate!);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _firstnameController.dispose();
    _lastnameController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _teamController.dispose();
    _contactController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2040),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
        _birthdayController.text = DateFormat('dd MMMM yyyy', 'ru').format(picked);
      });
    }
  }

  void _showSportCategoryPicker() {
    String? temp = _selectedSportCategory;
    showDialog<void>(
      context: context,
        builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text('Выберите разряд', style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: widget.sportCategories.map((c) {
                return RadioListTile<String>(
                  title: Text(c, style: GoogleFonts.unbounded(color: Colors.white)),
                  value: c,
                  groupValue: temp,
                  onChanged: (v) => setDialog(() => temp = v),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Отмена', style: GoogleFonts.unbounded(color: AppColors.mutedGold)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => _selectedSportCategory = temp);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.mutedGold, foregroundColor: AppColors.anthracite),
              child: Text('Сохранить', style: GoogleFonts.unbounded(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _showGenderPicker() {
    String? temp = _selectedGender;
    showDialog<void>(
      context: context,
        builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text('Выберите пол', style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _genderOptions.entries.map((e) {
              return RadioListTile<String>(
                title: Text(e.key, style: GoogleFonts.unbounded(color: Colors.white)),
                value: e.value,
                groupValue: temp,
                onChanged: (v) => setDialog(() => temp = v),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Отмена', style: GoogleFonts.unbounded(color: AppColors.mutedGold)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => _selectedGender = temp);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.mutedGold, foregroundColor: AppColors.anthracite),
              child: Text('Сохранить', style: GoogleFonts.unbounded(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final firstname = _firstnameController.text.trim();
    final lastname = _lastnameController.text.trim();
    final email = _emailController.text.trim();
    if (firstname.isEmpty || lastname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
        content: const Text('Заполните имя и фамилию', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
      ),
      );
      return;
    }
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
        content: const Text('Заполните email', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
      ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final updated = widget.user.copyWith(
      firstname: firstname,
      lastname: lastname,
      email: email,
      city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
      team: _teamController.text.trim().isEmpty ? null : _teamController.text.trim(),
      contact: _contactController.text.trim().isEmpty ? null : _contactController.text.trim(),
      sportCategory: _selectedSportCategory,
      gender: _selectedGender,
      birthday: _selectedDate != null ? DateFormat('yyyy-MM-dd').format(_selectedDate!) : null,
    );
    await widget.onSave(updated);
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 1,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Редактирование участника',
                style: GoogleFonts.unbounded(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  _buildTextField('Имя', _firstnameController, Icons.person),
                  _buildTextField('Фамилия', _lastnameController, Icons.person_outline),
                  _buildTextField('Email', _emailController, Icons.email, keyboardType: TextInputType.emailAddress),
                  _buildTextField('Город', _cityController, Icons.location_city),
                  _buildTextField('Команда/тренер', _teamController, Icons.group),
                  _buildTextField('Контакт', _contactController, Icons.phone, keyboardType: TextInputType.phone),
                  _buildDateField(),
                  _buildPickerField(
                    'Разряд',
                    displayValue(_selectedSportCategory),
                    Icons.sports,
                    _showSportCategoryPicker,
                  ),
                  _buildPickerField(
                    'Пол',
                    _selectedGender == 'male'
                        ? 'Мужской'
                        : _selectedGender == 'female'
                            ? 'Женский'
                            : displayValue(_selectedGender),
                    Icons.wc,
                    _showGenderPicker,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mutedGold,
                        foregroundColor: AppColors.anthracite,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text('Сохранить', style: GoogleFonts.unbounded(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.unbounded(color: AppColors.graphite),
          prefixIcon: Icon(icon, color: AppColors.mutedGold),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          filled: true,
          fillColor: AppColors.rowAlt,
        ),
        style: GoogleFonts.unbounded(color: Colors.white),
        keyboardType: keyboardType,
      ),
    );
  }

  Widget _buildDateField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: _selectDate,
        child: AbsorbPointer(
          child: TextField(
            controller: _birthdayController,
            decoration: InputDecoration(
              labelText: 'Дата рождения',
              labelStyle: GoogleFonts.unbounded(color: AppColors.graphite),
              prefixIcon: Icon(Icons.calendar_today, color: AppColors.mutedGold),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              filled: true,
              fillColor: AppColors.rowAlt,
            ),
            style: GoogleFonts.unbounded(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildPickerField(String label, String value, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            labelStyle: GoogleFonts.unbounded(color: AppColors.graphite),
            prefixIcon: Icon(icon, color: AppColors.mutedGold),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            filled: true,
            fillColor: AppColors.rowAlt,
          ),
          child: Text(value.isEmpty ? 'Не выбрано' : value, style: GoogleFonts.unbounded(color: Colors.white)),
        ),
      ),
    );
  }
}
