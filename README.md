# NetPulse Pro - Internet Speed & Data Usage Widget Monitor

Aplikasi mobile pemantau kecepatan internet real-time (Mbps & MB/s) dan kuota pemakaian data (MB & GB) dalam 4 periode waktu (Per 1 Jam, Mingguan, Bulanan, dan Tahunan) dilengkapi widget Home Screen & Lock Screen iOS / Android.

## 📱 Fitur Utama
1. **Live Internet Speed Monitor**:
   - Download & Upload (Mbps & MB/s transfer rate)
   - Ping / Latency (ms) & Jitter
   - Deteksi jaringan aktif (Wi-Fi 6 vs 5G/LTE Cellular) & ISP Info
   - Fitur interaktif: *Run Active Speedtest*

2. **Rekapitulasi Pemakaian Data (MB & GB) dalam 4 Periode**:
   - **Per 1 Jam (Hourly)**: Grafik batang & log pemakaian data 24 jam terakhir (00:00 - 23:00)
   - **Mingguan (Weekly)**: Total konsumsi 7 hari terakhir & rata-rata pemakaian
   - **Bulanan (Monthly)**: Progress kuota bulanan (Data Cap Progress Bar) & estimasi sisa kuota
   - **Tahunan (Yearly)**: Tren pemakaian kuota setahun penuh (GB / TB)

3. **iOS & Android Widgets**:
   - Small Widget (2x2): Compact Live Speed & pemakaian 1 jam terakhir
   - Medium Widget (4x2): Speedometer + Mini Bar Chart + ringkasan hari ini
   - Lock Screen Circular Widgets

4. **Multi-Screen Navigation (5 Layar Utama - OLED Dark Luxury Theme)**:
   - Tab 1: Live Speed Dashboard & Speedtest
   - Tab 2: Data Usage Analytics (Grafik 4 Periode & Rincian Sesi)
   - Tab 3: Widgets Gallery Preview
   - Tab 4: Quota & Bandwidth Alerts
   - Tab 5: Settings & Preferences

---

## 🚀 Interactive iPhone 15 Pro Simulator (Web Staging)
Coba langsung di browser tanpa perlu menunggu build:
👉 **[https://webui.5nod.com/staging/netpulse-pro/](https://webui.5nod.com/staging/netpulse-pro/)**

---

## 🛠️ Build Pipeline (Mode 4 Auto - GitHub Actions)
- **Workflow File**: `.github/workflows/build-mobile.yml`
- **iOS Sideload (.ipa)**: Dibangun otomatis di runner `macos-latest` (Zero local Xcode)
- **Android Release (.apk)**: Dibangun otomatis di runner `ubuntu-latest` (Zero local Android SDK)
- **Artifacts & Releases**: Otomatis dipublish ke GitHub Releases saat commit di-push ke GitHub.
