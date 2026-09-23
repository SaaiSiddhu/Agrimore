package com.agrimore.delivery

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.location.Location
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration

/**
 * Phase DLV-3A2 — the rider's location while online, independent of the
 * Flutter screen (OWNER_DECISIONS D-DLV-NATIVE-LOC, D-DLV-BGLOC-ALWAYS).
 *
 * DLV-3A ran location inside geolocator's foreground service, which stops
 * when its Flutter engine detaches: a swipe from Recents or an OS kill ended
 * tracking while the rider stayed online. This service owns the "You're
 * online" notification instead and needs no Flutter engine at all:
 *  - fused location (RiderLocationPolicy cadence, the same as the Dart
 *    location_policy.dart the rules suite and tests pin);
 *  - writes delivery_partners/{uid} (currentLat/currentLng/lastLocationUpdate,
 *    the DLV-0 owner allowlist) and, on an order,
 *    delivery_tasks/{orderId}/live/rider (phaseDLV3A_live_rules_test) as the
 *    signed-in rider — the same default FirebaseApp FlutterFire uses;
 *  - finds the active order itself and watches delivery_partners/{uid}:
 *    isOnline false (the server's silent-rider sweep, an admin suspension) or
 *    sign-out stops it;
 *  - stopWithTask=false keeps it through a swipe from Recents; START_STICKY
 *    brings it back after the process is killed, which Android allows for a
 *    location foreground service only with background location ("Allow all
 *    the time") — without it the restart clears itself and the server's
 *    15-min sweep takes the rider offline.
 */
class RiderLocationService : Service() {

    companion object {
        private const val TAG = "RiderLocation"
        const val ACTION_START = "com.agrimore.delivery.RIDER_LOCATION_START"
        const val ACTION_STOP = "com.agrimore.delivery.RIDER_LOCATION_STOP"
        private const val CHANNEL_ID = "rider_online"
        private const val NOTIFICATION_ID = 42010
        private const val PREFS = "rider_location"
        private const val KEY_ONLINE = "online"
        private const val KEY_UID = "uid"

        @Volatile
        var isRunning: Boolean = false
            private set

        fun start(context: Context) {
            val intent = Intent(context, RiderLocationService::class.java).setAction(ACTION_START)
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            // Clear the restart flag first: a stop must stick even if the
            // service is not running in this process.
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putBoolean(KEY_ONLINE, false).apply()
            if (isRunning) {
                context.startService(Intent(context, RiderLocationService::class.java).setAction(ACTION_STOP))
            }
        }

        fun hasForegroundLocation(context: Context): Boolean =
            granted(context, Manifest.permission.ACCESS_FINE_LOCATION) ||
                granted(context, Manifest.permission.ACCESS_COARSE_LOCATION)

        fun hasBackgroundLocation(context: Context): Boolean =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
                granted(context, Manifest.permission.ACCESS_BACKGROUND_LOCATION)

        private fun granted(context: Context, p: String) =
            ContextCompat.checkSelfPermission(context, p) == PackageManager.PERMISSION_GRANTED
    }

    private val main = Handler(Looper.getMainLooper())
    private var fused: FusedLocationProviderClient? = null
    private var partnerListener: ListenerRegistration? = null
    private var ordersListener: ListenerRegistration? = null
    private var authListener: FirebaseAuth.AuthStateListener? = null
    private var uid: String? = null
    private var activeOrderId: String? = null
    private var lastFix: Location? = null
    private var hasUnsentFix = false
    private var lastUploadMs: Long? = null
    private var uploading = false
    private var started = false

    private val tick = object : Runnable {
        override fun run() {
            maybeUpload(force = false)
            main.postDelayed(this, RiderLocationPolicy.TICK_MS)
        }
    }

