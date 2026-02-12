import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login_app/theme/app_theme.dart';
import 'package:intl/intl.dart'; // Для форматирования даты
import 'package:login_app/main.dart';
import '../ProfileScreen.dart';
import '../login.dart';
import '../models/UserProfile.dart';
import '../utils/display_helper.dart';
import '../services/ProfileService.dart';

class ProfileEditScreen extends StatefulWidget {
  @override
  _ProfileEditScreenState createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late Future<UserProfile?> _profileFuture;
  String? selectedSportCategory;
  String? selectedGender;
  DateTime? _selectedDate;

  final Map<String, String> genderOptions = {
    'Мужской': 'male',
    'Женский': 'female',
  };

  final TextEditingController _textEditingController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfileData();
  }

  // Загружаем данные профиля
  // Загружаем данные профиля
  Future<UserProfile?> _loadProfileData() async {
    final profileService = ProfileService(baseUrl: DOMAIN);
    final profile = await profileService.getProfile(context);

    // Обрабатываем дату рождения
    if (profile?.birthday != null) {
      try {
        final DateTime parsedDate = DateTime.parse(profile!.birthday);
        _selectedDate = parsedDate;
        _textEditingController.text = DateFormat('dd MMMM yyyy', 'ru').format(parsedDate);
      } catch (e) {
      }
    }

    return profile;
  }

  // Обновление профиля
  _saveChanges(UserProfile profile) async {
    if(selectedGender == null && profile.gender == null){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполните пол'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
    if(selectedSportCategory != null){
      profile.sportCategory = (selectedSportCategory)!;
    }
    if (_selectedDate != null) {
      profile.birthday = DateFormat('yyyy-MM-dd').format(_selectedDate!);
    }
    profile.gender = (selectedGender ?? profile.gender);
    final profileService = ProfileService(baseUrl: DOMAIN);
    // Обновляем значения полей
    final response = await profileService.updateProfile(profile);
    final responseBody = jsonDecode(response.body);
    final responseStatusCode = response.statusCode;
    if(responseStatusCode == 403){
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LoginScreen(),
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сессии')),
      );
    }
    if(responseStatusCode == 200){
      Navigator.pop(context, profile);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(responseBody['message']),
        backgroundColor: responseBody['error'] == true ? Colors.red : Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Функция для выбора даты
  _selectDate(BuildContext context) async {
    DateTime? newSelectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2040),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.blueGrey,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: Colors.grey[500],
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (newSelectedDate != null) {
      if (mounted) {
        setState(() {
          _selectedDate = newSelectedDate;
          _textEditingController.text = DateFormat('dd MMMM yyyy', 'ru').format(newSelectedDate);
        });
      }
    }
  }

  // Функция для открытия попапа выбора пола
  Future<void> _showGenderSelectionDialog() async {
    String? tempSelectedGender = selectedGender;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Выберите пол', style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: genderOptions.keys.map((genderText) {
                  return RadioListTile<String>(
                    title: Text(genderText, style: GoogleFonts.unbounded(color: Colors.white)),
                    value: genderOptions[genderText]!,
                    groupValue: tempSelectedGender,
                    onChanged: (String? value) {
                      setDialogState(() {
                        tempSelectedGender = value;
                      });
                    },
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Отмена', style: GoogleFonts.unbounded(color: AppColors.mutedGold)),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() => selectedGender = tempSelectedGender);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.mutedGold, foregroundColor: AppColors.anthracite),
                  child: Text('Сохранить', style: GoogleFonts.unbounded(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Функция для открытия попапа выбора разряда
  Future<void> _showSportCategorySelectionDialog() async {
    List<String> categories = ['КМС', 'МС', 'МСМК', 'ЗМС', 'б/р', '1р.', '2р.', '3р.'];
    String? tempSelectedCategory = selectedSportCategory;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Выберите разряд', style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: categories.map((category) {
                  return RadioListTile<String>(
                    title: Text(category, style: GoogleFonts.unbounded(color: Colors.white)),
                    value: category,
                    groupValue: tempSelectedCategory,
                    onChanged: (String? value) {
                      setDialogState(() {
                        tempSelectedCategory = value;
                      });
                    },
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Отмена', style: GoogleFonts.unbounded(color: AppColors.mutedGold)),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() => selectedSportCategory = tempSelectedCategory);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.mutedGold, foregroundColor: AppColors.anthracite),
                  child: Text('Сохранить', style: GoogleFonts.unbounded(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: Text('Изменение данных профиля', style: GoogleFonts.unbounded(fontWeight: FontWeight.w500, fontSize: 18)),
      ),
      body: Container(
        margin: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(12),
        ),
        child: FutureBuilder<UserProfile?>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: AppColors.mutedGold));
            } else if (snapshot.hasError) {
              return Center(child: Text('Ошибка при загрузке данных', style: GoogleFonts.unbounded(color: Colors.white70)));
            } else if (snapshot.hasData) {
              final profile = snapshot.data!;

              // Дополнительная защита от некорректного формата даты
              if (_selectedDate == null &&
                  profile.birthday != null &&
                  profile.birthday.isNotEmpty) {
                try {
                  final DateTime parsedDate =
                      DateTime.parse(profile.birthday);
                  _selectedDate = parsedDate;
                  final String formattedDate =
                      DateFormat('dd MMMM yyyy', 'ru').format(parsedDate);
                  _textEditingController.text = formattedDate;
                } catch (e) {
                  _selectedDate = null;
                  _textEditingController.text = '';
                }
              }

            return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  child: Column(
                    children: [
                      _buildTextFormFieldWithIcon(
                        'Имя',
                        profile.firstName,
                            (value) => profile.firstName = value,
                        Icons.person,
                      ),
                      _buildTextFormFieldWithIcon(
                        'Фамилия',
                        profile.lastName,
                            (value) => profile.lastName = value,
                        Icons.person_outline,
                      ),
                      _buildTextFormFieldWithIcon(
                        'Команда',
                        profile.team,
                            (value) => profile.team = value,
                        Icons.group,
                      ),
                      _buildTextFormFieldWithIcon(
                        'Город',
                        profile.city,
                            (value) => profile.city = value,
                        Icons.location_city,
                      ),
                      _buildTextFormFieldWithIcon(
                        'Контакты для быстрой связи',
                        profile.contact,
                            (value) => profile.contact = value,
                        Icons.phone,
                      ),

                      // Поле для выбора даты рождения с иконкой
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: TextField(
                          focusNode: _focusNode,
                          controller: _textEditingController,
                          readOnly: true,
                          onTap: () => _selectDate(context),
                          style: GoogleFonts.unbounded(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Дата рождения',
                            labelStyle: GoogleFonts.unbounded(color: AppColors.graphite),
                            filled: true,
                            fillColor: AppColors.rowAlt,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            prefixIcon: Icon(Icons.calendar_today, color: AppColors.mutedGold),
                          ),
                        ),
                      ),

                      // Поле для выбора пола с иконкой
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: GestureDetector(
                          onTap: _showGenderSelectionDialog,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Пол',
                              labelStyle: GoogleFonts.unbounded(color: AppColors.graphite),
                              filled: true,
                              fillColor: AppColors.rowAlt,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              prefixIcon: Icon(Icons.wc, color: AppColors.mutedGold),
                            ),
                            child: Text(
                              profile.gender == 'male'
                                  ? 'Мужской'
                                  : profile.gender == 'female'
                                      ? 'Женский'
                                      : displayValue(profile.gender),
                              style: GoogleFonts.unbounded(color: Colors.white),
                            ),
                          ),
                        ),
                      ),

                      // Поле для выбора разряда с иконкой
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: GestureDetector(
                          onTap: _showSportCategorySelectionDialog,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Разряд',
                              labelStyle: GoogleFonts.unbounded(color: AppColors.graphite),
                              filled: true,
                              fillColor: AppColors.rowAlt,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              prefixIcon: Icon(Icons.sports, color: AppColors.mutedGold),
                            ),
                            child: Text(
                              displayValue(profile.sportCategory),
                              style: GoogleFonts.unbounded(color: Colors.white),
                            ),
                          ),
                        ),
                      ),

                      _buildTextFormFieldWithIcon(
                        'Email',
                        profile.email,
                            (value) => profile.email = value,
                        Icons.email,
                        isEmail: true,
                      ),
                      SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _saveChanges(profile),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.mutedGold,
                            foregroundColor: AppColors.anthracite,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text('Сохранить',
                              style: GoogleFonts.unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.anthracite)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } else {
              return Center(child: Text('Нет данных', style: GoogleFonts.unbounded(color: Colors.white70)));
            }
          },
        ),
      ),
    );
  }

  Widget _buildTextFormFieldWithIcon(String label, String initialValue,
      ValueChanged<String> onChanged, IconData icon,
      {bool isEmail = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextFormField(
        initialValue: initialValue,
        onChanged: onChanged,
        style: GoogleFonts.unbounded(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.unbounded(color: AppColors.graphite),
          filled: true,
          fillColor: AppColors.rowAlt,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          prefixIcon: Icon(icon, color: AppColors.mutedGold),
        ),
        keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      ),
    );
  }

}
