package com.liuzq2002.adguard_home_manager

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        try {
            // 开机直接拉起主界面：ROM 视为“App 已使用”，磁贴服务才能绑定；
            // 主界面启动时会自动读取 YAML 并缓存最新端口
            context.startActivity(
                Intent(context, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
            )
            Log.i("AdGuardTile", "boot auto-start launched")
        } catch (t: Throwable) {
            Log.e("AdGuardTile", "boot auto-start failed", t)
        }
    }
}
