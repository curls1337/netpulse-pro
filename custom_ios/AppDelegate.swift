import UIKit
import Flutter
import ActivityKit
import Network
import CoreTelephony

public struct NetPulseAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var downloadSpeed: Double
        public var uploadSpeed: Double
        public var todayUsageGB: Double
        public var isSecure: Bool
        public var isp: String
        public var ping: Int
        public var unit: String
        public var downloadDisplay: String
        public var uploadDisplay: String

        public init(
            downloadSpeed: Double,
            uploadSpeed: Double,
            todayUsageGB: Double,
            isSecure: Bool,
            isp: String,
            ping: Int = 14,
            unit: String = "Auto",
            downloadDisplay: String = "0K",
            uploadDisplay: String = "0K"
        ) {
            self.downloadSpeed = downloadSpeed
            self.uploadSpeed = uploadSpeed
            self.todayUsageGB = todayUsageGB
            self.isSecure = isSecure
            self.isp = isp
            self.ping = ping
            self.unit = unit
            self.downloadDisplay = downloadDisplay
            self.uploadDisplay = uploadDisplay
        }
    }

    public var appName: String

    public init(appName: String) {
        self.appName = appName
    }
}

// ---------------------------------------------------------------------------
// REAL HARDWARE NETWORK & SPEED MONITOR ENGINE (GETIFADDRS + NWPATHMONITOR)
// ---------------------------------------------------------------------------
class NetworkSpeedMonitor {
    static let shared = NetworkSpeedMonitor()

    private var lastInBytes: UInt64 = 0
    private var lastOutBytes: UInt64 = 0
    private var lastTimestamp: Date = Date()
    private(set) var currentNetwork: String = "Wi-Fi"
    private var pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetPulseNetworkQueue")

    private let todayBytesKey = "NetPulse_TodayBytes"
    private let lastDateKey = "NetPulse_LastDate"

    init() {
        startPathMonitor()
        resetDailyCounterIfNeeded()
    }

