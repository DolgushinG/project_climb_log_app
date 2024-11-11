import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:login_app/main.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../login.dart';

class TakePartButtonScreen extends StatefulWidget {
  final int event_id;
  final bool is_participant;
  final VoidCallback onParticipationStatusChanged; // Колбек

  TakePartButtonScreen(this.event_id, this.is_participant, this.onParticipationStatusChanged);

  @override
  _MyButtonScreenState createState() => _MyButtonScreenState();
}

class _MyButtonScreenState extends State<TakePartButtonScreen> {
  bool _isButtonDisabled = false;
  String _buttonText = 'Принять участие';
  bool success = false;

  @override
  void initState() {
    super.initState();
    print('Принять участие кнопка обновлена');
    _fetchParticipationStatus();
  }

  Future<void> _fetchParticipationStatus() async {
    final String? token = await getToken();
    try {
      final response = await http.get(
        Uri.parse('${DOMAIN}/api/competitions?event_id=${widget.event_id}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        bool isParticipant = responseData['is_participant'];
        setState(() {
          _isButtonDisabled = isParticipant;
          _buttonText = isParticipant ? 'Вы участник' : 'Принять участие';
          success = isParticipant;
        });
      } else if (response.statusCode == 401 || response.statusCode == 419) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LoginScreen(),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сессии')),
        );
      } else {
        print(response.body);
        _showNotification('Ошибка при получении статуса', Colors.red);
      }
    } catch (e) {
      print(e);
      _showNotification('Ошибка сети', Colors.red);
    }
  }

  Future<void> _makeRequest() async {
    setState(() {
      _isButtonDisabled = true;
      _buttonText = 'Загрузка...';
    });

    try {
      final String? token = await getToken();

      final response = await http.post(
        Uri.parse('${DOMAIN}/api/event/take/part'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'event_id': '${widget.event_id}',

        }),
      );
      final responseData = json.decode(response.body);
      final message = responseData['message'];

      if (response.statusCode == 200) {
        _showNotification(message, Colors.green);
        setState(() {
          _isButtonDisabled = true;
          _buttonText = 'Вы участник';
          success = true;
        });
        widget.onParticipationStatusChanged();
      } else if (response.statusCode == 401 || response.statusCode == 419) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LoginScreen(),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сессии')),
        );
      } else {
        _handleError(message);
      }
    } catch (e) {
      print(e);
      _handleError('Ошибка сети');
    } finally {
      _resetButtonStateAfterDelay();
    }
  }

  void _showNotification(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handleError(String message) {
    setState(() {
      success = false;
      _isButtonDisabled = false;
      _buttonText = 'Принять участие';
    });
    _showNotification(message, Colors.red);
  }

  void _resetButtonStateAfterDelay() {
    Future.delayed(Duration(seconds: 3), () {
      setState(() {
        _isButtonDisabled = widget.is_participant;
        _buttonText = widget.is_participant ? "Вы участник" : 'Принять участие';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.is_participant ? Colors.grey : Colors.blue[600],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: widget.is_participant ? null : _makeRequest,
            child: Text(
              _buttonText,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.0,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),

      ],
    );
  }
}

// Экран для внесения результатов
class ResultsEntryScreen extends StatelessWidget {
  final int eventId;

  ResultsEntryScreen({required this.eventId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Внести результаты'),
      ),
      body: Center(
        child: Text('Форма для внесения результатов для события $eventId'),
      ),
    );
  }
}

