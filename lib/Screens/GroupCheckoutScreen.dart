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
import '../theme/app_theme.dart';
import '../utils/network_error_helper.dart';
import '../utils/session_error_helper.dart';
import '../widgets/error_report_modal.dart';
import 'GroupDocumentsScreen.dart';

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
  String? _errorStackTrace;
  Map<String, dynamic>? _errorExtra;
  bool _isUploadingReceipt = false;
  bool _isSavingPackage = false;

  /// Выбранные пакеты и размеры по user_id
  final Map<int, String?> _selectedPackageByUser = {};
  final Map<int, Map<String, String>> _selectedSizesByUser = {};
  bool _showingErrorModal = false;

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

  /// Для картинок мерча: бэкенд отдаёт относительный путь (event_images/...),
  /// Laravel отдаёт их через /storage/
  String _fullImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final relative = path.startsWith('/') ? path.substring(1) : path;
    if (!relative.startsWith('storage/')) {
      return '$_baseUrl/storage/$relative';
    }
    return '$_baseUrl/$relative';
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
      } else if (r.statusCode == 401) {
        if (mounted) redirectToLoginOnSessionError(context);
      } else if (r.statusCode == 404) {
        if (!silent) setState(() => _error = 'Данные группы не найдены');
      } else {
        if (!silent) setState(() => _error = 'Ошибка загрузки');
      }
    } catch (e, st) {
      if (!silent) setState(() {
        _error = networkErrorMessage(e, 'Не удалось загрузить данные');
        _errorStackTrace = st?.toString();
        _errorExtra = {'exception': e.toString(), 'type': e.runtimeType.toString()};
      });
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
        if (mounted) redirectToLoginOnSessionError(context);
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
        await _loadData(silent: true);
        if (group && mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
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
      SnackBar(
        content: Text(msg, style: unbounded(color: Colors.white)),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
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
          color: AppColors.cardDark,
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Оплата и прикрепление чека',
                    style: unbounded(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
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
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        collapsedBackgroundColor: AppColors.cardDark,
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '1. Выберите пакет участия для каждого участника\n'
              '2. Если в пакете есть мерч — выберите размер\n'
              '3. Выбор сохранится автоматически\n'
              '4. Цена обновится автоматически\n'
              '5. После выбора можно перейти к оплате',
              style: unbounded(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
        title: Row(
          children: [
            Icon(Icons.help_outline, color: AppColors.mutedGold, size: 22),
            const SizedBox(width: 12),
            Text('Как оплатить', style: unbounded(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
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
              onTap: () => _showImageFullscreen(_fullImageUrl(img?.toString())),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: img != null
                        ? CachedNetworkImage(
                            imageUrl: _fullImageUrl(img.toString()),
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
                  if (pkgs.isNotEmpty) Text('В: $pkgs', style: const TextStyle(color: Colors.white54, fontSize: 10), overflow: TextOverflow.ellipsis),
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

  Future<void> _showPackageSelectorModal(int userId, Map<String, dynamic> participant, List packages) async {
    String? currentPkg = _selectedPackageByUser[userId];
    Map<String, String> currentSizes = Map.from(_selectedSizesByUser[userId] ?? {});
    final spRaw = participant['selected_package'];
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

    List merchGallery = _data?['merch_gallery'] is List
        ? List.from(_data!['merch_gallery'])
        : (_data?['event'] is Map && _data!['event']['merch_gallery'] is List
            ? List.from(_data!['event']['merch_gallery'])
            : <dynamic>[]);
    if (merchGallery.isEmpty && packages.isNotEmpty) {
      final byName = <String, Map<String, dynamic>>{};
      for (final pkg in packages) {
        if (pkg is! Map) continue;
        final merch = pkg['merch'];
        if (merch is! List) continue;
        final pkgName = pkg['name']?.toString() ?? '';
        for (final m in merch) {
          if (m is! Map) continue;
          final name = m['name']?.toString() ?? '';
          if (name.isEmpty) continue;
          final img = m['image_url'] ?? m['image'];
          if (img == null || img.toString().isEmpty) continue;
          if (byName.containsKey(name)) {
            final existing = byName[name]!;
            final pkgs = (existing['packages'] as List? ?? []).cast<String>();
            if (pkgName.isNotEmpty && !pkgs.contains(pkgName)) {
              pkgs.add(pkgName);
              existing['packages'] = pkgs;
            }
          } else {
            byName[name] = {
              'name': name,
              'image_url': img,
              'image': img,
              'packages': pkgName.isNotEmpty ? [pkgName] : <String>[],
            };
          }
        }
      }
      merchGallery = byName.values.toList();
    }

    // merch_availability: { "Название мерча": { "available": 0, "limit": 10 } }
    Map<String, dynamic> merchAvailability = {};
    final ma1 = _data?['merch_availability'];
    final ma2 = _data?['event']?['merch_availability'];
    if (ma1 is Map) merchAvailability = Map.from(ma1);
    if (merchAvailability.isEmpty && ma2 is Map) merchAvailability = Map.from(ma2);
    // Fallback: собрать из packages.merch[].available / sizes[].available
    if (merchAvailability.isEmpty && packages.isNotEmpty) {
      for (final pkg in packages) {
        if (pkg is! Map) continue;
        for (final m in (pkg['merch'] is List ? pkg['merch'] as List : [])) {
          if (m is! Map) continue;
          final n = m['name']?.toString() ?? '';
          if (n.isEmpty) continue;
          if (merchAvailability.containsKey(n)) continue;
          final av = m['available'];
          final limit = m['limit'];
          if (av != null || limit != null) {
            merchAvailability[n] = {
              'available': av is num ? av.toInt() : (av != null ? int.tryParse(av.toString()) : null),
              'limit': limit is num ? limit.toInt() : (limit != null ? int.tryParse(limit.toString()) : null),
            };
          }
          final sizes = m['sizes'];
          if (sizes is List && sizes.isNotEmpty && !merchAvailability.containsKey(n)) {
            int totalAv = 0;
            for (final s in sizes) {
              if (s is Map) totalAv += ((s['available'] ?? 0) is num ? (s['available'] as num).toInt() : 0);
            }
            merchAvailability[n] = {'available': totalAv, 'limit': null};
          }
        }
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: DraggableScrollableSheet(
              initialChildSize: 0.7,
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Text(
                        'Выбрать пакет',
                        style: unbounded(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (merchGallery.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _buildMerchGallery(merchGallery),
                              ),
                            ],
                            ...packages.map((pkg) {
                            if (pkg is! Map) return const SizedBox.shrink();
                            final pkgName = pkg['name']?.toString() ?? '';
                            final priceVal = pkg['price'];
                            final price = (priceVal is num ? priceVal.toDouble() : double.tryParse(priceVal?.toString() ?? '') ?? 0).toInt();
                            final merch = pkg['merch'] is List ? pkg['merch'] as List : [];
                            bool pkgDisabled = false;
                            for (final m in merch) {
                              if (m is! Map) continue;
                              final n = m['name']?.toString() ?? '';
                              final av = merchAvailability[n];
                              if (av is Map && (av['available'] ?? 0) <= 0) {
                                pkgDisabled = true;
                                break;
                              }
                            }
                            final allSizesSelected = merch.every((m) {
                              if (m is! Map) return true;
                              final sList = m['sizes'];
                              if (sList is! List || sList.isEmpty) return true;
                              final n = m['name']?.toString() ?? '';
                              return currentSizes[n] != null && currentSizes[n]!.isNotEmpty;
                            });
                            final isSelected = currentPkg == pkgName;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: AppColors.graphite,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: Text(pkgName, style: unbounded(color: Colors.white), overflow: TextOverflow.ellipsis)),
                                      if (pkgDisabled)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 8),
                                          child: Text('Мерч закончился', style: unbounded(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500)),
                                        )
                                      else
                                        Text('$price ₽', style: unbounded(color: Colors.white70)),
                                    ],
                                  ),
                                  ...merch.map((m) {
                                    if (m is! Map) return const SizedBox.shrink();
                                    final merchName = m['name']?.toString() ?? '';
                                    final sizes = m['sizes'] is List ? m['sizes'] as List : [];
                                    final av = merchAvailability[merchName];
                                    final available = av is Map ? (av['available'] ?? 0) : null;
                                    final isMerchSoldOut = available != null && available <= 0;
                                    if (sizes.isEmpty) return const SizedBox.shrink();
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(merchName, style: unbounded(color: isMerchSoldOut ? Colors.red : Colors.white70, fontSize: 13)),
                                              if (!isMerchSoldOut && available != null)
                                                Text(' (осталось: $available)', style: unbounded(color: Colors.white54, fontSize: 12)),
                                            ],
                                          ),
                                          if (!isMerchSoldOut)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: DropdownButtonFormField<String>(
                                                value: currentSizes[merchName],
                                              decoration: InputDecoration(
                                                labelText: 'Размер',
                                                labelStyle: unbounded(color: AppColors.graphite),
                                                filled: true,
                                                fillColor: AppColors.rowAlt,
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                              ),
                                              dropdownColor: AppColors.cardDark,
                                              style: unbounded(color: Colors.white, fontSize: 15),
                                              items: sizes.map((s) {
                                                final sz = s is Map ? s['size']?.toString() ?? '' : s.toString();
                                                return DropdownMenuItem<String>(value: sz, child: Text(sz, style: unbounded(color: Colors.white, fontSize: 15)));
                                              }).toList(),
                                              onChanged: (v) {
                                                currentSizes[merchName] = v ?? '';
                                                setModalState(() {});
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: isSelected
                                        ? ElevatedButton.icon(
                                            onPressed: null,
                                            icon: const Icon(Icons.check_circle, color: Colors.white, size: 20),
                                            label: Text('Выбрано', style: unbounded(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.mutedGold,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                          )
                                        : OutlinedButton.icon(
                                            onPressed: !pkgDisabled && (allSizesSelected || merch.isEmpty)
                                                ? () async {
                                                    final sizesForPackage = <String, String>{};
                                                    for (final m in merch) {
                                                      if (m is Map) {
                                                        final n = m['name']?.toString() ?? '';
                                                        if (currentSizes[n] != null) sizesForPackage[n] = currentSizes[n]!;
                                                      }
                                                    }
                                                    await _savePackage(userId, pkgName, sizesForPackage, price);
                                                    if (mounted) Navigator.pop(ctx);
                                                  }
                                                : null,
                                            icon: const Icon(Icons.add_shopping_cart, size: 20),
                                            label: Text('Выбрать', style: unbounded(fontSize: 15, fontWeight: FontWeight.w600)),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppColors.mutedGold,
                                              side: const BorderSide(color: AppColors.mutedGold, width: 2),
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        },
      ),
    );
  }

  Widget _buildPaymentLink(String url) {
    final uri = Uri.tryParse(url.startsWith('http') ? url : '$_baseUrl$url');
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text('Ссылка на оплату', style: unbounded(color: Colors.white)),
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('QR-код для оплаты', style: unbounded(color: Colors.white, fontWeight: FontWeight.w600)),
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

  Widget _buildReceiptUpload({bool groupReceipt = false}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              groupReceipt ? 'Загрузить чек за всю группу' : 'Загрузить чек',
              style: unbounded(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text('JPEG, PNG или PDF. Макс. 10 МБ', style: unbounded(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
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
                  label: Text('Галерея', style: unbounded(fontSize: 13)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.rowAlt, foregroundColor: Colors.white),
                ),
                ElevatedButton.icon(
                  onPressed: _isUploadingReceipt
                      ? null
                      : () => groupReceipt
                          ? _pickFile(group: true)
                          : _showReceiptUserPicker(isFile: true),
                  icon: const Icon(Icons.attach_file),
                  label: Text('Файл', style: unbounded(fontSize: 13)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.rowAlt, foregroundColor: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showReceiptSourcePicker({required int userId}) async {
    final choice = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: AppColors.cardDark,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Загрузить чек', style: unbounded(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.mutedGold),
                title: Text('Галерея', style: unbounded(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
              ListTile(
                leading: const Icon(Icons.attach_file, color: AppColors.mutedGold),
                title: Text('Файл', style: unbounded(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, 'file'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == 'gallery') {
      await _pickImage(userId: userId);
    } else if (choice == 'file') {
      await _pickFile(userId: userId);
    }
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
      backgroundColor: AppColors.cardDark,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Выберите участника для чека', style: unbounded(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
              ),
              ...unpaid.map((g) {
                if (g is! Map) return const SizedBox.shrink();
                final uid = g['user_id'];
                final id = uid is int ? uid : int.tryParse(uid?.toString() ?? '');
                if (id == null) return const SizedBox.shrink();
                final name = '${g['middlename'] ?? ''} ${g['firstname'] ?? ''} ${g['lastname'] ?? ''}'.trim();
                return ListTile(
                  leading: Icon(Icons.person, color: AppColors.mutedGold),
                  title: Text(name.isEmpty ? 'Участник #$id' : name, style: unbounded(color: Colors.white, fontSize: 15)),
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
              title: Text('Оплата на месте', style: unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
              content: Text('Вы уверены, что хотите оплатить на месте за всю группу?', style: unbounded(color: Colors.white70)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Отмена', style: unbounded(color: AppColors.mutedGold))),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Да', style: unbounded(color: AppColors.mutedGold))),
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
          foregroundColor: AppColors.mutedGold,
          side: const BorderSide(color: AppColors.mutedGold),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text('Оплатить на месте', style: unbounded(fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Оформление группы', style: unbounded(fontWeight: FontWeight.w500, fontSize: 18, color: Colors.white)), backgroundColor: AppColors.cardDark),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      if (!_showingErrorModal) {
        _showingErrorModal = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _error == null) return;
          showErrorReportModal(
            context,
            message: _error!,
            screen: 'group-checkout',
            eventId: widget.eventId,
            stackTrace: _errorStackTrace,
            extra: _errorExtra,
            onRetry: () {
              setState(() {
                _error = null;
                _errorStackTrace = null;
                _errorExtra = null;
                _isLoading = true;
                _showingErrorModal = false;
              });
              _loadData();
            },
          ).then((_) {
            if (mounted) setState(() => _showingErrorModal = false);
          });
        });
      }
      return Scaffold(
        appBar: AppBar(
          title: Text('Оформление группы', style: unbounded(fontWeight: FontWeight.w500, fontSize: 18, color: Colors.white)),
          backgroundColor: AppColors.cardDark,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        ),
        body: const Center(child: CircularProgressIndicator()),
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
        title: Text('Оформление группы', style: unbounded(fontWeight: FontWeight.w500, fontSize: 18, color: Colors.white)),
        backgroundColor: AppColors.cardDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [],
      ),
      body: Container(
        color: AppColors.anthracite,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (eventTitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  eventTitle,
                  style: unbounded(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            Material(
              color: const Color(0xFF1E3A5F).withOpacity(0.4),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GroupDocumentsScreen(
                        eventId: widget.eventId,
                        eventTitle: eventTitle,
                      ),
                    ),
                  );
                  if (mounted) _loadData(silent: true);
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Icon(Icons.description, color: AppColors.mutedGold, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Документы участников',
                              style: unbounded(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Загрузить документы для участников группы',
                              style: unbounded(color: Colors.white70, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (groupIsNotPaid) ...[
              _buildHowToPayGroup(),
              const SizedBox(height: 16),
            ],
            Text(
              'Участники группы',
              style: unbounded(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(height: 12),
            ...group.map((g) => _buildParticipantCard(g as Map<String, dynamic>, packages)),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('Итого (неоплаченные):', style: unbounded(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_calcTotalSum()} ₽',
                    style: unbounded(color: AppColors.mutedGold, fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ],
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
                    backgroundColor: AppColors.mutedGold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Перейти к оплате или прикрепить чек', style: unbounded(fontWeight: FontWeight.w600)),
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
    final setStr = setInfo is Map ? 'Сет №${setInfo['number_set'] ?? ''} ${setInfo['time'] ?? ''}' : '';
    final catInfo = participant['participant_category'];
    final catStr = catInfo is Map ? (catInfo['category']?.toString() ?? '') : '';
    final isPaid = participant['is_paid'] == true;
    final hasReceipt = participant['has_receipt'] == true ||
        participant['receipt_attached'] == true ||
        participant['receipt_uploaded'] == true ||
        participant['receipt_pending'] == true ||
        (participant['receipt_file_id'] != null && participant['receipt_file_id'].toString().isNotEmpty) ||
        (participant['receipt_id'] != null && participant['receipt_id'].toString().isNotEmpty) ||
        (participant['receipts'] is List && (participant['receipts'] as List).isNotEmpty);
    final spRaw = participant['selected_package'];
    String? currentPkg = uid != null ? _selectedPackageByUser[uid] : null;
    if (currentPkg == null && spRaw is List && spRaw.isNotEmpty && spRaw.first is Map) {
      final first = spRaw.first as Map;
      currentPkg = first['package_name']?.toString() ?? first['name']?.toString();
    }

    final statusText = isPaid
        ? 'Оплачено'
        : (currentPkg != null && currentPkg.isNotEmpty ? 'Пакет: $currentPkg' : 'Выбрать пакет');
    final needsPackageSelection = !isPaid && uid != null && packages.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          collapsedBackgroundColor: AppColors.cardDark,
          backgroundColor: AppColors.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(isPaid ? Icons.check_circle : Icons.person, color: isPaid ? Colors.green : AppColors.mutedGold, size: 28),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name.isEmpty ? 'Участник' : name, style: unbounded(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
            if (setStr.isNotEmpty) Text(setStr, style: unbounded(color: Colors.white70, fontSize: 12)),
            if (catStr.isNotEmpty) Text(catStr, style: unbounded(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          statusText,
                          style: unbounded(
                            color: isPaid ? Colors.green : (currentPkg != null ? Colors.white70 : AppColors.mutedGold),
                            fontSize: 13,
                            fontWeight: isPaid ? FontWeight.w500 : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasReceipt) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.receipt_long, color: Colors.orange, size: 18),
                        const SizedBox(width: 4),
                        Text('На проверке', style: unbounded(color: Colors.orange, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
                if (needsPackageSelection) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      if (uid != null) _showPackageSelectorModal(uid, participant, packages);
                    },
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: Text(
                      currentPkg != null ? 'Изменить' : 'Выбрать',
                      style: unbounded(color: AppColors.mutedGold, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        children: [
          if (!isPaid && uid != null) ...[
            if (!hasReceipt)
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _isUploadingReceipt ? null : () => _showReceiptSourcePicker(userId: uid),
                    icon: _isUploadingReceipt ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.receipt_long, size: 18),
                    label: Text('Чек', style: unbounded(fontSize: 13)),
                    style: TextButton.styleFrom(foregroundColor: AppColors.mutedGold),
                  ),
                ],
              ),
            if (needsPackageSelection)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showPackageSelectorModal(uid, participant, packages),
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: Text(currentPkg != null ? 'Изменить пакет' : 'Выбрать пакет', style: unbounded(fontSize: 14)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.mutedGold,
                      side: const BorderSide(color: AppColors.mutedGold),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    ),
    );
  }
}
