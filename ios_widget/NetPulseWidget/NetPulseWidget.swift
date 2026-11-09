import WidgetKit
import SwiftUI
import ActivityKit
import Network
import CoreTelephony
#if canImport(AppIntents)
import AppIntents
#endif

// ---------------------------------------------------------------------------
// INTERACTIVE WIDGET REFRESH INTENT (iOS 17+ / iPhone 15)
// ---------------------------------------------------------------------------
#if canImport(AppIntents)
@available(iOS 16.0, *)
struct RefreshNetPulseIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh NetPulse Sentry"
    static var description = IntentDescription("Memperbarui metrik bandwidth dan penggunaan data secara langsung.")

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadTimelines(ofKind: "NetPulseWidget")
        return .result()
    }
}
#endif

// ---------------------------------------------------------------------------
// REAL HARDWARE WIDGET SAMPLER (GETIFADDRS + NWPATHMONITOR + APP GROUP)
// ---------------------------------------------------------------------------
final class WidgetHardwareSampler {
    static let shared = WidgetHardwareSampler()

    private let appGroupSuite = "group.com.devcurl.netpulse"
    private let prevInterfacesKey = "Widget_PrevInterfaces"
    private let hourlyBucketsKey = "Widget_HourlyBuckets"
    private let dailyBytesKey = "Widget_DailyBytes"
    private let lastDateKey = "Widget_LastDate"

    struct SampleResult {
        let downloadMbps: Double
        let uploadMbps: Double
        let lastHourMB: Double
        let todayMB: Double
        let dailyLimitMB: Double
        let isp: String
        let isSecure: Bool
        let unit: String
    }

    private func readInterfaceSnapshots() -> [String: (inBytes: UInt64, outBytes: UInt64)] {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return [:]
        }
        defer { freeifaddrs(ifaddr) }

        var snapshots: [String: (inBytes: UInt64, outBytes: UInt64)] = [:]
        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr

