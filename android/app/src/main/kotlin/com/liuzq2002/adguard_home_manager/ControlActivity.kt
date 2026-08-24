package com.liuzq2002.adguard_home_manager

import android.app.Activity
import android.app.AlertDialog
import android.content.ComponentName
import android.os.Bundle
import android.service.quicksettings.TileService
import android.util.Log

class ControlActivity : Activity() {
    companion object {
        const val EXTRA_MODE = "mode"
        const val MODE_REFRESH = "refresh"
        private const val TAG = "AdGuardTile"
    }

    private var finished = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (intent?.getStringExtra(EXTRA_MODE) == MODE_REFRESH) {
            runBootRefresh()
        } else {
            prepareControl()
        }
    }

    private fun runBootRefresh() {
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
                runOnUiThread { finishOnce() }
            }
        }.start()
    }

    private fun prepareControl() {
        Thread {
            try {
                // 先读缓存，失效则 su 重读 YAML（App 进程有 root）
                val fresh = AdGuardModuleController.resolvePort(this)
                if (fresh != null) {
                    AdGuardModuleController.saveCachedPort(this, fresh)
                }
                val enabled = fresh?.let { AdGuardModuleController.getProtectionState(it) }
                runOnUiThread { showControlDialog(fresh, enabled) }
            } catch (t: Throwable) {
                Log.e(TAG, "prepare control failed", t)
                runOnUiThread { showControlDialog(null, null) }
            }
        }.start()
    }

    private fun showControlDialog(port: Int?, enabled: Boolean?) {
        val title = when (enabled) {
            true -> "保护已开启"
            false -> "保护已暂停"
            null -> "初始化失败"
        }
        if (port == null) {
            AlertDialog.Builder(this)
                .setTitle(title)
                .setMessage("无法读取 AdGuardHome 配置，请打开管理器")
                .setPositiveButton("确定") { _, _ -> finishOnce() }
                .setOnDismissListener { finishOnce() }
                .show()
            return
        }

        val options = arrayOf(
            "启用保护",
            "暂停 30 秒",
            "暂停 1 分钟",
            "暂停 10 分钟",
            "暂停 1 小时",
            "暂停 24 小时",
            "取消"
        )
        val durations = longArrayOf(29000L, 59000L, 599000L, 3599000L, 86399000L)
        AlertDialog.Builder(this)
            .setTitle(title)
            .setItems(options) { _, which ->
                when {
                    which == 0 -> setProtection(port, true, null)
                    which <= durations.size -> setProtection(port, false, durations[which - 1])
                    else -> finishOnce()
                }
            }
            .setOnDismissListener { finishOnce() }
            .show()
    }

    private fun setProtection(port: Int, enabled: Boolean, durationMs: Long?) {
        Thread {
            try {
                val ok = AdGuardModuleController.setProtection(port, enabled, durationMs)
                Log.i(TAG, "control port=$port enabled=$enabled duration=$durationMs ok=$ok")
            } catch (t: Throwable) {
                Log.e(TAG, "control failed", t)
            } finally {
                runOnUiThread { finishOnce() }
            }
        }.start()
    }

    private fun finishOnce() {
        if (!finished) {
            finished = true
            finish()
        }
    }
}
