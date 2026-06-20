import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'map_embed_stub.dart' if (dart.library.html) 'map_embed_web.dart';
import 'url_opener_stub.dart' if (dart.library.html) 'url_opener_web.dart';

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
      home: const AppIntroGate(),
    );
  }
}

class AppIntroGate extends StatefulWidget {
  const AppIntroGate({super.key});

  @override
  State<AppIntroGate> createState() => _AppIntroGateState();
}

class _AppIntroGateState extends State<AppIntroGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _showDashboard = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();

    Timer(const Duration(milliseconds: 1700), () {
      if (!mounted) return;
      setState(() => _showDashboard = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 520),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _showDashboard
          ? const RentDashboardPage(key: ValueKey('dashboard'))
          : _StartupIntroPage(
              key: const ValueKey('intro'),
              animation: _controller,
            ),
    );
  }
}

class _StartupIntroPage extends StatelessWidget {
  const _StartupIntroPage({super.key, required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(fade);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      body: Center(
        child: FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: slide,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    final value = Curves.easeOutBack.transform(
                      animation.value.clamp(0.0, 1.0),
                    );
                    return Transform.scale(
                      scale: 0.86 + value * 0.14,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F4F1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFB7E0D8)),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(
                          Icons.home_work_outlined,
                          color: Color(0xFF0F766E),
                          size: 44,
                        ),
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: animation,
                            builder: (context, _) {
                              return CustomPaint(
                                painter: _IntroScanPainter(animation.value),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  '租屋搜尋儀表板',
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '正在整理最新房源',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: 220,
                  child: AnimatedBuilder(
                    animation: animation,
                    builder: (context, _) {
                      return LinearProgressIndicator(
                        value: animation.value.clamp(0.0, 1.0),
                        minHeight: 7,
                        borderRadius: BorderRadius.circular(999),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroScanPainter extends CustomPainter {
  _IntroScanPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final scanY = size.height * (0.18 + progress * 0.62);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: const [Color(0x000F766E), Color(0x660F766E), Color(0x000F766E)],
        stops: const [0, 0.5, 1],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(16, scanY - 10, size.width - 32, 20));

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(16, scanY - 10, size.width - 32, 20),
        const Radius.circular(999),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _IntroScanPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class RentDashboardPage extends StatefulWidget {
  const RentDashboardPage({super.key});

  @override
  State<RentDashboardPage> createState() => _RentDashboardPageState();
}

class _RentDashboardPageState extends State<RentDashboardPage> {
  static const _localApiBase = 'http://127.0.0.1:5000';
  static String get _webApiBase =>
      Uri.base.origin == 'null' ? _localApiBase : Uri.base.origin;
  static String get _defaultApiBase => kIsWeb ? _webApiBase : _localApiBase;
  static String get _defaultConnectionMode => kIsWeb ? 'web' : 'usb';

  final _apiBaseController = TextEditingController(text: _defaultApiBase);
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _kindController = TextEditingController();
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();
  final _maxPagesController = TextEditingController(text: '1');
  final _keywordController = TextEditingController();

  bool _subsidy = false;
  bool _loadingHouses = false;
  bool _loadingTrends = false;
  bool _startingCrawl = false;
  bool _checkingHealth = false;
  String _connectionMode = _defaultConnectionMode;
  String _sortMode = 'newest';
  String _viewMode = 'cards';
  String? _error;
  String? _healthText;
  String? _searchStatusText;
  Timer? _jobTimer;

  List<House> _houses = [];
  House? _selectedHouse;
  CrawlJob? _job;
  HouseStats? _stats;
  TrendData? _trends;
  PriceDistribution? _priceDistribution;
  Set<String> _favoriteKeys = {};
  int _total = 0;
  int _offset = 0;
  final int _limit = 20;

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
    await _loadFavoriteKeys();
    await _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final connected = await _checkHealth();
    if (!connected) return;

    await Future.wait([
      _fetchStats(),
      _fetchTrends(),
      _fetchPriceDistribution(),
      _fetchHouses(reset: true),
      _fetchLatestJob(),
    ]);
  }

  Future<void> _loadConnectionSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString('connectionMode');
    final mode = kIsWeb && savedMode == 'usb'
        ? 'web'
        : savedMode ?? _defaultConnectionMode;
    final apiBase = prefs.getString('apiBase') ?? _defaultApiBase;

    setState(() {
      _connectionMode = mode;
      _apiBaseController.text = switch (mode) {
        'web' => _webApiBase,
        'usb' => _localApiBase,
        _ => apiBase,
      };
    });
  }

  Future<void> _saveConnectionSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('connectionMode', _connectionMode);
    await prefs.setString('apiBase', _apiBase);
  }

  Future<void> _loadFavoriteKeys() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoriteKeys = (prefs.getStringList('favoriteHouseKeys') ?? []).toSet();
    });
  }

  Future<void> _saveFavoriteKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favoriteHouseKeys', _favoriteKeys.toList());
  }

  Future<void> _useWebMode() async {
    setState(() {
      _connectionMode = 'web';
      _apiBaseController.text = _webApiBase;
      _error = null;
    });
    await _saveConnectionSettings();
    await _loadInitialData();
  }

  Future<void> _useUsbMode() async {
    setState(() {
      _connectionMode = 'usb';
      _apiBaseController.text = _localApiBase;
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
        _error = switch (_connectionMode) {
          'web' => '公開網站模式無法連線到同網域 API，請確認後端服務已啟動且 /api/health 可存取。',
          'usb' => 'USB 模式未連線。請確認 Flask 已啟動，並執行 adb reverse tcp:5000 tcp:5000。',
          _ => error.toString(),
        };
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

  Future<void> _fetchTrends() async {
    if (_loadingTrends) return;

    final query = {
      'days': '30',
      if (_cityController.text.trim().isNotEmpty)
        'city': _cityController.text.trim(),
      if (_districtController.text.trim().isNotEmpty)
        'district': _districtController.text.trim(),
      if (_kindController.text.trim().isNotEmpty)
        'kind': _kindController.text.trim(),
      if (_minPriceController.text.trim().isNotEmpty)
        'min_price': _minPriceController.text.trim(),
      if (_maxPriceController.text.trim().isNotEmpty)
        'max_price': _maxPriceController.text.trim(),
      if (_keywordController.text.trim().isNotEmpty)
        'keyword': _keywordController.text.trim(),
    };

    setState(() {
      _loadingTrends = true;
      _searchStatusText ??= '正在更新租金趨勢';
    });

    try {
      final data = await _getJson('/api/houses/trends', query);
      setState(() => _trends = TrendData.fromJson(data));
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      setState(() => _loadingTrends = false);
    }
  }

  Future<void> _fetchPriceDistribution() async {
    final query = {
      if (_cityController.text.trim().isNotEmpty)
        'city': _cityController.text.trim(),
      if (_districtController.text.trim().isNotEmpty)
        'district': _districtController.text.trim(),
      if (_kindController.text.trim().isNotEmpty)
        'kind': _kindController.text.trim(),
      if (_minPriceController.text.trim().isNotEmpty)
        'min_price': _minPriceController.text.trim(),
      if (_maxPriceController.text.trim().isNotEmpty)
        'max_price': _maxPriceController.text.trim(),
      if (_keywordController.text.trim().isNotEmpty)
        'keyword': _keywordController.text.trim(),
    };

    try {
      final data = await _getJson('/api/houses/price-distribution', query);
      setState(() => _priceDistribution = PriceDistribution.fromJson(data));
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
      'sort': _sortMode,
      if (_cityController.text.trim().isNotEmpty)
        'city': _cityController.text.trim(),
      if (_districtController.text.trim().isNotEmpty)
        'district': _districtController.text.trim(),
      if (_kindController.text.trim().isNotEmpty)
        'kind': _kindController.text.trim(),
      if (_minPriceController.text.trim().isNotEmpty)
        'min_price': _minPriceController.text.trim(),
      if (_maxPriceController.text.trim().isNotEmpty)
        'max_price': _maxPriceController.text.trim(),
      if (_keywordController.text.trim().isNotEmpty)
        'keyword': _keywordController.text.trim(),
    };

    setState(() {
      _loadingHouses = true;
      _error = null;
      _searchStatusText = reset ? '正在搜尋符合條件的房源' : '正在載入分頁';
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
        _searchStatusText = items.isEmpty
            ? '搜尋完成，沒有符合條件的房源'
            : '搜尋完成，找到 $_total 筆房源';
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
        _searchStatusText = '搜尋失敗';
      });
    } finally {
      setState(() => _loadingHouses = false);
    }
  }

  Future<void> _searchHouses() async {
    if (_loadingHouses || _loadingTrends) return;

    setState(() {
      _error = null;
      _searchStatusText = '開始搜尋';
    });

    await Future<void>.delayed(const Duration(milliseconds: 120));

    try {
      await Future.wait([
        _fetchStats(),
        _fetchTrends(),
        _fetchPriceDistribution(),
        _fetchHouses(reset: true),
      ]);
    } finally {
      if (mounted) {
        Future<void>.delayed(const Duration(seconds: 3), () {
          if (!mounted || _loadingHouses || _loadingTrends) return;
          if (_searchStatusText?.startsWith('搜尋完成') == true) {
            setState(() => _searchStatusText = null);
          }
        });
      }
    }
  }

  Future<void> _clearSearchFilters() async {
    _cityController.clear();
    _districtController.clear();
    _kindController.clear();
    _minPriceController.clear();
    _maxPriceController.clear();
    _keywordController.clear();
    await _searchHouses();
  }

  Future<void> _changeSortMode(String sortMode) async {
    if (_sortMode == sortMode) return;

    setState(() => _sortMode = sortMode);
    await _searchHouses();
  }

  Future<void> _toggleFavorite(House house) async {
    final key = house.favoriteKey;
    if (key.isEmpty) return;

    setState(() {
      if (_favoriteKeys.contains(key)) {
        _favoriteKeys.remove(key);
      } else {
        _favoriteKeys.add(key);
      }
    });
    await _saveFavoriteKeys();
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
          await Future.wait([
            _fetchStats(),
            _fetchTrends(),
            _fetchPriceDistribution(),
            _fetchHouses(reset: true),
          ]);
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
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSearchPanel(),
                const SizedBox(height: 16),
                _buildStatsRow(),
                const SizedBox(height: 16),
                SizedBox(height: 320, child: _buildTrendPanel()),
                const SizedBox(height: 16),
                SizedBox(height: 320, child: _buildPriceDistributionPanel()),
                const SizedBox(height: 16),
                SizedBox(height: 780, child: _buildHouseList()),
                const SizedBox(height: 16),
                SizedBox(height: 420, child: _buildMapPanel()),
                const SizedBox(height: 16),
                SizedBox(height: 520, child: _buildHouseDetailPanel()),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
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
        SizedBox(height: 300, child: _buildTrendPanel()),
        const SizedBox(height: 12),
        SizedBox(height: 360, child: _buildPriceDistributionPanel()),
        const SizedBox(height: 12),
        SizedBox(height: 700, child: _buildHouseList()),
        const SizedBox(height: 12),
        SizedBox(height: 380, child: _buildMapPanel()),
        const SizedBox(height: 12),
        SizedBox(height: 520, child: _buildHouseDetailPanel()),
      ],
    );
  }

  Widget _buildHouseDetailPanel() {
    final house = _selectedHouse;
    return _HouseDetailPanel(
      house: house,
      favorite: house == null
          ? false
          : _favoriteKeys.contains(house.favoriteKey),
      onToggleFavorite: house == null ? null : () => _toggleFavorite(house),
    );
  }

  Widget _buildMapPanel() {
    return _HouseMapPanel(house: _selectedHouse);
  }

  Widget _buildSearchPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '搜尋房源',
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
                    decoration: const InputDecoration(
                      labelText: '縣市',
                      hintText: '全部',
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchHouses(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _districtController,
                    decoration: const InputDecoration(
                      labelText: '地區',
                      hintText: '全部',
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchHouses(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _kindController,
              decoration: const InputDecoration(
                labelText: '房型',
                hintText: '全部房型',
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _searchHouses(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '最低租金',
                      hintText: '不限',
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchHouses(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _maxPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '最高租金',
                      hintText: '不限',
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchHouses(),
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
                labelText: '關鍵字搜尋',
                prefixIcon: Icon(Icons.search),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _searchHouses(),
            ),
            const SizedBox(height: 12),
            _SortModeSelector(
              value: _sortMode,
              onChanged: _loadingHouses || _loadingTrends
                  ? null
                  : _changeSortMode,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadingHouses || _loadingTrends
                  ? null
                  : _searchHouses,
              icon: _loadingHouses || _loadingTrends
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(_loadingHouses || _loadingTrends ? '搜尋中' : '搜尋房源'),
            ),
            if (_searchStatusText != null) ...[
              const SizedBox(height: 10),
              _SearchProgressNotice(
                message: _searchStatusText!,
                active: _loadingHouses || _loadingTrends,
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
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
            TextButton.icon(
              onPressed: _loadingHouses ? null : _searchHouses,
              icon: const Icon(Icons.refresh),
              label: const Text('重新整理列表'),
            ),
            TextButton.icon(
              onPressed: _loadingHouses || _loadingTrends
                  ? null
                  : _clearSearchFilters,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('清除條件看全部'),
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
    final isWeb = _connectionMode == 'web';
    final isLockedApiBase = isUsb || isWeb;
    final modeLabel = switch (_connectionMode) {
      'web' => '網站',
      'usb' => 'USB',
      _ => '自訂',
    };
    final modeColor = switch (_connectionMode) {
      'web' => const Color(0xFF0F766E),
      'usb' => const Color(0xFF0F766E),
      _ => const Color(0xFF2563EB),
    };

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
              Icon(
                isWeb ? Icons.public : Icons.usb,
                color: const Color(0xFF0F766E),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '連線設定',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              _StatusPill(label: modeLabel, color: modeColor),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'web',
                icon: Icon(Icons.public),
                label: Text('網站'),
              ),
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
              if (selected.first == 'web') {
                _useWebMode();
              } else if (selected.first == 'usb') {
                _useUsbMode();
              } else {
                _useCustomMode();
              }
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _apiBaseController,
            readOnly: isLockedApiBase,
            decoration: InputDecoration(
              labelText: 'API 伺服器',
              prefixIcon: const Icon(Icons.dns_outlined),
              helperText: switch (_connectionMode) {
                'web' => '公開網站會使用目前網域的 Flask API',
                'usb' => '手機透過 USB 轉接到電腦 Flask',
                _ => '輸入 Wi-Fi 或其他 Flask 位址',
              },
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
          if (isUsb) ...[
            const SizedBox(height: 8),
            const Text(
              'USB 模式需在電腦執行：adb reverse tcp:5000 tcp:5000',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
          ],
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

  Widget _buildTrendPanel() {
    final trends = _trends;
    final items = trends?.items ?? const <TrendPoint>[];
    final summary = trends?.summary;
    final scope = _joinParts([
      _cityController.text.trim(),
      _districtController.text.trim(),
      _kindController.text.trim(),
    ]);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.show_chart, color: Color(0xFF0F766E)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '租金趨勢',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        scope.isEmpty ? '近 30 天全部房源' : '近 30 天 · $scope',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _TrendSummaryPill(
                  label: '平均',
                  value: _formatMoney(summary?.avgPrice),
                  color: const Color(0xFF0F766E),
                ),
                const SizedBox(width: 8),
                _TrendSummaryPill(
                  label: '新增',
                  value: '${summary?.total ?? 0}',
                  color: const Color(0xFFE11D48),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loadingTrends
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                  ? const _EmptyTrendState()
                  : Column(
                      children: [
                        Expanded(child: _TrendLineChart(points: items)),
                        const SizedBox(height: 10),
                        _TrendTable(points: items),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceDistributionPanel() {
    return _PriceDistributionPanel(distribution: _priceDistribution);
  }

  Widget _buildHouseList() {
    final start = _total == 0 ? 0 : _offset + 1;
    final end = (_offset + _houses.length).clamp(0, _total);
    final page = _total == 0 ? 0 : (_offset ~/ _limit) + 1;
    final pageCount = _total == 0 ? 0 : ((_total - 1) ~/ _limit) + 1;
    final canGoPrevious = _offset > 0 && !_loadingHouses;
    final canGoNext = _offset + _limit < _total && !_loadingHouses;
    final isSearching = _loadingHouses || _loadingTrends;

    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isSearching ? '搜尋房源中' : '房源列表',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isSearching
                          ? const Color(0xFF0F766E)
                          : const Color(0xFF111827),
                    ),
                  ),
                ),
                _ViewModeToggle(
                  value: _viewMode,
                  onChanged: (value) => setState(() => _viewMode = value),
                ),
                const SizedBox(width: 10),
                _StatusPill(label: '$_total 筆', color: const Color(0xFF0F766E)),
              ],
            ),
          ),
          if (_searchStatusText != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _SearchProgressNotice(
                message: _searchStatusText!,
                active: isSearching,
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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _loadingHouses
                  ? const _HouseListSkeleton(key: ValueKey('house-loading'))
                  : _houses.isEmpty
                  ? const _EmptyState(key: ValueKey('house-empty'))
                  : _viewMode == 'table'
                  ? _HouseDataTable(
                      key: ValueKey('house-table-$_offset-${_houses.length}'),
                      houses: _houses,
                      selectedHouse: _selectedHouse,
                      favoriteKeys: _favoriteKeys,
                      onSelect: (house) =>
                          setState(() => _selectedHouse = house),
                      onToggleFavorite: _toggleFavorite,
                    )
                  : ListView.separated(
                      key: ValueKey('house-list-$_offset-${_houses.length}'),
                      itemCount: _houses.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final house = _houses[index];
                        return _AnimatedHouseListItem(
                          index: index,
                          child: _HouseListTile(
                            house: house,
                            favorite: _favoriteKeys.contains(house.favoriteKey),
                            selected: house.id == _selectedHouse?.id,
                            onTap: () => setState(() => _selectedHouse = house),
                            onToggleFavorite: () => _toggleFavorite(house),
                          ),
                        );
                      },
                    ),
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

  String get favoriteKey => link.isNotEmpty ? link : 'house:$id';

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

class TrendData {
  TrendData({required this.items, required this.summary});

  final List<TrendPoint> items;
  final TrendSummary summary;

  factory TrendData.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(TrendPoint.fromJson)
        .toList();

    return TrendData(
      items: items,
      summary: TrendSummary.fromJson(
        json['summary'] is Map<String, dynamic> ? json['summary'] : null,
      ),
    );
  }
}

class TrendPoint {
  TrendPoint({
    required this.date,
    required this.count,
    required this.avgPrice,
    required this.minPrice,
    required this.maxPrice,
  });

  final String date;
  final int count;
  final int? avgPrice;
  final int? minPrice;
  final int? maxPrice;

  factory TrendPoint.fromJson(Map<String, dynamic> json) {
    return TrendPoint(
      date: json['date']?.toString() ?? '',
      count: _readInt(json['count']) ?? 0,
      avgPrice: _readInt(json['avg_price']),
      minPrice: _readInt(json['min_price']),
      maxPrice: _readInt(json['max_price']),
    );
  }
}

class TrendSummary {
  TrendSummary({
    required this.total,
    required this.avgPrice,
    required this.minPrice,
    required this.maxPrice,
  });

  final int total;
  final int? avgPrice;
  final int? minPrice;
  final int? maxPrice;

  factory TrendSummary.fromJson(Map<String, dynamic>? json) {
    return TrendSummary(
      total: _readInt(json?['total']) ?? 0,
      avgPrice: _readInt(json?['avg_price']),
      minPrice: _readInt(json?['min_price']),
      maxPrice: _readInt(json?['max_price']),
    );
  }
}

class PriceDistribution {
  PriceDistribution({required this.total, required this.items});

  final int total;
  final List<PriceDistributionItem> items;

  factory PriceDistribution.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(PriceDistributionItem.fromJson)
        .toList();

    return PriceDistribution(total: _readInt(json['total']) ?? 0, items: items);
  }
}

class PriceDistributionItem {
  PriceDistributionItem({required this.label, required this.count});

  final String label;
  final int count;

  factory PriceDistributionItem.fromJson(Map<String, dynamic> json) {
    return PriceDistributionItem(
      label: json['label']?.toString() ?? '未分類',
      count: _readInt(json['count']) ?? 0,
    );
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

class _TrendSummaryPill extends StatelessWidget {
  const _TrendSummaryPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 76),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _SearchProgressNotice extends StatelessWidget {
  const _SearchProgressNotice({required this.message, required this.active});

  final String message;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF0F766E) : const Color(0xFF2563EB);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                active ? Icons.manage_search : Icons.check_circle_outline,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          if (active) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              minHeight: 6,
              borderRadius: BorderRadius.circular(999),
            ),
          ],
        ],
      ),
    );
  }
}

class _SortModeSelector extends StatelessWidget {
  const _SortModeSelector({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.sort, size: 18, color: Color(0xFF0F766E)),
              SizedBox(width: 8),
              Text('排序', style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            selected: {value},
            segments: const [
              ButtonSegment(
                value: 'newest',
                icon: Icon(Icons.schedule),
                label: Text('最新'),
              ),
              ButtonSegment(
                value: 'price_asc',
                icon: Icon(Icons.arrow_downward),
                label: Text('低租金'),
              ),
              ButtonSegment(
                value: 'price_desc',
                icon: Icon(Icons.arrow_upward),
                label: Text('高租金'),
              ),
            ],
            onSelectionChanged: onChanged == null
                ? null
                : (selected) => onChanged!(selected.first),
          ),
        ],
      ),
    );
  }
}

class _ViewModeToggle extends StatelessWidget {
  const _ViewModeToggle({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      showSelectedIcon: false,
      selected: {value},
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 10),
        ),
      ),
      segments: const [
        ButtonSegment(
          value: 'cards',
          icon: Icon(Icons.view_agenda_outlined, size: 18),
          label: Text('卡片'),
        ),
        ButtonSegment(
          value: 'table',
          icon: Icon(Icons.table_rows_outlined, size: 18),
          label: Text('表格'),
        ),
      ],
      onSelectionChanged: (selected) => onChanged(selected.first),
    );
  }
}

