package com.liuzq2002.adguard_home_manager

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        try {
            // 启动透明 Activity：清除 stopped 状态并触发端口刷新 + 磁贴绑定
            context.startActivity(
                Intent(context, ControlActivity::class.java).apply {
                    putExtra(ControlActivity.EXTRA_MODE, ControlActivity.MODE_REFRESH)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            )
        } catch (t: Throwable) {
            Log.e("AdGuardTile", "boot start refresh failed", t)
        }
    }
}
