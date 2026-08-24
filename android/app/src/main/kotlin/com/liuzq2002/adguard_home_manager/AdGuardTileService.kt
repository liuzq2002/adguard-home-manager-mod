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
    private const val USER = "root"
    private const val PASSWORD = "root"
    private const val TAG = "AdGuardModule"

    fun readCachedPort(context: Context?): Int? {
        if (context == null) return null
        return try {
            val prefs: SharedPreferences = context.getSharedPreferences(
                "FlutterSharedPreferences",
                Context.MODE_PRIVATE
            )
            val saved = prefs.getString("moduleHttpAddress", null) ?: return null
            val normalized = if (saved.contains("://")) saved else "http://$saved"
            val port = Uri.parse(normalized).port
            if (port > 0) port else null
        } catch (t: Throwable) {
            Log.e(TAG, "read saved address failed", t)
            null
        }
    }

    fun saveCachedPort(context: Context?, port: Int) {
        if (context == null) return
        try {
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .edit()
                .putString("moduleHttpAddress", "127.0.0.1:$port")
                .apply()
        } catch (t: Throwable) {
            Log.e(TAG, "save port failed", t)
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
        val body = """{"enabled":$enabled,"duration":null}"""
        return httpRequest(port, "/control/protection", "POST", body) != null
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
                if (toggleProtection()) return@Thread
                Log.w("AdGuardTile", "toggle failed, opening app to re-fetch port")
                openApp()
            } catch (t: Throwable) {
                Log.e("AdGuardTile", "toggle failed", t)
                openApp()
            }
        }.start()
    }

    override fun onStartListening() {
        super.onStartListening()
        Thread {
            try {
                val port = AdGuardModuleController.readCachedPort(this)
                val enabled = port?.let { AdGuardModuleController.getProtectionState(it) }
                if (enabled != null && port != null) {
                    AdGuardModuleController.saveCachedPort(this, port)
                }
                val state = when (enabled) {
                    true -> Tile.STATE_ACTIVE
                    else -> Tile.STATE_INACTIVE
                }
                Log.i("AdGuardTile", "listening: port=$port enabled=$enabled state=$state")
                updateTile(state, if (enabled == null) R.string.tile_label_open else R.string.tile_label)
            } catch (t: Throwable) {
                Log.e("AdGuardTile", "refresh failed", t)
                updateTile(Tile.STATE_INACTIVE, R.string.tile_label_open)
            }
        }.start()
    }

    private fun toggleProtection(): Boolean {
        val port = AdGuardModuleController.readCachedPort(this) ?: return false
        val current = AdGuardModuleController.getProtectionState(port) ?: return false
        val target = current != true
        val ok = AdGuardModuleController.setProtection(port, target)
        if (ok) {
            Log.i("AdGuardTile", "toggle ok: port=$port target=$target")
            AdGuardModuleController.saveCachedPort(this, port)
            updateTile(if (target) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE)
        }
        return ok
    }

    private fun updateTile(state: Int, labelRes: Int = R.string.tile_label) {
        Handler(Looper.getMainLooper()).post {
            try {
                val tile = qsTile ?: return@post
                tile.state = state
                tile.label = getString(labelRes)
                tile.icon = Icon.createWithResource(this, R.drawable.ic_tile_adguard)
                tile.updateTile()
            } catch (t: Throwable) {
                Log.e("AdGuardTile", "update tile failed", t)
            }
        }
    }

    private fun openApp() {
        Handler(Looper.getMainLooper()).post {
            val intent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            try {
                startActivityAndCollapse(intent)
            } catch (t: Throwable) {
                Log.e("AdGuardTile", "startActivityAndCollapse failed, fallback to startActivity", t)
                try {
                    startActivity(intent)
                } catch (t2: Throwable) {
                    Log.e("AdGuardTile", "open app failed", t2)
                }
            }
        }
    }
}
