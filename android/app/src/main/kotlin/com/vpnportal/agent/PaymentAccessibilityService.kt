package com.vpnportal.agent

// PAYMENT_READER_V1 — command-driven KBZPay reader (replaces PAYNOTI_A11Y_NAV_V2's notification trigger).
//
// A command {verification_id, request_id, txn_ref, amount, paid_at} comes from PaymentReaderService
// (FCM data message or the /next poll). This service then: opens KBZPay -> skips the splash ad
// ("ကျော်မည် 3") -> Home: taps မှတ်တမ်း -> History: taps the အဝင် tab, finds the row whose time and
// amount match the slip -> taps it -> Receipt: reads the fields (txn no under လုပ်ဆောင်မှုအမှတ်) ->
// reports {found, txn_no, amount, paid_at, sender, rows[]} -> back x2. Not found within TIMEOUT_MS
// (or no matching row on the first page) -> {found:false, note}. The backend decides; this never does.
//
// Screens verified by uiautomator 2026-10-26 (see HANDOFF_PAYMENT_AUTO_CONFIRM_BACKEND_V1):
//   list row  = "ပေးပို့သူ U MYO THURA" | "Today 23:15:26" or "25/10 01:50:40" | "+1.00"
//   receipt   = label/value pairs, ids tv_field_name / tv_field_value (NAV_V2 probe 2026-10-25)
// The probe dump (logcat PAYA11Y + paya11y.jsonl) is kept while a command runs, for log-mode review.

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Context
import android.content.Intent
import android.graphics.Path
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

class PaymentAccessibilityService : AccessibilityService() {

    companion object {
        private const val KBZ = "com.kbzbank.kpaycustomer"
        private const val TAG = "PAYA11Y"
        private const val TIMEOUT_MS = 30_000L
        private const val LIST_SETTLE_MS = 6_000L   // wait this long for rows before "not found"
        private val SKIP_PREFIXES = listOf("ကျော်မည်", "ကျော်ရန်", "Skip", "SKIP")
        private val DISMISS_TEXTS = listOf("နောက်မှ", "ပိတ်မည်", "Close", "Not now", "Later")
        private val TIME_RE = Regex("(\\d{1,2}:\\d{2}:\\d{2})")

        @Volatile private var instance: PaymentAccessibilityService? = null
        @Volatile var busy: Boolean = false
            private set

        fun connected(): Boolean = instance != null

        /** Returns false when the a11y service is not connected (user has not enabled it). */
        fun runCommand(c: Context, cmd: JSONObject, onResult: (JSONObject) -> Unit): Boolean {
            val svc = instance ?: return false
            if (busy) return true
            busy = true
            svc.main.post { svc.begin(cmd, onResult) }
            return true
        }
    }

    private val main = Handler(Looper.getMainLooper())
    private enum class S { IDLE, OPENING, HISTORY, RECEIPT }
    @Volatile private var state = S.IDLE
    private var cmd: JSONObject? = null
    private var onResult: ((JSONObject) -> Unit)? = null
    private var stepGuard = 0L
    private var startedAt = 0L
    private var historyAt = 0L
    private var inTabTapped = false
    private var lastDump = ""
    private var lastTappedRow: String? = null
    private val rowsSeen = ArrayList<String>()
    private val timeout = Runnable { finish(JSONObject().put("found", false).put("note", "timeout in state $state")) }
    private val recheck = Runnable { if (state == S.HISTORY) rootInActiveWindow?.let { if (it.packageName?.toString() == KBZ) { stepGuard = 0L; drive(it) } } }

    // what we look for in the list
    private var wantTime = ""        // "23:15:26"
    private var wantSec = -1         // seconds of day, for the tolerance match
    private var wantDayToday = false // "Today" row
    private var wantDay = ""         // "26/10"
    private var wantAmount = ""      // "600,000.00"
    private val triedRows = HashSet<String>()   // rows whose receipt did not carry the slip's txn
    private var candidateTxn = ""              // the slip's txn (digits) when known
    // TIME_TOLERANCE_V1 — the sender's receipt and the receiver's history differ by a second or more
    // (2026-10-27: 01:03:10 on the slip, 01:03:11 in history), so the time is matched within this window
    private val TIME_TOLERANCE_SEC = 90

    override fun onServiceConnected() {
        instance = this
        Log.i(TAG, "a11y connected (READER_V1)")
        PaymentReaderService.ensureRunning(this)
    }

    override fun onDestroy() { instance = null; busy = false; super.onDestroy() }
    override fun onInterrupt() {}

    // ------------------------------------------------------------------ command

