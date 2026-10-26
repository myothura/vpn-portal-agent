package com.vpnportal.agent

// PAYMENT_READER_V1 — after a reboot the reader phone comes back on its own (no one taps the app).

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class PaymentReaderBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            PaymentReaderService.ensureRunning(context)
        }
    }
}
