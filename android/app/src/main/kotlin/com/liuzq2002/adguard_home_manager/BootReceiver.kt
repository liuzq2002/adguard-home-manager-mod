package com.liuzq2002.adguard_home_manager

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.service.quicksettings.TileService
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        try {
            // 请求系统绑定磁贴服务并触发 onStartListening（自动重读随机端口）
            TileService.requestListeningState(
                context,
                ComponentName(context, AdGuardTileService::class.java)
            )
            // 顺带预刷新缓存端口，避免磁贴首帧仍显示旧端口
            val fresh = AdGuardModuleController.readPortFromYaml()
            if (fresh != null) {
                AdGuardModuleController.saveCachedPort(context, fresh)
            }
        } catch (t: Throwable) {
            Log.e("AdGuardTile", "boot refresh failed", t)
        }
    }
}
