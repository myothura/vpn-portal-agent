package com.vpnportal.agent

// PAYNOTI_PROBE_V1: test-only probe. Logs every field of every posted
// notification so we can see what KBZPay (and other wallets) actually expose.
// Output: logcat tag PAYNOTI + <externalFilesDir>/paynoti.jsonl

import android.app.Notification
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

class PaymentNotificationListener : NotificationListenerService() {

    private val tag = "PAYNOTI"

    override fun onListenerConnected() {
        Log.i(tag, "listener connected")
    }

    override fun onListenerDisconnected() {
        Log.w(tag, "listener disconnected")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try {
            if (sbn.packageName == packageName) return
            val n = sbn.notification
            val json = JSONObject().apply {
                put("pkg", sbn.packageName)
                put("key", sbn.key)
                put("id", sbn.id)
                put("tag", sbn.tag ?: JSONObject.NULL)
                put("postTime", sbn.postTime)
                put("isOngoing", sbn.isOngoing)
                put("isGroupSummary", (n.flags and Notification.FLAG_GROUP_SUMMARY) != 0)
                put("channelId", if (android.os.Build.VERSION.SDK_INT >= 26) (n.channelId ?: JSONObject.NULL) else JSONObject.NULL)
                put("category", n.category ?: JSONObject.NULL)
                put("tickerText", n.tickerText?.toString() ?: JSONObject.NULL)
                put("extras", bundleToJson(n.extras))
            }
            Log.i(tag, json.toString())
            val dir = getExternalFilesDir(null) ?: filesDir
            File(dir, "paynoti.jsonl").appendText(json.toString() + "\n")

            // PAYNOTI_A11Y_NAV_V2: incoming-money -> kick a11y navigation.
            val txt = (n.extras.getCharSequence(android.app.Notification.EXTRA_TEXT)?.toString() ?: "") +
                      (n.extras.getCharSequence(android.app.Notification.EXTRA_BIG_TEXT)?.toString() ?: "")
            if (sbn.packageName == "com.kbzbank.kpaycustomer" && txt.contains("ငွေလက်ခံရရှိပါသည်")) {
                Log.i(tag, "incoming-money trigger")
                PaymentAccessibilityService.navigateNow(sbn.postTime)
            }
        } catch (e: Exception) {
            Log.e(tag, "capture failed", e)
        }
    }

    private fun bundleToJson(b: Bundle?): JSONObject {
        val o = JSONObject()
        if (b == null) return o
        for (k in b.keySet()) {
            @Suppress("DEPRECATION")
            val v = try { b.get(k) } catch (e: Exception) { "<${e.javaClass.simpleName}>" }
            o.put(k, when (v) {
                null -> JSONObject.NULL
                is CharSequence -> v.toString()
                is Array<*> -> JSONArray(v.map { it?.toString() })
                is Bundle -> bundleToJson(v)
                is Number, is Boolean -> v
                else -> v.toString()
            })
        }
        return o
    }
}
