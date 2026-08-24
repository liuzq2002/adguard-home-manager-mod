package com.liuzq2002.adguard_home_manager

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.util.Base64
import android.util.Log
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

object AdGuardModuleController {
    private const val YAML_PATH = "/data/adb/agh/bin/AdGuardHome.yaml"
    private const val USER = "root"
    private const val PASSWORD = "root"
    private const val TAG = "AdGuardModule"

    fun readPort(context: Context? = null): Int? {
        val saved = readSavedAddress(context)
        if (saved != null) return saved

        val output = runSu("cat $YAML_PATH") ?: return null
        return parsePort(output)
    }

    fun resolvePort(context: Context?): Int? {
        val cached = readSavedAddress(context)
        if (cached != null) return cached
        val output = runSu("cat $YAML_PATH") ?: return null
        return parsePort(output)
    }

    fun saveCachedPort(context: Context?, port: Int) {
        if (context == null) return
        try {
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .edit()
                .putString("flutter.moduleHttpAddress", "127.0.0.1:$port")
                .apply()
        } catch (t: Throwable) {
            Log.e(TAG, "save port failed", t)
        }
    }

    fun parsePort(output: String): Int? {
        val lines = output.lines()
        var inHttp = false
        for (line in lines) {
            val trimmed = line.trim()
            if (trimmed.startsWith("http:")) {
                inHttp = true
                continue
            }
            if (inHttp) {
                if (trimmed.isNotEmpty() && !line.startsWith(" ")) {
                    inHttp = false
                }
                if (inHttp && trimmed.startsWith("address:")) {
                    val value = trimmed.removePrefix("address:").trim()
                        .removePrefix("\"").removeSuffix("\"")
                        .removePrefix("'").removeSuffix("'")
                    return value.substringAfterLast(":", "").toIntOrNull()
                }
            }
        }
        return null
    }

    private fun readSavedAddress(context: Context?): Int? {
        if (context == null) return null
        return try {
            val prefs: SharedPreferences = context.getSharedPreferences(
                "FlutterSharedPreferences",
                Context.MODE_PRIVATE
            )
            val saved = prefs.getString("flutter.moduleHttpAddress", null) ?: return null
            val normalized = if (saved.contains("://")) saved else "http://$saved"
            val port = Uri.parse(normalized).port
            if (port > 0) port else null
        } catch (t: Throwable) {
            Log.e(TAG, "read saved address failed", t)
            null
        }
    }

    fun getProtectionState(port: Int): Boolean? {
        val body = httpRequest(port, "/control/status", "GET") ?: return null
        return try {
            val json = JSONObject(body)
            when {
                json.has("protection_enabled") -> json.getBoolean("protection_enabled")
                json.has("general_enabled") -> json.getBoolean("general_enabled")
                else -> null
            }
        } catch (t: Throwable) {
            Log.e(TAG, "parse status failed", t)
            null
        }
    }

    fun setProtection(port: Int, enabled: Boolean): Boolean {
        return setProtection(port, enabled, null)
    }

    fun setProtection(port: Int, enabled: Boolean, durationMs: Long?): Boolean {
        val duration = durationMs?.toString() ?: "null"
        val body = """{"enabled":$enabled,"duration":$duration}"""
        return httpRequest(port, "/control/protection", "POST", body) != null
    }

    private fun runSu(command: String): String? {
        val candidates = listOf(
            "su",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/debug_ramdisk/su",
        )
        for (su in candidates) {
            try {
                val process = ProcessBuilder(su, "-c", command)
                    .redirectErrorStream(true)
                    .start()
                val output = process.inputStream.bufferedReader().use { it.readText() }
                val code = process.waitFor()
                if (code == 0) return output
                val detail = output.trim().take(200)
                Log.w(TAG, "su($su) exit=$code${if (detail.isEmpty()) "" else " | $detail"}")
            } catch (t: Throwable) {
                Log.w(TAG, "su($su) unavailable", t)
            }
        }
        return null
    }

