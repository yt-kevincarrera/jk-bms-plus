package dev.selector.jk_bms

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/** Foreground lifetime for the shared engine, never a second Dart task/isolate. */
class HandsFreeHostService : Service() {
    companion object {
        private const val CHANNEL_ID = "jk_bms_hands_free"
        private const val NOTIFICATION_ID = 5513
        var instance: HandsFreeHostService? = null
            private set
        var running = false
            private set
    }
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate() {
        super.onCreate()
        HandsFreeRuntime.initialize(this)
        instance = this
        getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "JK BMS · Conexión automática", NotificationManager.IMPORTANCE_LOW)
                .apply { setSound(null, null); enableVibration(false) },
        )
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!HandsFreeRuntime.shouldRunHost()) { stopSelf(); return START_NOT_STICKY }
        try {
            updateNotification()
            HandsFreeRuntime.hostStarted()
        } catch (_: Exception) {
            HandsFreeRuntime.hostFailed()
            stopSelf()
            return START_NOT_STICKY
        }
        return START_STICKY
    }

    fun updateNotification() {
        val type = ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE or
            if (HandsFreeRuntime.locationClaim) ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION else 0
        if (Build.VERSION.SDK_INT >= 29) startForeground(NOTIFICATION_ID, notification(), type)
        else startForeground(NOTIFICATION_ID, notification())
        running = true
        updatePowerLease()
    }

    fun updatePowerLease() {
        val lease = HandsFreeRuntime.powerLeaseMillis()
        if (lease > 0 && running) {
            val lock = wakeLock ?: getSystemService(PowerManager::class.java)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "$packageName:hands-free-location")
                .apply { setReferenceCounted(false) }.also { wakeLock = it }
            // A non-reference-counted acquire refreshes this bounded timeout.
            // Notification updates renew it only while Dart reports real GPS work.
            lock.acquire(lease)
        } else releaseWakeLock()
    }

    private fun notification(): Notification {
        val open = PendingIntent.getActivity(this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val pause = PendingIntent.getBroadcast(this, 0,
            Intent(this, HandsFreePauseReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        return Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(HandsFreeRuntime.notificationTitle())
            .setContentText(HandsFreeRuntime.notificationText())
            .setContentIntent(open)
            .setOngoing(true).setOnlyAlertOnce(true).setShowWhen(false)
            .addAction(Notification.Action.Builder(null, "Pausar conexión automática", pause).build())
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Removing the UI task leaves the companion/trip owner intact.
        super.onTaskRemoved(rootIntent)
    }

    private fun releaseWakeLock() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
    }

    override fun onDestroy() {
        releaseWakeLock()
        running = false
        if (instance === this) instance = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        HandsFreeRuntime.hostStopped()
        super.onDestroy()
    }
}
