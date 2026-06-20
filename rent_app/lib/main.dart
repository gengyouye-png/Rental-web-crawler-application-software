import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const RentCrawlerApp());
}

class RentCrawlerApp extends StatelessWidget {
  const RentCrawlerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '租屋搜尋儀表板',
      theme: ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF6F8FA),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFFFF),
          foregroundColor: Color(0xFF111827),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
          ),
        ),
      ),
      home: const RentDashboardPage(),
    );
  }
}

class RentDashboardPage extends StatefulWidget {
  const RentDashboardPage({super.key});

  @override
  State<RentDashboardPage> createState() => _RentDashboardPageState();
}

class _RentDashboardPageState extends State<RentDashboardPage> {
  static const _usbApiBase = 'http://127.0.0.1:5000';

  final _apiBaseController = TextEditingController(text: _usbApiBase);
  final _cityController = TextEditingController(text: '台中');
  final _districtController = TextEditingController(text: '西屯區');
  final _kindController = TextEditingController(text: '獨立套房');
  final _minPriceController = TextEditingController(text: '5000');
  final _maxPriceController = TextEditingController(text: '10000');
  final _maxPagesController = TextEditingController(text: '1');
  final _keywordController = TextEditingController();

  bool _subsidy = false;
  bool _loadingHouses = false;
  bool _startingCrawl = false;
  bool _checkingHealth = false;
  String _connectionMode = 'usb';
  String? _error;
  String? _healthText;
  Timer? _jobTimer;

  List<House> _houses = [];
  House? _selectedHouse;
  CrawlJob? _job;
  HouseStats? _stats;
  int _total = 0;
  int _offset = 0;
  final int _limit = 10;

  String get _apiBase =>
      _apiBaseController.text.trim().replaceAll(RegExp(r'/+$'), '');

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _jobTimer?.cancel();
    _apiBaseController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _kindController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _maxPagesController.dispose();
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _loadConnectionSettings();
    await _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final connected = await _checkHealth();
    if (!connected) return;

