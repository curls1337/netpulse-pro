import WidgetKit
import SwiftUI
import ActivityKit

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), downloadSpeed: 84.5, uploadSpeed: 36.2, lastHourMB: 142.8, isp: "Biznet Fiber", isSecure: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), downloadSpeed: 84.5, uploadSpeed: 36.2, lastHourMB: 142.8, isp: "Biznet Fiber", isSecure: true)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        var entries: [SimpleEntry] = []
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: hourOffset * 15, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, downloadSpeed: 84.5, uploadSpeed: 36.2, lastHourMB: 142.8, isp: "Biznet Fiber", isSecure: true)
            entries.append(entry)
        }
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let downloadSpeed: Double
    let uploadSpeed: Double
    let lastHourMB: Double
    let isp: String
    let isSecure: Bool
}

struct NetPulseWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        default:
            MediumWidgetView(entry: entry)
        }
    }
}

struct SmallWidgetView: View {
    var entry: Provider.Entry

    var body: some View {
        ZStack {
            Color(red: 9/255, green: 13/255, blue: 22/255)
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
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%.1f", entry.downloadSpeed))
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(.white)
                    Text("Mbps Live")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.cyan)
                }
                Spacer()
                HStack {
                    Text(String(format: "1 Jam: %.0fM", entry.lastHourMB))
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color.orange)
                    Spacer()
                    Text(String(format: "↑ %.0fM", entry.uploadSpeed))
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color.purple)
                }
            }
            .padding(14)
        }
    }
}

struct MediumWidgetView: View {
    var entry: Provider.Entry

    var body: some View {
        ZStack {
            Color(red: 9/255, green: 13/255, blue: 22/255)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Circle()
                            .fill(entry.isSecure ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(entry.isSecure ? "ANTI-HACK SENTRY: AMAN" : "⚠️ WASPADA LONJAKAN DATA")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(entry.isSecure ? Color.green : Color.red)
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "%.1f", entry.downloadSpeed))
                            .font(.system(size: 30, weight: .black))
                            .foregroundColor(.white)
                        Text("Mbps Bandwidth Live")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color.cyan)
                    }
                    Spacer()
                    Text("Upload: " + String(format: "%.1f", entry.uploadSpeed) + "M • ISP: " + entry.isp)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider().background(Color.white.opacity(0.1))

                VStack(alignment: .leading, spacing: 6) {
                    Text("DATA 1 JAM")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.gray)
                    Text(String(format: "%.1f MB", entry.lastHourMB))
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(Color.orange)
                    Spacer()
                    Text("Batas Harian: 1024 MB\nStatus: Bersih")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.7))
                        .lineLimit(2)
                }
                .frame(width: 100, alignment: .leading)
            }
            .padding(16)
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
                        Text(String(format: "%.1f Mbps Down • %.1f Mbps Up", context.state.downloadSpeed, context.state.uploadSpeed))
                            .font(.system(size: 10, weight: .medium))
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
                        Text(String(format: "%.1f M", context.state.downloadSpeed))
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(Color.cyan)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("UPLOAD")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color.gray)
                        Text(String(format: "%.1f M", context.state.uploadSpeed))
                            .font(.system(size: 16, weight: .black))
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
                        Text("📶 " + context.state.isp)
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
                    Text(String(format: "%.0fM", context.state.downloadSpeed))
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(Color.cyan)
                }
            } compactTrailing: {
                HStack(spacing: 2) {
                    Text("↑")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.purple)
                    Text(String(format: "%.0fM", context.state.uploadSpeed))
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(Color.purple)
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