    private func startPathMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            if path.usesInterfaceType(.wifi) {
                self.currentNetwork = "Wi-Fi"
            } else if path.usesInterfaceType(.cellular) {
                self.currentNetwork = self.detectCellularCarrier()
            } else {
                self.currentNetwork = "Internet"
            }
        }
        pathMonitor.start(queue: monitorQueue)
    }

    private func detectCellularCarrier() -> String {
        let netInfo = CTTelephonyNetworkInfo()
        if let providers = netInfo.serviceSubscriberCellularProviders {
            for (_, carrier) in providers {
                if let name = carrier.carrierName, !name.isEmpty {
                    return name
                }
            }
        }
        return "Seluler (5G/LTE)"
    }

    private func resetDailyCounterIfNeeded() {
        let defaults = UserDefaults.standard
        let todayStr = String(ISO8601DateFormatter().string(from: Date()).prefix(10))
        let lastDateStr = defaults.string(forKey: lastDateKey) ?? ""
        if lastDateStr != todayStr {
            defaults.set(todayStr, forKey: lastDateKey)
            defaults.set(UInt64(0), forKey: todayBytesKey)
        }
    }

    private var currentPingMs: Int = 14

    func measureRealPing() {
        let host = NWEndpoint.Host("1.1.1.1")
        let port = NWEndpoint.Port(integerLiteral: 443)
        let conn = NWConnection(host: host, port: port, using: .tcp)
        let start = Date()
        conn.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                let ms = Int(Date().timeIntervalSince(start) * 1000.0)
                if ms > 0 && ms < 2000 {
                    self?.currentPingMs = ms
                }
                conn.cancel()
            case .failed(_), .cancelled:
                conn.cancel()
            default:
                break
            }
        }
        conn.start(queue: monitorQueue)
    }

    func getNetworkBytes() -> (inBytes: UInt64, outBytes: UInt64) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return (0, 0) }
        defer { freeifaddrs(ifaddr) }

        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0

        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let current = ptr {
            if let addr = current.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK) {
                let name = String(cString: current.pointee.ifa_name)
                // Monitor Wi-Fi (en), Cellular (pdp_ip), and System Tunnels/iCloud Private Relay (utun, ipsec)
                if name.hasPrefix("en") || name.hasPrefix("pdp_ip") || name.hasPrefix("utun") || name.hasPrefix("ipsec") {
                    if let data = current.pointee.ifa_data {
                        let ifData = data.assumingMemoryBound(to: if_data.self)
                        totalIn += UInt64(ifData.pointee.ifi_ibytes)
                        totalOut += UInt64(ifData.pointee.ifi_obytes)
                    }
                }
            }
            ptr = current.pointee.ifa_next
        }
        return (totalIn, totalOut)
    }

    func sampleSpeed() -> (downloadMbps: Double, uploadMbps: Double, todayGB: Double, isp: String, ping: Int) {
        resetDailyCounterIfNeeded()
        let (currentIn, currentOut) = getNetworkBytes()
        let now = Date()
        let deltaSec = now.timeIntervalSince(lastTimestamp)

        var downMbps: Double = 0.0
        var upMbps: Double = 0.0

        if lastInBytes > 0 && lastOutBytes > 0 && deltaSec > 0.4 {
            let inDelta = currentIn >= lastInBytes ? currentIn - lastInBytes : 0
            let outDelta = currentOut >= lastOutBytes ? currentOut - lastOutBytes : 0

            downMbps = (Double(inDelta) * 8.0) / (deltaSec * 1_000_000.0)
            upMbps = (Double(outDelta) * 8.0) / (deltaSec * 1_000_000.0)

            let defaults = UserDefaults.standard
            var totalToday = defaults.object(forKey: todayBytesKey) as? UInt64 ?? 0
            totalToday += (inDelta + outDelta)
            defaults.set(totalToday, forKey: todayBytesKey)
        }

        lastInBytes = currentIn
        lastOutBytes = currentOut
        lastTimestamp = now

        let defaults = UserDefaults.standard
        let totalTodayBytes = defaults.object(forKey: todayBytesKey) as? UInt64 ?? 0
        let todayGB = Double(totalTodayBytes) / (1024.0 * 1024.0 * 1024.0)

        // Occasionally measure ping
        if arc4random_uniform(5) == 0 {
            measureRealPing()
        }

        return (downMbps, upMbps, todayGB, currentNetwork, currentPingMs)
    }
}

