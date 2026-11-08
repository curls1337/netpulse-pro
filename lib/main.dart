import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

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
  double _downloadSpeed = 84.5; // Mbps
  double _uploadSpeed = 36.2; // Mbps
  int _ping = 14; // ms
  int _jitter = 2; // ms
  String _networkType = 'Wi-Fi 6 (5GHz)';
  String _ispName = 'Biznet Fiber Ultra';
  String _ipAddress = '182.253.112.94';
  bool _isTesting = false;

  // Usage Stats
  double _lastHourUsageMB = 142.8;
  double _todayUsageGB = 4.2;
  double _monthUsageGB = 84.6;
  double _monthlyQuotaGB = 150.0;

  Timer? _metricsTimer;

  @override
  void initState() {
    super.initState();
    _startSimulatedMetrics();
  }

  @override
  void dispose() {
    _metricsTimer?.cancel();
    super.dispose();
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
      ),
      AnalyticsTab(todayGB: _todayUsageGB, monthGB: _monthUsageGB, quotaGB: _monthlyQuotaGB),
      WidgetsGalleryTab(
        download: _downloadSpeed,
        upload: _uploadSpeed,
        lastHourMB: _lastHourUsageMB,
        isp: _ispName,
      ),
      QuotaAlertTab(currentUsageGB: _monthUsageGB, quotaLimitGB: _monthlyQuotaGB),
      SettingsTab(
        isDark: widget.isDark,
        onToggleTheme: widget.onToggleTheme,
        networkType: _networkType,
        onNetworkChanged: (val) => setState(() => _networkType = val),
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
          onTap: (index) => setState(() => _currentIndex = index),
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
  });

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

          const SizedBox(height: 24),

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
                const SizedBox(height: 16),
                // Main Speed Display
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      download.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Mbps',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
                    ),
                  ],
                ),
                Text(
                  '≈ ${(download / 8).toStringAsFixed(2)} MB/s transfer rate',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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

  const AnalyticsTab({super.key, required this.todayGB, required this.monthGB, required this.quotaGB});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  int _selectedPeriod = 0; // 0: 1 Jam, 1: Mingguan, 2: Bulanan, 3: Tahunan
  String _networkFilter = 'Semua';

  final List<double> _hourlyDataMB = [
    12.4, 8.1, 4.2, 2.5, 3.0, 15.6, 45.2, 98.4, 142.8, 120.5, 95.0, 88.2,
    110.4, 135.2, 102.0, 94.5, 115.0, 158.4, 180.2, 210.5, 195.0, 145.2, 90.0, 42.0
  ];

  final List<double> _weeklyDataGB = [3.8, 4.2, 5.1, 4.0, 6.2, 8.4, 7.1];
  final List<String> _weeklyLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  final List<double> _monthlyDataGB = [82.4, 91.0, 78.5, 94.2, 88.0, 84.6];
  final List<String> _monthlyLabels = ['Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov'];

  final List<double> _yearlyDataGB = [850, 920, 1040, 1180];
  final List<String> _yearlyLabels = ['2023', '2024', '2025', '2026'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Data Usage Analytics',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          const Text(
            'Rekapitulasi pemakaian bandwidth internet Wi-Fi & Seluler',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
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
                          ? 'Grafik 24 Jam Terakhir (MB)'
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
                        _selectedPeriod == 0 ? 'Puncak: 210.5 MB' : 'Total: ${widget.monthGB} GB',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Simple Responsive Bar Chart Visual
                SizedBox(
                  height: 140,
                  child: _buildBarChart(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Breakdown List
          const Text('Rincian Pemakaian Sesi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          _usageRow('Jam 19:00 - 20:00 (Puncak)', '210.5 MB', 'Wi-Fi 5GHz • Streaming 4K', true),
          _usageRow('Jam 18:00 - 19:00', '180.2 MB', 'Wi-Fi 5GHz • Online Meeting', false),
          _usageRow('Jam 17:00 - 18:00', '158.4 MB', 'Seluler 5G • Social Media', false),
          _usageRow('Jam 16:00 - 17:00', '115.0 MB', 'Wi-Fi 5GHz • Browsing', false),
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

  Widget _buildBarChart() {
    List<double> values;
    List<String> labels;

    if (_selectedPeriod == 0) {
      values = _hourlyDataMB.sublist(16, 24); // Show last 8 hours
      labels = ['16:00', '17:00', '18:00', '19:00', '20:00', '21:00', '22:00', '23:00'];
    } else if (_selectedPeriod == 1) {
      values = _weeklyDataGB;
      labels = _weeklyLabels;
    } else if (_selectedPeriod == 2) {
      values = _monthlyDataGB;
      labels = _monthlyLabels;
    } else {
      values = _yearlyDataGB;
      labels = _yearlyLabels;
    }

    final maxVal = values.reduce(max);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(values.length, (i) {
        final heightFactor = values[i] / maxVal;
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              _selectedPeriod == 0 ? '${values[i].toInt()}' : values[i].toStringAsFixed(1),
              style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 6),
            Container(
              width: 18,
              height: 90 * heightFactor,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF06B6D4), Color(0xFF6366F1)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              labels[i],
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
  final String isp;

  const WidgetsGalleryTab({
    super.key,
    required this.download,
    required this.upload,
    required this.lastHourMB,
    required this.isp,
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

          const SizedBox(height: 24),

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
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✓ Small Widget telah ditambahkan ke Home Screen!')),
                );
              },
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Tambahkan Small Widget ke Home Screen'),
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
                      const Text('Hari ini: 4.2 GB\\nBulan ini: 84.6 GB', style: TextStyle(fontSize: 9, color: Color(0xFF64748B), height: 1.3)),
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
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✓ Medium Widget telah ditambahkan ke Home Screen!')),
                );
              },
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Tambahkan Medium Widget ke Home Screen'),
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

  const QuotaAlertTab({super.key, required this.currentUsageGB, required this.quotaLimitGB});

  @override
  State<QuotaAlertTab> createState() => _QuotaAlertTabState();
}

class _QuotaAlertTabState extends State<QuotaAlertTab> {
  bool _dailyLimitActive = true;
  double _dailyLimitMB = 1024.0;
  bool _quota80Active = true;
  bool _quota95Active = true;
  bool _hourlyLimitActive = true;
  bool _switchNetworkActive = false;

  void _showSetDailyLimitDialog() {
    final controller = TextEditingController(text: _dailyLimitMB.toInt().toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: const Text('Setting Batas Harian (MB)', style: TextStyle(color: Colors.white, fontSize: 16)),
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
              final val = double.tryParse(controller.text) ?? _dailyLimitMB;
              setState(() => _dailyLimitMB = val);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Batas harian diubah ke: ${val.toInt()} MB (${(val / 1024).toStringAsFixed(2)} GB)')),
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
    final percent = (widget.currentUsageGB / widget.quotaLimitGB).clamp(0.0, 1.0);
    final remainingGB = (widget.quotaLimitGB - widget.currentUsageGB).clamp(0.0, widget.quotaLimitGB);

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

          const SizedBox(height: 24),

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
                    const Text('Batas Kuota Bulanan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text('${(percent * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4))),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 12,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF06B6D4)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Terpakai: ${widget.currentUsageGB.toStringAsFixed(1)} GB', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    Text('Sisa: ${remainingGB.toStringAsFixed(1)} GB', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const Text('Aturan Notifikasi & Batas Harian', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),

          // Interactive Batas Pemakaian Harian (Bisa di-ON-kan & di-Setting MB-nya)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _dailyLimitActive ? const Color(0xFF06B6D4).withOpacity(0.4) : Colors.white.withOpacity(0.06)),
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
                                  color: _dailyLimitActive ? const Color(0xFF10B981).withOpacity(0.2) : Colors.white10,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _dailyLimitActive ? 'AKTIF' : 'OFF',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: _dailyLimitActive ? const Color(0xFF10B981) : Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text('Kirim alarm jika pemakaian hari ini melebihi batas', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    Switch(
                      value: _dailyLimitActive,
                      onChanged: (val) {
                        setState(() => _dailyLimitActive = val);
                      },
                      activeColor: const Color(0xFF06B6D4),
                    ),
                  ],
                ),
                if (_dailyLimitActive) ...[
                  const Divider(color: Colors.white10, height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Setting Kuota: ${_dailyLimitMB.toInt()} MB (${(_dailyLimitMB / 1024).toStringAsFixed(2)} GB)',
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

          _alertToggle(
            'Batas Pemakaian Per 1 Jam (500 MB)',
            'Peringatkan jika ada aplikasi download berlebih',
            _hourlyLimitActive,
            (val) => setState(() => _hourlyLimitActive = val),
          ),

          _alertToggle(
            'Peringatan Kuota 80%',
            'Kirim notifikasi push saat kuota mencapai 80%',
            _quota80Active,
            (val) => setState(() => _quota80Active = val),
          ),

          _alertToggle(
            'Peringatan Kuota 95%',
            'Kirim alarm keras saat kuota tersisa 5%',
            _quota95Active,
            (val) => setState(() => _quota95Active = val),
          ),

          _alertToggle(
            'Notifikasi Putus Koneksi',
            'Bunyikan getar jika Wi-Fi beralih ke Seluler',
            _switchNetworkActive,
            (val) => setState(() => _switchNetworkActive = val),
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
  final ValueChanged<String> onNetworkChanged;

  const SettingsTab({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    required this.networkType,
    required this.onNetworkChanged,
  });

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

          _settingsTile(
            icon: Icons.scale_rounded,
            title: 'Satuan Kecepatan',
            desc: 'Mbps (Megabit per detik) & MB/s',
            trailing: const Text('Mbps', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF06B6D4))),
          ),

          _settingsTile(
            icon: Icons.router_rounded,
            title: 'Nama ISP Provider',
            desc: 'Penyedia layanan internet aktif saat ini',
            trailing: Text(networkType.contains('Wi-Fi') ? 'Biznet Fiber' : 'Telkomsel 5G', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF06B6D4))),
          ),

          _settingsTile(
            icon: Icons.calendar_month_rounded,
            title: 'Tanggal Reset Kuota',
            desc: 'Reset counter setiap tanggal 1 tiap bulan',
            trailing: const Text('Tgl 1', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),

          _settingsTile(
            icon: Icons.file_download_outlined,
            title: 'Export Data Log',
            desc: 'Simpan riwayat pemakaian per 1 jam ke CSV/JSON',
            trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B)),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('NetPulse Pro for iOS & Android', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                SizedBox(height: 4),
                Text('Version 1.0.0 (Build 1) • Mode 4 Zero-Local Cloud Build', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
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
