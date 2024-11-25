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
        print('Ошибка обработки даты: $e');
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
        automaticallyImplyLeading: true,
        title: Text('Изменение данных профиля'),
      ),
      body: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
        ),
        elevation: 4,
        margin: const EdgeInsets.all(16.0),
        child: FutureBuilder<UserProfile?>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Ошибка при загрузке данных'));
            } else if (snapshot.hasData) {
              final profile = snapshot.data!;

              if (_selectedDate == null){
                final DateTime parsedDate = DateTime.parse(profile.birthday);
                _selectedDate = parsedDate;
                final String formattedDate = DateFormat('dd MMMM yyyy', 'ru').format(parsedDate);
                _textEditingController.text = formattedDate;
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
                          decoration: InputDecoration(
                            labelText: 'Дата рождения',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
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
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.wc),
                            ),
                            child: Text(
                              profile.gender != null
                                  ? (profile.gender == 'male'
                                  ? 'Мужской'
                                  : 'Женский')
                                  : '-',
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
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.sports),
                            ),
                            child: Text(profile.sportCategory ?? '-'),
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
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Сохранить',
                              style: TextStyle(fontSize: 16, color: Colors.white)),
                        ),
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
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
          prefixIcon: Icon(icon),
        ),
        keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      ),
    );
  }

}