        while let current = ptr {
            if let addr = current.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK) {
                let name = String(cString: current.pointee.ifa_name)
                if !name.hasPrefix("lo") && !name.hasPrefix("awdl") {
                    if let data = current.pointee.ifa_data {
                        let ifData = data.assumingMemoryBound(to: if_data.self)
                        let inB = UInt64(ifData.pointee.ifi_ibytes)
                        let outB = UInt64(ifData.pointee.ifi_obytes)
                        snapshots[name] = (inB, outB)
                    }
                }
            }
            ptr = current.pointee.ifa_next
        }
        return snapshots
    }

    private func computeDelta(
        from prev: [String: (inBytes: UInt64, outBytes: UInt64)],
        to current: [String: (inBytes: UInt64, outBytes: UInt64)]
    ) -> (deltaIn: UInt64, deltaOut: UInt64) {
        var deltaInTotal: UInt64 = 0
        var deltaOutTotal: UInt64 = 0

        for (ifName, cur) in current {
            guard let old = prev[ifName] else { continue }

            if cur.inBytes >= old.inBytes {
                let diffIn = cur.inBytes - old.inBytes
                if diffIn < 2_000_000_000 {
                    deltaInTotal += diffIn
                }
            } else {
                let wrapIn = (UInt64(UInt32.max) - old.inBytes) + cur.inBytes
                if wrapIn < 2_000_000_000 {
                    deltaInTotal += wrapIn
                }
            }

            if cur.outBytes >= old.outBytes {
                let diffOut = cur.outBytes - old.outBytes
                if diffOut < 2_000_000_000 {
                    deltaOutTotal += diffOut
                }
            } else {
                let wrapOut = (UInt64(UInt32.max) - old.outBytes) + cur.outBytes
                if wrapOut < 2_000_000_000 {
                    deltaOutTotal += wrapOut
                }
            }
        }
        return (deltaInTotal, deltaOutTotal)
    }

    private func detectCarrierName() -> String {
        let netInfo = CTTelephonyNetworkInfo()
        if let providers = netInfo.serviceSubscriberCellularProviders {
            for (_, carrier) in providers {
                if let name = carrier.carrierName, !name.isEmpty, name != "--", name != "Carrier" {
                    return name
                }
            }
        }
        return "Seluler 5G/LTE"
    }

    private func detectCurrentNetworkName() -> String {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "com.devcurl.netpulse.widget.path")
        let semaphore = DispatchSemaphore(value: 0)
        var detected = "Wi-Fi"

        monitor.pathUpdateHandler = { [weak self] path in
            if path.status == .unsatisfied {
                detected = "Offline"
            } else if path.usesInterfaceType(.wifi) {
                detected = "Wi-Fi"
            } else if path.usesInterfaceType(.cellular) {
                detected = self?.detectCarrierName() ?? "Seluler 5G/LTE"
            } else {
                detected = "Internet"
            }
            semaphore.signal()
        }
        monitor.start(queue: queue)
        _ = semaphore.wait(timeout: .now() + 0.25)
        monitor.cancel()
        return detected
    }

    func sample(measureWindow: TimeInterval = 0.45) -> SampleResult {
        let defaults = UserDefaults.standard
        let now = Date()
        let nowTs = now.timeIntervalSince1970

        // 1. Measure real hardware speed via dual getifaddrs snapshot
        let snap1 = readInterfaceSnapshots()
        if measureWindow > 0 {
            Thread.sleep(forTimeInterval: measureWindow)
        }
        let snap2 = readInterfaceSnapshots()

        let instantDelta = computeDelta(from: snap1, to: snap2)
        let downMbps = measureWindow > 0 ? (Double(instantDelta.deltaIn) * 8.0) / (measureWindow * 1_000_000.0) : 0.0
        let upMbps = measureWindow > 0 ? (Double(instantDelta.deltaOut) * 8.0) / (measureWindow * 1_000_000.0) : 0.0

        // 2. Accumulate rolling 1-hour & daily bytes in widget sandbox
        var prevSaved: [String: (inBytes: UInt64, outBytes: UInt64)] = [:]
        if let rawPrev = defaults.dictionary(forKey: prevInterfacesKey) as? [String: [String: NSNumber]] {
            for (k, v) in rawPrev {
                let inB = v["in"]?.uint64Value ?? 0
                let outB = v["out"]?.uint64Value ?? 0
                prevSaved[k] = (inB, outB)
            }
        }

        let sinceLastReload = computeDelta(from: prevSaved, to: snap2)
        let transferredBytes = Double(sinceLastReload.deltaIn + sinceLastReload.deltaOut)

        // Persist current snapshot
        var toSave: [String: [String: NSNumber]] = [:]
        for (k, v) in snap2 {
            toSave[k] = ["in": NSNumber(value: v.inBytes), "out": NSNumber(value: v.outBytes)]
        }
        defaults.set(toSave, forKey: prevInterfacesKey)

        // Daily tracking
        let todayStr = String(ISO8601DateFormatter().string(from: now).prefix(10))
        let lastDateStr = defaults.string(forKey: lastDateKey) ?? ""
        var dailyBytes = defaults.double(forKey: dailyBytesKey)
        if lastDateStr != todayStr {
            dailyBytes = 0.0
            defaults.set(todayStr, forKey: lastDateKey)
        }
        dailyBytes += transferredBytes
        defaults.set(dailyBytes, forKey: dailyBytesKey)
        let localTodayMB = dailyBytes / (1024.0 * 1024.0)

        // Rolling 1-hour buckets
        var buckets = (defaults.array(forKey: hourlyBucketsKey) as? [[String: Double]]) ?? []
        buckets = buckets.filter { entry in
            guard let t = entry["t"] else { return false }
            return (nowTs - t) <= 3600.0 && (nowTs - t) >= 0.0
        }
        if transferredBytes > 0 {
            buckets.append(["t": nowTs, "b": transferredBytes])
        }
        defaults.set(buckets, forKey: hourlyBucketsKey)
        let hourBytes = buckets.reduce(0.0) { $0 + ($1["b"] ?? 0.0) }
        let localLastHourMB = hourBytes / (1024.0 * 1024.0)

        var finalDown = downMbps
        var finalUp = upMbps
        var finalHourMB = localLastHourMB
        var finalTodayMB = localTodayMB
        var finalLimitMB = defaults.double(forKey: "np_daily_limit_mb")
        if finalLimitMB <= 0 { finalLimitMB = 1024.0 }
        var finalISP = detectCurrentNetworkName()
        var finalSecure = upMbps < 40.0
        var finalUnit = "Auto"

        // 3. Merge with App Group shared defaults if accessible and fresher
        if let groupDefaults = UserDefaults(suiteName: appGroupSuite) {
            let updatedAt = groupDefaults.double(forKey: "np_updated_at")
            let groupLimit = groupDefaults.double(forKey: "np_daily_limit_mb")
            if groupLimit > 0 { finalLimitMB = groupLimit }

            let groupUnit = groupDefaults.string(forKey: "np_unit")
            if let u = groupUnit, !u.isEmpty { finalUnit = u }

            let groupTodayMB = groupDefaults.double(forKey: "np_today_gb") * 1024.0
            if groupTodayMB > finalTodayMB { finalTodayMB = groupTodayMB }

            let groupHourMB = groupDefaults.double(forKey: "np_lasthour_mb")
            if groupHourMB > finalHourMB && (nowTs - updatedAt) < 1800.0 {
                finalHourMB = groupHourMB
            }

            if (nowTs - updatedAt) < 30.0 {
                let appDown = groupDefaults.double(forKey: "np_download_mbps")
                let appUp = groupDefaults.double(forKey: "np_upload_mbps")
                if finalDown < 0.01 && appDown > 0 { finalDown = appDown }
                if finalUp < 0.01 && appUp > 0 { finalUp = appUp }
                if let appISP = groupDefaults.string(forKey: "np_isp"), !appISP.isEmpty {
                    finalISP = appISP
                }
                finalSecure = groupDefaults.bool(forKey: "np_is_secure")
            }
        }

        return SampleResult(
            downloadMbps: finalDown,
            uploadMbps: finalUp,
            lastHourMB: finalHourMB,
            todayMB: finalTodayMB,
            dailyLimitMB: finalLimitMB,
            isp: finalISP,
            isSecure: finalSecure,
            unit: finalUnit
        )
    }
}

