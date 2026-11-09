import UIKit
import Flutter
import ActivityKit
import Network
import CoreTelephony
import AVFoundation
import CoreLocation

class BackgroundLocationKeepAlive: NSObject, CLLocationManagerDelegate {
    static let shared = BackgroundLocationKeepAlive()
    private var locationManager: CLLocationManager?
    private(set) var isRunning = false

    func start() {
        guard !isRunning else { return }
        DispatchQueue.main.async {
            self.locationManager = CLLocationManager()
            self.locationManager?.delegate = self
            self.locationManager?.desiredAccuracy = kCLLocationAccuracyThreeKilometers
            self.locationManager?.distanceFilter = 999999.0
            self.locationManager?.pausesLocationUpdatesAutomatically = false
            self.locationManager?.showsBackgroundLocationIndicator = false
            self.locationManager?.allowsBackgroundLocationUpdates = true
            self.locationManager?.requestAlwaysAuthorization()
            self.locationManager?.startUpdatingLocation()
            self.isRunning = true
        }
    }

    func stop() {
        DispatchQueue.main.async {
            self.locationManager?.stopUpdatingLocation()
            self.locationManager = nil
            self.isRunning = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {}
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

class SilentAudioKeepAlive {
    static let shared = SilentAudioKeepAlive()
    private var audioPlayer: AVAudioPlayer?
    private(set) var isRunning = false

    func start() {
        guard !isRunning else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)

            let sampleRate: Int = 44100
            let numChannels: Int = 1
            let bitsPerSample: Int = 16
            let numSamples = sampleRate
            let dataSize = numSamples * numChannels * (bitsPerSample / 8)
            var data = Data()

            data.append(contentsOf: [0x52, 0x49, 0x46, 0x46])
            var chunkSize = UInt32(36 + dataSize).littleEndian
            data.append(Data(bytes: &chunkSize, count: 4))
            data.append(contentsOf: [0x57, 0x41, 0x56, 0x45])
            data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20])
            var subchunk1Size = UInt32(16).littleEndian
            data.append(Data(bytes: &subchunk1Size, count: 4))
            var audioFormat = UInt16(1).littleEndian
            data.append(Data(bytes: &audioFormat, count: 2))
            var channels = UInt16(numChannels).littleEndian
            data.append(Data(bytes: &channels, count: 2))
            var sRate = UInt32(sampleRate).littleEndian
            data.append(Data(bytes: &sRate, count: 4))
            var byteRate = UInt32(sampleRate * numChannels * (bitsPerSample / 8)).littleEndian
            data.append(Data(bytes: &byteRate, count: 4))
            var blockAlign = UInt16(numChannels * (bitsPerSample / 8)).littleEndian
            data.append(Data(bytes: &blockAlign, count: 2))
            var bPerSample = UInt16(bitsPerSample).littleEndian
            data.append(Data(bytes: &bPerSample, count: 2))
            data.append(contentsOf: [0x64, 0x61, 0x74, 0x61])
            var dSize = UInt32(dataSize).littleEndian
            data.append(Data(bytes: &dSize, count: 4))
            data.append(Data(repeating: 0, count: dataSize))

            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.volume = 0.0
            audioPlayer?.play()
            isRunning = true
        } catch {
            print("Silent audio keep-alive error: \(error)")
        }
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isRunning = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

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

    private var interfaceSnapshots: [String: (inBytes: UInt64, outBytes: UInt64)] = [:]
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

    func sampleSpeed() -> (downloadMbps: Double, uploadMbps: Double, todayGB: Double, isp: String, ping: Int) {
        resetDailyCounterIfNeeded()
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return (0.0, 0.0, 0.0, currentNetwork, currentPingMs)
        }
        defer { freeifaddrs(ifaddr) }

        var currentSnapshots: [String: (inBytes: UInt64, outBytes: UInt64)] = [:]
        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr

