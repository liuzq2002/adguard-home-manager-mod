package com.liuzq2002.adguard_home_manager

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.service.quicksettings.TileService
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                val appContext = context.applicationContext
                requestTileBind(appContext)

                // Some ROMs restore the QS configuration before SystemUI is ready.
                Handler(Looper.getMainLooper()).postDelayed(
                    { requestTileBind(appContext) },
                    3000
                )
            }
        }
    }

    private fun requestTileBind(context: Context) {
        try {
            TileService.requestListeningState(
                context,
                ComponentName(context, AdGuardTileService::class.java)
            )
            Log.i("AdGuardTile", "requested tile bind")
        } catch (t: Throwable) {
            Log.e("AdGuardTile", "request tile bind failed", t)
        }
    }
}
