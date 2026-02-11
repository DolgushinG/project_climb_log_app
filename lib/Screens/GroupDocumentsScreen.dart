import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../login.dart';
import '../main.dart';
import '../models/GroupDocumentsModels.dart';
import '../utils/network_error_helper.dart';

class GroupDocumentsScreen extends StatefulWidget {
  final int eventId;
  final String? eventTitle;

  const GroupDocumentsScreen({
    Key? key,
    required this.eventId,
    this.eventTitle,
  }) : super(key: key);

  @override
  State<GroupDocumentsScreen> createState() => _GroupDocumentsScreenState();
}

class _GroupDocumentsScreenState extends State<GroupDocumentsScreen> {
  GroupDocumentsResponse? _data;
  bool _isLoading = true;
  String? _error;
  final Map<String, bool> _uploadingByKey = {};
  static const _maxFileSizeBytes = 10 * 1024 * 1024;

  String get _baseUrl => DOMAIN.startsWith('http') ? DOMAIN : 'https://$DOMAIN';

  String _fullUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$_baseUrl${path.startsWith('/') ? '' : '/'}$path';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final token = await getToken();
      final r = await http.get(
        Uri.parse('$DOMAIN/api/event/${widget.eventId}/group-documents'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (r.statusCode == 200) {
        final raw = jsonDecode(r.body);
        final data = raw is Map ? Map<String, dynamic>.from(raw) : null;
        if (data != null) {
          _data = GroupDocumentsResponse.fromJson(data);
          if (mounted) setState(() {});
        } else if (!silent) {
          setState(() => _error = 'Неверный формат ответа');
        }
      } else if (r.statusCode == 401 || r.statusCode == 419) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginScreen()),
          );
        }
      } else if (r.statusCode == 404) {
        if (!silent) setState(() => _error = 'Данные не найдены');
      } else {
        if (!silent) setState(() => _error = 'Ошибка загрузки');
      }
    } catch (e) {
      if (!silent) setState(() => _error = networkErrorMessage(e, 'Не удалось загрузить данные'));
    } finally {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadDocument({
    required File file,
    required int documentIndex,
    required int userId,
  }) async {
    final key = '${userId}_$documentIndex';
    if (_uploadingByKey[key] == true) return;
    setState(() => _uploadingByKey[key] = true);
    try {
      final token = await getToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$DOMAIN/api/event/${widget.eventId}/upload-document'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath(
        'upload_document_participant',
        file.path,
        filename: file.path.split(RegExp(r'[/\\]')).last,
      ));
      request.fields['document_index'] = documentIndex.toString();
      request.fields['user_id'] = userId.toString();

      final streamed = await request.send();
      final r = await http.Response.fromStream(streamed);
      dynamic raw;
      try {
        raw = r.body.isNotEmpty ? jsonDecode(r.body) : null;
      } catch (_) {
        raw = null;
      }
      if (r.statusCode == 200 || (raw is Map && raw['success'] == true)) {
        _showSnack(raw is Map ? (raw['message']?.toString() ?? 'Документ загружен') : 'Документ загружен');
        await _loadData(silent: true);
      } else {
        final msg = raw is Map ? (raw['message'] ?? raw['error'])?.toString() : null;
        _showSnack(msg ?? 'Ошибка загрузки документа', isError: true);
      }
    } catch (e) {
      _showSnack(networkErrorMessage(e, 'Ошибка загрузки'), isError: true);
    } finally {
      if (mounted) {
        setState(() => _uploadingByKey.remove(key));
      }
    }
  }

  Future<void> _pickAndUpload(int userId, int documentIndex) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    if (f.path == null) return;
    final file = File(f.path!);
    final size = await file.length();
    if (size > _maxFileSizeBytes) {
      _showSnack('Размер файла не более 10 МБ', isError: true);
      return;
    }
    await _uploadDocument(file: file, documentIndex: documentIndex, userId: userId);
  }

  Future<void> _downloadTemplate(String? url) async {
    final full = url != null && url.isNotEmpty ? _fullUrl(url) : null;
    if (full == null || full.isEmpty) {
      _showSnack('Шаблон недоступен', isError: true);
      return;
    }
    final uri = Uri.tryParse(full);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnack('Не удалось открыть ссылку', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  bool _isUploading(int userId, int docIndex) =>
      _uploadingByKey['${userId}_$docIndex'] == true;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Документы участников'),
          backgroundColor: const Color(0xFF0B1220),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Документы участников'),
          backgroundColor: const Color(0xFF0B1220),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Назад')),
              ],
            ),
          ),
        ),
      );
    }

    final data = _data;
    if (data == null || (data.documents.isEmpty && data.users.isEmpty)) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Документы участников'),
          backgroundColor: const Color(0xFF0B1220),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Нет требуемых документов для этого события.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
        ),
      );
    }

    final eventTitle = data.event['title']?.toString() ?? widget.eventTitle ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Документы участников'),
        backgroundColor: const Color(0xFF0B1220),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        color: const Color(0xFF050816),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (eventTitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  eventTitle,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            if (data.documents.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const Icon(Icons.description, color: Color(0xFF16A34A), size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Требуемые документы',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ...data.documents.map((doc) => _buildDocumentHeader(doc)),
            const SizedBox(height: 24),
            if (data.users.isNotEmpty)
              const Text(
                'Участники',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            const SizedBox(height: 12),
            ...data.users.map((u) => _buildUserCard(u)),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentHeader(DocumentInfo doc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              doc.name,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          if (doc.documentUrl != null && doc.documentUrl!.isNotEmpty)
            TextButton.icon(
              onPressed: () => _downloadTemplate(doc.documentUrl),
              icon: const Icon(Icons.download, size: 18, color: Color(0xFF16A34A)),
              label: const Text('Скачать шаблон', style: TextStyle(color: Color(0xFF16A34A), fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildUserCard(UserDocuments user) {
    final setInfo = user.set != null
        ? 'Сет №${user.set!['number_set'] ?? ''} ${user.set!['time'] ?? ''}'
        : '';
    final category = user.participantCategory?['category']?.toString() ?? '';
    return Card(
      color: const Color(0xFF0B1220),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.middlename,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
            ),
            if (setInfo.isNotEmpty || category.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                [setInfo, category].where((s) => s.isNotEmpty).join(' • '),
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            ...user.documentsStatus.map((ds) => _buildDocumentRow(user.userId, ds)),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentRow(int userId, DocumentStatus ds) {
    final uploading = _isUploading(userId, ds.documentIndex);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ds.name,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ds.uploaded
                        ? const Color(0xFF16A34A).withOpacity(0.2)
                        : Colors.white12,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    ds.uploaded ? 'Загружено' : 'Ожидает',
                    style: TextStyle(
                      fontSize: 12,
                      color: ds.uploaded ? const Color(0xFF16A34A) : Colors.white54,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (ds.documentUrl != null && ds.documentUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: const Icon(Icons.download, color: Color(0xFF16A34A), size: 22),
                onPressed: uploading ? null : () => _downloadTemplate(ds.documentUrl),
                tooltip: 'Скачать шаблон',
              ),
            ),
          SizedBox(
            width: 120,
            child: ElevatedButton(
              onPressed: uploading
                  ? null
                  : () => _pickAndUpload(userId, ds.documentIndex),
              style: ElevatedButton.styleFrom(
                backgroundColor: ds.uploaded ? Colors.orange : const Color(0xFF16A34A),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: uploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(ds.uploaded ? 'Заменить' : 'Загрузить', style: const TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}
