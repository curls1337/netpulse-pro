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

        public init(downloadSpeed: Double, uploadSpeed: Double, todayUsageGB: Double, isSecure: Bool, isp: String) {
            self.downloadSpeed = downloadSpeed
            self.uploadSpeed = uploadSpeed
            self.todayUsageGB = todayUsageGB
            self.isSecure = isSecure
            self.isp = isp
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

    func getNetworkBytes() -> (inBytes: UInt64, outBytes: UInt64) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return (0, 0) }
        defer { freeifaddrs(ifaddr) }

        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0

        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let current = ptr {
            let name = String(cString: current.pointee.ifa_name)
            if name.hasPrefix("en") || name.hasPrefix("pdp_ip") {
                if let data = current.pointee.ifa_data {
                    let ifData = data.assumingMemoryBound(to: if_data.self)
                    totalIn += UInt64(ifData.pointee.ifi_ibytes)
                    totalOut += UInt64(ifData.pointee.ifi_obytes)
                }
            }
            ptr = current.pointee.ifa_next
        }
        return (totalIn, totalOut)
    }

    func sampleSpeed() -> (downloadMbps: Double, uploadMbps: Double, todayGB: Double, isp: String) {
        resetDailyCounterIfNeeded()
        let (currentIn, currentOut) = getNetworkBytes()
        let now = Date()
        let deltaSec = now.timeIntervalSince(lastTimestamp)

        var downMbps: Double = 0.0
        var upMbps: Double = 0.0

        if lastInBytes > 0 && lastOutBytes > 0 && deltaSec > 0.5 {
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

        return (downMbps, upMbps, todayGB, currentNetwork)
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
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    @available(iOS 16.1, *)
    private func startLiveActivityFlow(result: @escaping FlutterResult) {
        let sample = NetworkSpeedMonitor.shared.sampleSpeed()
        let attributes = NetPulseAttributes(appName: "NetPulse Pro")
        let initialContent = NetPulseAttributes.ContentState(
            downloadSpeed: sample.downloadMbps,
            uploadSpeed: sample.uploadMbps,
            todayUsageGB: sample.todayGB,
            isSecure: sample.uploadMbps < 40.0,
            isp: sample.isp
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
        // Native background loop updating Dynamic Island continuously
        liveTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let sample = NetworkSpeedMonitor.shared.sampleSpeed()
            let isSecure = (sample.uploadMbps < 40.0)
            let updatedContent = NetPulseAttributes.ContentState(
                downloadSpeed: sample.downloadMbps,
                uploadSpeed: sample.uploadMbps,
                todayUsageGB: sample.todayGB,
                isSecure: isSecure,
                isp: sample.isp
            )

            if let activity = self.currentActivity as? Activity<NetPulseAttributes> {
                Task {
                    await activity.update(using: updatedContent)
                }
            }

            DispatchQueue.main.async {
                self.liveChannel?.invokeMethod("onSpeedUpdate", [
                    "download": sample.downloadMbps,
                    "upload": sample.uploadMbps,
                    "todayGB": sample.todayGB,
                    "isp": sample.isp,
                    "isSecure": isSecure
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
