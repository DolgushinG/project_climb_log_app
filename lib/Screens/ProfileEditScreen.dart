import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Для форматирования даты
import 'package:login_app/main.dart';
import '../ProfileScreen.dart';
import '../login.dart';
import '../models/UserProfile.dart';
import '../services/ProfileService.dart';

class ProfileEditScreen extends StatefulWidget {
  @override
  _ProfileEditScreenState createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late Future<UserProfile> _profileFuture;
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
  Future<UserProfile> _loadProfileData() async {
    final profileService = ProfileService(baseUrl: DOMAIN);
    return await profileService.getProfile();
  }

  // Обновление профиля
  Future<void> _saveChanges(UserProfile profile) async {
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
    if(_selectedDate != null){
      String formattedDate = DateFormat('yyyy-M-d').format(_selectedDate!);
      profile.birthday = formattedDate;
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
      firstDate: DateTime(2000),
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
          _textEditingController.text = DateFormat('dd MMMM yyyy', 'ru').format(_selectedDate!);
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
              title: Text('Выберите пол'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: genderOptions.keys.map((genderText) {
                  return RadioListTile<String>(
                    title: Text(genderText),
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
                  onPressed: () {
                    Navigator.pop(context); // Закрыть окно без сохранения
                  },
                  child: Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      selectedGender = tempSelectedGender;
                    });
                    Navigator.pop(context); // Закрыть окно
                  },
                  child: Text('Сохранить'),
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
              title: Text('Выберите разряд'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: categories.map((category) {
                  return RadioListTile<String>(
                    title: Text(category),
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
                  onPressed: () {
                    Navigator.pop(context); // Закрыть окно без сохранения
                  },
                  child: Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      selectedSportCategory = tempSelectedCategory;
                    });
                    Navigator.pop(context); // Закрыть окно
                  },
                  child: Text('Сохранить'),
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
        automaticallyImplyLeading: false,
        title: Text('Изменение данных профиля'),
      ),
      body: FutureBuilder<UserProfile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Ошибка при загрузке данных'));
          } else if (snapshot.hasData) {
            final profile = snapshot.data!;

            // Обновляем значения полей в профиле после изменения
            profile.firstName = profile.firstName;
            profile.lastName = profile.lastName;
            profile.team = profile.team;
            profile.city = profile.city;
            profile.contact = profile.contact;
            profile.email = profile.email;
            profile.gender = profile.gender;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                child: Column(
                  children: [
                    _buildTextFormField('Имя', profile.firstName, (value) => profile.firstName = value),
                    _buildTextFormField('Фамилия', profile.lastName, (value) => profile.lastName = value),
                    _buildTextFormField('Команда', profile.team, (value) => profile.team = value),
                    _buildTextFormField('Город', profile.city, (value) => profile.city = value),
                    _buildTextFormField('Контакты для быстрой связи', profile.contact, (value) => profile.contact = value),

                    // Поле для выбора даты рождения
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: TextField(
                        focusNode: _focusNode,
                        controller: _textEditingController,
                        readOnly: true,
                        onTap: () => _selectDate(context),
                        decoration: InputDecoration(
                          labelText: 'Дата рождения',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),

                    // Поле для выбора пола
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: GestureDetector(
                        onTap: _showGenderSelectionDialog,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Пол',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            profile.gender != null
                                ? (profile.gender == 'male' ? 'Мужской' : 'Женский')
                                : '-',
                          ),
                        ),
                      ),
                    ),

                    // Поле для выбора разряда
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: GestureDetector(
                        onTap: _showSportCategorySelectionDialog,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Разряд',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(profile.sportCategory ?? '-'),
                        ),
                      ),
                    ),

                    _buildTextFormField('Email', profile.email, (value) => profile.email = value, isEmail: true),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        _saveChanges(profile);
                      },
                      child: Text('Сохранить'),
                    ),
                  ],
                ),
              ),
            );
          } else {
            return Center(child: Text('Нет данных'));
          }
        },
      ),
    );
  }

  Widget _buildTextFormField(String label, String initialValue, Function(String) onChanged, {bool isEmail = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextFormField(
        initialValue: initialValue,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      ),
    );
  }
}