class _HouseListSkeleton extends StatefulWidget {
  const _HouseListSkeleton({super.key});

  @override
  State<_HouseListSkeleton> createState() => _HouseListSkeletonState();
}

class _HouseListSkeletonState extends State<_HouseListSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: 6,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) => _SkeletonHouseCard(
            progress: _controller.value,
            compact: index.isOdd,
          ),
        );
      },
    );
  }
}

class _SkeletonHouseCard extends StatelessWidget {
  const _SkeletonHouseCard({required this.progress, required this.compact});

  final double progress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _ShimmerBlock(
                          progress: progress,
                          width: 62,
                          height: 24,
                          radius: 6,
                        ),
                        const SizedBox(width: 8),
                        _ShimmerBlock(
                          progress: progress,
                          width: 132,
                          height: 14,
                          radius: 6,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _ShimmerBlock(
                      progress: progress,
                      width: compact ? 360 : 520,
                      height: 22,
                      radius: 7,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _ShimmerBlock(
                    progress: progress,
                    width: 112,
                    height: 24,
                    radius: 7,
                  ),
                  const SizedBox(height: 10),
                  _ShimmerBlock(
                    progress: progress,
                    width: 88,
                    height: 34,
                    radius: 8,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ShimmerBlock(
                progress: progress,
                width: 86,
                height: 28,
                radius: 6,
              ),
              _ShimmerBlock(
                progress: progress,
                width: 74,
                height: 28,
                radius: 6,
              ),
              _ShimmerBlock(
                progress: progress,
                width: 98,
                height: 28,
                radius: 6,
              ),
              _ShimmerBlock(
                progress: progress,
                width: 82,
                height: 28,
                radius: 6,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ShimmerBlock(
            progress: progress,
            width: compact ? 420 : 620,
            height: 18,
            radius: 6,
          ),
        ],
      ),
    );
  }
}

