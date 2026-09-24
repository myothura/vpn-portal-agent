import Flutter
import UIKit
// ⭐️ 1. Import ထပ်ထည့်ပါ
import flutter_local_notifications 

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // ⭐️ 2. Notification Delegate ကို သတ်မှတ်ပေးရပါမယ်
    // ဒါမှ App ဖွင့်ထားချိန်မှာ Notification တက်မှာပါ
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}