// ---------------------------------------------------------------------------
// TIMELINE PROVIDER
// ---------------------------------------------------------------------------
struct Provider: TimelineProvider {
    private func makeEntry(date: Date, sample: WidgetHardwareSampler.SampleResult) -> SimpleEntry {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeStr = formatter.string(from: date)

        let downPair = formatSpeedPair(sample.downloadMbps, unit: sample.unit)
        let upShort = formatShortSpeed(sample.uploadMbps, unit: sample.unit)

        return SimpleEntry(
            date: date,
            downloadSpeed: sample.downloadMbps,
            uploadSpeed: sample.uploadMbps,
            lastHourMB: sample.lastHourMB,
            todayMB: sample.todayMB,
            dailyLimitMB: sample.dailyLimitMB,
            isp: sample.isp,
            isSecure: sample.isSecure,
            unit: sample.unit,
            downloadValueText: downPair.value,
            downloadUnitLabel: downPair.unitLabel,
            uploadShortText: upShort,
            timeString: timeStr
        )
    }

    private func formatSpeedPair(_ mbps: Double, unit: String) -> (value: String, unitLabel: String) {
        let kbps = mbps * 125.0
        let mbPerSec = mbps / 8.0
        switch unit {
        case "KB/s":
            return (String(format: "%.0f", kbps), "KB/s Bandwidth Live")
        case "MB/s":
            return (String(format: "%.1f", mbPerSec), "MB/s Bandwidth Live")
        case "Mbps":
            return (String(format: "%.1f", mbps), "Mbps Bandwidth Live")
        default: // Auto
            if mbps > 0.0 && mbps < 1.0 {
                return (String(format: "%.0f", kbps), "KB/s Bandwidth Live")
            } else {
                return (String(format: "%.1f", mbps), "Mbps Bandwidth Live")
            }
        }
    }

