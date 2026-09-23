package com.agrimore.delivery

/**
 * Phase DLV-3A2 — when RiderLocationService sends a location, and what it
 * sends. The Kotlin twin of lib/location/location_policy.dart:
 * test/location_policy_test.dart reads the constants below from this file and
 * fails if they drift from the Dart profiles, from firestore.rules' live-point
 * bounds, or from functions/src/delivery/dispatch.ts's active statuses.
 */
object RiderLocationPolicy {
    // The fused-location request (the Dart samplingProfile).
    const val SAMPLE_INTERVAL_MS = 5_000L
    const val SAMPLE_MIN_DISTANCE_M = 25f

    // On an order (the Dart taskProfile).
    const val ORDER_MIN_UPLOAD_GAP_MS = 10_000L
    const val ORDER_HEARTBEAT_MS = 30_000L

    // Online, no order (the Dart idleProfile).
    const val IDLE_MIN_UPLOAD_GAP_MS = 30_000L
    const val IDLE_HEARTBEAT_MS = 60_000L

    /** How often the service checks whether a heartbeat is due. */
    const val TICK_MS = 5_000L

    /** Order statuses in which the rider is on a job — dispatch.ts RIDER_ACTIVE_ORDER_STATUSES. */
    val ACTIVE_ORDER_STATUSES = listOf(
        "delivery_accepted",
        "arrived_at_store",
        "reached_pickup",
        "picked_up",
        "parcel_picked",
        "out_for_delivery",
        "outfordelivery",
        "outForDelivery",
    )

    fun shouldUpload(nowMs: Long, lastUploadMs: Long?, hasNewFix: Boolean, onOrder: Boolean): Boolean {
        if (lastUploadMs == null) return true
        val since = nowMs - lastUploadMs
        val gap = if (onOrder) ORDER_MIN_UPLOAD_GAP_MS else IDLE_MIN_UPLOAD_GAP_MS
        val heartbeat = if (onOrder) ORDER_HEARTBEAT_MS else IDLE_HEARTBEAT_MS
        if (hasNewFix && since >= gap) return true
        return since >= heartbeat
    }

    private fun inRange(v: Double?, lo: Double, hi: Double): Double? =
        if (v == null || v.isNaN() || v < lo || v > hi) null else v

    fun isValidFix(lat: Double, lng: Double): Boolean =
        !lat.isNaN() && !lng.isNaN() && lat in -90.0..90.0 && lng in -180.0..180.0

    /**
     * delivery_tasks/{orderId}/live/rider without `at` (the caller adds a
     * server timestamp). Keys and bounds are exactly firestore.rules'
     * livePointIsValid(); out-of-range readings become null.
     */
    fun livePointFields(
        riderId: String, lat: Double, lng: Double,
        accuracy: Double?, speed: Double?, heading: Double?, isMocked: Boolean,
    ): Map<String, Any?> = mapOf(
        "riderId" to riderId,
        "lat" to lat,
        "lng" to lng,
        "accuracy" to inRange(accuracy, 0.0, 100000.0),
        "speed" to inRange(speed, 0.0, 100.0),
        "heading" to inRange(heading, 0.0, 360.0),
        "isMocked" to isMocked,
    )
}
