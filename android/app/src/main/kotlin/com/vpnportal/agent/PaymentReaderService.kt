package com.vpnportal.agent

// PAYMENT_READER_V1 — sticky foreground service on the KBZPay phone. Keeps the process alive, polls
// GET payment-verify/next every pollSec as the fallback for a missed FCM command, and hands each
// command to PaymentAccessibilityService. One command at a time: the next poll waits until the
// a11y run reports (or times out).

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.util.Log
import org.json.JSONObject

class PaymentReaderService : Service() {

    companion object {
        private const val TAG = "PAYREADER"
        private const val CHANNEL = "payment_reader"
        private const val NOTIF_ID = 7701
        const val ACTION_COMMAND = "com.vpnportal.agent.PAYMENT_COMMAND"
        const val EXTRA_COMMAND = "command_json"

        @Volatile var running = false

        /** Start (or re-start) the service when this device is the registered reader. */
        fun ensureRunning(c: Context) {
            if (!PaymentReaderConfig.enabled(c) || !PaymentReaderConfig.configured(c)) return
            val i = Intent(c, PaymentReaderService::class.java)
            if (Build.VERSION.SDK_INT >= 26) c.startForegroundService(i) else c.startService(i)
        }

        fun stop(c: Context) {
            c.stopService(Intent(c, PaymentReaderService::class.java))
        }

        /** A command that arrived by FCM (Dart background handler -> MethodChannel). */
        fun deliver(c: Context, command: JSONObject) {
            val i = Intent(c, PaymentReaderService::class.java).setAction(ACTION_COMMAND).putExtra(EXTRA_COMMAND, command.toString())
            if (Build.VERSION.SDK_INT >= 26) c.startForegroundService(i) else c.startService(i)
        }
    }

    private lateinit var thread: HandlerThread
    private lateinit var worker: Handler
    private val poll = object : Runnable {
        override fun run() {
            try { pollOnce() } catch (e: Exception) { Log.w(TAG, "poll failed", e) }
            worker.postDelayed(this, PaymentReaderConfig.pollSec(this@PaymentReaderService) * 1000L)
        }
    }

    override fun onCreate() {
        super.onCreate()
        thread = HandlerThread("payment-reader").also { it.start() }
        worker = Handler(thread.looper)
        startForeground(NOTIF_ID, notification("Payment reader: waiting for commands"))
        running = true
        worker.post(poll)
        Log.i(TAG, "service started")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_COMMAND) {
            intent.getStringExtra(EXTRA_COMMAND)?.let { raw ->
                worker.post {
                    try { handle(JSONObject(raw), "fcm") } catch (e: Exception) { Log.w(TAG, "bad command", e) }
                }
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        worker.removeCallbacksAndMessages(null)
        thread.quitSafely()
        super.onDestroy()
        Log.i(TAG, "service stopped")
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun pollOnce() {
        if (!PaymentReaderConfig.enabled(this)) { stopSelf(); return }
        if (PaymentAccessibilityService.busy) return
        val r = PaymentApi.next(this)
        if (r.code == 403) { PaymentReaderConfig.setEnabled(this, false, "off"); stopSelf(); return }
        val cmd = r.json?.optJSONObject("command") ?: return
        handle(cmd, "poll")
    }

    private fun handle(cmd: JSONObject, source: String) {
        if (PaymentAccessibilityService.busy) { Log.i(TAG, "busy, command from $source queued for next poll"); return }
        val id = cmd.optString("verification_id")
        Log.i(TAG, "command #$id via $source: $cmd")
        notify("Payment reader: checking request #${cmd.optString("request_id")}")
        val ok = PaymentAccessibilityService.runCommand(this, cmd) { result ->
            worker.post {
                val resp = PaymentApi.result(this, id, result)
                Log.i(TAG, "result #$id -> ${resp.code} ${resp.json}")
                notify("Payment reader: waiting for commands")
            }
        }
        if (!ok) {
            // a11y service not enabled/connected: tell the backend so the request goes to a human
            val r = JSONObject().put("found", false).put("note", "a11y service not connected on reader phone")
            PaymentApi.result(this, id, r)
            notify("Payment reader: accessibility service OFF")
        }
    }

    private fun notify(text: String) {
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).notify(NOTIF_ID, notification(text))
    }

    private fun notification(text: String): Notification {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26 && nm.getNotificationChannel(CHANNEL) == null) {
            nm.createNotificationChannel(NotificationChannel(CHANNEL, "Payment reader", NotificationManager.IMPORTANCE_LOW).apply {
                setShowBadge(false)
            })
        }
        val pi = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0))
        val b = newBuilder()
        return b.setContentTitle("Portal Agent").setContentText(text).setSmallIcon(R.mipmap.launcher_icon)
            .setOngoing(true).setContentIntent(pi).build()
    }

    @Suppress("DEPRECATION")
    private fun newBuilder(): Notification.Builder =
        if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL) else Notification.Builder(this)
}
