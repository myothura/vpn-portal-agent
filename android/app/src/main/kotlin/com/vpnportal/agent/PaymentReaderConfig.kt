package com.vpnportal.agent

// PAYMENT_READER_V1 — settings the native payment reader keeps for itself, so it can run with the
// Flutter engine dead (FCM data message, boot, poll). Written from Dart through the MethodChannel
// right after login (PaymentReaderBridge.configure). allowBackup=false in the manifest keeps the
// bearer token out of ADB/cloud backup, as for the Dart-side token.

import android.content.Context
import android.content.SharedPreferences

object PaymentReaderConfig {
    private const val PREFS = "payment_reader_prefs"

    private fun p(c: Context): SharedPreferences = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun baseUrl(c: Context): String = p(c).getString("base_url", "") ?: ""
    fun token(c: Context): String = p(c).getString("token", "") ?: ""
    fun fcmToken(c: Context): String = p(c).getString("fcm_token", "") ?: ""
    /** backend said this device is the reader (POST payment-verify/register -> registered:true) */
    fun enabled(c: Context): Boolean = p(c).getBoolean("enabled", false)
    fun mode(c: Context): String = p(c).getString("mode", "off") ?: "off"
    // 15 s: the FCM command only reaches the native side while the Flutter engine is alive (the
    // background isolate has no MethodChannel to MainActivity), so the poll is the usual path
    fun pollSec(c: Context): Int = p(c).getInt("poll_sec", 15)

    fun save(c: Context, baseUrl: String, token: String, fcmToken: String) {
        p(c).edit().putString("base_url", baseUrl.trimEnd('/')).putString("token", token).putString("fcm_token", fcmToken).apply()
    }

    fun setEnabled(c: Context, enabled: Boolean, mode: String) {
        p(c).edit().putBoolean("enabled", enabled).putString("mode", mode).apply()
    }

    fun clear(c: Context) {
        p(c).edit().clear().apply()
    }

    fun configured(c: Context): Boolean = baseUrl(c).isNotEmpty() && token(c).isNotEmpty()
}