    private func formatShortSpeed(_ mbps: Double, unit: String) -> String {
        let kbps = mbps * 125.0
        let mbPerSec = mbps / 8.0
        switch unit {
        case "KB/s":
            return String(format: "%.0fK", kbps)
        case "MB/s":
            return String(format: "%.1fM", mbPerSec)
        case "Mbps":
            return String(format: "%.1fM", mbps)
        default:
            if mbps > 0.0 && mbps < 1.0 {
                return String(format: "%.0fK", kbps)
            } else {
                return String(format: "%.1fM", mbps)
            }
        }
    }

    func placeholder(in context: Context) -> SimpleEntry {
        let sample = WidgetHardwareSampler.SampleResult(
            downloadMbps: 0.0,
            uploadMbps: 0.0,
            lastHourMB: 0.0,
            todayMB: 0.0,
            dailyLimitMB: 1024.0,
            isp: "Wi-Fi",
            isSecure: true,
            unit: "Auto"
        )
        return makeEntry(date: Date(), sample: sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        if context.isPreview {
            let previewSample = WidgetHardwareSampler.SampleResult(
                downloadMbps: 42.6,
                uploadMbps: 14.8,
                lastHourMB: 68.4,
                todayMB: 312.0,
                dailyLimitMB: 1024.0,
                isp: "Wi-Fi",
                isSecure: true,
                unit: "Auto"
            )
            completion(makeEntry(date: Date(), sample: previewSample))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let live = WidgetHardwareSampler.shared.sample(measureWindow: 0.35)
            completion(self.makeEntry(date: Date(), sample: live))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        DispatchQueue.global(qos: .userInitiated).async {
            let live = WidgetHardwareSampler.shared.sample(measureWindow: 0.45)
            let now = Date()

            var entries: [SimpleEntry] = []
            for step in 0..<3 {
                let entryDate = Calendar.current.date(byAdding: .minute, value: step * 5, to: now) ?? now
                entries.append(self.makeEntry(date: entryDate, sample: live))
            }

            let nextRefresh = Calendar.current.date(byAdding: .minute, value: 5, to: now) ?? now.addingTimeInterval(300)
            let timeline = Timeline(entries: entries, policy: .after(nextRefresh))
            completion(timeline)
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let downloadSpeed: Double
    let uploadSpeed: Double
    let lastHourMB: Double
    let todayMB: Double
    let dailyLimitMB: Double
    let isp: String
    let isSecure: Bool
    let unit: String
    let downloadValueText: String
    let downloadUnitLabel: String
    let uploadShortText: String
    let timeString: String
}

// ---------------------------------------------------------------------------
// WIDGET VIEWS (iOS 16 & iOS 17+ CONTAINER BACKGROUND SUPPORT)
// ---------------------------------------------------------------------------
struct WidgetContainerBgModifier: ViewModifier {
    let bgColor = Color(red: 9/255, green: 13/255, blue: 22/255)

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .containerBackground(bgColor, for: .widget)
        } else {
            content
                .padding(14)
                .background(bgColor)
        }
    }
}

struct NetPulseWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(entry: entry)
            default:
                MediumWidgetView(entry: entry)
            }
        }
        .modifier(WidgetContainerBgModifier())
    }
}

struct SmallWidgetView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(entry.isSecure ? Color.green : Color.red)
                    .frame(width: 7, height: 7)
                Text(entry.isSecure ? "AMAN" : "WASPADA")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(entry.isSecure ? Color.green : Color.red)
                Spacer()
                Text(entry.isp)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color.cyan)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.downloadValueText)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                Text(entry.downloadUnitLabel.replacingOccurrences(of: " Bandwidth", with: ""))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color.cyan)
            }
            Spacer()
            HStack {
                Text(String(format: "1J: %.0fM", entry.lastHourMB))
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color.orange)
                Spacer()
                Text("↑ \(entry.uploadShortText)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color.purple)
            }
            HStack {
                Text("↻ \(entry.timeString)")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(Color.gray)
                Spacer()
            }
        }
    }
}