    private fun begin(c: JSONObject, cb: (JSONObject) -> Unit) {
        cmd = c; onResult = cb
        rowsSeen.clear(); triedRows.clear(); inTabTapped = false; historyAt = 0L; stepGuard = 0L
        candidateTxn = c.optString("txn_ref").filter { it.isDigit() }
        startedAt = System.currentTimeMillis()
        parseWant(c)
        state = S.OPENING
        main.removeCallbacks(timeout); main.postDelayed(timeout, TIMEOUT_MS)
        Log.i(TAG, "begin #${c.optString("verification_id")} time=$wantTime day=${if (wantDayToday) "Today" else wantDay} amount=$wantAmount")
        val i = packageManager.getLaunchIntentForPackage(KBZ)
        if (i == null) { finish(JSONObject().put("found", false).put("note", "KBZPay not installed")); return }
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
        startActivity(i)
        // the app may already be on a KBZ screen with no new event: drive once now
        main.postDelayed({ rootInActiveWindow?.let { if (it.packageName?.toString() == KBZ) drive(it) } }, 1200)
    }

    private fun secOfDay(hms: String): Int {
        val p = hms.split(":"); if (p.size != 3) return -1
        return (p[0].toIntOrNull() ?: return -1) * 3600 + (p[1].toIntOrNull() ?: return -1) * 60 + (p[2].toIntOrNull() ?: return -1)
    }

    private fun parseWant(c: JSONObject) {
        wantAmount = ""; wantTime = ""; wantSec = -1; wantDay = ""; wantDayToday = false
        c.optString("amount").filter { it.isDigit() }.toLongOrNull()?.let { wantAmount = String.format(Locale.US, "%,d.00", it) }
        val paid = c.optString("paid_at").trim()   // "26/10/2026 23:15:26"
        Regex("""(\d{1,2})/(\d{1,2})/(\d{4})\D+(\d{1,2}:\d{2}:\d{2})""").find(paid)?.let { m ->
            val d = m.groupValues[1].padStart(2, '0'); val mo = m.groupValues[2].padStart(2, '0'); val y = m.groupValues[3]
            wantTime = m.groupValues[4].let { if (it.length == 7) "0$it" else it }
            wantSec = secOfDay(wantTime)
            wantDay = "$d/$mo"
            val today = SimpleDateFormat("dd/MM/yyyy", Locale.US).format(Calendar.getInstance().time)
            wantDayToday = today == "$d/$mo/$y"
        }
    }

    private fun finish(result: JSONObject) {
        if (state == S.IDLE) return
        main.removeCallbacks(timeout); main.removeCallbacks(recheck)
        val st = state
        state = S.IDLE
        result.put("rows", JSONArray(rowsSeen.take(20)))
        result.put("ended_in", st.name)
        Log.i(TAG, "RESULT $result")
        try { File(getExternalFilesDir(null) ?: filesDir, "payextract.jsonl").appendText(result.toString() + "\n") } catch (_: Exception) {}
        val cb = onResult; onResult = null; cmd = null
        busy = false
        cb?.invoke(result)
        // leave KBZPay where it was: receipt -> history -> home
        if (st == S.RECEIPT) { main.postDelayed({ performGlobalAction(GLOBAL_ACTION_BACK) }, 400); main.postDelayed({ performGlobalAction(GLOBAL_ACTION_BACK) }, 1100) }
        else if (st == S.HISTORY) main.postDelayed({ performGlobalAction(GLOBAL_ACTION_BACK) }, 400)
    }

