import Flutter
import UIKit
// ⭐️ 1. Import ထပ်ထည့်ပါ
import flutter_local_notifications 

@main
// UISCENE_ADOPTION_V1 — FlutterImplicitEngineDelegate.
//
// Apple requires the UIScene lifecycle for any UIKit app linked against the
// iOS 27 SDK; without it the app is terminated at launch, before any
// AppDelegate method runs. This build is the first made with Xcode 27, which
// is why it started closing the instant it opened.
//
// Adopting UIScene also changes WHEN the Flutter engine exists: the scene has
// not connected while didFinishLaunchingWithOptions runs, so plugin
// registration moves to the callback below.
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // ⭐️ 2. Notification Delegate ကို သတ်မှတ်ပေးရပါမယ်
    // ဒါမှ App ဖွင့်ထားချိန်မှာ Notification တက်မှာပါ
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    // UISCENE_ADOPTION_V1 — plugin registration moved to
    // didInitializeImplicitFlutterEngine. Registering against `self` here
    // needs an engine that does not exist yet under the scene lifecycle.
    #if DEBUG
    assert(
      Bundle.main.object(forInfoDictionaryKey: "UIApplicationSceneManifest") != nil,
      "UIApplicationSceneManifest missing from Info.plist. Built against the "
      + "iOS 27 SDK this app will not launch at all - see UISCENE_ADOPTION_V1."
    )
    #endif

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// UISCENE_ADOPTION_V1 - everything that needs the Flutter engine.
  ///
  /// Called once the implicit engine exists, which under the UIScene lifecycle
  /// is after didFinishLaunchingWithOptions has returned.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}