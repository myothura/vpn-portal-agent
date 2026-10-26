package com.vpnportal.agent

// PAYMENT_READER_V1 — MethodChannel "com.vpnportal.agent/payment_reader" (Dart: PaymentReaderBridge):
//   configure {baseUrl, token, fcmToken} -> registers this device with the backend; starts the service
//                                           when the backend says it is the reader -> {registered, mode}
//   command   {data map of the FCM message} -> hands a payment_verify command to the service
//   status    -> {configured, enabled, mode, a11y, running}
//   openA11ySettings -> system Accessibility settings (user enables "Portal Agent Payment Reader")
//   clear     -> forget everything (logout)

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private val channel = "com.vpnportal.agent/payment_reader"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            val c = applicationContext
            when (call.method) {
                "configure" -> {
                    val baseUrl = call.argument<String>("baseUrl") ?: ""
                    val token = call.argument<String>("token") ?: ""
                    val fcm = call.argument<String>("fcmToken") ?: ""
                    if (baseUrl.isEmpty() || token.isEmpty()) { result.error("args", "baseUrl/token required", null); return@setMethodCallHandler }
                    PaymentReaderConfig.save(c, baseUrl, token, fcm)
                    thread {
                        val r = PaymentApi.register(c)
                        val registered = r.code == 200 && r.json?.optBoolean("registered") == true
                        val mode = r.json?.optString("mode") ?: "off"
                        PaymentReaderConfig.setEnabled(c, registered && mode != "off", mode)
                        if (registered && mode != "off") PaymentReaderService.ensureRunning(c) else PaymentReaderService.stop(c)
                        runOnUiThread { result.success(mapOf("registered" to registered, "mode" to mode, "http" to r.code)) }
                    }
                }
                "command" -> {
                    val data = call.argument<Map<String, Any?>>("data") ?: emptyMap()
                    val j = JSONObject(); data.forEach { (k, v) -> j.put(k, v?.toString() ?: "") }
                    if (j.optString("type") == "payment_verify" && PaymentReaderConfig.enabled(c)) {
                        PaymentReaderService.deliver(c, j); result.success(true)
                    } else result.success(false)
                }
                "status" -> result.success(mapOf(
                    "configured" to PaymentReaderConfig.configured(c),
                    "enabled" to PaymentReaderConfig.enabled(c),
                    "mode" to PaymentReaderConfig.mode(c),
                    "a11y" to PaymentAccessibilityService.connected(),
                    "running" to PaymentReaderService.running,
                ))
                "openA11ySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(true)
                }
                "clear" -> { PaymentReaderService.stop(c); PaymentReaderConfig.clear(c); result.success(true) }
                else -> result.notImplemented()
            }
        }
    }
}