class _ShimmerBlock extends StatelessWidget {
  const _ShimmerBlock({
    required this.progress,
    required this.width,
    required this.height,
    required this.radius,
  });

  final double progress;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final blockWidth = math.min(width, constraints.maxWidth);
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: CustomPaint(
            painter: _ShimmerPainter(progress),
            child: SizedBox(width: blockWidth, height: height),
          ),
        );
      },
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  _ShimmerPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()..color = const Color(0xFFE5E7EB);
    canvas.drawRect(Offset.zero & size, basePaint);

    final shimmerWidth = size.width * 0.55;
    final shimmerCenter =
        (size.width + shimmerWidth * 2) * progress - shimmerWidth;
    final rect = Rect.fromLTWH(
      shimmerCenter - shimmerWidth / 2,
      0,
      shimmerWidth,
      size.height,
    );
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x00FFFFFF), Color(0x99FFFFFF), Color(0x00FFFFFF)],
      ).createShader(rect);

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _ShimmerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _AnimatedHouseListItem extends StatelessWidget {
  const _AnimatedHouseListItem({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delay = math.min(index * 45, 260);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final opacityStart = delay / (260 + delay);
        final opacity = value <= opacityStart
            ? 0.0
            : ((value - opacityStart) / (1 - opacityStart)).clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - opacity)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _TrendLineChart extends StatelessWidget {
  const _TrendLineChart({required this.points});

  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TrendChartPainter(points),
      child: const SizedBox.expand(),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  _TrendChartPainter(this.points);

  final List<TrendPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    final pricePaint = Paint()
      ..color = const Color(0xFF0F766E)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final countPaint = Paint()
      ..color = const Color(0xFFE11D48)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..style = PaintingStyle.fill;
    final labelStyle = const TextStyle(
      color: Color(0xFF6B7280),
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );

    const left = 42.0;
    const right = 12.0;
    const top = 10.0;
    const bottom = 24.0;
    final chart = Rect.fromLTWH(
      left,
      top,
      math.max(1, size.width - left - right),
      math.max(1, size.height - top - bottom),
    );

    for (var i = 0; i <= 3; i++) {
      final y = chart.top + chart.height * i / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }

    final prices = points
        .map((point) => point.avgPrice)
        .whereType<int>()
        .where((price) => price > 0)
        .toList();
    final counts = points.map((point) => point.count).toList();

    if (prices.isEmpty && counts.isEmpty) return;

    final minPrice = prices.isEmpty ? 0 : prices.reduce(math.min);
    final maxPrice = prices.isEmpty ? 1 : prices.reduce(math.max);
    final maxCount = counts.isEmpty ? 1 : counts.reduce(math.max);
    final priceSpan = math.max(1, maxPrice - minPrice);
    final countSpan = math.max(1, maxCount);
    final step = points.length == 1 ? 0 : chart.width / (points.length - 1);

    Offset pointOffset(int index, double value, double min, double span) {
      final x =
          chart.left + (points.length == 1 ? chart.width / 2 : step * index);
      final y = chart.bottom - ((value - min) / span) * chart.height;
      return Offset(x, y.clamp(chart.top, chart.bottom));
    }

    final pricePath = Path();
    var hasPriceStart = false;
    final countPath = Path();

    for (var i = 0; i < points.length; i++) {
      final price = points[i].avgPrice;
      if (price != null && price > 0) {
        final offset = pointOffset(
          i,
          price.toDouble(),
          minPrice.toDouble(),
          priceSpan.toDouble(),
        );
        if (hasPriceStart) {
          pricePath.lineTo(offset.dx, offset.dy);
        } else {
          pricePath.moveTo(offset.dx, offset.dy);
          hasPriceStart = true;
        }
      }

      final countOffset = pointOffset(
        i,
        points[i].count.toDouble(),
        0,
        countSpan.toDouble(),
      );
      if (i == 0) {
        countPath.moveTo(countOffset.dx, countOffset.dy);
      } else {
        countPath.lineTo(countOffset.dx, countOffset.dy);
      }
    }

    if (hasPriceStart) canvas.drawPath(pricePath, pricePaint);
    canvas.drawPath(countPath, countPaint);

    for (var i = 0; i < points.length; i++) {
      final price = points[i].avgPrice;
      if (price != null && price > 0) {
        dotPaint.color = const Color(0xFF0F766E);
        canvas.drawCircle(
          pointOffset(
            i,
            price.toDouble(),
            minPrice.toDouble(),
            priceSpan.toDouble(),
          ),
          3.5,
          dotPaint,
        );
      }
      dotPaint.color = const Color(0xFFE11D48);
      canvas.drawCircle(
        pointOffset(i, points[i].count.toDouble(), 0, countSpan.toDouble()),
        3,
        dotPaint,
      );
    }

    _paintText(
      canvas,
      Offset(0, chart.top - 2),
      _formatMoney(maxPrice),
      labelStyle,
    );
    _paintText(
      canvas,
      Offset(0, chart.bottom - 12),
      _formatMoney(minPrice),
      labelStyle,
    );

    if (points.isNotEmpty) {
      _paintText(
        canvas,
        Offset(chart.left, chart.bottom + 8),
        _shortDate(points.first.date),
        labelStyle,
      );
      final lastLabel = _shortDate(points.last.date);
      final lastPainter = _textPainter(lastLabel, labelStyle);
      lastPainter.layout();
      lastPainter.paint(
        canvas,
        Offset(chart.right - lastPainter.width, chart.bottom + 8),
      );
    }

    _paintLegend(canvas, chart);
  }

  void _paintLegend(Canvas canvas, Rect chart) {
    final legendStyle = const TextStyle(
      color: Color(0xFF374151),
      fontSize: 11,
      fontWeight: FontWeight.w700,
    );
    final y = chart.top + 4;
    final x = chart.right - 142;
    final pricePaint = Paint()
      ..color = const Color(0xFF0F766E)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final countPaint = Paint()
      ..color = const Color(0xFFE11D48)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(x, y + 6), Offset(x + 18, y + 6), pricePaint);
    _paintText(canvas, Offset(x + 24, y), '平均租金', legendStyle);
    canvas.drawLine(Offset(x + 82, y + 6), Offset(x + 100, y + 6), countPaint);
    _paintText(canvas, Offset(x + 106, y), '新增', legendStyle);
  }

  void _paintText(Canvas canvas, Offset offset, String text, TextStyle style) {
    final painter = _textPainter(text, style)..layout();
    painter.paint(canvas, offset);
  }

  TextPainter _textPainter(String text, TextStyle style) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _TrendTable extends StatelessWidget {
  const _TrendTable({required this.points});

  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final recent = points.length <= 3
        ? points.reversed.toList()
        : points.sublist(points.length - 3).reversed.toList();

    return Row(
      children: recent.map((point) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _shortDate(point.date),
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatMoney(point.avgPrice),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0F766E),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '新增 ${point.count} 筆',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF374151),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _EmptyTrendState extends StatelessWidget {
  const _EmptyTrendState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.query_stats, size: 38, color: Color(0xFF9CA3AF)),
          SizedBox(height: 10),
          Text('近 30 天沒有可統計的房源', style: TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _PriceDistributionPanel extends StatelessWidget {
  const _PriceDistributionPanel({required this.distribution});

  static const _colors = [
    Color(0xFF0F766E),
    Color(0xFF2563EB),
    Color(0xFFE11D48),
    Color(0xFFD97706),
    Color(0xFF7C3AED),
    Color(0xFF6B7280),
  ];

  final PriceDistribution? distribution;

  @override
  Widget build(BuildContext context) {
    final data = distribution;
    final items =
        data?.items.where((item) => item.count > 0).toList() ??
        const <PriceDistributionItem>[];
    final total = data?.total ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.pie_chart_outline, color: Color(0xFF0F766E)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '租金分布',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '依目前搜尋條件統計租金區間比例',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusPill(label: '$total 筆', color: const Color(0xFF0F766E)),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: items.isEmpty
                  ? const _EmptyPieState()
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 680;
                        final chart = _PieChart(
                          items: items,
                          total: total,
                          colors: _colors,
                        );
                        final legend = _PieLegend(
                          items: items,
                          total: total,
                          colors: _colors,
                        );

                        if (compact) {
                          return Column(
                            children: [
                              Expanded(child: chart),
                              const SizedBox(height: 8),
                              SizedBox(height: 86, child: legend),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(flex: 4, child: chart),
                            const SizedBox(width: 18),
                            Expanded(flex: 5, child: legend),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PieChart extends StatelessWidget {
  const _PieChart({
    required this.items,
    required this.total,
    required this.colors,
  });

  final List<PriceDistributionItem> items;
  final int total;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PieChartPainter(items: items, total: total, colors: colors),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$total',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
            const Text(
              '房源',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PieChartPainter extends CustomPainter {
  _PieChartPainter({
    required this.items,
    required this.total,
    required this.colors,
  });

  final List<PriceDistributionItem> items;
  final int total;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: side * 0.86,
      height: side * 0.86,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = side * 0.16
      ..strokeCap = StrokeCap.butt;
    var start = -math.pi / 2;

    for (var i = 0; i < items.length; i++) {
      final sweep = total == 0 ? 0.0 : (items[i].count / total) * math.pi * 2;
      paint.color = colors[i % colors.length];
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }

    final innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(rect.center, side * 0.28, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.items != items || oldDelegate.total != total;
  }
}

class _PieLegend extends StatelessWidget {
  const _PieLegend({
    required this.items,
    required this.total,
    required this.colors,
  });

  final List<PriceDistributionItem> items;
  final int total;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        final percent = total == 0 ? 0 : (item.count / total * 100).round();
        final color = colors[index % colors.length];

        return Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${item.count} 筆',
              style: const TextStyle(
                color: Color(0xFF374151),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 46,
              child: Text(
                '$percent%',
                textAlign: TextAlign.right,
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyPieState extends StatelessWidget {
  const _EmptyPieState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pie_chart_outline, size: 40, color: Color(0xFF9CA3AF)),
          SizedBox(height: 12),
          Text('目前沒有可統計的租金資料', style: TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _HouseMapPanel extends StatelessWidget {
  const _HouseMapPanel({required this.house});

  final House? house;

  @override
  Widget build(BuildContext context) {
    final selected = house;
    final query = selected == null
        ? ''
        : _joinParts([
            selected.city,
            selected.district,
            selected.address,
            selected.title,
          ]);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.map_outlined, color: Color(0xFF0F766E)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '地圖定位',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        selected == null
                            ? '選取列表中的房源後同步定位'
                            : _joinParts([selected.district, selected.address]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: selected == null || query.isEmpty
                      ? null
                      : () => _openHouseMap(context, query),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('開啟地圖'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: selected == null || query.isEmpty
                      ? const _EmptyMapState()
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            MapEmbedView(key: ValueKey(query), query: query),
                            IgnorePointer(
                              child: Center(
                                child: _MapPriceMarker(
                                  price: selected.price.isEmpty
                                      ? '租金'
                                      : selected.price,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPriceMarker extends StatelessWidget {
  const _MapPriceMarker({required this.price});

  final String price;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, -18 * (1 - value)),
          child: Transform.scale(
            scale: 0.9 + value * 0.1,
            child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE11D48),
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Text(
              price,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          CustomPaint(
            size: const Size(18, 10),
            painter: _MapMarkerTipPainter(),
          ),
        ],
      ),
    );
  }
}

class _MapMarkerTipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFE11D48));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EmptyMapState extends StatelessWidget {
  const _EmptyMapState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_location_alt_outlined,
            size: 42,
            color: Color(0xFF9CA3AF),
          ),
          SizedBox(height: 12),
          Text('點選房源後，地圖會同步定位', style: TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _HouseDataTable extends StatelessWidget {
  const _HouseDataTable({
    super.key,
    required this.houses,
    required this.selectedHouse,
    required this.favoriteKeys,
    required this.onSelect,
    required this.onToggleFavorite,
  });

  final List<House> houses;
  final House? selectedHouse;
  final Set<String> favoriteKeys;
  final ValueChanged<House> onSelect;
  final ValueChanged<House> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 1220,
          child: SingleChildScrollView(
            child: DataTable(
              showCheckboxColumn: false,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
              dataRowMinHeight: 62,
              dataRowMaxHeight: 78,
              columnSpacing: 22,
              columns: const [
                DataColumn(label: Text('收藏')),
                DataColumn(label: Text('來源')),
                DataColumn(label: Text('標題')),
                DataColumn(label: Text('租金')),
                DataColumn(label: Text('地區')),
                DataColumn(label: Text('坪數')),
                DataColumn(label: Text('房型')),
                DataColumn(label: Text('樓層')),
                DataColumn(label: Text('操作')),
              ],
              rows: houses.map((house) {
                final selected = selectedHouse?.id == house.id;
                final favorite = favoriteKeys.contains(house.favoriteKey);

                return DataRow(
                  selected: selected,
                  color: WidgetStateProperty.resolveWith((states) {
                    if (selected) return const Color(0xFFE6F4F1);
                    return null;
                  }),
                  onSelectChanged: (_) => onSelect(house),
                  cells: [
                    DataCell(
                      IconButton(
                        tooltip: favorite ? '取消收藏' : '收藏房源',
                        onPressed: () => onToggleFavorite(house),
                        icon: Icon(
                          favorite ? Icons.star : Icons.star_border,
                          color: favorite
                              ? const Color(0xFFE11D48)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    DataCell(_SourceBadge(source: house.source)),
                    DataCell(
                      SizedBox(
                        width: 300,
                        child: Text(
                          house.title.isEmpty ? '未命名房源' : house.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        house.price.isEmpty ? '-' : house.price,
                        style: const TextStyle(
                          color: Color(0xFFE11D48),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(house.district.isEmpty ? '-' : house.district),
                    ),
                    DataCell(Text(house.area.isEmpty ? '-' : house.area)),
                    DataCell(
                      Text(house.roomType.isEmpty ? '-' : house.roomType),
                    ),
                    DataCell(Text(house.floor.isEmpty ? '-' : house.floor)),
                    DataCell(
                      FilledButton.tonalIcon(
                        onPressed: house.link.isEmpty
                            ? null
                            : () => _openHouseLink(context, house.link),
                        icon: const Icon(Icons.open_in_new, size: 17),
                        label: const Text('查看'),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _HouseListTile extends StatelessWidget {
  const _HouseListTile({
    required this.house,
    required this.favorite,
    required this.selected,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final House house;
  final bool favorite;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFE6F4F1) : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _SourceBadge(source: house.source),
                            const SizedBox(width: 8),
                            if (house.createdAt.isNotEmpty)
                              Flexible(
                                child: Text(
                                  house.createdAt,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          house.title.isEmpty ? '未命名房源' : house.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _FavoriteButton(
                        favorite: favorite,
                        onPressed: onToggleFavorite,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        house.price.isEmpty ? '-' : house.price,
                        style: const TextStyle(
                          color: Color(0xFFE11D48),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (house.link.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _openHouseLink(context, house.link),
                          icon: const Icon(Icons.open_in_new, size: 17),
                          label: const Text('查看'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(icon: Icons.place_outlined, text: house.district),
                  _InfoChip(icon: Icons.square_foot, text: house.area),
                  _InfoChip(
                    icon: Icons.meeting_room_outlined,
                    text: house.roomType,
                  ),
                  _InfoChip(icon: Icons.layers_outlined, text: house.floor),
                ],
              ),
              if (house.address.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 17,
                      color: Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        house.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF4B5563),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF0F766E)),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF374151),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.favorite, required this.onPressed});

  final bool favorite;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = favorite ? const Color(0xFFE11D48) : const Color(0xFF6B7280);

    return IconButton.filledTonal(
      tooltip: favorite ? '取消收藏' : '收藏房源',
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: favorite
            ? const Color(0xFFFCE7F3)
            : const Color(0xFFF3F4F6),
        foregroundColor: color,
      ),
      icon: Icon(favorite ? Icons.star : Icons.star_border),
    );
  }
}

class _HouseDetailPanel extends StatelessWidget {
  const _HouseDetailPanel({
    required this.house,
    required this.favorite,
    required this.onToggleFavorite,
  });

  final House? house;
  final bool favorite;
  final VoidCallback? onToggleFavorite;

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
                      _FavoriteButton(
                        favorite: favorite,
                        onPressed: onToggleFavorite,
                      ),
                      const SizedBox(width: 8),
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
                  if (selected.link.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () =>
                                _openHouseLink(context, selected.link),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('開啟房源'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton.filledTonal(
                          tooltip: '複製連結',
                          onPressed: () =>
                              _copyHouseLink(context, selected.link),
                          icon: const Icon(Icons.content_copy),
                        ),
                      ],
                    ),
                  ],
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: SelectableText(
                        selected.link,
                        style: const TextStyle(
                          color: Color(0xFF0F766E),
                          fontWeight: FontWeight.w600,
                        ),
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
    final saved = result?['saved'] ?? result?['inserted'];
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
          if (saved != null) ...[
            const SizedBox(height: 6),
            Text(
              '目前保存 $saved 筆，整理 $total 筆',
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
  const _EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          return Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, 16 * (1 - value)),
              child: Transform.scale(scale: 0.94 + value * 0.06, child: child),
            ),
          );
        },
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 44, color: Color(0xFF9CA3AF)),
            SizedBox(height: 12),
            Text('目前沒有符合條件的房源', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
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

Future<void> _openHouseLink(BuildContext context, String link) async {
  final messenger = ScaffoldMessenger.of(context);
  final opened = await openExternalUrl(link);
  if (opened) return;

  await _copyLink(messenger, link);
}

Future<void> _openHouseMap(BuildContext context, String query) async {
  final messenger = ScaffoldMessenger.of(context);
  final url =
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}';
  final opened = await openExternalUrl(url);
  if (opened) return;

  await _copyLink(messenger, url);
}

Future<void> _copyHouseLink(BuildContext context, String link) async {
  final messenger = ScaffoldMessenger.of(context);
  await _copyLink(messenger, link);
}

Future<void> _copyLink(ScaffoldMessengerState messenger, String link) async {
  await Clipboard.setData(ClipboardData(text: link));
  messenger.showSnackBar(const SnackBar(content: Text('已複製房源連結')));
}

String _readString(Map<String, dynamic> json, String key) {
  return json[key]?.toString() ?? '';
}

int? _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '');
}

String _formatMoney(int? value) {
  if (value == null || value <= 0) return '-';
  return '\$${value.toString()}';
}

String _shortDate(String value) {
  if (value.length >= 10) return value.substring(5, 10).replaceAll('-', '/');
  return value;
}

String _joinParts(List<String> parts) {
  return parts.where((part) => part.trim().isNotEmpty).join(' · ');
}