    private val callback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            val loc = result.lastLocation ?: return
            lastFix = loc
            hasUnsentFix = true
            maybeUpload(force = false)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            shutdown(clearFlag = true)
            return START_NOT_STICKY
        }
        // Every start must reach startForeground() quickly, even one we are
        // about to refuse, or Android raises an ANR for the promise.
        if (!enterForeground()) {
            shutdown(clearFlag = false)
            return START_NOT_STICKY
        }
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val user = FirebaseAuth.getInstance().currentUser
        val restart = intent == null
        val refuse = when {
            user == null -> "not signed in"
            !hasForegroundLocation(this) -> "no location permission"
            restart && !prefs.getBoolean(KEY_ONLINE, false) -> "restart while offline"
            restart && prefs.getString(KEY_UID, null) != user.uid -> "restart for another user"
            restart && !hasBackgroundLocation(this) -> "restart without background location"
            else -> null
        }
        if (refuse != null) {
            Log.i(TAG, "Not tracking: $refuse")
            shutdown(clearFlag = restart)
            return START_NOT_STICKY
        }
        prefs.edit().putBoolean(KEY_ONLINE, true).putString(KEY_UID, user!!.uid).apply()
        if (!started) begin(user.uid, restart)
        return START_STICKY
    }

    private fun enterForeground(): Boolean {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Online status", NotificationManager.IMPORTANCE_LOW).apply {
                    description = "Shows while you are online and sharing your location"
                    setShowBadge(false)
                }
            )
        }
        val open = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(this, 0, it, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        }
        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_delivery_offer)
            .setContentTitle("You're online")
            .setContentText("Sharing your location for nearby orders and live tracking. Go offline in the app to stop.")
            .setStyle(NotificationCompat.BigTextStyle())
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setContentIntent(open)
            .build()
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            true
        } catch (e: Exception) {
            // ForegroundServiceStartNotAllowedException / SecurityException:
            // a background start without background location.
            Log.w(TAG, "Foreground start refused: ${e.javaClass.simpleName}: ${e.message}")
            false
        }
    }

    private fun begin(riderId: String, restart: Boolean) {
        started = true
        isRunning = true
        uid = riderId
        Log.i(TAG, "Tracking started (restart=$restart)")
        val db = FirebaseFirestore.getInstance()

        partnerListener = db.collection("delivery_partners").document(riderId)
            .addSnapshotListener { snap, err ->
                if (err != null) {
                    Log.w(TAG, "Partner listener: ${err.message}")
                    return@addSnapshotListener
                }
                // A cached snapshot may predate the app's own isOnline write:
                // act only on what the server says.
                if (snap == null || snap.metadata.isFromCache) return@addSnapshotListener
                if (snap.getBoolean("isOnline") != true) {
                    Log.i(TAG, "Server has the rider offline; stopping")
                    shutdown(clearFlag = true)
                }
            }

        // The same single-field query the rider app's watchActiveOrder runs
        // (allowed by the orders rules for the assigned rider, no composite
        // index); the active statuses are filtered here.
        ordersListener = db.collection("orders")
            .whereEqualTo("deliveryPartnerId", riderId)
            .addSnapshotListener { snap, err ->
                if (err != null) {
                    Log.w(TAG, "Orders listener: ${err.message}")
                    return@addSnapshotListener
                }
                val next = snap?.documents
                    ?.filter { it.getString("orderStatus") in RiderLocationPolicy.ACTIVE_ORDER_STATUSES }
                    ?.map { it.id }?.sorted()?.firstOrNull()
                if (next != activeOrderId) {
                    activeOrderId = next
                    Log.i(TAG, "Active order: ${next ?: "none"}")
                    maybeUpload(force = true)
                }
            }

        authListener = FirebaseAuth.AuthStateListener { auth ->
            if (auth.currentUser?.uid != riderId) {
                Log.i(TAG, "Signed out; stopping")
                shutdown(clearFlag = true)
            }
        }.also { FirebaseAuth.getInstance().addAuthStateListener(it) }

        val client = LocationServices.getFusedLocationProviderClient(this)
        fused = client
        val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, RiderLocationPolicy.SAMPLE_INTERVAL_MS)
            .setMinUpdateDistanceMeters(RiderLocationPolicy.SAMPLE_MIN_DISTANCE_M)
            .setWaitForAccurateLocation(false)
            .build()
        try {
            client.requestLocationUpdates(request, callback, Looper.getMainLooper())
            client.lastLocation.addOnSuccessListener { loc ->
                if (loc != null && lastFix == null) {
                    lastFix = loc
                    hasUnsentFix = true
                    maybeUpload(force = true)
                }
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "Location permission lost: ${e.message}")
            shutdown(clearFlag = true)
            return
        }
        main.postDelayed(tick, RiderLocationPolicy.TICK_MS)
    }

    private fun maybeUpload(force: Boolean) {
        val loc = lastFix ?: return
        val riderId = uid ?: return
        if (uploading) return
        val now = System.currentTimeMillis()
        val onOrder = activeOrderId != null
        if (!force && !RiderLocationPolicy.shouldUpload(now, lastUploadMs, hasUnsentFix, onOrder)) return
        if (!RiderLocationPolicy.isValidFix(loc.latitude, loc.longitude)) return
        uploading = true
        val db = FirebaseFirestore.getInstance()
        db.collection("delivery_partners").document(riderId).update(
            mapOf(
                "currentLat" to loc.latitude,
                "currentLng" to loc.longitude,
                "lastLocationUpdate" to FieldValue.serverTimestamp(),
            )
        ).addOnCompleteListener { t ->
            uploading = false
            if (!t.isSuccessful) Log.w(TAG, "Location write failed: ${t.exception?.message}")
        }
        // Offline, Firestore queues the write; the gap and heartbeat count
        // from the attempt.
        lastUploadMs = now
        hasUnsentFix = false
        val orderId = activeOrderId ?: return
        val mocked = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) loc.isMock else {
            @Suppress("DEPRECATION") loc.isFromMockProvider
        }
        val live = RiderLocationPolicy.livePointFields(
            riderId = riderId,
            lat = loc.latitude,
            lng = loc.longitude,
            accuracy = if (loc.hasAccuracy()) loc.accuracy.toDouble() else null,
            speed = if (loc.hasSpeed()) loc.speed.toDouble() else null,
            heading = if (loc.hasBearing()) loc.bearing.toDouble() else null,
            isMocked = mocked,
        ) + ("at" to FieldValue.serverTimestamp())
        db.collection("delivery_tasks").document(orderId).collection("live").document("rider")
            .set(live)
            .addOnFailureListener { e ->
                // The task projection trails the order after accept, and the
                // rules refuse once the leg ends.
                Log.w(TAG, "Live point for $orderId not written: ${e.message}")
            }
    }

    private fun shutdown(clearFlag: Boolean) {
        if (clearFlag) {
            getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_ONLINE, false).apply()
        }
        main.removeCallbacks(tick)
        fused?.removeLocationUpdates(callback)
        fused = null
        partnerListener?.remove()
        partnerListener = null
        ordersListener?.remove()
        ordersListener = null
        authListener?.let { FirebaseAuth.getInstance().removeAuthStateListener(it) }
        authListener = null
        started = false
        isRunning = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION") stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        if (started) shutdown(clearFlag = false)
        super.onDestroy()
    }
}
