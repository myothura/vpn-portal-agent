package com.vpnportal.agent

// PAYMENT_READER_V1 — the three backend calls the reader phone makes (HttpURLConnection, no extra
// dependency): register this device, fetch the next command, report a result. All blocking: call
// from a background thread.

import android.content.Context
import android.os.Build
import android.util.Log
import org.json.JSONObject
import java.io.BufferedReader
import java.net.HttpURLConnection
import java.net.URL

object PaymentApi {
    private const val TAG = "PAYREADER"

    data class Resp(val code: Int, val json: JSONObject?)

    private fun call(c: Context, method: String, path: String, body: JSONObject?): Resp {
        val base = PaymentReaderConfig.baseUrl(c)
        val token = PaymentReaderConfig.token(c)
        if (base.isEmpty() || token.isEmpty()) return Resp(0, null)
        var conn: HttpURLConnection? = null
        return try {
            conn = (URL(base + path).openConnection() as HttpURLConnection).apply {
                requestMethod = method
                connectTimeout = 10_000
                readTimeout = 20_000
                setRequestProperty("Authorization", "Bearer $token")
                setRequestProperty("Accept", "application/json")
                if (body != null) {
                    setRequestProperty("Content-Type", "application/json")
                    doOutput = true
                    outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
                }
            }
            val code = conn.responseCode
            val stream = if (code in 200..299) conn.inputStream else conn.errorStream
            val text = stream?.bufferedReader()?.use(BufferedReader::readText) ?: ""
            val json = try { if (text.isNotBlank()) JSONObject(text) else null } catch (_: Exception) { null }
            if (code !in 200..299) Log.w(TAG, "$method $path -> $code ${text.take(200)}")
            Resp(code, json)
        } catch (e: Exception) {
            Log.w(TAG, "$method $path failed: ${e.message}")
            Resp(0, null)
        } finally {
            conn?.disconnect()
        }
    }

    /** POST /agent/payment-verify/register -> {registered, mode}. 403 = this agent is not the reader. */
    fun register(c: Context): Resp {
        val body = JSONObject().put("fcm_token", PaymentReaderConfig.fcmToken(c))
            .put("device", "${Build.MANUFACTURER} ${Build.MODEL} / Android ${Build.VERSION.RELEASE}")
        return call(c, "POST", "/agent/payment-verify/register", body)
    }

    /** GET /agent/payment-verify/next -> {command: {...}|null, mode} */
    fun next(c: Context): Resp = call(c, "GET", "/agent/payment-verify/next", null)

    /** POST /agent/payment-verify/{id}/result */
    fun result(c: Context, verificationId: String, body: JSONObject): Resp =
        call(c, "POST", "/agent/payment-verify/$verificationId/result", body)
}