struct MediumWidgetView: View {
    var entry: Provider.Entry

    var isQuotaExceeded: Bool {
        return entry.todayMB >= entry.dailyLimitMB
    }

    var statusLabel: String {
        if !entry.isSecure { return "Waspada Trafik" }
        if isQuotaExceeded { return "Limit Harian!" }
        return "Bersih"
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(entry.isSecure ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(entry.isSecure ? "ANTI-HACK SENTRY: AMAN" : "⚠️ WASPADA LONJAKAN DATA")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(entry.isSecure ? Color.green : Color.red)
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.downloadValueText)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                    Text(entry.downloadUnitLabel)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.cyan)
                }
                Spacer()
                Text("Upload: \(entry.uploadShortText) • ISP: \(entry.isp)")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().background(Color.white.opacity(0.12))

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("DATA 1 JAM")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.gray)
                    Spacer()
                    if #available(iOS 17.0, *) {
                        Button(intent: RefreshNetPulseIntent()) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color.cyan)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color.cyan.opacity(0.7))
                    }
                }
                Text(String(format: "%.1f MB", entry.lastHourMB))
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(Color.orange)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Batas Harian: \(Int(entry.dailyLimitMB)) MB")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.75))
                        .lineLimit(1)
                    Text("Status: \(statusLabel) • \(entry.timeString)")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(isQuotaExceeded || !entry.isSecure ? Color.red : Color.green.opacity(0.9))
                        .lineLimit(1)
                }
            }
            .frame(width: 112, alignment: .leading)
        }
    }
}

struct NetPulseWidget: Widget {
    let kind: String = "NetPulseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            NetPulseWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("NetPulse Anti-Hack Sentry")
        .description("Pantau bandwidth live & deteksi lonjakan trafik mencurigakan.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// ---------------------------------------------------------------------------
// DYNAMIC ISLAND (ACTIVITYKIT LIVE ACTIVITY FOR IPHONE 15)
// ---------------------------------------------------------------------------
struct NetPulseLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NetPulseAttributes.self) { context in
            ZStack {
                Color(red: 9/255, green: 13/255, blue: 22/255)
                HStack(spacing: 12) {
                    Circle()
                        .fill(context.state.isSecure ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.isSecure ? "ANTI-HACK SENTRY: AMAN" : "🚨 WASPADA: LONJAKAN TRAFIK!")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(context.state.isSecure ? Color.green : Color.red)
                        Text("↓ \(context.state.downloadDisplay) Down • ↑ \(context.state.uploadDisplay) Up")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text(context.state.isp)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.cyan)
                }
                .padding()
            }
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("DOWNLOAD")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color.gray)
                        Text(context.state.downloadDisplay)
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(Color.cyan)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("UPLOAD")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color.gray)
                        Text(context.state.uploadDisplay)
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(Color.purple)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text("TOTAL HARI INI")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(Color.orange)
                        Text(String(format: "%.2f GB", context.state.todayUsageGB))
                            .font(.system(size: 13, weight: .black))
                            .foregroundColor(Color.white)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.isSecure ? "🟢 SENTRY AMAN" : "🚨 WASPADA HACK!")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(context.state.isSecure ? Color.green : Color.red)
                        Spacer()
                        Text("📶 " + context.state.isp + " • " + String(context.state.ping) + "ms")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color.cyan)
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                HStack(spacing: 2) {
                    Text("↓")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.cyan)
                    Text(context.state.downloadDisplay)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(Color.cyan)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
            } compactTrailing: {
                HStack(spacing: 2) {
                    Text("↑")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.purple)
                    Text(context.state.uploadDisplay)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(Color.purple)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
            } minimal: {
                Circle()
                    .fill(context.state.isSecure ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
            }
        }
    }
}

@main
struct NetPulseBundle: WidgetBundle {
    var body: some Widget {
        NetPulseWidget()
        NetPulseLiveActivity()
    }
}
