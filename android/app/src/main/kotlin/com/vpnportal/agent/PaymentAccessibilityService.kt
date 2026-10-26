package com.vpnportal.agent

// PAYNOTI_A11Y_NAV_V2: auto-navigate + extract (dispatchGesture based).
// Trigger (from PaymentNotificationListener): KBZPay "ငွေလက်ခံရရှိပါသည်" posted.
// Flow: open KBZPay launcher -> tap မှတ်တမ်း -> tap top row -> read receipt
//       fields (tv_field_name/tv_field_value) -> emit JSON -> back x2.
// Still dumps every KBZPay screen to logcat PAYA11Y + paya11y.jsonl (probe kept).

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

class PaymentAccessibilityService : AccessibilityService() {

    companion object {
        private const val KBZ = "com.kbzbank.kpaycustomer"
        // Intent action fired by PaymentNotificationListener on incoming-money noti.
        const val ACTION_TRIGGER = "com.vpnportal.agent.PAYMENT_TRIGGER"

        // Shared flag the listener flips; service reads on next KBZ window event.
        @Volatile var pendingTrigger: Boolean = false
        @Volatile var triggerPostTime: Long = 0L

        private var instance: PaymentAccessibilityService? = null
        fun navigateNow(postTime: Long) {
            instance?.let {
                it.triggerAt = postTime
                it.main.post { it.startNav() }
            } ?: run { pendingTrigger = true; triggerPostTime = postTime }
        }
    }

    private val tag = "PAYA11Y"
    private val main = Handler(Looper.getMainLooper())
    private var lastDump = ""

    // Nav state machine
    private enum class S { IDLE, OPENING, HOME, HISTORY, RECEIPT, DONE }
    @Volatile private var state = S.IDLE
    private var triggerAt = 0L
    private var stepGuard = 0L   // debounce taps per screen

    override fun onServiceConnected() {
        instance = this
        Log.i(tag, "a11y connected (NAV_V2)")
        if (pendingTrigger) { pendingTrigger = false; navigateNow(triggerPostTime) }
    }

    override fun onDestroy() { instance = null; super.onDestroy() }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        val root = rootInActiveWindow ?: return
        if (root.packageName?.toString() != KBZ) return

