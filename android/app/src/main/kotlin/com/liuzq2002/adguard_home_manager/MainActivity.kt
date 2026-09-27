package com.liuzq2002.adguard_home_manager

import android.content.ComponentName
import android.service.quicksettings.TileService
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onStart() {
        super.onStart()
        TileService.requestListeningState(
            this,
            ComponentName(this, AdGuardTileService::class.java)
        )
    }
}
