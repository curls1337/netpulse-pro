import os

html_code = """<!DOCTYPE html>
<html lang="id" class="dark">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover" />
  <title>NetPulse Pro — Interactive iPhone 15 Pro & Widget Simulator</title>
  
  <!-- Tailwind CSS CDN & Google Fonts -->
  <script src="https://cdn.tailwindcss.com"></script>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800;900&display=swap" rel="stylesheet" />

  <script>
    tailwind.config = {
      darkMode: 'class',
      theme: {
        extend: {
          fontFamily: {
            sans: ['"Plus Jakarta Sans"', 'sans-serif'],
          },
          colors: {
            oled: '#090D16',
            surface: '#111827',
            card: '#161F30',
            neonCyan: '#06B6D4',
            neonIndigo: '#6366F1',
            neonEmerald: '#10B981',
            neonAmber: '#F59E0B'
          }
        }
      }
    }
  </script>
  <style>
    body {
      background: radial-gradient(circle at 50% 20%, #111827 0%, #030712 100%);
      font-family: 'Plus Jakarta Sans', sans-serif;
    }
    /* iPhone 15 Pro Titanium Frame */
    .iphone-case {
      width: 395px;
      height: 812px;
      border-radius: 54px;
      box-shadow: 0 0 0 12px #262c3a, 0 0 0 14px #1b1f29, 0 25px 50px -12px rgba(0, 0, 0, 0.75), 0 0 40px rgba(6, 182, 212, 0.15);
      position: relative;
      overflow: hidden;
    }
    .dynamic-island {
      width: 120px;
      height: 32px;
      background: #000000;
      border-radius: 20px;
      position: absolute;
      top: 10px;
      left: 50%;
      transform: translateX(-50%);
      z-index: 50;
      transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1);
    }
    .dynamic-island:hover {
      width: 220px;
      height: 44px;
      border-radius: 24px;
    }
    .glass-card {
      background: rgba(17, 24, 39, 0.85);
      backdrop-filter: blur(16px);
      border: 1px solid rgba(255, 255, 255, 0.08);
    }
    .widget-shadow {
      box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.5), 0 0 15px rgba(6, 182, 212, 0.1);
    }
    /* Hide scrollbars */
    ::-webkit-scrollbar { display: none; }
    * { -ms-overflow-style: none; scrollbar-width: none; }
  </style>
</head>
<body class="min-h-screen text-slate-100 flex flex-col items-center justify-center p-4 py-8 select-none">

  <!-- Simulator Top Navigation / Mode Switcher -->
  <div class="max-w-4xl w-full flex flex-col md:flex-row items-center justify-between gap-4 mb-6 px-4">
    <div class="flex items-center gap-3">
      <div class="w-10 h-10 rounded-2xl bg-gradient-to-tr from-cyan-500 to-indigo-600 flex items-center justify-center text-slate-950 font-black shadow-lg shadow-cyan-500/20">
        NP
      </div>
      <div>
        <h1 class="text-lg font-extrabold text-white tracking-tight flex items-center gap-2">
          NetPulse Pro
          <span class="text-[10px] uppercase font-bold tracking-wider px-2 py-0.5 rounded-full bg-cyan-500/20 text-cyan-400 border border-cyan-500/30">Simulator</span>
        </h1>
        <p class="text-xs text-slate-400">Interactive iPhone 15 Pro & Home Screen Widget Suite</p>
      </div>
    </div>

    <!-- Mode Selector Tabs -->
    <div class="flex items-center gap-2 p-1.5 rounded-2xl bg-slate-900 border border-slate-800 shadow-xl">
      <button onclick="switchMode('app')" id="btn-mode-app" class="px-4 py-2 rounded-xl text-xs font-bold transition flex items-center gap-2 bg-cyan-500 text-slate-950 shadow-md shadow-cyan-500/20">
        📱 Full iOS App
      </button>
      <button onclick="switchMode('widgets')" id="btn-mode-widgets" class="px-4 py-2 rounded-xl text-xs font-semibold text-slate-400 hover:text-white transition flex items-center gap-2">
        🔲 Home Screen Widgets
      </button>
      <button onclick="switchMode('lockscreen')" id="btn-mode-lockscreen" class="px-4 py-2 rounded-xl text-xs font-semibold text-slate-400 hover:text-white transition flex items-center gap-2">
        🔒 Lock Screen
      </button>
    </div>
  </div>

  <!-- The iPhone 15 Pro Physical Device Frame -->
  <div class="iphone-case bg-oled flex flex-col">
    
    <!-- Dynamic Island -->
    <div class="dynamic-island flex items-center justify-between px-3 text-[10px] text-slate-400">
      <div class="flex items-center gap-1.5">
        <span class="w-2 h-2 rounded-full bg-cyan-400 animate-pulse"></span>
        <span class="font-bold text-white text-[9px]" id="island-speed">84.5M</span>
      </div>
      <div class="flex items-center gap-1">
        <span class="text-emerald-400 text-[9px]">↑36M</span>
      </div>
    </div>

    <!-- Status Bar (iOS 17 Clock & Icons) -->
    <div class="h-11 pt-3 px-7 flex items-center justify-between text-xs font-bold text-white z-40">
      <span id="clock-time">09:41</span>
      <div class="flex items-center gap-2 text-[10px]">
        <span>5G</span>
        <span>Wi-Fi</span>
        <span>100%</span>
      </div>
    </div>

    <!-- SCREEN CONTENT 1: FULL APP -->
    <div id="screen-app" class="flex-1 flex flex-col overflow-hidden relative">
      
      <!-- Scrollable Tab Views -->
      <div class="flex-1 overflow-y-auto px-5 pt-3 pb-24" id="app-content-container">
        
        <!-- ================= TAB 1: LIVE SPEED DASHBOARD ================= -->
        <div id="tab-view-speed" class="space-y-4">
          <!-- Header Network Status -->
          <div class="flex items-center justify-between pt-1">
            <div>
              <div class="flex items-center gap-2">
                <span class="w-2 h-2 rounded-full bg-emerald-400 animate-ping"></span>
                <span class="text-xs font-bold text-emerald-400" id="live-network-badge">Wi-Fi 6 (5GHz)</span>
              </div>
              <h2 class="text-xl font-black text-white tracking-tight mt-0.5">Speed Monitor</h2>
            </div>
            <div class="px-3 py-1 rounded-full bg-cyan-500/10 border border-cyan-500/30 text-cyan-400 text-xs font-bold flex items-center gap-1.5">
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M13 10V3L4 14h7v7l9-11h-7z"/></svg>
              <span id="live-ping">14 ms</span>
            </div>
          </div>

          <!-- Radial Hero Speedometer Card -->
          <div class="glass-card rounded-3xl p-6 text-center relative overflow-hidden">
            <div class="absolute inset-0 bg-gradient-to-b from-cyan-500/10 via-transparent to-transparent pointer-events-none"></div>
            <div class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-3" id="speedtest-status-label">
              REAL-TIME BANDWIDTH
            </div>

            <div class="flex items-baseline justify-center gap-1 my-2">
              <span class="text-6xl font-black text-white tracking-tighter" id="live-download-speed">84.5</span>
              <span class="text-base font-bold text-cyan-400">Mbps</span>
            </div>

            <p class="text-xs text-slate-400 mb-6" id="live-mb-transfer">≈ 10.56 MB/s transfer rate</p>

            <button onclick="runSpeedtestAnimation()" id="btn-speedtest" class="w-full py-3.5 px-6 rounded-2xl bg-gradient-to-r from-cyan-500 to-indigo-600 hover:from-cyan-400 hover:to-indigo-500 text-slate-950 font-black text-xs uppercase tracking-wider flex items-center justify-center gap-2 shadow-lg shadow-cyan-500/25 active:scale-95 transition">
              <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clip-rule="evenodd"/></svg>
              Run Speedtest
            </button>
          </div>

          <!-- 2x2 Bento Metrics Grid -->
          <div class="grid grid-cols-2 gap-3">
            <div class="glass-card rounded-2xl p-4">
              <div class="flex items-center gap-2 text-indigo-400 mb-2">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 10l7-7m0 0l7 7m-7-7v18"/></svg>
                <span class="text-[10px] font-bold text-slate-400 uppercase">Upload</span>
              </div>
              <div class="text-lg font-black text-white" id="live-upload-speed">36.2 <span class="text-xs font-normal text-slate-400">Mbps</span></div>
              <div class="text-[10px] text-slate-500 mt-1">≈ 4.52 MB/s</div>
            </div>

            <div class="glass-card rounded-2xl p-4">
              <div class="flex items-center gap-2 text-emerald-400 mb-2">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
                <span class="text-[10px] font-bold text-slate-400 uppercase">Latency</span>
              </div>
              <div class="text-lg font-black text-white" id="live-jitter-display">14 <span class="text-xs font-normal text-slate-400">ms</span></div>
              <div class="text-[10px] text-slate-500 mt-1">Jitter: 2 ms</div>
            </div>

            <!-- 1 Jam Terakhir Metric -->
            <div class="glass-card rounded-2xl p-4">
              <div class="flex items-center gap-2 text-amber-400 mb-2">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
                <span class="text-[10px] font-bold text-slate-400 uppercase">1 Jam Terakhir</span>
              </div>
              <div class="text-lg font-black text-white" id="live-hourly-mb">142.8 <span class="text-xs font-normal text-slate-400">MB</span></div>
              <div class="text-[10px] text-slate-500 mt-1">0.14 GB data terpakai</div>
            </div>

            <div class="glass-card rounded-2xl p-4">
              <div class="flex items-center gap-2 text-cyan-400 mb-2">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/></svg>
                <span class="text-[10px] font-bold text-slate-400 uppercase">ISP & IP</span>
              </div>
              <div class="text-sm font-bold text-white truncate">Biznet Fiber</div>
              <div class="text-[10px] text-slate-500 mt-1">182.253.112.94</div>
            </div>
          </div>
        </div>

        <!-- ================= TAB 2: ANALYTICS (HOURLY, WEEKLY, MONTHLY, YEARLY) ================= -->
        <div id="tab-view-analytics" class="space-y-4 hidden">
          <h2 class="text-xl font-black text-white tracking-tight pt-1">Usage Analytics</h2>
          <p class="text-xs text-slate-400">Rekapitulasi konsumsi kuota data internet (MB & GB)</p>

          <!-- 4 Segmented Control Buttons -->
          <div class="grid grid-cols-4 gap-1 p-1 rounded-2xl bg-slate-900 border border-slate-800 text-[11px] font-bold text-center">
            <button onclick="selectPeriod('hourly')" id="p-btn-hourly" class="py-2 rounded-xl bg-cyan-500 text-slate-950 transition">1 Jam</button>
            <button onclick="selectPeriod('weekly')" id="p-btn-weekly" class="py-2 rounded-xl text-slate-400 hover:text-white transition">Minggu</button>
            <button onclick="selectPeriod('monthly')" id="p-btn-monthly" class="py-2 rounded-xl text-slate-400 hover:text-white transition">Bulan</button>
            <button onclick="selectPeriod('yearly')" id="p-btn-yearly" class="py-2 rounded-xl text-slate-400 hover:text-white transition">Tahun</button>
          </div>

          <!-- Dynamic Bar Chart Box -->
          <div class="glass-card rounded-3xl p-5">
            <div class="flex items-center justify-between mb-4">
              <span class="text-xs font-bold text-white" id="chart-title">Grafik 24 Jam Terakhir (MB)</span>
              <span class="text-[10px] font-bold px-2 py-0.5 rounded-full bg-cyan-500/20 text-cyan-400" id="chart-peak-badge">Puncak: 210.5 MB</span>
            </div>

            <!-- The Bar Graph SVG / DOM -->
            <div class="h-36 flex items-end justify-between gap-1.5 pt-4" id="bars-container">
              <!-- Bars injected by JS -->
            </div>
          </div>

          <!-- Breakdown List -->
          <div class="space-y-2">
            <div class="text-xs font-bold text-slate-300 uppercase tracking-wider">Rincian Sesi Pemakaian</div>
            
            <div class="glass-card rounded-2xl p-3.5 flex items-center justify-between border-cyan-500/30">
              <div class="flex items-center gap-3">
                <div class="w-8 h-8 rounded-xl bg-cyan-500/10 text-cyan-400 flex items-center justify-center font-bold text-xs">⚡</div>
                <div>
                  <div class="text-xs font-bold text-white">Jam 19:00 - 20:00 (Puncak)</div>
                  <div class="text-[10px] text-slate-400">Wi-Fi 5GHz • 4K Streaming</div>
                </div>
              </div>
              <div class="text-xs font-black text-cyan-400">210.5 MB</div>
            </div>

            <div class="glass-card rounded-2xl p-3.5 flex items-center justify-between">
              <div class="flex items-center gap-3">
                <div class="w-8 h-8 rounded-xl bg-slate-800 text-slate-300 flex items-center justify-center font-bold text-xs">📊</div>
                <div>
                  <div class="text-xs font-bold text-white">Jam 18:00 - 19:00</div>
                  <div class="text-[10px] text-slate-400">Wi-Fi 5GHz • Video Call</div>
                </div>
              </div>
              <div class="text-xs font-black text-slate-200">180.2 MB</div>
            </div>

            <div class="glass-card rounded-2xl p-3.5 flex items-center justify-between">
              <div class="flex items-center gap-3">
                <div class="w-8 h-8 rounded-xl bg-slate-800 text-slate-300 flex items-center justify-center font-bold text-xs">📶</div>
                <div>
                  <div class="text-xs font-bold text-white">Jam 17:00 - 18:00</div>
                  <div class="text-[10px] text-slate-400">Seluler 5G • Media Sosial</div>
                </div>
              </div>
              <div class="text-xs font-black text-slate-200">158.4 MB</div>
            </div>
          </div>
        </div>

        <!-- ================= TAB 3: WIDGETS GALLERY ================= -->
        <div id="tab-view-widgets" class="space-y-4 hidden">
          <h2 class="text-xl font-black text-white tracking-tight pt-1">Widget Gallery</h2>
          <p class="text-xs text-slate-400">Koleksi widget live monitor untuk Home Screen iOS & Android</p>

          <!-- Small Widget Card Preview -->
          <div class="text-xs font-bold text-slate-300 uppercase tracking-wider">1. Small Widget (2x2)</div>
          <div class="flex justify-center">
            <div class="w-40 h-40 rounded-[28px] bg-slate-900 border border-slate-700/80 p-4 flex flex-col justify-between widget-shadow">
              <div class="flex items-center justify-between">
                <span class="text-[9px] font-extrabold text-cyan-400 tracking-wider">NETPULSE</span>
                <span class="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse"></span>
              </div>
              <div>
                <div class="text-2xl font-black text-white tracking-tight" id="widget-small-dl">84.5</div>
                <div class="text-[9px] text-slate-400">Mbps Live Speed</div>
              </div>
              <div class="flex justify-between items-center text-[9px] text-slate-400 border-t border-slate-800 pt-1.5">
                <span class="text-amber-400 font-bold" id="widget-small-1h">142 MB/h</span>
                <span>↑ 36 Mbps</span>
              </div>
            </div>
          </div>

          <!-- Medium Widget Preview -->
          <div class="text-xs font-bold text-slate-300 uppercase tracking-wider pt-2">2. Medium Widget (4x2)</div>
          <div class="w-full h-36 rounded-[28px] bg-slate-900 border border-slate-700/80 p-4 flex items-center justify-between widget-shadow">
            <div class="flex-1 flex flex-col justify-between h-full pr-3 border-r border-slate-800">
              <div class="flex items-center gap-1.5 text-[9px] font-bold text-slate-400">
                <span class="w-1.5 h-1.5 rounded-full bg-emerald-400"></span>
                Wi-Fi 6 Connected
              </div>
              <div>
                <div class="text-3xl font-black text-white tracking-tight" id="widget-med-dl">84.5</div>
                <div class="text-[10px] text-cyan-400 font-bold">Mbps Download</div>
              </div>
              <div class="text-[9px] text-slate-400">Ping: 14ms • Upload: 36.2M</div>
            </div>
            <div class="flex-1 pl-4 flex flex-col justify-between h-full">
              <div class="text-[10px] text-slate-400 font-bold uppercase">1 Jam Terakhir</div>
              <div class="text-xl font-black text-amber-400" id="widget-med-1h">142.8 MB</div>
              <div class="text-[9px] text-slate-500 leading-tight">Hari ini: 4.2 GB<br/>Bulan ini: 84.6 GB</div>
            </div>
          </div>
        </div>

        <!-- ================= TAB 4: ALERTS & QUOTA ================= -->
        <div id="tab-view-alerts" class="space-y-4 hidden">
          <h2 class="text-xl font-black text-white tracking-tight pt-1">Quota & Alerts</h2>
          <p class="text-xs text-slate-400">Pantau batas kuota bulanan & atur notifikasi otomatis</p>

          <!-- Quota Progress Card -->
          <div class="glass-card rounded-3xl p-5">
            <div class="flex items-center justify-between text-xs font-bold mb-3">
              <span class="text-white">Kuota Bulanan (150 GB)</span>
              <span class="text-cyan-400">56.4% Terpakai</span>
            </div>
            <div class="w-full h-3 rounded-full bg-slate-800 overflow-hidden mb-3">
              <div class="h-full bg-gradient-to-r from-cyan-500 to-indigo-600 rounded-full w-[56.4%]"></div>
            </div>
            <div class="flex items-center justify-between text-[11px] text-slate-400">
              <span>Terpakai: 84.6 GB</span>
              <span class="text-emerald-400 font-bold">Sisa: 65.4 GB</span>
            </div>
          </div>

          <!-- Alert Toggles -->
          <div class="space-y-2">
            <div class="glass-card rounded-2xl p-4 flex items-center justify-between">
              <div>
                <div class="text-xs font-bold text-white">Peringatan Kuota 80%</div>
                <div class="text-[10px] text-slate-400">Kirim notifikasi saat kuota mendekati batas</div>
              </div>
              <input type="checkbox" checked class="accent-cyan-500 w-4 h-4 cursor-pointer" />
            </div>

            <div class="glass-card rounded-2xl p-4 flex items-center justify-between">
              <div>
                <div class="text-xs font-bold text-white">Batas 1 Jam (500 MB)</div>
                <div class="text-[10px] text-slate-400">Alarm jika ada aplikasi boros data di background</div>
              </div>
              <input type="checkbox" checked class="accent-cyan-500 w-4 h-4 cursor-pointer" />
            </div>

            <div class="glass-card rounded-2xl p-4 flex items-center justify-between">
              <div>
                <div class="text-xs font-bold text-white">Auto-Switch Wi-Fi & Seluler</div>
                <div class="text-[10px] text-slate-400">Notifikasi getar jika jaringan Wi-Fi terputus</div>
              </div>
              <input type="checkbox" class="accent-cyan-500 w-4 h-4 cursor-pointer" />
            </div>
          </div>
        </div>

        <!-- ================= TAB 5: SETTINGS ================= -->
        <div id="tab-view-settings" class="space-y-4 hidden">
          <h2 class="text-xl font-black text-white tracking-tight pt-1">Settings</h2>
          <p class="text-xs text-slate-400">Preferensi satuan kecepatan & informasi build</p>

          <div class="space-y-2">
            <div class="glass-card rounded-2xl p-4 flex items-center justify-between">
              <div class="text-xs font-bold text-white">Satuan Kecepatan</div>
              <span class="text-xs font-bold text-cyan-400">Mbps (Megabit)</span>
            </div>

            <div class="glass-card rounded-2xl p-4 flex items-center justify-between">
              <div class="text-xs font-bold text-white">Tanggal Reset Kuota</div>
              <span class="text-xs font-bold text-white">Tgl 1 Tiap Bulan</span>
            </div>

            <div class="glass-card rounded-2xl p-4 flex items-center justify-between">
              <div class="text-xs font-bold text-white">Mode Tampilan</div>
              <span class="text-xs font-bold text-slate-400">OLED Dark Theme</span>
            </div>
          </div>

          <!-- Cloud Build Info -->
          <div class="p-4 rounded-2xl bg-cyan-950/40 border border-cyan-800/50 text-[11px] space-y-1.5">
            <div class="font-extrabold text-cyan-300">🚀 NetPulse Pro Mobile Build</div>
            <div class="text-slate-300">• Engine: Flutter Cross-Platform (Dart)</div>
            <div class="text-slate-300">• iOS Target: Sideloadable NetPulsePro.ipa</div>
            <div class="text-slate-300">• Android Target: Release NetPulsePro.apk</div>
            <div class="text-slate-400 text-[10px] pt-1">Build otomatis diproses di cloud via GitHub Actions.</div>
          </div>
        </div>

      </div>

      <!-- App Bottom Bar Navigation (iOS HIG) -->
      <nav class="absolute bottom-0 left-0 right-0 h-16 bg-surface/95 backdrop-blur-lg border-t border-slate-800/80 px-6 flex items-center justify-between z-40">
        <button onclick="switchTab('speed')" id="nav-speed" class="flex flex-col items-center gap-1 text-cyan-400 transition">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.2" d="M13 10V3L4 14h7v7l9-11h-7z"/></svg>
          <span class="text-[9px] font-bold">Live Speed</span>
        </button>

        <button onclick="switchTab('analytics')" id="nav-analytics" class="flex flex-col items-center gap-1 text-slate-500 hover:text-slate-300 transition">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/></svg>
          <span class="text-[9px] font-bold">Analytics</span>
        </button>

        <button onclick="switchTab('widgets')" id="nav-widgets" class="flex flex-col items-center gap-1 text-slate-500 hover:text-slate-300 transition">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z"/></svg>
          <span class="text-[9px] font-bold">Widgets</span>
        </button>

        <button onclick="switchTab('alerts')" id="nav-alerts" class="flex flex-col items-center gap-1 text-slate-500 hover:text-slate-300 transition">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"/></svg>
          <span class="text-[9px] font-bold">Alerts</span>
        </button>

        <button onclick="switchTab('settings')" id="nav-settings" class="flex flex-col items-center gap-1 text-slate-500 hover:text-slate-300 transition">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/></svg>
          <span class="text-[9px] font-bold">Settings</span>
        </button>
      </nav>

      <!-- Home Indicator Bar -->
      <div class="absolute bottom-1.5 left-1/2 transform -translate-x-1/2 w-32 h-1 bg-white/40 rounded-full z-50 pointer-events-none"></div>
    </div>

    <!-- SCREEN CONTENT 2: HOME SCREEN WITH LIVE WIDGETS -->
    <div id="screen-widgets" class="flex-1 flex flex-col p-6 hidden overflow-y-auto space-y-5 bg-gradient-to-b from-slate-900 to-slate-950">
      
      <!-- iOS Home Screen App Icons Grid Mockup -->
      <div class="text-center mb-1">
        <div class="text-xs text-slate-400 font-semibold">iOS 17 Home Screen</div>
      </div>

      <!-- Medium Widget Live on Home Screen -->
      <div class="w-full rounded-[26px] bg-slate-900/90 border border-slate-700 p-4 widget-shadow backdrop-blur-md">
        <div class="flex items-center justify-between mb-2">
          <div class="flex items-center gap-1.5">
            <div class="w-5 h-5 rounded-lg bg-cyan-500 text-slate-950 font-black text-[10px] flex items-center justify-center">NP</div>
            <span class="text-xs font-bold text-white">NetPulse Pro</span>
          </div>
          <span class="text-[10px] text-cyan-400 font-bold">Wi-Fi 6</span>
        </div>

        <div class="grid grid-cols-2 gap-2">
          <div>
            <div class="text-3xl font-black text-white" id="hs-med-dl">84.5</div>
            <div class="text-[10px] text-cyan-400 font-semibold">Mbps Download</div>
            <div class="text-[9px] text-slate-400 mt-1">↑ 36.2M • Ping 14ms</div>
          </div>
          <div class="border-l border-slate-800 pl-3 flex flex-col justify-between">
            <div>
              <div class="text-[9px] text-slate-400 font-bold uppercase">1 Jam Terakhir</div>
              <div class="text-lg font-black text-amber-400" id="hs-med-1h">142.8 MB</div>
            </div>
            <div class="text-[9px] text-slate-500">Hari ini: 4.2 GB</div>
          </div>
        </div>
      </div>

      <!-- 2 Small Widgets Side by Side -->
      <div class="grid grid-cols-2 gap-4">
        <!-- Small Widget 1: Speed Gauge -->
        <div class="aspect-square rounded-[26px] bg-slate-900/90 border border-slate-700 p-4 widget-shadow flex flex-col justify-between">
          <div class="flex justify-between items-center">
            <span class="text-[9px] font-extrabold text-cyan-400">SPEED</span>
            <span class="w-1.5 h-1.5 rounded-full bg-emerald-400"></span>
          </div>
          <div>
            <div class="text-2xl font-black text-white" id="hs-small-dl">84.5</div>
            <div class="text-[9px] text-slate-400">Mbps Live</div>
          </div>
          <div class="text-[8px] text-indigo-400 font-bold">↑ 36.2 Mbps Up</div>
        </div>

        <!-- Small Widget 2: 1-Hour Data Usage -->
        <div class="aspect-square rounded-[26px] bg-slate-900/90 border border-slate-700 p-4 widget-shadow flex flex-col justify-between">
          <div class="flex justify-between items-center">
            <span class="text-[9px] font-extrabold text-amber-400">USAGE</span>
            <span class="text-[8px] text-slate-400 font-bold">1 JAM</span>
          </div>
          <div>
            <div class="text-2xl font-black text-amber-400" id="hs-small-1h">142.8</div>
            <div class="text-[9px] text-slate-400">MB Terpakai</div>
          </div>
          <div class="text-[8px] text-slate-500">Bulan ini: 84.6 GB</div>
        </div>
      </div>

      <!-- App Icons Dummy Row -->
      <div class="grid grid-cols-4 gap-4 pt-2 text-center">
        <div class="flex flex-col items-center gap-1">
          <div class="w-14 h-14 rounded-2xl bg-cyan-500 flex items-center justify-center text-slate-950 font-black text-lg shadow-lg shadow-cyan-500/20">NP</div>
          <span class="text-[10px] text-slate-300">NetPulse</span>
        </div>
        <div class="flex flex-col items-center gap-1">
          <div class="w-14 h-14 rounded-2xl bg-slate-800 flex items-center justify-center text-slate-300 text-lg">💬</div>
          <span class="text-[10px] text-slate-300">Messages</span>
        </div>
        <div class="flex flex-col items-center gap-1">
          <div class="w-14 h-14 rounded-2xl bg-slate-800 flex items-center justify-center text-slate-300 text-lg">📷</div>
          <span class="text-[10px] text-slate-300">Camera</span>
        </div>
        <div class="flex flex-col items-center gap-1">
          <div class="w-14 h-14 rounded-2xl bg-slate-800 flex items-center justify-center text-slate-300 text-lg">⚙️</div>
          <span class="text-[10px] text-slate-300">Settings</span>
        </div>
      </div>

    </div>

    <!-- SCREEN CONTENT 3: LOCK SCREEN WITH CIRCULAR WIDGET -->
    <div id="screen-lockscreen" class="flex-1 flex flex-col items-center justify-between p-8 hidden bg-gradient-to-b from-slate-950 via-slate-900 to-black text-center relative overflow-hidden">
      
      <div class="pt-4">
        <div class="text-slate-400 text-xs font-semibold">Sabtu, 7 November</div>
        <div class="text-6xl font-light text-white tracking-tight mt-1">09:41</div>

        <!-- Lock Screen Circular Widgets Row -->
        <div class="flex items-center justify-center gap-3 mt-4">
          <!-- Widget 1: Speed Gauge -->
          <div class="w-24 h-10 rounded-2xl bg-white/10 backdrop-blur-md px-2.5 py-1 flex items-center gap-2 border border-white/10">
            <span class="text-cyan-400 font-black text-xs">⚡</span>
            <div class="text-left">
              <div class="text-[10px] font-black text-white leading-none" id="ls-speed">84.5M</div>
              <div class="text-[8px] text-slate-400 leading-none mt-0.5">Speed</div>
            </div>
          </div>

          <!-- Widget 2: 1 Hour Usage -->
          <div class="w-24 h-10 rounded-2xl bg-white/10 backdrop-blur-md px-2.5 py-1 flex items-center gap-2 border border-white/10">
            <span class="text-amber-400 font-black text-xs">📊</span>
            <div class="text-left">
              <div class="text-[10px] font-black text-white leading-none" id="ls-usage">142 MB</div>
              <div class="text-[8px] text-slate-400 leading-none mt-0.5">1 Jam</div>
            </div>
          </div>
        </div>
      </div>

      <div class="w-full flex items-center justify-between px-4 pb-4">
        <div class="w-12 h-12 rounded-full bg-white/10 backdrop-blur-md flex items-center justify-center text-lg">🔦</div>
        <div class="w-12 h-12 rounded-full bg-white/10 backdrop-blur-md flex items-center justify-center text-lg">📷</div>
      </div>

    </div>

  </div>

  <!-- JavaScript Simulator Controller -->
  <script>
    // State Store
    const state = {
      mode: 'app',
      activeTab: 'speed',
      period: 'hourly',
      download: 84.5,
      upload: 36.2,
      ping: 14,
      lastHourMB: 142.8,
      isTesting: false
    };

    // Periodic simulation
    setInterval(() => {
      if (!state.isTesting) {
        state.download = +(78 + Math.random() * 22).toFixed(1);
        state.upload = +(30 + Math.random() * 12).toFixed(1);
        state.ping = Math.floor(12 + Math.random() * 5);
        state.lastHourMB = +(135 + Math.random() * 15).toFixed(1);
        updateLiveDOM();
      }
    }, 3000);

    function updateLiveDOM() {
      document.getElementById('island-speed').textContent = state.download + 'M';
      document.getElementById('live-download-speed').textContent = state.download;
      document.getElementById('live-upload-speed').innerHTML = state.upload + ' <span class="text-xs font-normal text-slate-400">Mbps</span>';
      document.getElementById('live-ping').textContent = state.ping + ' ms';
      document.getElementById('live-hourly-mb').innerHTML = state.lastHourMB + ' <span class="text-xs font-normal text-slate-400">MB</span>';
      document.getElementById('live-mb-transfer').textContent = '≈ ' + (state.download / 8).toFixed(2) + ' MB/s transfer rate';

      document.getElementById('widget-small-dl').textContent = state.download;
      document.getElementById('widget-small-1h').textContent = Math.round(state.lastHourMB) + ' MB/h';
      document.getElementById('widget-med-dl').textContent = state.download;
      document.getElementById('widget-med-1h').textContent = state.lastHourMB + ' MB';

      document.getElementById('hs-med-dl').textContent = state.download;
      document.getElementById('hs-med-1h').textContent = state.lastHourMB + ' MB';
      document.getElementById('hs-small-dl').textContent = state.download;
      document.getElementById('hs-small-1h').textContent = state.lastHourMB;

      document.getElementById('ls-speed').textContent = state.download + 'M';
      document.getElementById('ls-usage').textContent = Math.round(state.lastHourMB) + ' MB';
    }

    function switchMode(m) {
      state.mode = m;
      document.getElementById('screen-app').classList.toggle('hidden', m !== 'app');
      document.getElementById('screen-widgets').classList.toggle('hidden', m !== 'widgets');
      document.getElementById('screen-lockscreen').classList.toggle('hidden', m !== 'lockscreen');

      ['app', 'widgets', 'lockscreen'].forEach(id => {
        const btn = document.getElementById('btn-mode-' + id);
        if (id === m) {
          btn.className = 'px-4 py-2 rounded-xl text-xs font-bold transition flex items-center gap-2 bg-cyan-500 text-slate-950 shadow-md shadow-cyan-500/20';
        } else {
          btn.className = 'px-4 py-2 rounded-xl text-xs font-semibold text-slate-400 hover:text-white transition flex items-center gap-2';
        }
      });
    }

    function switchTab(t) {
      state.activeTab = t;
      ['speed', 'analytics', 'widgets', 'alerts', 'settings'].forEach(id => {
        const view = document.getElementById('tab-view-' + id);
        const btn = document.getElementById('nav-' + id);
        if (id === t) {
          view.classList.remove('hidden');
          btn.className = 'flex flex-col items-center gap-1 text-cyan-400 transition';
        } else {
          view.classList.add('hidden');
          btn.className = 'flex flex-col items-center gap-1 text-slate-500 hover:text-slate-300 transition';
        }
      });

      if (t === 'analytics') {
        renderAnalyticsBars();
      }
    }

    function selectPeriod(p) {
      state.period = p;
      ['hourly', 'weekly', 'monthly', 'yearly'].forEach(id => {
        const btn = document.getElementById('p-btn-' + id);
        if (id === p) {
          btn.className = 'py-2 rounded-xl bg-cyan-500 text-slate-950 transition font-bold';
        } else {
          btn.className = 'py-2 rounded-xl text-slate-400 hover:text-white transition';
        }
      });
      renderAnalyticsBars();
    }

    function renderAnalyticsBars() {
      const container = document.getElementById('bars-container');
      container.innerHTML = '';

      let items = [];
      if (state.period === 'hourly') {
        document.getElementById('chart-title').textContent = 'Grafik 8 Jam Terakhir (MB)';
        document.getElementById('chart-peak-badge').textContent = 'Puncak: 210.5 MB';
        items = [
          { label: '16:00', val: 115 },
          { label: '17:00', val: 158 },
          { label: '18:00', val: 180 },
          { label: '19:00', val: 210 },
          { label: '20:00', val: 195 },
          { label: '21:00', val: 145 },
          { label: '22:00', val: 90 },
          { label: '23:00', val: 42 }
        ];
      } else if (state.period === 'weekly') {
        document.getElementById('chart-title').textContent = 'Grafik 7 Hari Terakhir (GB)';
        document.getElementById('chart-peak-badge').textContent = 'Total: 38.8 GB';
        items = [
          { label: 'Sen', val: 3.8 },
          { label: 'Sel', val: 4.2 },
          { label: 'Rab', val: 5.1 },
          { label: 'Kam', val: 4.0 },
          { label: 'Jum', val: 6.2 },
          { label: 'Sab', val: 8.4 },
          { label: 'Min', val: 7.1 }
        ];
      } else if (state.period === 'monthly') {
        document.getElementById('chart-title').textContent = 'Tren 6 Bulan Terakhir (GB)';
        document.getElementById('chart-peak-badge').textContent = 'Total: 84.6 GB (Nov)';
        items = [
          { label: 'Jun', val: 82 },
          { label: 'Jul', val: 91 },
          { label: 'Agu', val: 78 },
          { label: 'Sep', val: 94 },
          { label: 'Okt', val: 88 },
          { label: 'Nov', val: 85 }
        ];
      } else {
        document.getElementById('chart-title').textContent = 'Tren Tahunan (GB)';
        document.getElementById('chart-peak-badge').textContent = 'Rata-rata 1 TB/tahun';
        items = [
          { label: '2023', val: 850 },
          { label: '2024', val: 920 },
          { label: '2025', val: 1040 },
          { label: '2026', val: 1180 }
        ];
      }

      const maxVal = Math.max(...items.map(x => x.val));
      items.forEach(item => {
        const pct = Math.round((item.val / maxVal) * 100);
        const col = document.createElement('div');
        col.className = 'flex-1 flex flex-col items-center justify-end h-full gap-1';
        col.innerHTML = `
          <span class="text-[8px] text-slate-400 font-bold">` + item.val + `</span>
          <div class="w-full rounded-md bg-gradient-to-t from-indigo-600 to-cyan-400 transition-all duration-500" style="height: ` + pct + `%"></div>
          <span class="text-[9px] text-slate-400 font-medium">` + item.label + `</span>
        `;
        container.appendChild(col);
      });
    }

    function runSpeedtestAnimation() {
      if (state.isTesting) return;
      state.isTesting = true;
      const btn = document.getElementById('btn-speedtest');
      const label = document.getElementById('speedtest-status-label');
      btn.textContent = 'MENGUJI DOWNLOAD...';
      btn.disabled = true;
      label.textContent = 'TESTING PING & DOWNLOAD BANDWIDTH...';
      label.className = 'text-[10px] font-bold text-amber-400 uppercase tracking-widest mb-3 animate-pulse';

      let step = 0;
      const interval = setInterval(() => {
        step++;
        if (step < 12) {
          state.download = +(step * 14.5 + Math.random() * 8).toFixed(1);
          updateLiveDOM();
        } else if (step < 20) {
          btn.textContent = 'MENGUJI UPLOAD...';
          label.textContent = 'TESTING UPLOAD BANDWIDTH...';
          state.upload = +((step - 12) * 8.2 + Math.random() * 5).toFixed(1);
          updateLiveDOM();
        } else {
          clearInterval(interval);
          state.download = 142.8;
          state.upload = 64.5;
          state.ping = 9;
          state.isTesting = false;
          btn.innerHTML = `<svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clip-rule="evenodd"/></svg> Run Speedtest`;
          btn.disabled = false;
          label.textContent = 'HASIL PENGUJIAN LENGKAP';
          label.className = 'text-[10px] font-bold text-emerald-400 uppercase tracking-widest mb-3';
          updateLiveDOM();
        }
      }, 250);
    }

    // Init
    updateLiveDOM();
    renderAnalyticsBars();
  </script>
</body>
</html>
"""

with open('/home/devcurl/workspace/netpulse-pro/index.html', 'w', encoding='utf-8') as f:
    f.write(html_code.strip())

print('SUCCESS: index.html written!')
