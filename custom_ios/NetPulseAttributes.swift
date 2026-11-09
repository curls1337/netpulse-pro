import Foundation
import ActivityKit

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