        dump(root, event)          // probe (unchanged behaviour)
        if (state == S.IDLE || state == S.DONE) return
        driveNav(root)
    }

    // ---- navigation ----

    fun startNav() {
        state = S.OPENING
        stepGuard = 0
        Log.i(tag, "nav start -> open KBZPay")
        val i = packageManager.getLaunchIntentForPackage(KBZ)
        if (i != null) {
            i.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(i)
        } else {
            Log.e(tag, "no launch intent for $KBZ"); state = S.IDLE
        }
    }

    private fun driveNav(root: AccessibilityNodeInfo) {
        val now = System.currentTimeMillis()
        if (now - stepGuard < 900) return    // let each screen settle

        when (state) {
            S.OPENING, S.HOME -> {
                // Home shows a "မှတ်တမ်း" quick-action text node.
                val mhtt = findByText(root, "မှတ်တမ်း")
                if (mhtt != null) {
                    stepGuard = now; state = S.HISTORY
                    Log.i(tag, "tap မှတ်တမ်း"); tapCenter(mhtt)
                }
            }
            S.HISTORY -> {
                // History toolbar title == "မှတ်တမ်း"; top row id = iv_head/tv_trans_type.
                val title = findInToolbar(root, "မှတ်တမ်း")
                val topRow = findFirstById(root, "$KBZ:id/tv_trans_type")
                if (title != null && topRow != null) {
                    stepGuard = now; state = S.RECEIPT
                    Log.i(tag, "tap top row"); tapRowFor(topRow)
                }
            }
            S.RECEIPT -> {
                // Receipt: txn no lives in tv_field_value under label လုပ်ဆောင်မှုအမှတ်.
                val fields = readFields(root)
                if (fields.has("လုပ်ဆောင်မှုအမှတ်")) {
                    stepGuard = now; state = S.DONE
                    emit(fields)
                    main.postDelayed({ performGlobalAction(GLOBAL_ACTION_BACK) }, 400)
                    main.postDelayed({ performGlobalAction(GLOBAL_ACTION_BACK) }, 1100)
                    state = S.IDLE
                }
            }
            else -> {}
        }
    }

    private fun readFields(root: AccessibilityNodeInfo): JSONObject {
        val o = JSONObject()
        val names = ArrayList<AccessibilityNodeInfo>()
        val vals = ArrayList<AccessibilityNodeInfo>()
        collectById(root, "$KBZ:id/tv_field_name", names)
        collectById(root, "$KBZ:id/tv_field_value", vals)
        val n = minOf(names.size, vals.size)
        for (i in 0 until n) {
            val k = names[i].text?.toString()?.trim() ?: continue
            val v = vals[i].text?.toString()?.trim() ?: ""
            o.put(k, v)
        }
        findFirstById(root, "$KBZ:id/tv_amount")?.text?.toString()?.let { o.put("_amount", it.trim()) }
        findFirstById(root, "$KBZ:id/tv_status")?.text?.toString()?.let { o.put("_status", it.trim()) }
        return o
    }

    private fun emit(fields: JSONObject) {
        val out = JSONObject().apply {
            put("t", System.currentTimeMillis())
            put("triggerPostTime", triggerAt)
            put("fields", fields)
        }
        Log.i(tag, "EXTRACT $out")
        val dir = getExternalFilesDir(null) ?: filesDir
        File(dir, "payextract.jsonl").appendText(out.toString() + "\n")
        // TODO backend POST goes here once parser confirmed.
    }

    // ---- gesture tap (dispatchGesture) ----

    private fun tapCenter(node: AccessibilityNodeInfo) {
        val r = android.graphics.Rect(); node.getBoundsInScreen(r)
        tapXY(r.exactCenterX(), r.exactCenterY())
    }

    // For a list row: the clickable container is an ancestor of tv_trans_type.
    private fun tapRowFor(label: AccessibilityNodeInfo) {
        var p: AccessibilityNodeInfo? = label
        while (p != null && !p.isClickable) p = p.parent
        val target = p ?: label
        val r = android.graphics.Rect(); target.getBoundsInScreen(r)
        tapXY(r.exactCenterX(), r.exactCenterY())
    }

    private fun tapXY(x: Float, y: Float) {
        val path = Path().apply { moveTo(x, y) }
        val stroke = GestureDescription.StrokeDescription(path, 0, 60)
        val g = GestureDescription.Builder().addStroke(stroke).build()
        dispatchGesture(g, null, null)
    }

    // ---- node finders ----

    private fun findByText(root: AccessibilityNodeInfo, text: String): AccessibilityNodeInfo? =
        root.findAccessibilityNodeInfosByText(text)?.firstOrNull { it.text?.toString() == text }

    private fun findInToolbar(root: AccessibilityNodeInfo, text: String): AccessibilityNodeInfo? {
        val tb = findFirstById(root, "$KBZ:id/toolbar") ?: return null
        val hit = ArrayList<AccessibilityNodeInfo>()
        collectText(tb, text, hit)
        return hit.firstOrNull()
    }

    private fun findFirstById(root: AccessibilityNodeInfo, id: String): AccessibilityNodeInfo? =
        root.findAccessibilityNodeInfosByViewId(id)?.firstOrNull()

    private fun collectById(node: AccessibilityNodeInfo, id: String, out: MutableList<AccessibilityNodeInfo>) {
        node.findAccessibilityNodeInfosByViewId(id)?.let { out.addAll(it) }
    }

    private fun collectText(node: AccessibilityNodeInfo?, text: String, out: MutableList<AccessibilityNodeInfo>) {
        if (node == null) return
        if (node.text?.toString() == text) out.add(node)
        for (i in 0 until node.childCount) collectText(node.getChild(i), text, out)
    }

    // ---- probe dump (kept from V1) ----

    private fun dump(root: AccessibilityNodeInfo, event: AccessibilityEvent) {
        try {
            val texts = ArrayList<String>()
            collect(root, texts)
            val joined = texts.joinToString("|")
            if (joined.isEmpty() || joined == lastDump) return
            lastDump = joined
            val json = JSONObject().apply {
                put("t", System.currentTimeMillis())
                put("event", AccessibilityEvent.eventTypeToString(event.eventType))
                put("cls", event.className?.toString() ?: JSONObject.NULL)
                put("state", state.name)
                put("texts", JSONArray(texts))
            }
            Log.i(tag, json.toString())
            val dir = getExternalFilesDir(null) ?: filesDir
            File(dir, "paya11y.jsonl").appendText(json.toString() + "\n")
        } catch (e: Exception) {
            Log.e(tag, "dump failed", e)
        }
    }

    private fun collect(node: AccessibilityNodeInfo?, out: MutableList<String>) {
        if (node == null) return
        node.text?.toString()?.takeIf { it.isNotBlank() }?.let { out.add(it) }
        for (i in 0 until node.childCount) collect(node.getChild(i), out)
    }

    override fun onInterrupt() {}
}