    private fun httpRequest(port: Int, path: String, method: String, body: String? = null): String? {
        val connection = URL("http://127.0.0.1:$port$path").openConnection() as HttpURLConnection
        return try {
            connection.requestMethod = method
            connection.connectTimeout = 5000
            connection.readTimeout = 5000
            val credentials = Base64.encodeToString(
                "$USER:$PASSWORD".toByteArray(Charsets.UTF_8),
                Base64.NO_WRAP
            )
            connection.setRequestProperty("Authorization", "Basic $credentials")
            if (body != null) {
                connection.doOutput = true
                connection.setRequestProperty("Content-Type", "application/json")
                connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            }
            val code = connection.responseCode
            if (code < 400) {
                connection.inputStream.bufferedReader().use { it.readText() }
            } else {
                val errorBody = connection.errorStream?.bufferedReader()?.use { it.readText() }?.take(200)
                Log.w(TAG, "http $method $path status=$code${if (errorBody.isNullOrEmpty()) "" else " | $errorBody"}")
                null
            }
        } catch (t: Throwable) {
            Log.e(TAG, "http $method $path failed", t)
            null
        } finally {
            connection.disconnect()
        }
    }
}

class AdGuardTileService : TileService() {
    override fun onClick() {
        super.onClick()
        val tile = qsTile ?: return

        Thread {
            try {
                val port = AdGuardModuleController.readPort(this)
                if (port == null) {
                    updateTile(Tile.STATE_UNAVAILABLE)
                    return@Thread
                }
                val current = AdGuardModuleController.getProtectionState(port)
                if (current == true) {
                    // 保护开启中 → 打开暂停时长选择
                    startActivity(
                        Intent(this, RefreshActivity::class.java).apply {
                            putExtra(RefreshActivity.EXTRA_MODE, RefreshActivity.MODE_PAUSE)
                            putExtra(RefreshActivity.EXTRA_PORT, port)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                    )
                    return@Thread
                }
                val target = current != true
                val ok = AdGuardModuleController.setProtection(port, target)
                if (ok) {
                    Log.i("AdGuardTile", "toggle ok: port=$port target=$target")
                    updateTile(if (target) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE)
                } else {
                    Log.w("AdGuardTile", "toggle failed: port=$port")
                    updateTile(Tile.STATE_UNAVAILABLE)
                }
            } catch (t: Throwable) {
                Log.e("AdGuardTile", "toggle failed", t)
                updateTile(Tile.STATE_UNAVAILABLE)
            }
        }.start()
    }

    override fun onStartListening() {
        super.onStartListening()
        Thread {
            try {
                val port = AdGuardModuleController.readPort(this)
                if (port == null) {
                    Log.w("AdGuardTile", "listening: no port (su/yaml failed)")
                    updateTile(Tile.STATE_UNAVAILABLE)
                    return@Thread
                }
                val enabled = AdGuardModuleController.getProtectionState(port)
                val state = when (enabled) {
                    true -> Tile.STATE_ACTIVE
                    false -> Tile.STATE_INACTIVE
                    null -> Tile.STATE_UNAVAILABLE
                }
                Log.i("AdGuardTile", "listening: port=$port enabled=$enabled state=$state")
                updateTile(state)
            } catch (t: Throwable) {
                Log.e("AdGuardTile", "refresh failed", t)
                updateTile(Tile.STATE_UNAVAILABLE)
            }
        }.start()
    }

    private fun updateTile(state: Int) {
        Handler(Looper.getMainLooper()).post {
            try {
                val tile = qsTile ?: return@post
                tile.state = state
                tile.label = getString(R.string.tile_label)
                tile.icon = Icon.createWithResource(this, R.drawable.ic_tile_adguard)
                tile.updateTile()
            } catch (t: Throwable) {
                Log.e("AdGuardTile", "update tile failed", t)
            }
        }
    }
}