    await Future.wait([
      _fetchStats(),
      _fetchHouses(reset: true),
      _fetchLatestJob(),
    ]);
  }

  Future<void> _loadConnectionSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('connectionMode') ?? 'usb';
    final apiBase = prefs.getString('apiBase') ?? _usbApiBase;

    setState(() {
      _connectionMode = mode;
      _apiBaseController.text = mode == 'usb' ? _usbApiBase : apiBase;
    });
  }

  Future<void> _saveConnectionSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('connectionMode', _connectionMode);
    await prefs.setString('apiBase', _apiBase);
  }

  Future<void> _useUsbMode() async {
    setState(() {
      _connectionMode = 'usb';
      _apiBaseController.text = _usbApiBase;
      _error = null;
    });
    await _saveConnectionSettings();
    await _loadInitialData();
  }

  Future<void> _useCustomMode() async {
    setState(() {
      _connectionMode = 'custom';
      _error = null;
    });
    await _saveConnectionSettings();
  }

  Future<bool> _checkHealth() async {
    setState(() {
      _checkingHealth = true;
      _healthText = '檢查中';
    });

    try {
      final data = await _getJson('/api/health');
      final connected = data['ok'] == true;
      setState(() {
        _healthText = connected ? 'API 已連線' : 'API 異常';
        if (connected) {
          _error = null;
        }
      });
      return connected;
    } catch (error) {
      setState(() {
        _healthText = 'API 未連線';
        _error = _connectionMode == 'usb'
            ? 'USB 模式未連線。請確認 Flask 已啟動，並執行 adb reverse tcp:5000 tcp:5000。'
            : error.toString();
      });
      return false;
    } finally {
      setState(() => _checkingHealth = false);
    }
  }

  Future<void> _fetchLatestJob() async {
    try {
      final data = await _getJson('/api/crawl/latest');
      final jobData = data['job'];
      if (jobData is Map<String, dynamic>) {
        setState(() => _job = CrawlJob.fromJson(jobData));
        _startPollingIfNeeded();
      }
    } catch (_) {
      // Health check already surfaces connection errors.
    }
  }

  Future<void> _fetchStats() async {
    try {
      final data = await _getJson('/api/houses/stats');
      setState(() => _stats = HouseStats.fromJson(data));
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  Future<void> _fetchHouses({bool reset = false}) async {
    if (_loadingHouses) return;

    final nextOffset = reset ? 0 : _offset;
    final query = {
      'limit': _limit.toString(),
      'offset': nextOffset.toString(),
      if (_cityController.text.trim().isNotEmpty)
        'city': _cityController.text.trim(),
      if (_districtController.text.trim().isNotEmpty)
        'district': _districtController.text.trim(),
      if (_keywordController.text.trim().isNotEmpty)
        'keyword': _keywordController.text.trim(),
    };

    setState(() {
      _loadingHouses = true;
      _error = null;
    });

    try {
      final data = await _getJson('/api/houses', query);
      final items = (data['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(House.fromJson)
          .toList();

      setState(() {
        _houses = items;
        _selectedHouse = items.isEmpty ? null : items.first;
        _total = data['total'] as int? ?? items.length;
        _offset = nextOffset;
      });
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      setState(() => _loadingHouses = false);
    }
  }

  void _goToPreviousPage() {
    if (_loadingHouses || _offset == 0) return;

    setState(() {
      _offset = (_offset - _limit).clamp(0, _total);
    });
    _fetchHouses();
  }

  void _goToNextPage() {
    if (_loadingHouses || _offset + _limit >= _total) return;

    setState(() {
      _offset += _limit;
    });
    _fetchHouses();
  }

  Future<void> _startCrawl() async {
    if (_startingCrawl) return;

    setState(() {
      _startingCrawl = true;
      _error = null;
    });

    try {
      final data = await _postJson('/api/crawl', {
        'city': _cityController.text.trim(),
        'district': _districtController.text.trim(),
        'kind_text': _kindController.text.trim(),
        'min_price': int.tryParse(_minPriceController.text.trim()) ?? 5000,
        'max_price': int.tryParse(_maxPriceController.text.trim()) ?? 10000,
        'max_pages': int.tryParse(_maxPagesController.text.trim()) ?? 1,
        'subsidy': _subsidy,
      });

      setState(() {
        _job = CrawlJob.fromJson(data['job']);
        if (data['error'] == 'crawler_is_running') {
          _error = '爬蟲已在執行，已接上目前任務狀態。';
        }
      });
      _startPollingIfNeeded();
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      setState(() => _startingCrawl = false);
    }
  }

  void _startPollingIfNeeded() {
    _jobTimer?.cancel();
    if (_job == null || !_job!.isActive) return;

    _jobTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final job = _job;
      if (job == null) return;

      try {
        final data = await _getJson('/api/crawl/${job.id}');
        final updated = CrawlJob.fromJson(data['job']);
        setState(() => _job = updated);

        if (!updated.isActive) {
          _jobTimer?.cancel();
          await Future.wait([_fetchStats(), _fetchHouses(reset: true)]);
        }
      } catch (error) {
        setState(() => _error = error.toString());
      }
    });
  }

  Future<Map<String, dynamic>> _getJson(
    String path, [
    Map<String, String>? query,
  ]) async {
    final uri = Uri.parse('$_apiBase$path').replace(queryParameters: query);
    final response = await http.get(uri).timeout(const Duration(seconds: 6));
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$_apiBase$path');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 6));
    return _decodeResponse(response);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded as Map<String, dynamic>;
    }

    if (response.statusCode == 409 &&
        decoded is Map<String, dynamic> &&
        decoded['error'] == 'crawler_is_running' &&
        decoded['job'] is Map<String, dynamic>) {
      return decoded;
    }

    final message = decoded is Map<String, dynamic>
        ? decoded['error'] ?? decoded['errors'] ?? 'HTTP ${response.statusCode}'
        : 'HTTP ${response.statusCode}';
    throw Exception(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '租屋搜尋儀表板',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          _StatusPill(
            label: _healthText ?? '檢查中',
            color: _healthText == 'API 已連線'
                ? const Color(0xFF0F766E)
                : const Color(0xFFE11D48),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;
          if (compact) {
            return _buildCompactLayout();
          }
          return _buildDesktopLayout();
        },
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 300, child: _buildSearchPanel()),
          const SizedBox(width: 16),
          Expanded(
            flex: 5,
            child: Column(
              children: [
                _buildStatsRow(),
                const SizedBox(height: 12),
                Expanded(child: _buildHouseList()),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(width: 360, child: _HouseDetailPanel(house: _selectedHouse)),
        ],
      ),
    );
  }

  Widget _buildCompactLayout() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSearchPanel(),
        const SizedBox(height: 12),
        _buildStatsRow(),
        const SizedBox(height: 12),
        SizedBox(height: 520, child: _buildHouseList()),
        const SizedBox(height: 12),
        _HouseDetailPanel(house: _selectedHouse),
      ],
    );
  }

  Widget _buildSearchPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '搜尋與爬蟲',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            _buildConnectionBox(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cityController,
                    decoration: const InputDecoration(labelText: '縣市'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _districtController,
                    decoration: const InputDecoration(labelText: '地區'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _kindController,
              decoration: const InputDecoration(labelText: '房型'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '最低租金'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _maxPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '最高租金'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _maxPagesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '每站頁數'),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _subsidy,
              onChanged: (value) => setState(() => _subsidy = value),
              title: const Text('只看可租補'),
            ),
            const Divider(height: 24),
            TextField(
              controller: _keywordController,
              decoration: const InputDecoration(
                labelText: '列表關鍵字',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (_) => _fetchHouses(reset: true),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _startingCrawl || (_job?.isActive ?? false)
                  ? null
                  : _startCrawl,
              icon: _startingCrawl
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.travel_explore),
              label: const Text('開始爬蟲'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _loadingHouses
                  ? null
                  : () => _fetchHouses(reset: true),
              icon: const Icon(Icons.refresh),
              label: const Text('重新整理列表'),
            ),
            const SizedBox(height: 16),
            _JobStatusCard(job: _job),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _ErrorBox(message: _error!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionBox() {
    final isUsb = _connectionMode == 'usb';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.usb, color: Color(0xFF0F766E)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '連線設定',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              _StatusPill(
                label: isUsb ? 'USB' : '自訂',
                color: isUsb
                    ? const Color(0xFF0F766E)
                    : const Color(0xFF2563EB),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'usb',
                icon: Icon(Icons.usb),
                label: Text('USB'),
              ),
              ButtonSegment(
                value: 'custom',
                icon: Icon(Icons.edit),
                label: Text('自訂'),
              ),
            ],
            selected: {_connectionMode},
            onSelectionChanged: (selected) {
              if (selected.first == 'usb') {
                _useUsbMode();
              } else {
                _useCustomMode();
              }
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _apiBaseController,
            readOnly: isUsb,
            decoration: InputDecoration(
              labelText: 'API 伺服器',
              prefixIcon: const Icon(Icons.dns_outlined),
              helperText: isUsb
                  ? '手機透過 USB 轉接到電腦 Flask'
                  : '輸入 Wi-Fi 或其他 Flask 位址',
            ),
            onSubmitted: (_) async {
              await _saveConnectionSettings();
              await _loadInitialData();
            },
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _checkingHealth
                ? null
                : () async {
                    await _saveConnectionSettings();
                    await _loadInitialData();
                  },
            icon: _checkingHealth
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_tethering),
            label: const Text('測試連線'),
          ),
          const SizedBox(height: 8),
          const Text(
            'USB 模式需在電腦執行：adb reverse tcp:5000 tcp:5000',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final stats = _stats;
    final firstSource = stats?.bySource.isNotEmpty == true
        ? stats!.bySource.first
        : null;
    final secondSource = stats?.bySource.length == 2
        ? stats!.bySource[1]
        : null;

    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: '總房源',
            value: '${stats?.total ?? _total}',
            icon: Icons.home_work_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            label: firstSource?.label ?? '主要來源',
            value: '${firstSource?.count ?? 0}',
            icon: Icons.public,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            label: secondSource?.label ?? '其他來源',
            value: '${secondSource?.count ?? 0}',
            icon: Icons.view_list_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildHouseList() {
    final start = _total == 0 ? 0 : _offset + 1;
    final end = (_offset + _houses.length).clamp(0, _total);
    final page = _total == 0 ? 0 : (_offset ~/ _limit) + 1;
    final pageCount = _total == 0 ? 0 : ((_total - 1) ~/ _limit) + 1;
    final canGoPrevious = _offset > 0 && !_loadingHouses;
    final canGoNext = _offset + _limit < _total && !_loadingHouses;

    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '房源列表',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusPill(label: '$_total 筆', color: const Color(0xFF0F766E)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _PaginationControls(
              start: start,
              end: end,
              total: _total,
              page: page,
              pageCount: pageCount,
              canGoPrevious: canGoPrevious,
              canGoNext: canGoNext,
              onPrevious: _goToPreviousPage,
              onNext: _goToNextPage,
              dense: true,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loadingHouses
                ? const Center(child: CircularProgressIndicator())
                : _houses.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                    itemCount: _houses.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final house = _houses[index];
                      return _HouseListTile(
                        house: house,
                        selected: house.id == _selectedHouse?.id,
                        onTap: () => setState(() => _selectedHouse = house),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canGoPrevious ? _goToPreviousPage : null,
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('上一頁'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: canGoNext ? _goToNextPage : null,
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('下一頁'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class House {
  House({
    required this.id,
    required this.source,
    required this.city,
    required this.district,
    required this.title,
    required this.price,
    required this.priceNumber,
    required this.deposit,
    required this.address,
    required this.area,
    required this.roomType,
    required this.floor,
    required this.link,
    required this.createdAt,
  });

  final int id;
  final String source;
  final String city;
  final String district;
  final String title;
  final String price;
  final int? priceNumber;
  final String deposit;
  final String address;
  final String area;
  final String roomType;
  final String floor;
  final String link;
  final String createdAt;

  factory House.fromJson(Map<String, dynamic> json) {
    return House(
      id: json['id'] as int? ?? 0,
      source: _readString(json, '來源'),
      city: _readString(json, '縣市'),
      district: _readString(json, '地區'),
      title: _readString(json, '標題'),
      price: _readString(json, '租金'),
      priceNumber: json['租金數字'] as int?,
      deposit: _readString(json, '押金'),
      address: _readString(json, '地址'),
      area: _readString(json, '坪數'),
      roomType: _readString(json, '房型'),
      floor: _readString(json, '樓層'),
      link: _readString(json, '連結'),
      createdAt: _readString(json, '建立時間'),
    );
  }
}

class CrawlJob {
  CrawlJob({
    required this.id,
    required this.status,
    this.result,
    this.error,
    required this.progress,
    this.createdAt = '',
    this.startedAt,
    this.finishedAt,
  });

  final String id;
  final String status;
  final Map<String, dynamic>? result;
  final Map<String, dynamic>? error;
  final CrawlProgress progress;
  final String createdAt;
  final String? startedAt;
  final String? finishedAt;

  bool get isActive => status == 'pending' || status == 'running';

  factory CrawlJob.fromJson(Map<String, dynamic> json) {
    return CrawlJob(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'unknown',
      result: json['result'] is Map<String, dynamic> ? json['result'] : null,
      error: json['error'] is Map<String, dynamic> ? json['error'] : null,
      progress: CrawlProgress.fromJson(
        json['progress'] is Map<String, dynamic> ? json['progress'] : null,
      ),
      createdAt: json['created_at']?.toString() ?? '',
      startedAt: json['started_at']?.toString(),
      finishedAt: json['finished_at']?.toString(),
    );
  }
}

class CrawlProgress {
  CrawlProgress({
    required this.current,
    required this.total,
    required this.percent,
    required this.source,
    required this.message,
  });

  final int current;
  final int total;
  final int percent;
  final String source;
  final String message;

  factory CrawlProgress.fromJson(Map<String, dynamic>? json) {
    return CrawlProgress(
      current: json?['current'] as int? ?? 0,
      total: json?['total'] as int? ?? 0,
      percent: json?['percent'] as int? ?? 0,
      source: json?['source']?.toString() ?? '',
      message: json?['message']?.toString() ?? '',
    );
  }
}

class HouseStats {
  HouseStats({required this.total, required this.bySource});

  final int total;
  final List<StatItem> bySource;

  factory HouseStats.fromJson(Map<String, dynamic> json) {
    final bySource = (json['by_source'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => StatItem(
            label: item['source']?.toString() ?? '未分類',
            count: item['count'] as int? ?? 0,
          ),
        )
        .toList();

    return HouseStats(total: json['total'] as int? ?? 0, bySource: bySource);
  }
}

class StatItem {
  StatItem({required this.label, required this.count});

  final String label;
  final int count;
}

class _PaginationControls extends StatelessWidget {
  const _PaginationControls({
    required this.start,
    required this.end,
    required this.total,
    required this.page,
    required this.pageCount,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
    this.dense = false,
  });

  final int start;
  final int end;
  final int total;
  final int page;
  final int pageCount;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 10 : 12,
        vertical: dense ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          IconButton.filledTonal(
            tooltip: '上一頁',
            onPressed: canGoPrevious ? onPrevious : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  total == 0 ? '沒有資料' : '第 $page / $pageCount 頁',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  total == 0 ? '請重新整理或開始爬蟲' : '顯示 $start-$end，共 $total 筆',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filled(
            tooltip: '下一頁',
            onPressed: canGoNext ? onNext : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF0F766E)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Color(0xFF6B7280))),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HouseListTile extends StatelessWidget {
  const _HouseListTile({
    required this.house,
    required this.selected,
    required this.onTap,
  });

  final House house;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFE6F4F1) : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SourceBadge(source: house.source),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      house.title.isEmpty ? '未命名房源' : house.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    house.price.isEmpty ? '-' : house.price,
                    style: const TextStyle(
                      color: Color(0xFFE11D48),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _joinParts([
                  house.district,
                  house.address,
                  house.area,
                  house.roomType,
                  house.floor,
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HouseDetailPanel extends StatelessWidget {
  const _HouseDetailPanel({required this.house});

  final House? house;

  @override
  Widget build(BuildContext context) {
    final selected = house;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: selected == null
            ? const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '房源詳情',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 24),
                  _EmptyDetail(),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _SourceBadge(source: selected.source),
                      const Spacer(),
                      Text(
                        '#${selected.id}',
                        style: const TextStyle(color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    selected.title.isEmpty ? '未命名房源' : selected.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    selected.price.isEmpty ? '-' : selected.price,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFE11D48),
                    ),
                  ),
                  const Divider(height: 28),
                  _DetailRow(label: '地址', value: selected.address),
                  _DetailRow(
                    label: '地區',
                    value: _joinParts([selected.city, selected.district]),
                  ),
                  _DetailRow(label: '坪數', value: selected.area),
                  _DetailRow(label: '房型', value: selected.roomType),
                  _DetailRow(label: '樓層', value: selected.floor),
                  _DetailRow(label: '押金', value: selected.deposit),
                  _DetailRow(label: '建立時間', value: selected.createdAt),
                  const Spacer(),
                  if (selected.link.isNotEmpty)
                    SelectableText(
                      selected.link,
                      style: const TextStyle(
                        color: Color(0xFF0F766E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _JobStatusCard extends StatelessWidget {
  const _JobStatusCard({required this.job});

  final CrawlJob? job;

  @override
  Widget build(BuildContext context) {
    final current = job;
    final status = current?.status ?? 'idle';
    final color = switch (status) {
      'done' => const Color(0xFF0F766E),
      'failed' => const Color(0xFFE11D48),
      'running' => const Color(0xFF2563EB),
      'pending' => const Color(0xFFD97706),
      _ => const Color(0xFF6B7280),
    };
    final result = current?.result;
    final inserted = result?['inserted'];
    final total = result?['total'];
    final progress = current?.progress;
    final progressValue = progress == null
        ? 0.0
        : (progress.percent.clamp(0, 100) / 100).toDouble();
    final message = status == 'idle'
        ? '尚未啟動爬蟲'
        : progress?.message.isNotEmpty == true
        ? progress!.message
        : status;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                progress == null || progress.total == 0
                    ? status
                    : '${progress.percent}%',
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (current?.isActive == true || status == 'done') ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progressValue == 0 && current?.isActive == true
                  ? null
                  : progressValue,
              minHeight: 8,
              borderRadius: BorderRadius.circular(999),
            ),
            const SizedBox(height: 8),
            Text(
              progress == null || progress.total == 0
                  ? '等待進度回報'
                  : '來源：${progress.source.isEmpty ? '整理資料' : progress.source} · ${progress.current}/${progress.total}',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
          ],
          if (inserted != null) ...[
            const SizedBox(height: 6),
            Text(
              '新增 $inserted 筆，整理 $total 筆',
              style: const TextStyle(
                color: Color(0xFF374151),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F4F1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        source.isEmpty ? '來源' : source,
        style: const TextStyle(
          color: Color(0xFF0F766E),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFF991B1B),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 40, color: Color(0xFF9CA3AF)),
          SizedBox(height: 12),
          Text('目前沒有符合條件的房源', style: TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: const [
          Icon(Icons.home_outlined, size: 44, color: Color(0xFF9CA3AF)),
          SizedBox(height: 12),
          Text('選取列表中的房源查看詳情'),
        ],
      ),
    );
  }
}

String _readString(Map<String, dynamic> json, String key) {
  return json[key]?.toString() ?? '';
}

String _joinParts(List<String> parts) {
  return parts.where((part) => part.trim().isNotEmpty).join(' · ');
}
