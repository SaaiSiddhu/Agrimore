package com.agrimore.delivery

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.net.Uri
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Phase DLV-2B — lets a delivery offer ring and show over the lock screen.
 *
 * The offer alert (lib/offers/offer_alerts.dart) is a full-screen-intent
 * notification whose payload starts with "delivery_offer:". When Android
 * launches this activity from it, the activity is allowed to appear over the
 * lock screen and turn the screen on — for THAT launch only. A blanket
 * android:showWhenLocked would leave the whole app (customer names, phones,
 * addresses) readable on a locked phone, so the Dart side clears it again
 * when the offer screen closes (channel below).
 *
 * Phase DLV-3A adds moveToBackground (see the channel); DLV-3A2 adds the
 * com.agrimore.delivery/rider channel for RiderLocationService.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.agrimore.delivery/offers"
    private val riderChannelName = "com.agrimore.delivery/rider"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (isOfferLaunch(intent)) setShowOverLockScreen(true)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (isOfferLaunch(intent)) setShowOverLockScreen(true)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "showOverLockScreen" -> {
                        setShowOverLockScreen(call.argument<Boolean>("show") == true)
                        result.success(null)
                    }
                    "canUseFullScreenIntent" -> result.success(canUseFullScreenIntent())
                    // Phase DLV-3A: Back on the home screen while online sends
                    // the app to the background instead of finishing this
                    // activity — finishing destroys the Flutter engine, and
                    // with it the location stream (geolocator stops when its
                    // engine detaches), silently ending tracking.
                    "moveToBackground" -> result.success(moveTaskToBack(true))
                    else -> result.notImplemented()
                }
            }
        // Phase DLV-3A2: the native location service and what it needs.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, riderChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        try {
                            RiderLocationService.start(this)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "stop" -> {
                        RiderLocationService.stop(this)
                        result.success(null)
                    }
                    "isRunning" -> result.success(RiderLocationService.isRunning)
                    "hasBackgroundLocation" -> result.success(RiderLocationService.hasBackgroundLocation(this))
                    // Android 11+ drops a request that bundles background with
                    // foreground location (geolocator does), silently: ask
                    // for ACCESS_BACKGROUND_LOCATION alone. Android then shows
                    // its own screen with "Allow all the time".
                    "requestBackgroundLocation" -> requestBackgroundLocation(result)
                    "isIgnoringBatteryOptimizations" -> result.success(isIgnoringBatteryOptimizations())
                    "openBatterySettings" -> result.success(openBatterySettings())
                    else -> result.notImplemented()
                }
            }
    }

    private var pendingBackgroundResult: MethodChannel.Result? = null
    private val backgroundRequestCode = 4211

    private fun requestBackgroundLocation(result: MethodChannel.Result) {
        if (RiderLocationService.hasBackgroundLocation(this) || Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.success(RiderLocationService.hasBackgroundLocation(this))
            return
        }
        if (!RiderLocationService.hasForegroundLocation(this) || pendingBackgroundResult != null) {
            result.success(false)
            return
        }
        pendingBackgroundResult = result
        requestPermissions(arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION), backgroundRequestCode)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == backgroundRequestCode) {
            pendingBackgroundResult?.success(RiderLocationService.hasBackgroundLocation(this))
            pendingBackgroundResult = null
        }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    /**
     * D-DLV-BATTERY: opens the app's own settings page (Battery / Autostart
     * live there on most phones) — no REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
     * permission, which Play restricts.
     */
    private fun openBatterySettings(): Boolean = try {
        startActivity(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
        true
    } catch (e: Exception) {
        false
    }

    // flutter_local_notifications launches with action SELECT_NOTIFICATION and
    // the payload in the "payload" extra.
    private fun isOfferLaunch(intent: Intent?): Boolean =
        intent?.action == "SELECT_NOTIFICATION" &&
            (intent.getStringExtra("payload") ?: "").startsWith("delivery_offer:")

    private fun setShowOverLockScreen(show: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(show)
            setTurnScreenOn(show)
        } else {
            @Suppress("DEPRECATION")
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (show) window.addFlags(flags) else window.clearFlags(flags)
        }
    }

    private fun canUseFullScreenIntent(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return true
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return nm.canUseFullScreenIntent()
    }
}
