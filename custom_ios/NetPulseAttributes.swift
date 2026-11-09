import Foundation
import ActivityKit

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
