import UIKit
import Flutter
import ActivityKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    private var currentActivity: Any?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController
        let liveActivityChannel = FlutterMethodChannel(
            name: "com.devcurl.netpulse/live_activity",
            binaryMessenger: controller.binaryMessenger
        )

        liveActivityChannel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }

            if #available(iOS 16.1, *) {
                switch call.method {
                case "startLiveActivity":
                    let args = call.arguments as? [String: Any] ?? [:]
                    let download = args["download"] as? Double ?? 84.5
                    let upload = args["upload"] as? Double ?? 36.2
                    let isSecure = args["isSecure"] as? Bool ?? true
                    let isp = args["isp"] as? String ?? "Biznet Fiber"

                    let attributes = NetPulseAttributes(appName: "NetPulse Pro")
                    let initialContent = NetPulseAttributes.ContentState(
                        downloadSpeed: download,
                        uploadSpeed: upload,
                        isSecure: isSecure,
                        isp: isp
                    )

                    do {
                        let activity = try Activity<NetPulseAttributes>.request(
                            attributes: attributes,
                            contentState: initialContent,
                            pushType: nil
                        )
                        self.currentActivity = activity
                        result(true)
                    } catch {
                        result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
                    }

                case "updateLiveActivity":
                    let args = call.arguments as? [String: Any] ?? [:]
                    let download = args["download"] as? Double ?? 84.5
                    let upload = args["upload"] as? Double ?? 36.2
                    let isSecure = args["isSecure"] as? Bool ?? true
                    let isp = args["isp"] as? String ?? "Biznet Fiber"

                    let updatedContent = NetPulseAttributes.ContentState(
                        downloadSpeed: download,
                        uploadSpeed: upload,
                        isSecure: isSecure,
                        isp: isp
                    )

                    if let activity = self.currentActivity as? Activity<NetPulseAttributes> {
                        Task {
                            await activity.update(using: updatedContent)
                        }
                    }
                    result(true)

                case "stopLiveActivity":
                    if let activity = self.currentActivity as? Activity<NetPulseAttributes> {
                        Task {
                            await activity.end(dismissalPolicy: .immediate)
                        }
                    }
                    self.currentActivity = nil
                    result(true)

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
}