    // ------------------------------------------------------------------ events

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (state == S.IDLE) return
        val root = rootInActiveWindow ?: return
        if (root.packageName?.toString() != KBZ) return
        dump(root, event)
        drive(root)
    }

    private fun drive(root: AccessibilityNodeInfo) {
        val now = System.currentTimeMillis()
        if (now - stepGuard < 900) return

        // 1. splash ad / popups on any screen
        findByPrefix(root, SKIP_PREFIXES)?.let { stepGuard = now; Log.i(TAG, "tap skip '${it.text}'"); tapNode(it); return }

        val isHistory = findByText(root, "အဝင်") != null && findByText(root, "အထွက်") != null && findByText(root, "မှတ်တမ်း") != null
        val isReceipt = findByText(root, "လုပ်ဆောင်မှုအမှတ်") != null
        val isHome = !isHistory && !isReceipt && findByText(root, "မှတ်တမ်း") != null

        when {
            isReceipt -> {
                val fields = readFields(root)
                val txn = fields.optString("လုပ်ဆောင်မှုအမှတ်").filter { it.isDigit() }
                if (txn.isEmpty()) return   // still rendering
                // a receipt KBZPay was left on from before: only ours (tapped from history, or the slip's txn)
                val wantTxn = candidateTxn
                if (state != S.HISTORY && !(wantTxn.isNotEmpty() && wantTxn == txn)) {
                    stepGuard = now; Log.i(TAG, "stale receipt $txn, back"); performGlobalAction(GLOBAL_ACTION_BACK); return
                }
                // TIME_TOLERANCE_V1 — opened a near-time row that is not the slip's transfer: back, try the next one
                if (wantTxn.isNotEmpty() && wantTxn != txn && triedRows.size < 3) {
                    lastTappedRow?.let { triedRows.add(it) }
                    stepGuard = now; Log.i(TAG, "receipt $txn != slip $wantTxn, trying next row"); performGlobalAction(GLOBAL_ACTION_BACK); return
                }
                state = S.RECEIPT; stepGuard = now
                val amount = fields.optString("ငွေပမာဏ").ifEmpty { fields.optString("_amount") }
                finish(JSONObject()
                    .put("found", true)
                    .put("txn_no", txn)
                    .put("amount", amount.replace(Regex("[^0-9.]"), "").substringBefore(".").ifEmpty { JSONObject.NULL })
                    .put("paid_at", fields.optString("လုပ်ဆောင်သော အချိန်"))
                    .put("sender", fields.optString("ပေးပို့သူ"))
                    .put("fields", fields))
            }
            isHistory -> {
                if (state != S.HISTORY) { state = S.HISTORY; historyAt = now }
                if (!inTabTapped) {
                    findByText(root, "အဝင်")?.let { inTabTapped = true; stepGuard = now; Log.i(TAG, "tap အဝင်"); tapNode(it); return }
                }
                val rows = listRows(root)
                rowsSeen.clear(); rows.forEach { rowsSeen.add(it.second) }
                val hit = rows.filter { it.second !in triedRows }
                    .mapNotNull { r -> rowDelta(r.second)?.let { d -> r to d } }
                    .minByOrNull { it.second }?.first
                if (hit != null) {
                    stepGuard = now
                    lastTappedRow = hit.second
                    Log.i(TAG, "tap row '${hit.second}'")
                    tapNode(hit.first)
                } else if (rows.isNotEmpty() && now - historyAt > LIST_SETTLE_MS) {
                    finish(JSONObject().put("found", false).put("note", "no row for time=${if (wantDayToday) "Today " else "$wantDay "}$wantTime amount=$wantAmount on first page"))
                } else if (rows.isNotEmpty()) {
                    // a settled list fires no more events: re-check once the settle window has passed
                    main.removeCallbacks(recheck); main.postDelayed(recheck, LIST_SETTLE_MS - (now - historyAt) + 200)
                }
            }
            isHome -> {
                if (state == S.OPENING || state == S.HISTORY) {
                    findByText(root, "မှတ်တမ်း")?.let { state = S.OPENING; stepGuard = now; Log.i(TAG, "tap မှတ်တမ်း"); tapNode(it) }
                }
            }
            else -> {
                // unknown KBZ screen (PIN, dialog): try a generic dismiss, otherwise wait for the timeout
                findByPrefix(root, DISMISS_TEXTS)?.let { stepGuard = now; Log.i(TAG, "tap dismiss '${it.text}'"); tapNode(it) }
            }
        }
    }

    // ------------------------------------------------------------------ list + receipt readers

    /** (clickable row node, "text | text | text") for every history row, top first. */
    private fun listRows(root: AccessibilityNodeInfo): List<Pair<AccessibilityNodeInfo, String>> {
        val out = ArrayList<Pair<AccessibilityNodeInfo, String>>()
        val byId = root.findAccessibilityNodeInfosByViewId("$KBZ:id/tv_trans_type") ?: emptyList()
        val anchors: List<AccessibilityNodeInfo> = if (byId.isNotEmpty()) byId
            else root.findAccessibilityNodeInfosByText("ပေးပို့သူ")?.filter { it.text?.toString()?.startsWith("ပေးပို့သူ") == true } ?: emptyList()
        val seen = HashSet<String>()
        for (a in anchors) {
            var p: AccessibilityNodeInfo? = a
            while (p != null && !p.isClickable) p = p.parent
            val row = p ?: a
            val texts = ArrayList<String>(); collect(row, texts)
            val line = texts.joinToString(" | ")
            if (line.isNotEmpty() && seen.add(line)) out.add(row to line)
        }
        return out
    }

    /** null = not this row; else how far (seconds) its time is from the slip's — 0 when no time was given */
    private fun rowDelta(line: String): Int? {
        if (wantTime.isEmpty() && wantAmount.isEmpty()) return null
        if (!line.contains("+")) return null // incoming only
        if (wantAmount.isNotEmpty() && !line.contains(wantAmount)) return null
        if (wantSec < 0) return 0
        val dayOk = (wantDayToday && line.contains("Today")) || (wantDay.isNotEmpty() && line.contains("$wantDay "))
        if (!dayOk) return null
        val m = TIME_RE.find(line) ?: return null
        val sec = secOfDay(m.groupValues[1].let { if (it.length == 7) "0$it" else it })
        if (sec < 0) return null
        val d = kotlin.math.abs(sec - wantSec)
        return if (d <= TIME_TOLERANCE_SEC) d else null
    }

    /** Receipt label -> value. ids first (tv_field_name/tv_field_value), else label-then-next-text order. */
    private fun readFields(root: AccessibilityNodeInfo): JSONObject {
        val o = JSONObject()
        val names = root.findAccessibilityNodeInfosByViewId("$KBZ:id/tv_field_name") ?: emptyList()
        val vals = root.findAccessibilityNodeInfosByViewId("$KBZ:id/tv_field_value") ?: emptyList()
        if (names.isNotEmpty() && names.size == vals.size) {
            for (i in names.indices) {
                val k = names[i].text?.toString()?.trim() ?: continue
                o.put(k, vals[i].text?.toString()?.trim() ?: "")
            }
        } else {
            val texts = ArrayList<String>(); collect(root, texts)
            val labels = listOf("လုပ်ဆောင်သော အချိန်", "လုပ်ဆောင်မှုအမှတ်", "လုပ်ဆောင်မှုအမျိုးအစား", "ပေးပို့သူ", "ငွေပမာဏ", "မှတ်ချက်")
            for (i in texts.indices) if (texts[i] in labels && i + 1 < texts.size) o.put(texts[i], texts[i + 1])
        }
        root.findAccessibilityNodeInfosByViewId("$KBZ:id/tv_amount")?.firstOrNull()?.text?.toString()?.let { o.put("_amount", it.trim()) }
        return o
    }

    // ------------------------------------------------------------------ node helpers

    private fun findByText(root: AccessibilityNodeInfo, text: String): AccessibilityNodeInfo? =
        root.findAccessibilityNodeInfosByText(text)?.firstOrNull { it.text?.toString()?.trim() == text }

    private fun findByPrefix(root: AccessibilityNodeInfo, prefixes: List<String>): AccessibilityNodeInfo? {
        for (p in prefixes) {
            root.findAccessibilityNodeInfosByText(p)?.firstOrNull { it.text?.toString()?.trim()?.startsWith(p) == true }?.let { return it }
        }
        return null
    }

    private fun tapNode(node: AccessibilityNodeInfo) {
        var p: AccessibilityNodeInfo? = node
        while (p != null && !p.isClickable) p = p.parent
        if (p != null && p.performAction(AccessibilityNodeInfo.ACTION_CLICK)) return
        val r = Rect(); node.getBoundsInScreen(r)
        val path = Path().apply { moveTo(r.exactCenterX(), r.exactCenterY()) }
        dispatchGesture(GestureDescription.Builder().addStroke(GestureDescription.StrokeDescription(path, 0, 60)).build(), null, null)
    }

    private fun collect(node: AccessibilityNodeInfo?, out: MutableList<String>) {
        if (node == null) return
        node.text?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { out.add(it) }
        for (i in 0 until node.childCount) collect(node.getChild(i), out)
    }

    // ------------------------------------------------------------------ probe dump (log mode)

    private fun dump(root: AccessibilityNodeInfo, event: AccessibilityEvent) {
        try {
            val texts = ArrayList<String>(); collect(root, texts)
            val joined = texts.joinToString("|")
            if (joined.isEmpty() || joined == lastDump) return
            lastDump = joined
            val json = JSONObject().put("t", System.currentTimeMillis())
                .put("event", AccessibilityEvent.eventTypeToString(event.eventType))
                .put("cls", event.className?.toString() ?: JSONObject.NULL)
                .put("state", state.name).put("texts", JSONArray(texts))
            Log.i(TAG, json.toString())
            File(getExternalFilesDir(null) ?: filesDir, "paya11y.jsonl").appendText(json.toString() + "\n")
        } catch (e: Exception) { Log.e(TAG, "dump failed", e) }
    }
}
