package com.liuzq2002.adguard_home_manager

import android.app.Activity
import android.app.AlertDialog
import android.content.ComponentName
import android.content.Intent
import android.os.Bundle
import android.service.quicksettings.TileService
import android.util.Log

class RefreshActivity : Activity() {
    companion object {
        const val EXTRA_MODE = "mode"
        const val MODE_REFRESH = "refresh"
        const val MODE_PAUSE = "pause"
        const val EXTRA_PORT = "port"
        private const val TAG = "AdGuardTile"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        when (intent?.getStringExtra(EXTRA_MODE)) {
            MODE_REFRESH -> runRefresh()
            MODE_PAUSE -> showPauseDialog(intent.getIntExtra(EXTRA_PORT, -1))
            else -> finish()
        }
    }

    private fun runRefresh() {
        Thread {
            try {
                val fresh = AdGuardModuleController.resolvePort(this)
                if (fresh != null) {
                    AdGuardModuleController.saveCachedPort(this, fresh)
                    Log.i(TAG, "boot refresh: port=$fresh")
                }
                TileService.requestListeningState(
                    this,
                    ComponentName(this, AdGuardTileService::class.java)
                )
            } catch (t: Throwable) {
                Log.e(TAG, "refresh failed", t)
            } finally {
                runOnUiThread { finish() }
            }
        }.start()
    }

    private fun showPauseDialog(port: Int) {
        if (port <= 0) {
            Thread {
                val resolved = AdGuardModuleController.resolvePort(this)
                runOnUiThread { showPauseDialog(resolved ?: -1) }
            }.start()
            return
        }

        val options = arrayOf("暂停 15 分钟", "暂停 30 分钟", "暂停 1 小时", "直接关闭", "取消")
        val minutes = intArrayOf(15, 30, 60, 0)
        AlertDialog.Builder(this)
            .setTitle("暂停过滤")
            .setItems(options) { _, which ->
                if (which < minutes.size) {
                    pauseProtection(port, minutes[which])
                }
            }
            .setOnDismissListener { if (!isFinishing) finish() }
            .show()
    }

    private fun pauseProtection(port: Int, minutes: Int) {
        Thread {
            try {
                val ok = AdGuardModuleController.setProtection(port, false, minutes * 60000L)
                Log.i(TAG, "pause port=$port minutes=$minutes ok=$ok")
            } catch (t: Throwable) {
                Log.e(TAG, "pause failed", t)
            } finally {
                runOnUiThread { finish() }
            }
        }.start()
    }
}
