import 'dart:async';
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

class CheckoutScreen extends StatefulWidget {
  final int eventId;
  final Map<String, dynamic>? initialData;

  const CheckoutScreen({Key? key, required this.eventId, this.initialData}) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;
  Timer? _timer;
  int _remainingSeconds = 0;
  final _promoController = TextEditingController();
  String? _appliedPromo;
  Map<String, String> _selectedSizes = {};
  String? _selectedPackageName;
  bool _isUploadingReceipt = false;
  bool _isSavingPackage = false;
  bool _isApplyingPromo = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _applyData(widget.initialData!);
    } else {
      _loadCheckout();
    }
  }

  void _applyData(Map<String, dynamic> data) {
    setState(() {
      _data = data;
      _remainingSeconds = (data['remaining_seconds'] is num) ? (data['remaining_seconds'] as num).toInt() : 0;
      // pay_time_expired=1 означает, что время уже истекло на бэке
      if (data['pay_time_expired'] == 1) _remainingSeconds = 0;
      _isLoading = false;
      // Синхронизируем выбранный пакет с бэком
      _selectedPackageName = null;
      _selectedSizes.clear();
      final spRaw = data['selected_package'];
      if (spRaw is List && spRaw.isNotEmpty && spRaw.first is Map) {
        final sp = Map<String, dynamic>.from(spRaw.first as Map);
        final spName = sp['name']?.toString() ?? sp['package_name']?.toString();
        if (spName != null && spName.isNotEmpty) {
          _selectedPackageName = spName;
        }
        final sizesRaw = sp['sizes'];
        if (sizesRaw is Map) {
          for (final e in sizesRaw.entries) {
            final k = e.key?.toString();
            final v = e.value?.toString();
            if (k != null && v != null && v.isNotEmpty) {
              _selectedSizes[k] = v;
            }
          }
        } else {
          final merchRaw = sp['merch'];
          if (merchRaw is List) {
            for (final m in merchRaw) {
              if (m is! Map) continue;
              final n = m['name']?.toString();
              final sz = m['selected_size']?.toString();
              if (n != null && sz != null && sz.isNotEmpty) {
                _selectedSizes[n] = sz;
              }
            }
          }
        }
      }
    });
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _promoController.dispose();
    super.dispose();
  }

  String get _baseUrl => DOMAIN.startsWith('http') ? DOMAIN : 'https://$DOMAIN';

  String _fullUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$_baseUrl${path.startsWith('/') ? '' : '/'}$path';
  }

  /// Получить выбранный пакет с сервера (get-package). Лёгкий запрос для обновления выбора.
  Future<void> _fetchGetPackage() async {
    try {
      final token = await getToken();
      final r = await http.get(
        Uri.parse('$DOMAIN/api/event/${widget.eventId}/get-package'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (r.statusCode == 401 && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
        return;
      }
      if (r.statusCode != 200 || !mounted) return;
      final raw = jsonDecode(r.body);
      final list = raw is List ? raw : [];
      for (final row in list) {
        if (row is! Map) continue;
        final spRaw = row['selected_package'];
        if (spRaw is! List || spRaw.isEmpty) continue;
        final sp = spRaw.first;
        if (sp is! Map) continue;
        final pkgName = sp['package_name']?.toString();
        if (pkgName == null || pkgName.isEmpty) continue;
        final sizes = <String, String>{};
        final merchRaw = sp['merch'];
        if (merchRaw is List) {
          for (final m in merchRaw) {
            if (m is! Map) continue;
            final name = m['name']?.toString();
            final sz = m['selected_size']?.toString();
            if (name != null && sz != null && sz.isNotEmpty) {
              sizes[name] = sz;
            }
          }
        }
        final amount = sp['amount'];
        if (mounted) {
          setState(() {
            _selectedPackageName = pkgName;
            _selectedSizes.clear();
            _selectedSizes.addAll(sizes);
            if (_data != null) {
              final newSp = <String, dynamic>{
                'name': pkgName,
                'package_name': pkgName,
                'sizes': sizes,
                'amount': amount,
                'price': amount,
              };
              _data = Map<String, dynamic>.from(_data!);
              _data!['selected_package'] = [newSp];
            }
          });
        }
        return;
      }
    } catch (_) {}
  }

  Future<void> _loadCheckout({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final token = await getToken();
      final r = await http.get(
        Uri.parse('$DOMAIN/api/event/${widget.eventId}/checkout'),
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
          final spRaw = data['selected_package'];
          final hasSelectedPackage = spRaw is List && spRaw.isNotEmpty;
          if (!hasSelectedPackage && data['event'] != null) {
            _fetchGetPackage();
          }
        } else if (!silent) {
          setState(() => _isLoading = false);
        }
      } else if (r.statusCode == 404) {
        if (!silent) setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Регистрация отменена. Зарегистрируйтесь заново.')),
          );
          Navigator.pop(context);
        }
      } else {
        setState(() {
          _error = 'Не удалось загрузить checkout';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = networkErrorMessage(e, 'Не удалось загрузить данные');
        _isLoading = false;
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (_remainingSeconds <= 0) {
      // Время уже истекло — отменяем регистрацию после следующего кадра
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cancelTakePart();
      });
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      bool shouldCancel = false;
      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds <= 0) {
          _timer?.cancel();
          shouldCancel = true;
        }
      });
      if (shouldCancel && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _cancelTakePart();
        });
      }
    });
  }

  Future<void> _cancelTakePart() async {
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Время оплаты истекло'),
        content: const Text(
          'Оплата не была произведена. Регистрация отменена. Зарегистрируйтесь заново.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ок'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        final token = await getToken();
        await http.post(
          Uri.parse('$DOMAIN/api/event/${widget.eventId}/cancel-take-part'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );
      } catch (_) {}
      if (mounted) Navigator.pop(context);
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

  Future<void> _savePackage(String name, Map<String, String> sizes, int amount) async {
    if (_isSavingPackage) return;
    setState(() => _isSavingPackage = true);
    try {
      final token = await getToken();
      final r = await http.post(
        Uri.parse('$DOMAIN/api/event/${widget.eventId}/save-package'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'name': name, 'sizes': sizes, 'amount': amount}),
      );
      final raw = r.body.isNotEmpty ? jsonDecode(r.body) : null;
      final isSuccess = r.statusCode == 200 && (raw is Map && raw['success'] == true);
      if (isSuccess) {
        final savedName = name;
        final savedSizes = Map<String, String>.from(sizes);
        await _fetchGetPackage();
        if (mounted) {
          setState(() {
            _selectedPackageName = savedName;
            _selectedSizes.clear();
            _selectedSizes.addAll(savedSizes);
          });
        }
      } else if (r.statusCode == 401) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginScreen()),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка сессии. Войдите снова.')),
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

  Future<void> _applyPromo() async {
    final code = _promoController.text.trim();
    if (code.isEmpty) return;
    if (_isApplyingPromo) return;
    setState(() => _isApplyingPromo = true);
    try {
      final token = await getToken();
      final eventRaw = _data?['event'];
      final packages = (eventRaw is Map && eventRaw['packages'] is List) ? eventRaw['packages'] as List : null;
      final packageId = (packages != null && packages.isNotEmpty && packages.first is Map) ? (packages.first as Map)['package_id'] : null;
      final r = await http.post(
        Uri.parse('$DOMAIN/api/event/${widget.eventId}/check-promo-code'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'promo_code': code, 'package_id': packageId}),
      );
      final body = jsonDecode(r.body);
      if (r.statusCode == 200 && body is Map && body['success'] == true) {
        setState(() {
          _appliedPromo = code;
          _isApplyingPromo = false;
        });
        await _loadCheckout();
      } else {
        final msg = body is Map ? body['message']?.toString() : null;
        _showSnack(msg ?? 'Промокод не найден', isError: true);
      }
    } catch (e) {
      _showSnack('Ошибка: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isApplyingPromo = false);
    }
  }

  Future<void> _cancelPromo() async {
    if (_appliedPromo == null) return;
    try {
      final token = await getToken();
      final eventRaw = _data?['event'];
      final packages = (eventRaw is Map && eventRaw['packages'] is List) ? eventRaw['packages'] as List : null;
      final packageId = (packages != null && packages.isNotEmpty && packages.first is Map) ? (packages.first as Map)['package_id'] : null;
      await http.post(
        Uri.parse('$DOMAIN/api/event/${widget.eventId}/cancel-promo-code'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'promo_code': _appliedPromo, 'package_id': packageId}),
      );
      setState(() => _appliedPromo = null);
      await _loadCheckout();
    } catch (_) {}
  }

  Future<void> _uploadReceipt(File file, {String? filename}) async {
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
        _showSnack('Чек успешно загружен');
        if (mounted) Navigator.pop(context, {'receipt_uploaded': true});
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x != null) await _uploadReceipt(File(x.path), filename: x.name);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result != null && result.files.isNotEmpty) {
      final f = result.files.first;
      if (f.path != null) {
        await _uploadReceipt(File(f.path!), filename: f.name);
      } else if (f.bytes != null) {
        await _uploadReceiptFromBytes(f.bytes!, filename: f.name);
      } else {
        _showSnack('Не удалось прочитать файл', isError: true);
      }
    }
  }

  Future<void> _uploadReceiptFromBytes(List<int> bytes, {required String filename}) async {
    if (_isUploadingReceipt) return;
    setState(() => _isUploadingReceipt = true);
    try {
      final token = await getToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$DOMAIN/api/event/${widget.eventId}/upload-receipt'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(http.MultipartFile.fromBytes(
        'receipt',
        bytes,
        filename: filename.isNotEmpty ? filename : 'receipt.jpg',
      ));
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
        _showSnack('Чек успешно загружен');
        if (mounted) Navigator.pop(context, {'receipt_uploaded': true});
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

  Future<void> _paymentToPlace() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Оплата на месте'),
        content: const Text('Вы уверены, что хотите оплатить на месте?'),
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
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context); // закрыть bottom sheet
        }
        if (mounted) Navigator.pop(context); // закрыть CheckoutScreen
      } else {
        _showSnack('Ошибка', isError: true);
      }
    } catch (e) {
      _showSnack('Ошибка: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.green),
    );
  }

  Future<void> _showPaymentBottomSheet({
    required String? linkPayment,
    required String? imgPayment,
    required bool isPayCashToPlace,
  }) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
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
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
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
                        _buildReceiptUpload(),
                        if (isPayCashToPlace)
                          _buildPayOnPlaceButton(),
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
    if (mounted && result != null && result['receipt_uploaded'] == true) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Оформление')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Оформление')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadCheckout,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    final eventRaw = _data?['event'];
    final event = eventRaw is Map ? Map<String, dynamic>.from(eventRaw) : <String, dynamic>{};
    final hasBill = _data?['has_bill'] == true;
    final isPayCashToPlace = event['is_pay_cash_to_place'] == true;
    final packagesRaw = event['packages'];
    final packages = packagesRaw is List ? List.from(packagesRaw) : [];
    final numberSet = _data?['number_set']?.toString() ?? '';
    final yourGroup = _data?['your_group']?.toString() ?? '';
    final showPromoCode = _data?['show_promo_code'] == true;
    final selectedPackageRaw = _data?['selected_package'];
    final selectedPackage = selectedPackageRaw is List
        ? List.from(selectedPackageRaw)
        : (selectedPackageRaw is Map ? [selectedPackageRaw] : []);
    final amountStartPriceRaw = _data?['amount_start_price'];
    final amountStartPrice = amountStartPriceRaw is num
        ? amountStartPriceRaw
        : (int.tryParse(amountStartPriceRaw?.toString() ?? '') ?? 0);
    final isAddToListPending = _data?['is_add_to_list_pending'] == true;
    final linkPayment = event['link_payment'] ?? event['link_payment_dynamic'];
    final imgPayment = event['img_payment_dynamic'] ?? event['img_payment'];
    final merchGalleryRaw = _data?['merch_gallery'];
    final merchGallery = merchGalleryRaw is List ? List.from(merchGalleryRaw) : [];
    final merchAvailabilityRaw = _data?['merch_availability'];
    final merchAvailability = merchAvailabilityRaw is Map ? Map.from(merchAvailabilityRaw) : {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Оформление'),
        backgroundColor: const Color(0xFF0B1220),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Вернуться к событию',
        ),
      ),
      body: Container(
        color: const Color(0xFF050816),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (numberSet.isNotEmpty)
              _buildInfoChip('Сет', numberSet),
            if (yourGroup.isNotEmpty)
              _buildInfoChip('Группа', yourGroup),
            const SizedBox(height: 8),
            _buildHowToPay(),
            if (!isAddToListPending && _remainingSeconds > 0) ...[
              const SizedBox(height: 16),
              _buildTimer(),
            ],
            if (merchGallery.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildSectionTitle('Мерч в пакетах'),
              const SizedBox(height: 8),
              _buildMerchGallery(merchGallery),
            ],
            if (packages.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildSectionTitle('Пакеты'),
              ...packages.map((p) => _buildPackageCard(p, merchAvailability)),
            ],
            if (showPromoCode) ...[
              const SizedBox(height: 20),
              _buildPromoCode(),
            ],
            const SizedBox(height: 20),
            _buildTotalPrice(amountStartPrice, selectedPackage, packages, _selectedPackageName),
            const SizedBox(height: 20),
            if (hasBill)
              _buildHasBillCard()
            else
              _buildPayButton(
                onTap: () {
                  if (_selectedPackageName == null || _selectedPackageName!.isEmpty) {
                    _showSnack('Сначала выберите пакет участия', isError: true);
                    return;
                  }
                  if (!_hasAllSizesSelectedForPackage(_selectedPackageName!, packages)) {
                    _showSnack('Выберите размеры мерча в выбранном пакете', isError: true);
                    return;
                  }
                  _showPaymentBottomSheet(
                    linkPayment: linkPayment?.toString(),
                    imgPayment: imgPayment?.toString(),
                    isPayCashToPlace: isPayCashToPlace,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(color: Colors.white70, fontSize: 14)),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildHowToPay() {
    return Card(
      color: const Color(0xFF0B1220),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Как оплатить', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              '1. Выберите пакет участия\n'
              '2. Если в пакете есть мерч — выберите размер\n'
              '3. После этого сохранится ваш выбор\n'
              '4. Цена и ссылка обновятся автоматически\n'
              '5. После выбора можно перейти к оплате',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimer() {
    final mins = _remainingSeconds ~/ 60;
    final secs = _remainingSeconds % 60;
    final isUrgent = _remainingSeconds <= 300;
    return Card(
      color: isUrgent ? Colors.red.withOpacity(0.2) : const Color(0xFF0B1220),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.timer, color: isUrgent ? Colors.red : Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Оплатите и прикрепите чек до истечения времени: ${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
                style: TextStyle(color: isUrgent ? Colors.red : Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600));
  }

  Widget _buildMerchGallery(List merchGallery) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: merchGallery.length,
        itemBuilder: (_, i) {
          final item = merchGallery[i];
          final m = item is Map ? Map.from(item) : <String, dynamic>{};
          final name = m['name']?.toString() ?? '';
          final img = m['image_url'] ?? m['image'];
          final packagesList = m['packages'];
          final pkgs = packagesList is List ? packagesList.join(', ') : packagesList?.toString() ?? '';
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => _showImageFullscreen(_fullUrl(img?.toString())),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: img != null
                        ? CachedNetworkImage(
                            imageUrl: _fullUrl(img.toString()),
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const SizedBox(width: 80, height: 80, child: CircularProgressIndicator()),
                            errorWidget: (_, __, ___) => Container(width: 80, height: 80, color: Colors.grey),
                          )
                        : Container(width: 80, height: 80, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(width: 80, child: Text(name, style: const TextStyle(color: Colors.white70, fontSize: 11), overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
                  if (pkgs.isNotEmpty) Text('В: $pkgs', style: TextStyle(color: Colors.white54, fontSize: 10), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showImageFullscreen(String url) {
    if (url.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildPackageCard(Map<String, dynamic> pkg, Map merchAvailability) {
    final name = pkg['name']?.toString() ?? '';
    final priceVal = pkg['price'];
    final price = (priceVal is num)
        ? priceVal.toDouble()
        : (double.tryParse(priceVal?.toString() ?? '') ?? 0.0);
    final merchRaw = pkg['merch'];
    final merch = merchRaw is List ? List.from(merchRaw) : [];
    bool isDisabled = false;
    for (final m in merch) {
      if (m is! Map) continue;
      final n = m['name']?.toString() ?? '';
      final av = merchAvailability[n];
      if (av is Map && (av['available'] ?? 0) <= 0) {
        isDisabled = true;
        break;
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                Text('${price.toInt()} ₽', style: const TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            ...merch.map((m) {
              if (m is! Map) return const SizedBox.shrink();
              final merchName = m['name']?.toString() ?? '';
              final sizesRaw = m['sizes'];
              final sizes = sizesRaw is List ? List.from(sizesRaw) : [];
              final av = merchAvailability[merchName];
              final available = av is Map ? (av['available'] ?? 0) : null;
              final limit = av is Map ? (av['limit'] ?? 0) : null;
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(merchName, style: TextStyle(color: Colors.white70, fontSize: 14)),
                        if (available != null && limit != null)
                          Text(' (осталось: $available)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                    if (sizes.isNotEmpty)
                      DropdownButton<String>(
                        value: _selectedSizes[merchName],
                        hint: const Text('Выберите размер', style: TextStyle(color: Colors.white54)),
                        dropdownColor: const Color(0xFF1E293B),
                        items: sizes.map((s) {
                          final sz = s is Map ? s['size']?.toString() ?? '' : s.toString();
                          return DropdownMenuItem(value: sz, child: Text(sz, style: const TextStyle(color: Colors.white)));
                        }).toList(),
                        onChanged: isDisabled ? null : (v) {
                          setState(() {
                            _selectedSizes[merchName] = v ?? '';
                            _selectedPackageName = name;
                          });
                          // Сохраняем только когда все размеры мерча в пакете выбраны
                          final allSizesSelected = merch.every((m) {
                            if (m is! Map) return true;
                            final sList = m['sizes'];
                            if (sList is! List || sList.isEmpty) return true;
                            final n = m['name']?.toString() ?? '';
                            return _selectedSizes[n] != null && _selectedSizes[n]!.isNotEmpty;
                          });
                          if (allSizesSelected) {
                            final sizesToSave = <String, String>{};
                            for (final m in merch) {
                              if (m is! Map) continue;
                              final n = m['name']?.toString() ?? '';
                              if (_selectedSizes[n] != null && _selectedSizes[n]!.isNotEmpty) {
                                sizesToSave[n] = _selectedSizes[n]!;
                              }
                            }
                            _savePackage(name, sizesToSave, price.toInt());
                          }
                        },
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final allSizesSelected = merch.every((m) {
                  if (m is! Map) return true;
                  final sList = m['sizes'];
                  if (sList is! List || sList.isEmpty) return true;
                  final n = m['name']?.toString() ?? '';
                  return _selectedSizes[n] != null && _selectedSizes[n]!.isNotEmpty;
                });
                final isSelected = _selectedPackageName == name;
                return SizedBox(
                  width: double.infinity,
                  child: isSelected
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
                          onPressed: (isDisabled || !allSizesSelected)
                              ? null
                              : () async {
                                  setState(() => _selectedPackageName = name);
                                  final sizes = <String, String>{};
                                  for (final m in merch) {
                                    if (m is! Map) continue;
                                    final n = m['name']?.toString() ?? '';
                                    if (_selectedSizes[n] != null && _selectedSizes[n]!.isNotEmpty) {
                                      sizes[n] = _selectedSizes[n]!;
                                    }
                                  }
                                  await _savePackage(name, sizes, price.toInt());
                                },
                          icon: const Icon(Icons.add_shopping_cart, size: 20),
                          label: const Text('Выбрать', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF60A5FA),
                            side: const BorderSide(color: Color(0xFF60A5FA), width: 2),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoCode() {
    return Card(
      color: const Color(0xFF0B1220),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Промокод', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promoController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Введите промокод',
                      hintStyle: TextStyle(color: Colors.white54),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_appliedPromo != null)
                  TextButton(
                    onPressed: _cancelPromo,
                    child: const Text('Убрать'),
                  )
                else
                  ElevatedButton(
                    onPressed: _isApplyingPromo ? null : _applyPromo,
                    child: _isApplyingPromo ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Применить'),
                  ),
              ],
            ),
            if (_appliedPromo != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Промокод $_appliedPromo применён', style: const TextStyle(color: Colors.green, fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }

  int _resolveTotalPrice(dynamic amountStartPrice, List selectedPackage, List packages, String? selectedPackageName) {
    int total = amountStartPrice is int ? amountStartPrice : (amountStartPrice is num ? amountStartPrice.toInt() : int.tryParse(amountStartPrice?.toString() ?? '') ?? 0);
    bool gotFromSelectedPackage = false;
    if (selectedPackage.isNotEmpty) {
      final first = selectedPackage.first;
      if (first is Map) {
        final amt = first['amount'] ?? first['price'] ?? first['total'];
        if (amt != null) {
          total = amt is int ? amt : (amt is num ? amt.toInt() : int.tryParse(amt?.toString() ?? '') ?? total);
          gotFromSelectedPackage = true;
        }
      }
    }
    if (!gotFromSelectedPackage && selectedPackageName != null && selectedPackageName.isNotEmpty && packages.isNotEmpty) {
      for (final p in packages) {
        if (p is! Map) continue;
        if (p['name']?.toString() == selectedPackageName) {
          final priceVal = p['price'];
          if (priceVal != null) {
            total = priceVal is int ? priceVal : (priceVal is num ? priceVal.toInt() : int.tryParse(priceVal?.toString() ?? '') ?? 0);
          }
          break;
        }
      }
    }
    return total;
  }

  bool _hasAllSizesSelectedForPackage(String pkgName, List packages) {
    for (final p in packages) {
      if (p is! Map) continue;
      if (p['name']?.toString() != pkgName) continue;
      final merch = p['merch'];
      if (merch is! List) return true;
      for (final m in merch) {
        if (m is! Map) continue;
        final sList = m['sizes'];
        if (sList is List && sList.isNotEmpty) {
          final n = m['name']?.toString() ?? '';
          if (_selectedSizes[n] == null || _selectedSizes[n]!.isEmpty) return false;
        }
      }
      return true;
    }
    return true;
  }

  Widget _buildTotalPrice(dynamic amount, List selectedPackage, List packages, String? selectedPackageName) {
    final hasPackage = (selectedPackageName != null && selectedPackageName.isNotEmpty) || selectedPackage.isNotEmpty;
    final total = hasPackage ? _resolveTotalPrice(amount, selectedPackage, packages, selectedPackageName) : 0;
    return Card(
      color: const Color(0xFF0B1220),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Итого:', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            Text(
              hasPackage ? '$total ₽' : '—',
              style: TextStyle(
                color: hasPackage ? Colors.white : Colors.white54,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayButton({required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF16A34A),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('Перейти к оплате или прикрепить чек'),
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
            CachedNetworkImage(
              imageUrl: url,
              width: 160,
              height: 160,
              fit: BoxFit.contain,
              errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptUpload() {
    return Card(
      color: const Color(0xFF0B1220),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Загрузить чек', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('JPEG, PNG или PDF. Макс. 10 МБ', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isUploadingReceipt ? null : _pickImage,
                  icon: _isUploadingReceipt ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.photo_library),
                  label: const Text('Галерея'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isUploadingReceipt ? null : _pickFile,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Файл'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayOnPlaceButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _paymentToPlace,
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

  Widget _buildHasBillCard() {
    return Card(
      color: Colors.green.withOpacity(0.2),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                'Чек уже загружен! Ожидайте подтверждения администратором.',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
