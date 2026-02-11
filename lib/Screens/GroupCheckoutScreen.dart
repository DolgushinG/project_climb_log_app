import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../login.dart';
import '../main.dart';
import '../utils/network_error_helper.dart';

class GroupCheckoutScreen extends StatefulWidget {
  final int eventId;

  const GroupCheckoutScreen({Key? key, required this.eventId}) : super(key: key);

  @override
  State<GroupCheckoutScreen> createState() => _GroupCheckoutScreenState();
}

class _GroupCheckoutScreenState extends State<GroupCheckoutScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;
  bool _isUploadingReceipt = false;
  bool _isSavingPackage = false;

  /// Выбранные пакеты и размеры по user_id
  final Map<int, String?> _selectedPackageByUser = {};
  final Map<int, Map<String, String>> _selectedSizesByUser = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String get _baseUrl => DOMAIN.startsWith('http') ? DOMAIN : 'https://$DOMAIN';

  String _fullUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$_baseUrl${path.startsWith('/') ? '' : '/'}$path';
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
        Uri.parse('$DOMAIN/api/event/${widget.eventId}/group-checkout'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (r.statusCode == 200) {
        final raw = jsonDecode(r.body);
        final data = raw is Map ? Map<String, dynamic>.from(raw) : null;
        if (data != null) {
          _applyData(data);
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
        if (!silent) setState(() => _error = 'Данные группы не найдены');
      } else {
        if (!silent) setState(() => _error = 'Ошибка загрузки');
      }
    } catch (e) {
      if (!silent) setState(() => _error = networkErrorMessage(e, 'Не удалось загрузить данные'));
    } finally {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  void _applyData(Map<String, dynamic> data) {
    _data = data;
    _selectedPackageByUser.clear();
    _selectedSizesByUser.clear();
    final groupRaw = data['group'];
    if (groupRaw is List) {
      for (final g in groupRaw) {
        if (g is! Map) continue;
        final userId = g['user_id'];
        if (userId == null) continue;
        final uid = userId is int ? userId : int.tryParse(userId.toString());
        if (uid == null) continue;
        final spRaw = g['selected_package'];
        if (spRaw is List && spRaw.isNotEmpty) {
          final sp = spRaw.first;
          if (sp is Map) {
            final name = sp['package_name']?.toString() ?? sp['name']?.toString();
            if (name != null && name.isNotEmpty) {
              _selectedPackageByUser[uid] = name;
            }
            final merch = sp['merch'];
            if (merch is List) {
              final sizes = <String, String>{};
              for (final m in merch) {
                if (m is Map) {
                  final n = m['name']?.toString();
                  final sz = m['selected_size']?.toString();
                  if (n != null && sz != null && sz.isNotEmpty) {
                    sizes[n] = sz;
                  }
                }
              }
              _selectedSizesByUser[uid] = sizes;
            }
          }
        }
      }
    }
  }

  String _formatSavePackageError(String? backendMsg) {
    if (backendMsg == null || backendMsg.isEmpty) return 'Ошибка сохранения';
    if (backendMsg.contains('Лимит мерча') && backendMsg.contains('исчерпан (для вашего пола)')) {
      return 'Для вашего пола мерч закончился. Выберите другой пакет.';
    }
    if (backendMsg.contains('Лимит мерча') && backendMsg.contains('исчерпан')) {
      return 'К сожалению, мерч закончился. Выберите другой пакет.';
    }
    if (backendMsg.contains('нужно выбрать размер')) {
      return 'Выберите размер для мерча';
    }
    return backendMsg;
  }

  Future<void> _savePackage(int? userId, String name, Map<String, String> sizes, int amount) async {
    if (_isSavingPackage) return;
    setState(() => _isSavingPackage = true);
    try {
      final token = await getToken();
      final body = <String, dynamic>{
        'name': name,
        'sizes': sizes,
        'amount': amount,
      };
      if (userId != null) body['user_id'] = userId;
      final r = await http.post(
        Uri.parse('$DOMAIN/api/event/${widget.eventId}/save-package'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      final raw = r.body.isNotEmpty ? jsonDecode(r.body) : null;
      final isSuccess = r.statusCode == 200 && (raw is Map && raw['success'] == true);
      if (isSuccess) {
        if (userId != null) {
          setState(() {
            _selectedPackageByUser[userId] = name;
            _selectedSizesByUser[userId] = Map.from(sizes);
          });
        }
        await _loadData(silent: true);
      } else if (r.statusCode == 401) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginScreen()),
          );
        }
      } else {
        final msg = raw is Map ? (raw['message'] ?? raw['error'])?.toString() : null;
        _showSnack(_formatSavePackageError(msg), isError: true);
      }
    } catch (e) {
      _showSnack('Ошибка: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSavingPackage = false);
    }
  }

  Future<void> _uploadReceipt(File file, {int? userId, bool group = false, String? filename}) async {
    if (_isUploadingReceipt) return;
    setState(() => _isUploadingReceipt = true);
    try {
      final token = await getToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$DOMAIN/api/event/${widget.eventId}/upload-receipt'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath(
        'receipt',
        file.path,
        filename: filename ?? file.path.split(RegExp(r'[/\\]')).last,
      ));
      if (userId != null) request.fields['user_id'] = userId.toString();
      if (group) request.fields['group'] = 'true';
      request.fields['event_id'] = widget.eventId.toString();

      final streamed = await request.send();
      final r = await http.Response.fromStream(streamed);
      dynamic raw;
      try {
        raw = r.body.isNotEmpty ? jsonDecode(r.body) : null;
      } catch (_) {
        raw = null;
      }
      final isSuccess = r.statusCode == 200 || r.statusCode == 201 || (raw is Map && raw['success'] == true);
      if (isSuccess) {
        _showSnack(raw is Map ? (raw['message']?.toString() ?? 'Чек загружен') : 'Чек загружен');
        await _loadData();
      } else {
        final msg = raw is Map ? (raw['message'] ?? raw['error'])?.toString() : null;
        _showSnack(msg ?? 'Ошибка загрузки чека', isError: true);
      }
    } catch (e) {
      _showSnack('Ошибка: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingReceipt = false);
    }
  }

  Future<void> _pickImage({int? userId, bool group = false}) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x != null) await _uploadReceipt(File(x.path), userId: userId, group: group, filename: x.name);
  }

  Future<void> _pickFile({int? userId, bool group = false}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result != null && result.files.isNotEmpty) {
      final f = result.files.first;
      if (f.path != null) {
        await _uploadReceipt(File(f.path!), userId: userId, group: group, filename: f.name);
      }
    }
  }

  int? _getPackagePrice(List packagesList, String pkgName) {
    for (final p in packagesList) {
      if (p is! Map) continue;
      final n = p['name']?.toString() ?? p['package_name']?.toString();
      if (n != pkgName) continue;
      final priceVal = p['price'] ?? p['amount'];
      if (priceVal != null) return priceVal is int ? priceVal : (priceVal is num ? priceVal.toInt() : int.tryParse(priceVal.toString()));
    }
    return null;
  }

  /// Считаем сумму только по неоплаченным участникам с выбранным пакетом. Без пакета — 0.
  int _calcTotalSum() {
    final groupRaw = _data?['group'];
    if (groupRaw is! List) return 0;
    final packages = _data?['event']?['packages'];
    final packagesList = packages is List ? packages : [];
    int sum = 0;
    for (final g in groupRaw) {
      if (g is! Map) continue;
      if (g['is_paid'] == true) continue;
      final userId = g['user_id'];
      final uid = userId is int ? userId : int.tryParse(userId?.toString() ?? '');
      int userPrice = 0;
      final pkgName = uid != null ? _selectedPackageByUser[uid] : null;
      if (pkgName != null && packagesList.isNotEmpty) {
        final pkPrice = _getPackagePrice(packagesList, pkgName);
        if (pkPrice != null) userPrice = pkPrice;
      } else {
        final spRaw = g['selected_package'];
        if (spRaw is List && spRaw.isNotEmpty && spRaw.first is Map) {
          final first = spRaw.first as Map;
          final amt = first['amount'] ?? first['price'];
          if (amt != null) {
            userPrice = amt is int ? amt : (amt is num ? amt.toInt() : int.tryParse(amt.toString()) ?? 0);
          }
        }
      }
      sum += userPrice;
    }
    return sum;
  }

  bool _hasAllUnpaidParticipantsReady(List packages) {
    final groupRaw = _data?['group'];
    if (groupRaw is! List) return true;
    for (final g in groupRaw) {
      if (g is! Map || g['is_paid'] == true) continue;
      final uid = g['user_id'] is int ? g['user_id'] as int? : int.tryParse(g['user_id']?.toString() ?? '');
      if (uid == null) continue;
      final pkgName = _selectedPackageByUser[uid];
      if (packages.isEmpty) continue;
      if (pkgName == null || pkgName.isEmpty) return false;
      final sizes = _selectedSizesByUser[uid] ?? {};
      for (final p in packages) {
        if (p is! Map) continue;
        if ((p['name'] ?? p['package_name'])?.toString() != pkgName) continue;
        final merch = p['merch'];
        if (merch is! List) break;
        for (final m in merch) {
          if (m is! Map) continue;
          final sList = m['sizes'];
          if (sList is List && sList.isNotEmpty) {
            final n = m['name']?.toString() ?? '';
            if (sizes[n] == null || sizes[n]!.isEmpty) return false;
          }
        }
        break;
      }
    }
    return true;
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.green),
    );
  }

  Future<void> _showPaymentBottomSheet({bool groupReceipt = false}) async {
    final event = _data?['event'];
    final linkPayment = event is Map ? (event['link_payment'] ?? event['link_payment_dynamic'])?.toString() : null;
    final imgPayment = event is Map ? (event['img_payment_dynamic'] ?? event['img_payment'])?.toString() : null;
    final isPayCashToPlace = event is Map && event['is_pay_cash_to_place'] == true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0B1220),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Оплата и прикрепление чека',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (linkPayment != null && linkPayment.isNotEmpty)
                          _buildPaymentLink(linkPayment),
                        if (imgPayment != null && imgPayment.isNotEmpty)
                          _buildQrCode(imgPayment),
                        _buildReceiptUpload(groupReceipt: groupReceipt),
                        if (isPayCashToPlace) _buildPayOnPlaceButton(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHowToPayGroup() {
    return Card(
      color: const Color(0xFF0B1220),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Как оплатить', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              '1. Выберите пакет участия для каждого участника\n'
              '2. Если в пакете есть мерч — выберите размер\n'
              '3. Выбор сохранится автоматически\n'
              '4. Цена обновится автоматически\n'
              '5. После выбора можно перейти к оплате',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentLink(String url) {
    final uri = Uri.tryParse(url.startsWith('http') ? url : '$_baseUrl$url');
    return Card(
      color: const Color(0xFF0B1220),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: const Text('Ссылка на оплату', style: TextStyle(color: Colors.white)),
        trailing: const Icon(Icons.open_in_new, color: Colors.blue),
        onTap: () async {
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
      ),
    );
  }

  Widget _buildQrCode(String path) {
    final url = _fullUrl(path);
    if (url.isEmpty) return const SizedBox.shrink();
    return Card(
      color: const Color(0xFF0B1220),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('QR-код для оплаты', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            CachedNetworkImage(imageUrl: url, width: 160, height: 160, fit: BoxFit.contain),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptUpload({bool groupReceipt = false}) {
    return Card(
      color: const Color(0xFF0B1220),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              groupReceipt ? 'Загрузить чек за всю группу' : 'Загрузить чек',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text('JPEG, PNG или PDF. Макс. 10 МБ', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isUploadingReceipt
                      ? null
                      : () => groupReceipt
                          ? _pickImage(group: true)
                          : _showReceiptUserPicker(),
                  icon: _isUploadingReceipt
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.photo_library),
                  label: const Text('Галерея'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade700, foregroundColor: Colors.white70),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isUploadingReceipt
                      ? null
                      : () => groupReceipt
                          ? _pickFile(group: true)
                          : _showReceiptUserPicker(isFile: true),
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Файл'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade700, foregroundColor: Colors.white70),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showReceiptUserPicker({bool isFile = false}) async {
    final groupRaw = _data?['group'];
    if (groupRaw is! List || groupRaw.isEmpty) return;
    final unpaid = groupRaw.where((g) => g is Map && g['is_paid'] != true).toList();
    if (unpaid.isEmpty) return;
    if (unpaid.length == 1) {
      final g = unpaid.first as Map;
      final uid = g['user_id'];
      final id = uid is int ? uid : int.tryParse(uid?.toString() ?? '');
      if (id != null) {
        if (isFile) {
          await _pickFile(userId: id);
        } else {
          await _pickImage(userId: id);
        }
      }
      return;
    }
    final userId = await showModalBottomSheet<int?>(
      context: context,
      backgroundColor: const Color(0xFF0B1220),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Выберите участника для чека', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
              ),
              ...unpaid.map((g) {
                if (g is! Map) return const SizedBox.shrink();
                final uid = g['user_id'];
                final id = uid is int ? uid : int.tryParse(uid?.toString() ?? '');
                if (id == null) return const SizedBox.shrink();
                final name = '${g['middlename'] ?? ''} ${g['firstname'] ?? ''} ${g['lastname'] ?? ''}'.trim();
                return ListTile(
                  leading: const Icon(Icons.person, color: Colors.white70),
                  title: Text(name.isEmpty ? 'Участник #$id' : name, style: const TextStyle(color: Colors.white, fontSize: 15)),
                  onTap: () => Navigator.pop(ctx, id),
                );
              }),
            ],
          ),
        );
      },
    );
    if (userId != null) {
      if (isFile) {
        await _pickFile(userId: userId);
      } else {
        await _pickImage(userId: userId);
      }
    }
  }

  Widget _buildPayOnPlaceButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Оплата на месте'),
              content: const Text('Вы уверены, что хотите оплатить на месте за всю группу?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Да')),
              ],
            ),
          );
          if (ok != true) return;
          try {
            final token = await getToken();
            final r = await http.post(
              Uri.parse('$DOMAIN/api/event/${widget.eventId}/payment-to-place'),
              headers: {'Authorization': 'Bearer $token'},
            );
            if (r.statusCode == 200) {
              _showSnack('Оплата на месте подтверждена');
              if (mounted) Navigator.pop(context);
            } else {
              _showSnack('Ошибка', isError: true);
            }
          } catch (e) {
            _showSnack('Ошибка: $e', isError: true);
          }
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.orange,
          side: const BorderSide(color: Colors.orange),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('Оплатить на месте'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Оформление группы'), backgroundColor: const Color(0xFF0B1220)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Оформление группы'), backgroundColor: const Color(0xFF0B1220)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _loadData, child: const Text('Повторить')),
              ],
            ),
          ),
        ),
      );
    }

    final event = _data?['event'];
    final eventTitle = event is Map ? (event['title']?.toString() ?? '') : '';
    final groupRaw = _data?['group'];
    final group = groupRaw is List ? groupRaw : [];
    final packagesRaw = event is Map ? event['packages'] : null;
    final packages = packagesRaw is List ? packagesRaw : [];
    final groupIsNotPaid = _data?['group_is_not_paid'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Оформление группы'),
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
            if (groupIsNotPaid) ...[
              _buildHowToPayGroup(),
              const SizedBox(height: 16),
            ],
            const Text(
              'Участники группы',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(height: 12),
            ...group.map((g) => _buildParticipantCard(g as Map<String, dynamic>, packages)),
            const SizedBox(height: 20),
            Card(
              color: const Color(0xFF0B1220),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Итого (неоплаченные):', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                    Text(
                      '${_calcTotalSum()} ₽',
                      style: const TextStyle(color: Color(0xFF16A34A), fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
            if (groupIsNotPaid) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (packages.isNotEmpty && !_hasAllUnpaidParticipantsReady(packages)) {
                      _showSnack('Выберите пакет и размеры мерча для всех участников', isError: true);
                      return;
                    }
                    _showPaymentBottomSheet(groupReceipt: true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Перейти к оплате или прикрепить чек'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantCard(Map<String, dynamic> participant, List packages) {
    final userId = participant['user_id'];
    final uid = userId is int ? userId : int.tryParse(userId?.toString() ?? '');
    final name = '${participant['middlename'] ?? ''} ${participant['firstname'] ?? ''} ${participant['lastname'] ?? ''}'.trim();
    final setInfo = participant['set'];
    final setStr = setInfo is Map
        ? 'Сет №${setInfo['number_set'] ?? ''} ${setInfo['time'] ?? ''}'
        : '';
    final catInfo = participant['participant_category'];
    final catStr = catInfo is Map ? (catInfo['category']?.toString() ?? '') : '';
    final amountStart = participant['amount_start_price'];
    final basePrice = amountStart is num ? amountStart.toInt() : int.tryParse(amountStart?.toString() ?? '') ?? 0;
    final isPaid = participant['is_paid'] == true;
    final spRaw = participant['selected_package'];
    String? currentPkg = uid != null ? _selectedPackageByUser[uid] : null;
    Map<String, String> currentSizes = uid != null ? (_selectedSizesByUser[uid] ?? {}) : {};
    if (currentPkg == null && spRaw is List && spRaw.isNotEmpty && spRaw.first is Map) {
      final first = spRaw.first as Map;
      currentPkg = first['package_name']?.toString() ?? first['name']?.toString();
      final merch = first['merch'];
      if (merch is List) {
        for (final m in merch) {
          if (m is Map) {
            final n = m['name']?.toString();
            final sz = m['selected_size']?.toString();
            if (n != null && sz != null) currentSizes[n] = sz;
          }
        }
      }
    }

    return Card(
      color: const Color(0xFF0B1220),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isPaid ? Icons.check_circle : Icons.person, color: isPaid ? Colors.green : Colors.white70),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.isEmpty ? 'Участник' : name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      if (setStr.isNotEmpty) Text(setStr, style: TextStyle(color: Colors.white70, fontSize: 12)),
                      if (catStr.isNotEmpty) Text(catStr, style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                if (isPaid)
                  const Text('Оплачено', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500)),
              ],
            ),
            if (!isPaid && uid != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isUploadingReceipt
                        ? null
                        : () => _pickImage(userId: uid),
                    icon: _isUploadingReceipt
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.photo_library, size: 18),
                    label: const Text('Чек (галерея)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey,
                      side: const BorderSide(color: Colors.grey),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isUploadingReceipt ? null : () => _pickFile(userId: uid),
                    icon: const Icon(Icons.attach_file, size: 18),
                    label: const Text('Чек (файл)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey,
                      side: const BorderSide(color: Colors.grey),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  if (participant['has_receipt'] == true || participant['receipt_attached'] == true)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long, color: Colors.orange, size: 20),
                          SizedBox(width: 6),
                          Text('Чек на проверке', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w500, fontSize: 13)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            if (!isPaid && packages.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...packages.map((pkg) {
                if (pkg is! Map) return const SizedBox.shrink();
                final pkgName = pkg['name']?.toString() ?? '';
                final priceVal = pkg['price'];
                final price = (priceVal is num ? priceVal.toDouble() : double.tryParse(priceVal?.toString() ?? '') ?? 0).toInt();
                final merch = pkg['merch'] is List ? pkg['merch'] as List : [];
                final allSizesSelected = merch.every((m) {
                  if (m is! Map) return true;
                  final sList = m['sizes'];
                  if (sList is! List || sList.isEmpty) return true;
                  final n = m['name']?.toString() ?? '';
                  return currentSizes[n] != null && currentSizes[n]!.isNotEmpty;
                });
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(pkgName, style: const TextStyle(color: Colors.white)),
                          Text('$price ₽', style: const TextStyle(color: Colors.white70)),
                        ],
                      ),
                      ...merch.map((m) {
                        if (m is! Map) return const SizedBox.shrink();
                        final merchName = m['name']?.toString() ?? '';
                        final sizes = m['sizes'] is List ? m['sizes'] as List : [];
                        if (sizes.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: DropdownButtonFormField<String>(
                            value: currentSizes[merchName],
                            decoration: const InputDecoration(
                              filled: true,
                              fillColor: Color(0xFF1E293B),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            dropdownColor: const Color(0xFF1E293B),
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                            items: sizes.map((s) {
                              final sz = s is Map ? s['size']?.toString() ?? '' : s.toString();
                              return DropdownMenuItem<String>(value: sz, child: Text(sz, style: const TextStyle(color: Colors.white, fontSize: 15)));
                            }).toList(),
                            onChanged: (v) {
                              final updatedSizes = Map<String, String>.from(currentSizes);
                              updatedSizes[merchName] = v ?? '';
                              setState(() {
                                if (uid != null) {
                                  _selectedSizesByUser[uid] = updatedSizes;
                                }
                              });
                              // Если пакет уже выбран — пересохраняем с новыми размерами для пересчёта суммы
                              if (uid != null && currentPkg == pkgName) {
                                final sizesForPackage = <String, String>{};
                                for (final m in merch) {
                                  if (m is Map) {
                                    final n = m['name']?.toString() ?? '';
                                    if (updatedSizes[n] != null) sizesForPackage[n] = updatedSizes[n]!;
                                  }
                                }
                                final needAll = merch.where((m) => m is Map && (m['sizes'] is List) && (m['sizes'] as List).isNotEmpty).length;
                                if (sizesForPackage.length >= needAll || merch.isEmpty) {
                                  _savePackage(uid, pkgName, sizesForPackage, price);
                                }
                              }
                            },
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: currentPkg == pkgName
                            ? ElevatedButton.icon(
                                onPressed: null,
                                icon: const Icon(Icons.check_circle, color: Colors.white, size: 20),
                                label: const Text('Выбрано', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              )
                            : OutlinedButton.icon(
                                onPressed: (allSizesSelected || merch.isEmpty)
                                    ? () {
                                        final sizesForPackage = <String, String>{};
                                        for (final m in merch) {
                                          if (m is Map) {
                                            final n = m['name']?.toString() ?? '';
                                            if (currentSizes[n] != null) sizesForPackage[n] = currentSizes[n]!;
                                          }
                                        }
                                        _savePackage(uid, pkgName, sizesForPackage, price);
                                      }
                                    : null,
                                icon: const Icon(Icons.add_shopping_cart, size: 20),
                                label: const Text('Выбрать', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF60A5FA),
                                  side: const BorderSide(color: Color(0xFF60A5FA), width: 2),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
