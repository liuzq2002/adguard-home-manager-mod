package com.liuzq2002.adguard_home_manager

import android.app.LocaleManager
import android.content.ComponentName
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.LocaleList
import android.service.quicksettings.TileService
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity: FlutterActivity() {
    private val channelName = "com.jgeek00.adguard_home_manager/locale"
    private val localNetworkChannelName = "com.jgeek00.adguard_home_manager/local_network"
    private val installedAppsChannelName = "com.jgeek00.adguard_home_manager/installed_apps"

    // String literal on purpose: the constant only exists in API 37 SDK and
    // the project compiles with 36.
    private val localNetworkPermission = "android.permission.ACCESS_LOCAL_NETWORK"
    private val localNetworkRequestCode = 0x4C4E
    private var localNetworkResult: MethodChannel.Result? = null

    @Volatile
    private var cachedInstalledApps: List<Map<String, Any?>>? = null
    @Volatile
    private var cachedInstalledAppsIncludeSystem: Boolean = false
    @Volatile
    private var cachedInstalledAppsTimestamp: Long = 0L

    override fun onStart() {
        super.onStart()
        TileService.requestListeningState(
            this,
            ComponentName(this, AdGuardTileService::class.java)
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getApplicationLocale" -> result.success(getApplicationLocale())
                "setApplicationLocale" -> {
                    setApplicationLocale(call.argument<String>("tag"))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            localNetworkChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isGranted" -> result.success(isLocalNetworkGranted())
                "request" -> requestLocalNetworkPermission(result)
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            installedAppsChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledApps" -> {
                    val includeSystem = call.argument<Boolean>("includeSystem") ?: false
                    val forceRefresh = call.argument<Boolean>("forceRefresh") ?: false
                    val now = System.currentTimeMillis()
                    val cached = cachedInstalledApps
                    if (!forceRefresh &&
                        cached != null &&
                        cachedInstalledAppsIncludeSystem == includeSystem &&
                        now - cachedInstalledAppsTimestamp < 60_000L
                    ) {
                        result.success(cached)
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            val apps = queryInstalledApps(includeSystem)
                            cachedInstalledApps = apps
                            cachedInstalledAppsIncludeSystem = includeSystem
                            cachedInstalledAppsTimestamp = System.currentTimeMillis()
                            runOnUiThread { result.success(apps) }
                        } catch (t: Throwable) {
                            runOnUiThread {
                                result.error("QUERY_APPS_FAILED", t.message, null)
                            }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun queryInstalledApps(includeSystem: Boolean): List<Map<String, Any?>> {
        val pm = packageManager
        val installed = pm.getInstalledApplications(0)
        val selfPkg = applicationContext.packageName
        val list = ArrayList<Map<String, Any?>>(installed.size)
        for (app in installed) {
            val pkg = app.packageName ?: continue
            if (pkg == selfPkg) continue
            val isSystem = (app.flags and ApplicationInfo.FLAG_SYSTEM) != 0 &&
                (app.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) == 0
            if (isSystem && !includeSystem) continue

            val label = try {
                pm.getApplicationLabel(app)?.toString()?.trim().takeUnless { it.isNullOrEmpty() } ?: pkg
            } catch (_: Throwable) {
                pkg
            }
            val iconBytes = try {
                drawableToPngBytes(pm.getApplicationIcon(app), 72)
            } catch (_: Throwable) {
                null
            }
            list.add(
                mapOf(
                    "package" to pkg,
                    "name" to label,
                    "uid" to app.uid,
                    "isSystem" to isSystem,
                    "icon" to iconBytes
                )
            )
        }
        return list
    }

    private fun drawableToPngBytes(drawable: Drawable, sizePx: Int): ByteArray? {
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, sizePx, sizePx)
        drawable.draw(canvas)
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 90, stream)
        bitmap.recycle()
        return stream.toByteArray()
    }

    /** Local Network Protection is only enforced on Android 16+, and the
        ACCESS_LOCAL_NETWORK runtime permission only exists on Android 17+ for
        apps targeting SDK 37. Below that, INTERNET implicitly covers the LAN. */
    private fun isLocalNetworkGranted(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.BAKLAVA) return true
        return ContextCompat.checkSelfPermission(this, localNetworkPermission) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun requestLocalNetworkPermission(result: MethodChannel.Result) {
        if (isLocalNetworkGranted()) {
            result.success(true)
            return
        }
        localNetworkResult?.success(false)
        localNetworkResult = result
        ActivityCompat.requestPermissions(
            this, arrayOf(localNetworkPermission), localNetworkRequestCode
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == localNetworkRequestCode) {
            localNetworkResult?.success(
                grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
            )
            localNetworkResult = null
        }
    }

    private fun getApplicationLocale(): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return null

        val localeManager = getSystemService(LocaleManager::class.java) ?: return null
        val locales = localeManager.applicationLocales
        if (locales.isEmpty) return null
        return locales.get(0)?.toLanguageTag()
    }

    private fun setApplicationLocale(tag: String?) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return

        val localeManager = getSystemService(LocaleManager::class.java) ?: return
        localeManager.applicationLocales = if (tag.isNullOrEmpty()) {
            LocaleList.getEmptyLocaleList()
        } else {
            LocaleList.forLanguageTags(tag)
        }
    }
}