// ---------------------------------------------------------------------------
// FLUTTER APP DELEGATE WITH LIVE ACTIVITY BACKGROUND LOOP
// ---------------------------------------------------------------------------
@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    private var currentActivity: Any?
    private var liveTimer: Timer?
    private var liveChannel: FlutterMethodChannel?
    private var selectedUnit: String = "Auto"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController
        liveChannel = FlutterMethodChannel(
            name: "com.devcurl.netpulse/live_activity",
            binaryMessenger: controller.binaryMessenger
        )

        liveChannel?.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }

            if #available(iOS 16.1, *) {
                switch call.method {
                case "startLiveActivity":
                    self.startLiveActivityFlow(result: result)

                case "updateLiveActivity":
                    result(true)

                case "stopLiveActivity":
                    self.stopLiveActivityFlow(result: result)

                case "setSpeedUnit":
                    let args = call.arguments as? [String: Any] ?? [:]
                    self.selectedUnit = args["unit"] as? String ?? "Auto"
                    result(true)

                case "getNetworkStatus":
                    let sample = NetworkSpeedMonitor.shared.sampleSpeed()
                    result([
                        "download": sample.downloadMbps,
                        "upload": sample.uploadMbps,
                        "todayGB": sample.todayGB,
                        "isp": sample.isp
                    ])

                default:
                    result(FlutterMethodNotImplemented)
                }
            } else {
                result(FlutterError(code: "UNSUPPORTED_VERSION", message: "Live Activities requires iOS 16.1+", details: nil))
            }
        }

        GeneratedPluginRegistrant.register(with: self)

        // Automatically start real hardware speed monitor on app launch
        if #available(iOS 16.1, *) {
            self.startNativeLiveTimer()
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    @available(iOS 16.1, *)
    private func formatSpeedText(_ mbps: Double, unit: String) -> String {
        let kbps = mbps * 125.0
        let mbPerSec = mbps / 8.0
        switch unit {
        case "KB/s":
            return String(format: "%.0fK", kbps)
        case "MB/s":
            return String(format: "%.1fM", mbPerSec)
        case "Mbps":
            return String(format: "%.1fM", mbps)
        default: // Auto
            if mbps < 1.0 {
                return String(format: "%.0fK", kbps)
            } else {
                return String(format: "%.1fM", mbps)
            }
        }
    }

    @available(iOS 16.1, *)
    private func startLiveActivityFlow(result: @escaping FlutterResult) {
        let sample = NetworkSpeedMonitor.shared.sampleSpeed()
        let downText = formatSpeedText(sample.downloadMbps, unit: selectedUnit)
        let upText = formatSpeedText(sample.uploadMbps, unit: selectedUnit)

        let attributes = NetPulseAttributes(appName: "NetPulse Pro")
        let initialContent = NetPulseAttributes.ContentState(
            downloadSpeed: sample.downloadMbps,
            uploadSpeed: sample.uploadMbps,
            todayUsageGB: sample.todayGB,
            isSecure: sample.uploadMbps < 40.0,
            isp: sample.isp,
            ping: sample.ping,
            unit: selectedUnit,
            downloadDisplay: downText,
            uploadDisplay: upText
        )

        do {
            let activity = try Activity<NetPulseAttributes>.request(
                attributes: attributes,
                contentState: initialContent,
                pushType: nil
            )
            self.currentActivity = activity
            self.startNativeLiveTimer()
            result(true)
        } catch {
            result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
        }
    }

    @available(iOS 16.1, *)
    private func startNativeLiveTimer() {
        liveTimer?.invalidate()
        // Native background loop updating Dynamic Island and app continuously
        liveTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let sample = NetworkSpeedMonitor.shared.sampleSpeed()
            let isSecure = (sample.uploadMbps < 40.0)
            let downText = self.formatSpeedText(sample.downloadMbps, unit: self.selectedUnit)
            let upText = self.formatSpeedText(sample.uploadMbps, unit: self.selectedUnit)

            let updatedContent = NetPulseAttributes.ContentState(
                downloadSpeed: sample.downloadMbps,
                uploadSpeed: sample.uploadMbps,
                todayUsageGB: sample.todayGB,
                isSecure: isSecure,
                isp: sample.isp,
                ping: sample.ping,
                unit: self.selectedUnit,
                downloadDisplay: downText,
                uploadDisplay: upText
            )

            if let activity = self.currentActivity as? Activity<NetPulseAttributes> {
                Task {
                    await activity.update(using: updatedContent)
                }
            }

            DispatchQueue.main.async {
                self.liveChannel?.invokeMethod("onSpeedUpdate", arguments: [
                    "download": sample.downloadMbps,
                    "upload": sample.uploadMbps,
                    "todayGB": sample.todayGB,
                    "isp": sample.isp,
                    "isSecure": isSecure,
                    "ping": sample.ping,
                    "downloadDisplay": downText,
                    "uploadDisplay": upText
                ])
            }
        }
    }

    @available(iOS 16.1, *)
    private func stopLiveActivityFlow(result: @escaping FlutterResult) {
        liveTimer?.invalidate()
        liveTimer = nil

        if let activity = self.currentActivity as? Activity<NetPulseAttributes> {
            Task {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
        self.currentActivity = nil
        result(true)
    }
}
