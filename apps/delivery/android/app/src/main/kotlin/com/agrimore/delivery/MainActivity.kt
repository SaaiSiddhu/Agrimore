package com.agrimore.delivery

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
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
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.agrimore.delivery/offers"

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
                    else -> result.notImplemented()
                }
            }
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