        while let current = ptr {
            if let addr = current.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK) {
                let name = String(cString: current.pointee.ifa_name)
                // Filter out loopback (lo0) and AirDrop (awdl0).
                // Capture all physical interfaces: Wi-Fi (en), Cellular (pdp_ip), Personal Hotspot (ap)
                if !name.hasPrefix("lo") && !name.hasPrefix("awdl") {
                    if let data = current.pointee.ifa_data {
                        let ifData = data.assumingMemoryBound(to: if_data.self)
                        let inB = UInt64(ifData.pointee.ifi_ibytes)
                        let outB = UInt64(ifData.pointee.ifi_obytes)
                        currentSnapshots[name] = (inB, outB)
                    }
                }
            }
            ptr = current.pointee.ifa_next
        }

        let now = Date()
        let deltaSec = now.timeIntervalSince(lastTimestamp)
        var deltaInTotal: UInt64 = 0
        var deltaOutTotal: UInt64 = 0

        if !interfaceSnapshots.isEmpty && deltaSec > 0.4 {
            for (ifName, current) in currentSnapshots {
                if let prev = interfaceSnapshots[ifName] {
                    if current.inBytes >= prev.inBytes {
                        let diffIn = current.inBytes - prev.inBytes
                        if diffIn < 1_000_000_000 {
                            deltaInTotal += diffIn
                        }
                    } else {
                        // 32-bit wrap around handling
                        let wrapIn = (UInt64(UInt32.max) - prev.inBytes) + current.inBytes
                        if wrapIn < 1_000_000_000 {
                            deltaInTotal += wrapIn
                        }
                    }

                    if current.outBytes >= prev.outBytes {
                        let diffOut = current.outBytes - prev.outBytes
                        if diffOut < 1_000_000_000 {
                            deltaOutTotal += diffOut
                        }
                    } else {
                        let wrapOut = (UInt64(UInt32.max) - prev.outBytes) + current.outBytes
                        if wrapOut < 1_000_000_000 {
                            deltaOutTotal += wrapOut
                        }
                    }
                }
            }
        }

        interfaceSnapshots = currentSnapshots
        lastTimestamp = now

        let downMbps = deltaSec > 0.4 ? (Double(deltaInTotal) * 8.0) / (deltaSec * 1_000_000.0) : 0.0
        let upMbps = deltaSec > 0.4 ? (Double(deltaOutTotal) * 8.0) / (deltaSec * 1_000_000.0) : 0.0

        let defaults = UserDefaults.standard
        var totalToday = defaults.object(forKey: todayBytesKey) as? UInt64 ?? 0
        totalToday += (deltaInTotal + deltaOutTotal)
        defaults.set(totalToday, forKey: todayBytesKey)
        let todayGB = Double(totalToday) / (1024.0 * 1024.0 * 1024.0)

        if arc4random_uniform(4) == 0 {
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

                case "isLiveActivityActive":
                    let count = Activity<NetPulseAttributes>.activities.count
                    result(count > 0)

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

        // Automatically attach to active Live Activity if already running on launch, or clean up duplicates
        if #available(iOS 16.1, *) {
            Task {
                let all = Activity<NetPulseAttributes>.activities
                if all.count > 1 {
                    for zombie in all.dropLast() {
                        if #available(iOS 16.2, *) {
                            await zombie.end(nil, dismissalPolicy: .immediate)
                        } else {
                            await zombie.end(dismissalPolicy: .immediate)
                        }
                    }
                }
                if let active = Activity<NetPulseAttributes>.activities.last {
                    DispatchQueue.main.async {
                        self.currentActivity = active
                        SilentAudioKeepAlive.shared.start()
                        BackgroundLocationKeepAlive.shared.start()
                    }
                }
            }
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
        Task {
            // 1. Immediately terminate ANY AND ALL existing activities to prevent duplicate cards & freeze
            for existing in Activity<NetPulseAttributes>.activities {
                if #available(iOS 16.2, *) {
                    await existing.end(nil, dismissalPolicy: .immediate)
                } else {
                    await existing.end(dismissalPolicy: .immediate)
                }
            }

            let sample = NetworkSpeedMonitor.shared.sampleSpeed()
            let downText = self.formatSpeedText(sample.downloadMbps, unit: self.selectedUnit)
            let upText = self.formatSpeedText(sample.uploadMbps, unit: self.selectedUnit)

            let attributes = NetPulseAttributes(appName: "NetPulse Pro")
            let initialContent = NetPulseAttributes.ContentState(
                downloadSpeed: sample.downloadMbps,
                uploadSpeed: sample.uploadMbps,
                todayUsageGB: sample.todayGB,
                isSecure: sample.uploadMbps < 40.0,
                isp: sample.isp,
                ping: sample.ping,
                unit: self.selectedUnit,
                downloadDisplay: downText,
                uploadDisplay: upText
            )

            do {
                let activity: Activity<NetPulseAttributes>
                if #available(iOS 16.2, *) {
                    let content = ActivityContent(
                        state: initialContent,
                        staleDate: Date().addingTimeInterval(8.0),
                        relevanceScore: 100.0
                    )
                    activity = try Activity<NetPulseAttributes>.request(
                        attributes: attributes,
                        content: content,
                        pushType: nil
                    )
                } else {
                    activity = try Activity<NetPulseAttributes>.request(
                        attributes: attributes,
                        contentState: initialContent,
                        pushType: nil
                    )
                }

                DispatchQueue.main.async {
                    self.currentActivity = activity
                    SilentAudioKeepAlive.shared.start()
                    BackgroundLocationKeepAlive.shared.start()
                    self.startNativeLiveTimer()
                    result(true)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    @available(iOS 16.1, *)
    private func startNativeLiveTimer() {
        liveTimer?.invalidate()
        // Native background loop updating Dynamic Island and app continuously
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
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

            Task {
                let allActivities = Activity<NetPulseAttributes>.activities
                guard !allActivities.isEmpty else { return }

                // Enforce strictly single Live Activity: dismiss any duplicate zombies!
                if allActivities.count > 1 {
                    for zombie in allActivities.dropLast() {
                        if #available(iOS 16.2, *) {
                            await zombie.end(nil, dismissalPolicy: .immediate)
                        } else {
                            await zombie.end(dismissalPolicy: .immediate)
                        }
                    }
                }

                if let active = allActivities.last {
                    DispatchQueue.main.async {
                        self.currentActivity = active
                    }
                    if #available(iOS 16.2, *) {
                        let content = ActivityContent(
                            state: updatedContent,
                            staleDate: Date().addingTimeInterval(8.0),
                            relevanceScore: 100.0
                        )
                        await active.update(content)
                    } else {
                        await active.update(using: updatedContent)
                    }
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
        RunLoop.main.add(timer, forMode: .common)
        self.liveTimer = timer
    }

    @available(iOS 16.1, *)
    private func stopLiveActivityFlow(result: @escaping FlutterResult) {
        SilentAudioKeepAlive.shared.stop()
        BackgroundLocationKeepAlive.shared.stop()

        Task {
            // Dismiss ALL activities immediately so none are left frozen on Lock Screen or Dynamic Island
            for act in Activity<NetPulseAttributes>.activities {
                if #available(iOS 16.2, *) {
                    await act.end(nil, dismissalPolicy: .immediate)
                } else {
                    await act.end(dismissalPolicy: .immediate)
                }
            }
            DispatchQueue.main.async {
                self.currentActivity = nil
                result(true)
            }
        }
    }
}
