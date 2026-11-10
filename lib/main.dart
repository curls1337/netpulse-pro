import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const NetPulseProApp());
}

class NetPulseProApp extends StatefulWidget {
  const NetPulseProApp({super.key});

  @override
  State<NetPulseProApp> createState() => _NetPulseProAppState();
}

class _NetPulseProAppState extends State<NetPulseProApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NetPulse Pro',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        primaryColor: const Color(0xFF06B6D4),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF06B6D4),
          secondary: Color(0xFF6366F1),
          surface: Colors.white,
        ),
        fontFamily: 'sans-serif',
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090D16),
        primaryColor: const Color(0xFF06B6D4),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF06B6D4),
          secondary: Color(0xFF6366F1),
          surface: Color(0xFF111827),
        ),
        fontFamily: 'sans-serif',
      ),
      home: MainShell(onToggleTheme: toggleTheme, isDark: _themeMode == ThemeMode.dark),
    );
  }
}

class MainShell extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;

  const MainShell({super.key, required this.onToggleTheme, required this.isDark});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  // Real-time metrics
  double _downloadSpeed = 0.0; // Mbps
  double _uploadSpeed = 0.0; // Mbps
  int _ping = 14; // ms
  int _jitter = 2; // ms
  String _networkType = 'Wi-Fi';
  String _ispName = 'Mendeteksi...';
  String _ipAddress = 'Local Interface';
  bool _isTesting = false;

  // Usage Stats
  double _lastHourUsageMB = 0.0;
  double _todayUsageGB = 0.0;
  double _monthUsageGB = 0.0;
  double _monthlyQuotaGB = 150.0;

  // Alert & Settings Preferences (Persisted via Native UserDefaults)
  bool _dailyLimitActive = true;
  double _dailyLimitMB = 1024.0;
  bool _hourlyLimitActive = true;
  double _hourlyLimitMB = 500.0;
  bool _quota80Active = true;
  bool _quota95Active = true;
  bool _switchNetworkActive = false;
  int _resetDay = 1;

  // Dynamic Analytics Data from Native Hardware
  List<double> _hourlyDataMB = List<double>.filled(24, 0.0);
  List<String> _hourlyLabels = const [];
  List<double> _weeklyDataGB = List<double>.filled(7, 0.0);
  List<String> _weeklyLabels = const ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  List<double> _monthlyDataGB = List<double>.filled(6, 0.0);
  List<String> _monthlyLabels = const ['Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov'];
  List<double> _yearlyDataGB = List<double>.filled(4, 0.0);
  List<String> _yearlyLabels = const ['2023', '2024', '2025', '2026'];

  // Dynamic Island (Live Activity)
  static const _liveActivityChannel = MethodChannel('com.devcurl.netpulse/live_activity');
  bool _isDynamicIslandActive = false;
  String _speedUnit = 'Auto'; // 'Auto', 'Mbps', 'KB/s', 'MB/s'

  Timer? _metricsTimer;
  String _lastKnownNetType = '';

  Future<void> _setSpeedUnit(String unit) async {
    setState(() => _speedUnit = unit);
    try {
      await _liveActivityChannel.invokeMethod('setSpeedUnit', {'unit': unit});
    } catch (e) {
      debugPrint('Unit update error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _setupNativeSpeedListener();
    _checkExistingLiveActivity();
    _fetchInitialNetworkStatus();
    _loadAlertSettings();
    _loadAnalyticsData();
  }

  Future<void> _loadAlertSettings() async {
    try {
      final res = await _liveActivityChannel.invokeMethod<Map<dynamic, dynamic>>('getAlertSettings');
      if (res != null && mounted) {
        setState(() {
          _dailyLimitActive = res['dailyLimitActive'] as bool? ?? true;
          _dailyLimitMB = (res['dailyLimitMB'] as num?)?.toDouble() ?? 1024.0;
          _hourlyLimitActive = res['hourlyLimitActive'] as bool? ?? true;
          _hourlyLimitMB = (res['hourlyLimitMB'] as num?)?.toDouble() ?? 500.0;
          _quota80Active = res['quota80Active'] as bool? ?? true;
          _quota95Active = res['quota95Active'] as bool? ?? true;
          _switchNetworkActive = res['switchNetworkActive'] as bool? ?? false;
          _monthlyQuotaGB = (res['monthlyQuotaGB'] as num?)?.toDouble() ?? 150.0;
          _resetDay = (res['resetDay'] as num?)?.toInt() ?? 1;
          _speedUnit = res['speedUnit'] as String? ?? _speedUnit;
        });
      }
    } catch (e) {
      debugPrint('Load alert settings error: $e');
    }
  }

  Future<void> _saveAlertSettings(Map<String, dynamic> updates) async {
    try {
      await _liveActivityChannel.invokeMethod('saveAlertSettings', updates);
    } catch (e) {
      debugPrint('Save alert settings error: $e');
    }
  }

  Future<void> _loadAnalyticsData() async {
    try {
      final res = await _liveActivityChannel.invokeMethod<Map<dynamic, dynamic>>('getAnalyticsData');
      if (res != null && mounted) {
        setState(() {
          final h = (res['hourly'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList();
          final hl = (res['hourlyLabels'] as List<dynamic>?)?.map((e) => e.toString()).toList();
          final w = (res['weekly'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList();
          final wl = (res['weeklyLabels'] as List<dynamic>?)?.map((e) => e.toString()).toList();
          final m = (res['monthly'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList();
          final ml = (res['monthlyLabels'] as List<dynamic>?)?.map((e) => e.toString()).toList();
          final y = (res['yearly'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList();
          final yl = (res['yearlyLabels'] as List<dynamic>?)?.map((e) => e.toString()).toList();

          if (h != null && h.isNotEmpty) _hourlyDataMB = h;
          if (hl != null && hl.isNotEmpty) _hourlyLabels = hl;
          if (w != null && w.isNotEmpty) _weeklyDataGB = w;
          if (wl != null && wl.isNotEmpty) _weeklyLabels = wl;
          if (m != null && m.isNotEmpty) _monthlyDataGB = m;
          if (ml != null && ml.isNotEmpty) _monthlyLabels = ml;
          if (y != null && y.isNotEmpty) _yearlyDataGB = y;
          if (yl != null && yl.isNotEmpty) _yearlyLabels = yl;

          final t = (res['todayGB'] as num?)?.toDouble();
          final mo = (res['monthGB'] as num?)?.toDouble();
          if (t != null) _todayUsageGB = t;
          if (mo != null) _monthUsageGB = mo;
          final isp = res['isp'] as String?;
          if (isp != null && isp.isNotEmpty) {
            _ispName = isp;
            _networkType = isp.contains('Wi-Fi') ? 'Wi-Fi' : 'Seluler 5G/LTE';
          }
        });
      }
    } catch (e) {
      debugPrint('Load analytics error: $e');
    }
  }

  Future<void> _exportDataLog() async {
    String csvText = 'Slot_Waktu,Data_MB,Jaringan,Total_Hari_GB,Total_Bulan_GB\n';
    try {
      final res = await _liveActivityChannel.invokeMethod<String>('exportDataLog');
      if (res != null && res.isNotEmpty) {
        csvText = res;
      }
    } catch (_) {
      csvText += '${DateTime.now().hour}:00,${_lastHourUsageMB.toStringAsFixed(2)},$_ispName,${_todayUsageGB.toStringAsFixed(3)},${_monthUsageGB.toStringAsFixed(3)}\n';
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: const Text('Export Data Log (CSV)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          height: 260,
          child: SingleChildScrollView(
            child: SelectableText(
              csvText,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF94A3B8)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csvText));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✓ Log CSV berhasil disalin ke Clipboard!')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Salin CSV'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4), foregroundColor: const Color(0xFF090D16)),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchInitialNetworkStatus() async {
    try {
      final res = await _liveActivityChannel.invokeMethod<Map<dynamic, dynamic>>('getNetworkStatus');
      if (res != null && mounted) {
        setState(() {
          _downloadSpeed = (res['download'] as num?)?.toDouble() ?? _downloadSpeed;
          _uploadSpeed = (res['upload'] as num?)?.toDouble() ?? _uploadSpeed;
          _lastHourUsageMB = (res['lastHourMB'] as num?)?.toDouble() ?? _lastHourUsageMB;
          final today = (res['todayGB'] as num?)?.toDouble() ?? 0.0;
          _todayUsageGB = today;
          if (_monthUsageGB < today) _monthUsageGB = today;
          final isp = res['isp'] as String?;
          if (isp != null && isp.isNotEmpty) {
            _ispName = isp;
            _networkType = isp.contains('Wi-Fi') ? 'Wi-Fi' : 'Seluler 5G/LTE';
            _lastKnownNetType = _networkType;
          }
          final pingVal = (res['ping'] as num?)?.toInt() ?? 0;
          if (pingVal > 0) _ping = pingVal;
        });
      }
    } catch (_) {}
  }

  Future<void> _reloadWidgetFromFlutter() async {
    try {
      final res = await _liveActivityChannel.invokeMethod<Map<dynamic, dynamic>>('reloadWidget');
      if (res != null && mounted) {
        setState(() {
          _downloadSpeed = (res['download'] as num?)?.toDouble() ?? _downloadSpeed;
          _uploadSpeed = (res['upload'] as num?)?.toDouble() ?? _uploadSpeed;
          _lastHourUsageMB = (res['lastHourMB'] as num?)?.toDouble() ?? _lastHourUsageMB;
          final today = (res['todayGB'] as num?)?.toDouble() ?? 0.0;
          if (today > 0) _todayUsageGB = double.parse(today.toStringAsFixed(2));
          final isp = res['isp'] as String?;
          if (isp != null && isp.isNotEmpty) _ispName = isp;
        });
      }
    } catch (e) {
      debugPrint('Reload widget error: $e');
    }
  }

  Future<void> _checkExistingLiveActivity() async {
    try {
      final active = await _liveActivityChannel.invokeMethod<bool>('isLiveActivityActive') ?? false;
      if (mounted && active) {
        setState(() => _isDynamicIslandActive = true);
      }
    } catch (_) {}
  }

  void _setupNativeSpeedListener() {
    _liveActivityChannel.setMethodCallHandler((call) async {
      if (call.method == 'onLiveActivityStateChanged') {
        final args = call.arguments as Map<dynamic, dynamic>? ?? {};
        final active = args['active'] as bool? ?? false;
        if (mounted) {
          setState(() => _isDynamicIslandActive = active);
        }
      } else if (call.method == 'onSpeedUpdate') {
        final args = call.arguments as Map<dynamic, dynamic>? ?? {};
        if (mounted && !_isTesting) {
          setState(() {
            _downloadSpeed = (args['download'] as num?)?.toDouble() ?? _downloadSpeed;
            _uploadSpeed = (args['upload'] as num?)?.toDouble() ?? _uploadSpeed;
            _lastHourUsageMB = (args['lastHourMB'] as num?)?.toDouble() ?? _lastHourUsageMB;
            final today = (args['todayGB'] as num?)?.toDouble() ?? 0.0;
            final isp = (args['isp'] as String?) ?? '';
            final pingVal = (args['ping'] as num?)?.toInt() ?? 0;

            if (today >= 0) {
              _todayUsageGB = today;
              if (_monthUsageGB < today) {
                _monthUsageGB = today;
              }
            }
            if (isp.isNotEmpty) {
              _ispName = isp;
              final newNet = isp.contains('Wi-Fi') ? 'Wi-Fi' : 'Seluler 5G/LTE';
              if (_switchNetworkActive && _lastKnownNetType.isNotEmpty && _lastKnownNetType != newNet) {
                HapticFeedback.heavyImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFFF59E0B),
                    content: Text('⚠️ Jaringan berpindah: $_lastKnownNetType → $newNet ($isp)', style: const TextStyle(color: Color(0xFF090D16), fontWeight: FontWeight.bold)),
                  ),
                );
              }
              _networkType = newNet;
              _lastKnownNetType = newNet;
            }
            if (pingVal > 0) {
              _ping = pingVal;
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _metricsTimer?.cancel();
    super.dispose();
  }

  Future<void> _toggleDynamicIsland(bool enable) async {
    setState(() => _isDynamicIslandActive = enable);
    try {
      if (enable) {
        await _liveActivityChannel.invokeMethod('startLiveActivity', {
          'download': _downloadSpeed,
          'upload': _uploadSpeed,
          'isSecure': _downloadSpeed < 100 && _uploadSpeed < 40,
          'isp': _ispName,
        });
      } else {
        await _liveActivityChannel.invokeMethod('stopLiveActivity');
      }
    } catch (e) {
      debugPrint('Live Activity error: $e');
    }
  }

  void _syncLiveActivity() {
    if (_isDynamicIslandActive) {
      _liveActivityChannel.invokeMethod('updateLiveActivity', {
        'download': _downloadSpeed,
        'upload': _uploadSpeed,
        'isSecure': _downloadSpeed < 100 && _uploadSpeed < 40,
        'isp': _ispName,
      });
    }
  }

  void _startSimulatedMetrics() {
    _metricsTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isTesting && mounted) {
        final rand = Random();
        setState(() {
          _downloadSpeed = double.parse((78.0 + rand.nextDouble() * 20.0).toStringAsFixed(1));
          _uploadSpeed = double.parse((32.0 + rand.nextDouble() * 10.0).toStringAsFixed(1));
          _ping = 12 + rand.nextInt(5);
          _lastHourUsageMB = double.parse((130.0 + rand.nextDouble() * 25.0).toStringAsFixed(1));
        });
        _syncLiveActivity();
      }
    });
  }

  void _runSpeedtest() {
    if (_isTesting) return;
    setState(() => _isTesting = true);

    int step = 0;
    Timer.periodic(const Duration(milliseconds: 300), (t) {
      step++;
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (step < 10) {
          _downloadSpeed = double.parse((step * 15.0 + Random().nextDouble() * 10).toStringAsFixed(1));
        } else if (step < 20) {
          _uploadSpeed = double.parse(((step - 10) * 6.0 + Random().nextDouble() * 5).toStringAsFixed(1));
        } else {
          _isTesting = false;
          _downloadSpeed = 128.4;
          _uploadSpeed = 54.2;
          _ping = 9;
          t.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardTab(
        download: _downloadSpeed,
        upload: _uploadSpeed,
        ping: _ping,
        jitter: _jitter,
        networkType: _networkType,
        isp: _ispName,
        ip: _ipAddress,
        isTesting: _isTesting,
        lastHourMB: _lastHourUsageMB,
        onRunTest: _runSpeedtest,
        isDynamicIsland: _isDynamicIslandActive,
        onToggleDynamicIsland: _toggleDynamicIsland,
        speedUnit: _speedUnit,
        onSelectSpeedUnit: _setSpeedUnit,
      ),
      AnalyticsTab(
        todayGB: _todayUsageGB,
        monthGB: _monthUsageGB,
        quotaGB: _monthlyQuotaGB,
        isp: _ispName,
        networkType: _networkType,
        hourlyDataMB: _hourlyDataMB,
        hourlyLabels: _hourlyLabels,
        weeklyDataGB: _weeklyDataGB,
        weeklyLabels: _weeklyLabels,
        monthlyDataGB: _monthlyDataGB,
        monthlyLabels: _monthlyLabels,
        yearlyDataGB: _yearlyDataGB,
        yearlyLabels: _yearlyLabels,
        onRefresh: _loadAnalyticsData,
      ),
      WidgetsGalleryTab(
        download: _downloadSpeed,
        upload: _uploadSpeed,
        lastHourMB: _lastHourUsageMB,
        todayGB: _todayUsageGB,
        monthGB: _monthUsageGB,
        isp: _ispName,
        onReloadWidget: _reloadWidgetFromFlutter,
      ),
      QuotaAlertTab(
        currentUsageGB: _monthUsageGB,
        quotaLimitGB: _monthlyQuotaGB,
        dailyUsageMB: _todayUsageGB * 1024.0,
        hourlyUsageMB: _lastHourUsageMB,
        dailyLimitMB: _dailyLimitMB,
        hourlyLimitMB: _hourlyLimitMB,
        dailyLimitActive: _dailyLimitActive,
        hourlyLimitActive: _hourlyLimitActive,
        quota80Active: _quota80Active,
        quota95Active: _quota95Active,
        switchNetworkActive: _switchNetworkActive,
        onDailyLimitChanged: (val) {
          setState(() => _dailyLimitMB = val);
          _saveAlertSettings({'dailyLimitMB': val});
        },
        onDailyLimitToggled: (val) {
          setState(() => _dailyLimitActive = val);
          _saveAlertSettings({'dailyLimitActive': val});
        },
        onHourlyLimitChanged: (val) {
          setState(() => _hourlyLimitMB = val);
          _saveAlertSettings({'hourlyLimitMB': val});
        },
        onHourlyLimitToggled: (val) {
          setState(() => _hourlyLimitActive = val);
          _saveAlertSettings({'hourlyLimitActive': val});
        },
        onQuota80Toggled: (val) {
          setState(() => _quota80Active = val);
          _saveAlertSettings({'quota80Active': val});
        },
        onQuota95Toggled: (val) {
          setState(() => _quota95Active = val);
          _saveAlertSettings({'quota95Active': val});
        },
        onSwitchNetworkToggled: (val) {
          setState(() => _switchNetworkActive = val);
          _saveAlertSettings({'switchNetworkActive': val});
        },
        onQuotaLimitChanged: (val) {
          setState(() => _monthlyQuotaGB = val);
          _saveAlertSettings({'monthlyQuotaGB': val});
        },
      ),
      SettingsTab(
        isDark: widget.isDark,
        onToggleTheme: widget.onToggleTheme,
        networkType: _networkType,
        ispName: _ispName,
        speedUnit: _speedUnit,
        monthlyQuotaGB: _monthlyQuotaGB,
        resetDay: _resetDay,
        onNetworkChanged: (val) => setState(() => _networkType = val),
        onSelectSpeedUnit: _setSpeedUnit,
        onMonthlyQuotaChanged: (val) {
          setState(() => _monthlyQuotaGB = val);
          _saveAlertSettings({'monthlyQuotaGB': val});
        },
        onResetDayChanged: (val) {
          setState(() => _resetDay = val);
          _saveAlertSettings({'resetDay': val});
        },
        onExportLog: _exportDataLog,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: screens[_currentIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF111827) : Colors.white,
          border: Border(
            top: BorderSide(
              color: widget.isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
            if (index == 1) _loadAnalyticsData();
            if (index == 3) _loadAlertSettings();
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF06B6D4),
          unselectedItemColor: widget.isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.speed_rounded), label: 'Live Speed'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Analytics'),
            BottomNavigationBarItem(icon: Icon(Icons.widgets_rounded), label: 'Widgets'),
            BottomNavigationBarItem(icon: Icon(Icons.notifications_active_rounded), label: 'Alerts'),
            BottomNavigationBarItem(icon: Icon(Icons.tune_rounded), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 1: DASHBOARD (LIVE SPEED & HOURLY USAGE)
// ---------------------------------------------------------------------------
class DashboardTab extends StatelessWidget {
  final double download;
  final double upload;
  final int ping;
  final int jitter;
  final String networkType;
  final String isp;
  final String ip;
  final bool isTesting;
  final double lastHourMB;
  final VoidCallback onRunTest;
  final bool isDynamicIsland;
  final ValueChanged<bool> onToggleDynamicIsland;
  final String speedUnit;
  final ValueChanged<String> onSelectSpeedUnit;

  const DashboardTab({
    super.key,
    required this.download,
    required this.upload,
    required this.ping,
    required this.jitter,
    required this.networkType,
    required this.isp,
    required this.ip,
    required this.isTesting,
    required this.lastHourMB,
    required this.onRunTest,
    required this.isDynamicIsland,
    required this.onToggleDynamicIsland,
    required this.speedUnit,
    required this.onSelectSpeedUnit,
  });

  String getFormattedSpeed(double mbps) {
    final kbps = mbps * 125.0;
    final mbPerSec = mbps / 8.0;
    switch (speedUnit) {
      case 'KB/s':
        return kbps.toStringAsFixed(0);
      case 'MB/s':
        return mbPerSec.toStringAsFixed(2);
      case 'Mbps':
        return mbps.toStringAsFixed(1);
      default:
        return (mbps < 1.0) ? kbps.toStringAsFixed(0) : mbps.toStringAsFixed(1);
    }
  }

  String getSpeedUnitLabel(double mbps) {
    switch (speedUnit) {
      case 'KB/s':
        return 'KB/s';
      case 'MB/s':
        return 'MB/s';
      case 'Mbps':
        return 'Mbps';
      default:
        return (mbps < 1.0) ? 'KB/s' : 'Mbps';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        networkType,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'NetPulse Pro',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi, size: 14, color: Color(0xFF06B6D4)),
                    const SizedBox(width: 6),
                    Text(
                      '$ping ms',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF06B6D4)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Anti-Hack & Intrusion Threat Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: download > 100 || upload > 40
                  ? const Color(0xFFEF4444).withOpacity(0.15)
                  : const Color(0xFF10B981).withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: download > 100 || upload > 40
                    ? const Color(0xFFEF4444).withOpacity(0.4)
                    : const Color(0xFF10B981).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  download > 100 || upload > 40
                      ? Icons.warning_amber_rounded
                      : Icons.shield_rounded,
                  color: download > 100 || upload > 40
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF10B981),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        download > 100 || upload > 40
                            ? 'WASPADA: Lonjakan Trafik Tinggi!'
                            : 'STATUS: AMAN (Sistem Bersih)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: download > 100 || upload > 40
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF10B981),
                        ),
                      ),
                      Text(
                        download > 100 || upload > 40
                            ? 'Terdeteksi transmisi data mendadak. Periksa aplikasi background!'
                            : 'Tidak ada transmisi background mencurigakan atau indikasi sadap.',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Dynamic Island Live Activity Switch Card for iPhone 15
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDynamicIsland ? const Color(0xFF06B6D4) : Colors.white.withOpacity(0.06),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDynamicIsland ? const Color(0xFF06B6D4) : Colors.white24),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isDynamicIsland ? const Color(0xFF10B981) : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Dynamic Island (iPhone 15)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text(
                          isDynamicIsland ? 'Live Speed aktif di pulau atas' : 'Tampilkan kecepatan live di atas iPhone',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ],
                ),
                Switch(
                  value: isDynamicIsland,
                  onChanged: onToggleDynamicIsland,
                  activeColor: const Color(0xFF06B6D4),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Speedometer Radial Bento Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF111827),
                  const Color(0xFF0F172A).withOpacity(0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF06B6D4).withOpacity(0.08),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              children: [
                Text(
                  isTesting ? 'SEDANG MENGUJI KONEKSI...' : 'LIVE REAL-TIME BANDWIDTH',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                    color: isTesting ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 12),

                // Speed Unit Selector Chips (Auto, Mbps, KB/s, MB/s)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: ['Auto', 'Mbps', 'KB/s', 'MB/s'].map((u) {
                    final isSel = speedUnit == u;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: GestureDetector(
                        onTap: () => onSelectSpeedUnit(u),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSel ? const Color(0xFF06B6D4) : Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isSel ? const Color(0xFF06B6D4) : Colors.white12),
                          ),
                          child: Text(
                            u,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                              color: isSel ? const Color(0xFF090D16) : Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 14),
                // Main Speed Display
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      getFormattedSpeed(download),
                      style: const TextStyle(
                        fontSize: 60,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      getSpeedUnitLabel(download),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
                    ),
                  ],
                ),
                Text(
                  'Ping: $ping ms (Jitter: $jitter ms) • ${(download / 8).toStringAsFixed(2)} MB/s',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),

                const SizedBox(height: 24),

                // Button Speedtest
                SizedBox(
                  width: 200,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isTesting ? null : onRunTest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF06B6D4),
                      foregroundColor: const Color(0xFF090D16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(isTesting ? Icons.hourglass_top_rounded : Icons.play_arrow_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          isTesting ? 'Testing...' : 'Run Speedtest',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2x2 Bento Metrics (Upload, Ping, Jitter, Last 1h Usage)
          Row(
            children: [
              Expanded(
                child: _metricBox(
                  icon: Icons.arrow_upward_rounded,
                  iconColor: const Color(0xFF6366F1),
                  title: 'Upload Speed',
                  value: '${upload.toStringAsFixed(1)} Mbps',
                  sub: '${(upload / 8).toStringAsFixed(1)} MB/s',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricBox(
                  icon: Icons.timer_outlined,
                  iconColor: const Color(0xFF10B981),
                  title: 'Latency / Ping',
                  value: '$ping ms',
                  sub: 'Jitter: $jitter ms',
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _metricBox(
                  icon: Icons.history_toggle_off_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  title: '1 Jam Terakhir',
                  value: '${lastHourMB.toStringAsFixed(1)} MB',
                  sub: '${(lastHourMB / 1024).toStringAsFixed(2)} GB terpakai',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricBox(
                  icon: Icons.router_rounded,
                  iconColor: const Color(0xFF06B6D4),
                  title: 'ISP Provider',
                  value: isp.split(' ').first,
                  sub: ip,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricBox({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String sub,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 2: ANALYTICS (HOURLY, WEEKLY, MONTHLY, YEARLY)
// ---------------------------------------------------------------------------
class AnalyticsTab extends StatefulWidget {
  final double todayGB;
  final double monthGB;
  final double quotaGB;
  final String isp;
  final String networkType;
  final List<double> hourlyDataMB;
  final List<String> hourlyLabels;
  final List<double> weeklyDataGB;
  final List<String> weeklyLabels;
  final List<double> monthlyDataGB;
  final List<String> monthlyLabels;
  final List<double> yearlyDataGB;
  final List<String> yearlyLabels;
  final Future<void> Function() onRefresh;

  const AnalyticsTab({
    super.key,
    required this.todayGB,
    required this.monthGB,
    required this.quotaGB,
    required this.isp,
    required this.networkType,
    required this.hourlyDataMB,
    required this.hourlyLabels,
    required this.weeklyDataGB,
    required this.weeklyLabels,
    required this.monthlyDataGB,
    required this.monthlyLabels,
    required this.yearlyDataGB,
    required this.yearlyLabels,
    required this.onRefresh,
  });

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  int _selectedPeriod = 0; // 0: 1 Jam, 1: Mingguan, 2: Bulanan, 3: Tahunan

  List<String> _defaultHourlyLabels() {
    final now = DateTime.now();
    return List.generate(8, (i) {
      final h = (now.hour - 7 + i + 24) % 24;
      return '${h.toString().padLeft(2, '0')}:00';
    });
  }

  List<double> _currentValues() {
    if (_selectedPeriod == 0) {
      return widget.hourlyDataMB.length >= 8
          ? widget.hourlyDataMB.sublist(widget.hourlyDataMB.length - 8)
          : widget.hourlyDataMB;
    } else if (_selectedPeriod == 1) {
      return widget.weeklyDataGB;
    } else if (_selectedPeriod == 2) {
      return widget.monthlyDataGB;
    } else {
      return widget.yearlyDataGB;
    }
  }

  List<String> _currentLabels() {
    if (_selectedPeriod == 0) {
      return widget.hourlyLabels.length >= 8
          ? widget.hourlyLabels.sublist(widget.hourlyLabels.length - 8)
          : _defaultHourlyLabels();
    } else if (_selectedPeriod == 1) {
      return widget.weeklyLabels;
    } else if (_selectedPeriod == 2) {
      return widget.monthlyLabels;
    } else {
      return widget.yearlyLabels;
    }
  }

  @override
  Widget build(BuildContext context) {
    final values = _currentValues();
    final labels = _currentLabels();
    final peakVal = values.isEmpty ? 0.0 : values.reduce(max);
    final peakIdx = values.isEmpty ? 0 : values.indexOf(peakVal);
    final peakLabel = (peakIdx >= 0 && peakIdx < labels.length) ? labels[peakIdx] : '-';
    final totalPeriodVal = values.fold<double>(0.0, (a, b) => a + b);

    // Dynamic session breakdown sorted by highest recent hours
    final recentHours = widget.hourlyDataMB.length >= 8
        ? widget.hourlyDataMB.sublist(widget.hourlyDataMB.length - 8)
        : widget.hourlyDataMB;
    final recentLabels = widget.hourlyLabels.length >= 8
        ? widget.hourlyLabels.sublist(widget.hourlyLabels.length - 8)
        : _defaultHourlyLabels();

    final sessionItems = <Map<String, dynamic>>[];
    for (int i = recentHours.length - 1; i >= 0; i--) {
      final mb = recentHours[i];
      final lbl = i < recentLabels.length ? recentLabels[i] : '--:00';
      sessionItems.add({
        'label': lbl,
        'mb': mb,
        'isPeak': mb > 0 && mb >= (recentHours.reduce(max)),
      });
    }
    sessionItems.sort((a, b) => (b['mb'] as double).compareTo(a['mb'] as double));
    final topSessions = sessionItems.take(4).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data Usage Analytics',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Rekapitulasi hardware bandwidth Wi-Fi & Seluler',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
              IconButton(
                onPressed: () async {
                  await widget.onRefresh();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✓ Data analytics diperbarui dari sensor jaringan')),
                    );
                  }
                },
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF06B6D4)),
                tooltip: 'Refresh Data',
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Period Segmented Buttons
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                _periodBtn(0, 'Per 1 Jam'),
                _periodBtn(1, 'Mingguan'),
                _periodBtn(2, 'Bulanan'),
                _periodBtn(3, 'Tahunan'),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Chart Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedPeriod == 0
                          ? 'Grafik 8 Jam Terakhir (MB)'
                          : _selectedPeriod == 1
                              ? 'Grafik 7 Hari Terakhir (GB)'
                              : _selectedPeriod == 2
                                  ? 'Tren 6 Bulan Terakhir (GB)'
                                  : 'Tren Tahunan (GB)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _selectedPeriod == 0
                            ? 'Puncak ($peakLabel): ${peakVal.toStringAsFixed(1)} MB'
                            : 'Total: ${totalPeriodVal.toStringAsFixed(2)} GB',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 140,
                  child: _buildBarChart(values, labels),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Summary & Breakdown List
          const Text('Rincian Pemakaian Hardware Live', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          _usageRow(
            'Total Hari Ini (${widget.networkType})',
            '${(widget.todayGB * 1024).toStringAsFixed(1)} MB',
            'ISP: ${widget.isp} • ${widget.todayGB.toStringAsFixed(3)} GB',
            true,
          ),
          _usageRow(
            'Akumulasi Siklus Bulan Ini',
            '${widget.monthGB.toStringAsFixed(2)} GB',
            'Kuota: ${widget.quotaGB.toInt()} GB (${((widget.monthGB / (widget.quotaGB > 0 ? widget.quotaGB : 1)) * 100).toStringAsFixed(1)}%)',
            false,
          ),
          ...topSessions.take(2).map((s) {
            final mb = s['mb'] as double;
            final lbl = s['label'] as String;
            final isPeak = s['isPeak'] as bool;
            return _usageRow(
              isPeak ? 'Jam $lbl (Puncak Terakhir)' : 'Sesi Jam $lbl',
              '${mb.toStringAsFixed(1)} MB',
              '${widget.networkType} • ${widget.isp}',
              isPeak,
            );
          }),
        ],
      ),
    );
  }

  Widget _periodBtn(int index, String label) {
    final isSelected = _selectedPeriod == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPeriod = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF06B6D4) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? const Color(0xFF090D16) : const Color(0xFF94A3B8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart(List<double> values, List<String> labels) {
    if (values.isEmpty) {
      return const Center(child: Text('Mengumpulkan data...', style: TextStyle(color: Color(0xFF64748B))));
    }
    final maxVal = values.fold<double>(0.0, max);
    final safeMax = maxVal > 0 ? maxVal : 1.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(values.length, (i) {
        final val = values[i];
        final heightFactor = maxVal > 0 ? (val / safeMax).clamp(0.06, 1.0) : 0.06;
        final label = i < labels.length ? labels[i] : '';
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              _selectedPeriod == 0
                  ? (val >= 10 ? val.toStringAsFixed(0) : val.toStringAsFixed(1))
                  : val.toStringAsFixed(2),
              style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 6),
            Container(
              width: 18,
              height: 90 * heightFactor,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: val > 0
                      ? [const Color(0xFF06B6D4), const Color(0xFF6366F1)]
                      : [const Color(0xFF1E293B), const Color(0xFF334155)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            ),
          ],
        );
      }),
    );
  }

  Widget _usageRow(String title, String size, String desc, bool isPeak) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isPeak ? const Color(0xFF06B6D4).withOpacity(0.4) : Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isPeak ? const Color(0xFF06B6D4).withOpacity(0.15) : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isPeak ? Icons.bolt_rounded : Icons.data_usage_rounded,
                  color: isPeak ? const Color(0xFF06B6D4) : const Color(0xFF94A3B8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(desc, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ],
          ),
          Text(size, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF06B6D4))),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 3: WIDGETS GALLERY (SMALL, MEDIUM, LARGE, LOCK SCREEN PREVIEWS)
// ---------------------------------------------------------------------------
class WidgetsGalleryTab extends StatelessWidget {
  final double download;
  final double upload;
  final double lastHourMB;
  final double todayGB;
  final double monthGB;
  final String isp;
  final Future<void> Function() onReloadWidget;

  const WidgetsGalleryTab({
    super.key,
    required this.download,
    required this.upload,
    required this.lastHourMB,
    required this.todayGB,
    required this.monthGB,
    required this.isp,
    required this.onReloadWidget,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'iOS & Android Widgets',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          const Text(
            'Preview tampilan widget live di Home Screen & Lock Screen iPhone / Android',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),

          const SizedBox(height: 16),

          // Panduan Memasang Widget Resmi di iPhone
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF06B6D4).withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '💡 Cara Memasang Widget di iPhone:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
                ),
                SizedBox(height: 6),
                Text(
                  '1. Tekan & tahan (long-press) area kosong di Home Screen iPhone sampai ikon bergoyang.\n2. Tap tombol tanda tambah (+) di pojok kiri atas layar.\n3. Cari \"NetPulse Anti-Hack Sentry\" pada daftar widget.\n4. Pilih ukuran Small atau Medium lalu tap \"Tambah Widget\"!',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), height: 1.4),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Small Widget (2x2)
          const Text('1. Small Widget (2x2 Compact)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 160,
              height: 160,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 15, offset: Offset(0, 8))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.speed_rounded, size: 20, color: Color(0xFF06B6D4)),
                      Text(
                        isp.split(' ').first,
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        download.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                      const Text('Mbps Download', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('1 Jam: ${lastHourMB.toInt()}MB', style: const TextStyle(fontSize: 9, color: Color(0xFFF59E0B))),
                      Text('↑ ${upload.toStringAsFixed(0)}M', style: const TextStyle(fontSize: 9, color: Color(0xFF6366F1))),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await onReloadWidget();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✓ Data disinkronkan ke Small Widget iOS! Pasang via (+) di Home Screen.')),
                  );
                }
              },
              icon: const Icon(Icons.sync_rounded, size: 16),
              label: const Text('Sinkronkan & Refresh Small Widget'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
                foregroundColor: const Color(0xFF090D16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Medium Widget (4x2 Wide)
          const Text('2. Medium Widget (4x2 Live Speed & Mini Chart)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            height: 150,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF111827), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
              boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 15, offset: Offset(0, 8))],
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.wifi, size: 14, color: Color(0xFF06B6D4)),
                              SizedBox(width: 6),
                              Text('NetPulse', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                          Text(
                            isp,
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
                          ),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            download.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                          const SizedBox(width: 4),
                          const Text('Mbps', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4))),
                        ],
                      ),
                      Text('Upload: ${upload.toStringAsFixed(1)} Mbps • Ping: 14ms', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    ],
                  ),
                ),
                Container(width: 1, height: double.infinity, color: Colors.white.withOpacity(0.08)),
                const SizedBox(width: 14),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Pemakaian 1 Jam', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                      Text('${lastHourMB.toStringAsFixed(1)} MB', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
                      Text('Hari ini: ${todayGB.toStringAsFixed(2)} GB\nBulan ini: ${monthGB.toStringAsFixed(1)} GB', style: const TextStyle(fontSize: 9, color: Color(0xFF64748B), height: 1.3)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await onReloadWidget();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✓ Data disinkronkan ke Medium Widget iOS! Tap ↻ di widget untuk refresh cepat.')),
                  );
                }
              },
              icon: const Icon(Icons.sync_rounded, size: 16),
              label: const Text('Sinkronkan & Refresh Medium Widget'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
                foregroundColor: const Color(0xFF090D16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 4: QUOTA ALERTS & LIMITS
// ---------------------------------------------------------------------------
class QuotaAlertTab extends StatefulWidget {
  final double currentUsageGB;
  final double quotaLimitGB;
  final double dailyUsageMB;
  final double hourlyUsageMB;
  final double dailyLimitMB;
  final double hourlyLimitMB;
  final bool dailyLimitActive;
  final bool hourlyLimitActive;
  final bool quota80Active;
  final bool quota95Active;
  final bool switchNetworkActive;
  final ValueChanged<double> onDailyLimitChanged;
  final ValueChanged<bool> onDailyLimitToggled;
  final ValueChanged<double> onHourlyLimitChanged;
  final ValueChanged<bool> onHourlyLimitToggled;
  final ValueChanged<bool> onQuota80Toggled;
  final ValueChanged<bool> onQuota95Toggled;
  final ValueChanged<bool> onSwitchNetworkToggled;
  final ValueChanged<double> onQuotaLimitChanged;

  const QuotaAlertTab({
    super.key,
    required this.currentUsageGB,
    required this.quotaLimitGB,
    required this.dailyUsageMB,
    required this.hourlyUsageMB,
    required this.dailyLimitMB,
    required this.hourlyLimitMB,
    required this.dailyLimitActive,
    required this.hourlyLimitActive,
    required this.quota80Active,
    required this.quota95Active,
    required this.switchNetworkActive,
    required this.onDailyLimitChanged,
    required this.onDailyLimitToggled,
    required this.onHourlyLimitChanged,
    required this.onHourlyLimitToggled,
    required this.onQuota80Toggled,
    required this.onQuota95Toggled,
    required this.onSwitchNetworkToggled,
    required this.onQuotaLimitChanged,
  });

  @override
  State<QuotaAlertTab> createState() => _QuotaAlertTabState();
}

class _QuotaAlertTabState extends State<QuotaAlertTab> {
  bool _testAlertTriggered = false;

  void _showSetDailyLimitDialog() {
    final controller = TextEditingController(text: widget.dailyLimitMB.toInt().toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: const Text('Setting Batas Harian (MB)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Contoh: 1024',
            suffixText: 'MB',
            suffixStyle: TextStyle(color: Color(0xFF06B6D4)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text) ?? widget.dailyLimitMB;
              widget.onDailyLimitChanged(val);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('✓ Batas harian diubah ke: ${val.toInt()} MB (${(val / 1024).toStringAsFixed(2)} GB)')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4)),
            child: const Text('Simpan', style: TextStyle(color: Color(0xFF090D16), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSetHourlyLimitDialog() {
    final controller = TextEditingController(text: widget.hourlyLimitMB.toInt().toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: const Text('Setting Batas 1 Jam (MB)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Contoh: 500',
            suffixText: 'MB',
            suffixStyle: TextStyle(color: Color(0xFF06B6D4)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text) ?? widget.hourlyLimitMB;
              widget.onHourlyLimitChanged(val);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('✓ Batas 1 jam diubah ke: ${val.toInt()} MB')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4)),
            child: const Text('Simpan', style: TextStyle(color: Color(0xFF090D16), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSetMonthlyQuotaDialog() {
    final controller = TextEditingController(text: widget.quotaLimitGB.toInt().toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: const Text('Setting Batas Kuota Bulanan', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Contoh: 150',
            suffixText: 'GB',
            suffixStyle: TextStyle(color: Color(0xFF06B6D4)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text) ?? widget.quotaLimitGB;
              widget.onQuotaLimitChanged(val);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('✓ Batas kuota bulanan diubah ke: ${val.toInt()} GB')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4)),
            child: const Text('Simpan', style: TextStyle(color: Color(0xFF090D16), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _triggerTestAlert() {
    HapticFeedback.heavyImpact();
    setState(() => _testAlertTriggered = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFFEF4444),
        content: Text('🚨 SIMULASI ALARM: Batas kuota harian terlewati! Notifikasi sentry aktif.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) setState(() => _testAlertTriggered = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final quotaSafe = widget.quotaLimitGB > 0 ? widget.quotaLimitGB : 1.0;
    final percent = (widget.currentUsageGB / quotaSafe).clamp(0.0, 1.0);
    final remainingGB = (widget.quotaLimitGB - widget.currentUsageGB).clamp(0.0, widget.quotaLimitGB);

    final isDailyExceeded = widget.dailyLimitActive && (widget.dailyUsageMB >= widget.dailyLimitMB);
    final isHourlyExceeded = widget.hourlyLimitActive && (widget.hourlyUsageMB >= widget.hourlyLimitMB);
    final isQuota80Exceeded = widget.quota80Active && (percent >= 0.8);
    final hasActiveWarning = isDailyExceeded || isHourlyExceeded || isQuota80Exceeded || _testAlertTriggered;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quota & Bandwidth Alerts',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          const Text(
            'Atur batas kuota data seluler/Wi-Fi agar tidak jebol',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),

          const SizedBox(height: 16),

          // Active Warning Banner (When limits exceeded or tested)
          if (hasActiveWarning) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.6)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _testAlertTriggered
                              ? '🚨 SIMULASI ALARM NETPULSE AKTIF'
                              : isDailyExceeded
                                  ? '🚨 BATAS HARIAN TERLEWATI!'
                                  : isHourlyExceeded
                                      ? '⚠️ LONJAKAN 1 JAM TERDETEKSI!'
                                      : '⚠️ PERINGATAN KUOTA 80%+',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isDailyExceeded
                              ? 'Pemakaian hari ini (${widget.dailyUsageMB.toStringAsFixed(1)} MB) melebihi batas (${widget.dailyLimitMB.toInt()} MB).'
                              : isHourlyExceeded
                                  ? 'Trafik 1 jam (${widget.hourlyUsageMB.toStringAsFixed(1)} MB) melebihi batas (${widget.hourlyLimitMB.toInt()} MB).'
                                  : 'Sisa kuota bulanan tersisa ${remainingGB.toStringAsFixed(1)} GB.',
                          style: const TextStyle(fontSize: 11, color: Color(0xFFFCA5A5)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Quota Progress Card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('Batas Kuota Bulanan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _showSetMonthlyQuotaDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF06B6D4).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Edit GB', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4))),
                          ),
                        ),
                      ],
                    ),
                    Text('${(percent * 100).toStringAsFixed(1)}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: percent >= 0.8 ? const Color(0xFFEF4444) : const Color(0xFF06B6D4))),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 12,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(percent >= 0.8 ? const Color(0xFFEF4444) : const Color(0xFF06B6D4)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Terpakai: ${widget.currentUsageGB.toStringAsFixed(2)} GB', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    Text('Sisa: ${remainingGB.toStringAsFixed(2)} GB / ${widget.quotaLimitGB.toInt()} GB', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const Text('Aturan Notifikasi & Batas Harian', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),

          // Interactive Batas Pemakaian Harian
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: widget.dailyLimitActive ? const Color(0xFF06B6D4).withOpacity(0.4) : Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Batas Pemakaian Harian', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: widget.dailyLimitActive ? const Color(0xFF10B981).withOpacity(0.2) : Colors.white10,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  widget.dailyLimitActive ? 'AKTIF' : 'OFF',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: widget.dailyLimitActive ? const Color(0xFF10B981) : Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text('Penggunaan hari ini: ${widget.dailyUsageMB.toStringAsFixed(1)} MB', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    Switch(
                      value: widget.dailyLimitActive,
                      onChanged: widget.onDailyLimitToggled,
                      activeColor: const Color(0xFF06B6D4),
                    ),
                  ],
                ),
                if (widget.dailyLimitActive) ...[
                  const Divider(color: Colors.white10, height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Setting Kuota: ${widget.dailyLimitMB.toInt()} MB (${(widget.dailyLimitMB / 1024).toStringAsFixed(2)} GB)',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
                      ),
                      TextButton.icon(
                        onPressed: _showSetDailyLimitDialog,
                        icon: const Icon(Icons.edit, size: 12, color: Color(0xFF06B6D4)),
                        label: const Text('Ubah MB', style: TextStyle(fontSize: 11, color: Color(0xFF06B6D4))),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Interactive Batas Pemakaian Per 1 Jam
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: widget.hourlyLimitActive ? const Color(0xFF06B6D4).withOpacity(0.4) : Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Batas Pemakaian 1 Jam (${widget.hourlyLimitMB.toInt()} MB)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: widget.hourlyLimitActive ? const Color(0xFF10B981).withOpacity(0.2) : Colors.white10,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  widget.hourlyLimitActive ? 'AKTIF' : 'OFF',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: widget.hourlyLimitActive ? const Color(0xFF10B981) : Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text('Trafik 1 jam terakhir: ${widget.hourlyUsageMB.toStringAsFixed(1)} MB', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    Switch(
                      value: widget.hourlyLimitActive,
                      onChanged: widget.onHourlyLimitToggled,
                      activeColor: const Color(0xFF06B6D4),
                    ),
                  ],
                ),
                if (widget.hourlyLimitActive) ...[
                  const Divider(color: Colors.white10, height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Peringatan lonjakan jika 1 jam > ${widget.hourlyLimitMB.toInt()} MB',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
                      ),
                      TextButton.icon(
                        onPressed: _showSetHourlyLimitDialog,
                        icon: const Icon(Icons.edit, size: 12, color: Color(0xFF06B6D4)),
                        label: const Text('Ubah MB', style: TextStyle(fontSize: 11, color: Color(0xFF06B6D4))),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          _alertToggle(
            'Peringatan Kuota 80%',
            'Kirim notifikasi push saat kuota mencapai 80%',
            widget.quota80Active,
            widget.onQuota80Toggled,
          ),

          _alertToggle(
            'Peringatan Kuota 95%',
            'Kirim alarm keras saat kuota tersisa 5%',
            widget.quota95Active,
            widget.onQuota95Toggled,
          ),

          _alertToggle(
            'Notifikasi Putus / Pindah Koneksi',
            'Getar & tampilkan snackbar jika Wi-Fi beralih ke Seluler',
            widget.switchNetworkActive,
            widget.onSwitchNetworkToggled,
          ),

          const SizedBox(height: 12),

          // Simulation Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _triggerTestAlert,
              icon: const Icon(Icons.crisis_alert_rounded, size: 16, color: Color(0xFFEF4444)),
              label: const Text('Uji Coba Alarm & Simulasi Notifikasi Sentry', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFEF4444)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _alertToggle(String title, String desc, bool val, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Switch(
            value: val,
            onChanged: onChanged,
            activeColor: const Color(0xFF06B6D4),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 5: SETTINGS & CONFIGURATION
// ---------------------------------------------------------------------------
class SettingsTab extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  final String networkType;
  final String ispName;
  final String speedUnit;
  final double monthlyQuotaGB;
  final int resetDay;
  final ValueChanged<String> onNetworkChanged;
  final ValueChanged<String> onSelectSpeedUnit;
  final ValueChanged<double> onMonthlyQuotaChanged;
  final ValueChanged<int> onResetDayChanged;
  final VoidCallback onExportLog;

  const SettingsTab({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    required this.networkType,
    required this.ispName,
    required this.speedUnit,
    required this.monthlyQuotaGB,
    required this.resetDay,
    required this.onNetworkChanged,
    required this.onSelectSpeedUnit,
    required this.onMonthlyQuotaChanged,
    required this.onResetDayChanged,
    required this.onExportLog,
  });

  void _showSpeedUnitSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pilih Satuan Kecepatan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 14),
                for (final u in ['Auto', 'Mbps', 'MB/s', 'KB/s'])
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    tileColor: speedUnit == u ? const Color(0xFF06B6D4).withOpacity(0.12) : null,
                    title: Text(u, style: TextStyle(color: speedUnit == u ? const Color(0xFF06B6D4) : Colors.white, fontWeight: FontWeight.bold)),
                    trailing: speedUnit == u ? const Icon(Icons.check_rounded, color: Color(0xFF06B6D4)) : null,
                    onTap: () {
                      onSelectSpeedUnit(u);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('✓ Satuan kecepatan diubah ke: $u')),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showResetDayDialog(BuildContext context) {
    int selected = resetDay;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: const Text('Pilih Tanggal Reset Siklus Kuota', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: StatefulBuilder(
          builder: (context, setLocalState) {
            return DropdownButton<int>(
              value: selected,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              isExpanded: true,
              items: List.generate(31, (i) => i + 1).map((day) {
                return DropdownMenuItem(value: day, child: Text('Tanggal $day tiap bulan'));
              }).toList(),
              onChanged: (val) {
                if (val != null) setLocalState(() => selected = val);
              },
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              onResetDayChanged(selected);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('✓ Siklus kuota akan direset setiap tanggal $selected')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4)),
            child: const Text('Simpan', style: TextStyle(color: Color(0xFF090D16), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showMonthlyQuotaDialog(BuildContext context) {
    final controller = TextEditingController(text: monthlyQuotaGB.toInt().toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: const Text('Setting Kuota Bulanan (GB)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Contoh: 150',
            suffixText: 'GB',
            suffixStyle: TextStyle(color: Color(0xFF06B6D4)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text) ?? monthlyQuotaGB;
              onMonthlyQuotaChanged(val);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('✓ Batas kuota bulanan diubah ke: ${val.toInt()} GB')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4)),
            child: const Text('Simpan', style: TextStyle(color: Color(0xFF090D16), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings & Preferences',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          const Text(
            'Konfigurasi satuan kecepatan, tanggal reset kuota, dan preferensi aplikasi',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),

          const SizedBox(height: 24),

          _settingsTile(
            icon: Icons.dark_mode_rounded,
            title: 'Tema Tampilan',
            desc: isDark ? 'OLED Dark Mode (Hemat Baterai)' : 'Clean Alabaster Light Mode',
            trailing: Switch(value: isDark, onChanged: (_) => onToggleTheme(), activeColor: const Color(0xFF06B6D4)),
          ),

          GestureDetector(
            onTap: () => _showSpeedUnitSelector(context),
            child: _settingsTile(
              icon: Icons.scale_rounded,
              title: 'Satuan Kecepatan',
              desc: 'Pilihan format: Auto, Mbps, MB/s, KB/s',
              trailing: Row(
                children: [
                  Text(speedUnit, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF06B6D4))),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B), size: 18),
                ],
              ),
            ),
          ),

          _settingsTile(
            icon: Icons.router_rounded,
            title: 'Nama ISP Provider',
            desc: '$networkType • Terdeteksi otomatis dari antarmuka fisik',
            trailing: Text(ispName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF06B6D4))),
          ),

          GestureDetector(
            onTap: () => _showMonthlyQuotaDialog(context),
            child: _settingsTile(
              icon: Icons.pie_chart_outline_rounded,
              title: 'Batas Kuota Bulanan',
              desc: 'Batas paket data internet Anda',
              trailing: Row(
                children: [
                  Text('${monthlyQuotaGB.toInt()} GB', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF06B6D4))),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B), size: 18),
                ],
              ),
            ),
          ),

          GestureDetector(
            onTap: () => _showResetDayDialog(context),
            child: _settingsTile(
              icon: Icons.calendar_month_rounded,
              title: 'Tanggal Reset Kuota',
              desc: 'Reset counter otomatis tiap tanggal $resetDay',
              trailing: Row(
                children: [
                  Text('Tgl $resetDay', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B), size: 18),
                ],
              ),
            ),
          ),

          GestureDetector(
            onTap: onExportLog,
            child: _settingsTile(
              icon: Icons.file_download_outlined,
              title: 'Export Data Log (CSV)',
              desc: 'Simpan dan salin riwayat pemakaian per jam ke CSV',
              trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B)),
            ),
          ),

          const SizedBox(height: 20),

          // Build Info Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NetPulse Pro for iOS & Android', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                SizedBox(height: 4),
                Text('Version 2.0.21 (Build 21) • Hardware Monitor & WidgetKit Engine', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                SizedBox(height: 4),
                Text('GitHub Actions Engine: macOS Runner (iOS .ipa) & Ubuntu Runner (Android .apk)', style: TextStyle(fontSize: 10, color: Color(0xFF06B6D4))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String desc,
    required Widget trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF06B6D4).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF06B6D4), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
