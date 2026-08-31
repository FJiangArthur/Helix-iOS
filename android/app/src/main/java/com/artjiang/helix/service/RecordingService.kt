// Foreground service that keeps audio capture alive while Helix is backgrounded
// and shows the persistent "recording" indicator.
//
// Two jobs, both load-bearing:
//
//  1. CORRECTNESS. On targetSdk 34+ an app may not keep capturing microphone
//     audio from the background without a running foreground service typed
//     `microphone`. Without this service the OS silences capture the moment the
//     user leaves the app or the screen locks — which is precisely when a
//     hands-free glasses assistant is most useful.
//  2. HONESTY. A always-on microphone deserves an always-visible, non-dismissable
//     indicator, on the lock screen as well as the shade, with a one-tap Stop.
//
// PRIVACY: transcript text is never passed to android.util.Log, and the
// lock-screen (public) version of the notification omits it entirely. See
// RecordingContent's doc for the reasoning.
package com.artjiang.helix.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.artjiang.helix.HelixApplication
import com.artjiang.helix.MainActivity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch

class RecordingService : Service() {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val presenter = RecordingNotificationPresenter()
    private var observerJob: Job? = null

    /** SystemClock base for the chronometer; set once per session. */
    private var sessionBaseRealtime = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            // The Stop action ends the session; the isListening observer below
            // then tears the service down, so both stop paths converge.
            bridge()?.stopListening()
            stopSelf()
            return START_NOT_STICKY
        }

        // Post something immediately: startForeground must be called within a
        // few seconds of start or the process is killed with ForegroundServiceDidNotStartInTime.
        if (sessionBaseRealtime == 0L) sessionBaseRealtime = SystemClock.elapsedRealtime()
        presenter.reset()
        startForegroundCompat(build(presenter.contentFor(RecordingPhase.STARTING, "")))
        observeSession()

        // NOT_STICKY on purpose. If the process is killed, audio capture died
        // with it — a service the system silently restarts would post a
        // "recording" notification with nothing behind it. The user restarts a
        // session explicitly instead.
        return START_NOT_STICKY
    }

    private fun observeSession() {
        val bridge = bridge()
        if (bridge == null) {
            stopSelf()
            return
        }
        observerJob?.cancel()
        observerJob = scope.launch {
            combine(
                bridge.isListening,
                bridge.partialTranscript,
                bridge.transcriptText,
            ) { listening, partial, transcript ->
                // Partial text is the freshest thing the user is saying;
                // the settled transcript is the fallback between utterances.
                val text = partial.ifBlank { transcript }
                if (listening) RecordingPhase.ACTIVE to text else RecordingPhase.STOPPED to ""
            }.collect { (phase, text) ->
                if (phase == RecordingPhase.STOPPED) {
                    // Session ended by any route (UI button, glasses triple tap,
                    // recognizer error). Never leave a stale indicator up.
                    stopSelf()
                    return@collect
                }
                val content = presenter.contentFor(phase, text)
                if (presenter.shouldUpdate(content, System.currentTimeMillis())) {
                    notifyIfPermitted(build(content))
                }
            }
        }
    }

    override fun onDestroy() {
        observerJob?.cancel()
        scope.cancel()
        // Remove the notification with the service; a lingering "recording"
        // chip when nothing records is worse than no chip at all.
        stopForegroundAndRemoveNotification()
        super.onDestroy()
    }

    // MARK: - Notification construction

    private fun build(content: RecordingContent): Notification {
        val open = PendingIntent.getActivity(
            this,
            REQUEST_OPEN,
            Intent(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val stop = PendingIntent.getService(
            this,
            REQUEST_STOP,
            Intent(this, RecordingService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        // The lock-screen face: same title and chronometer, no transcript.
        val public = baseBuilder()
            .setContentTitle(RecordingNotificationPresenter.TITLE)
            .setContentText(content.publicText)
            .setContentIntent(open)
            .build()

        return baseBuilder()
            .setContentTitle(content.title)
            .setContentText(content.privateText)
            .setStyle(NotificationCompat.BigTextStyle().bigText(content.privateText))
            .setContentIntent(open)
            .addAction(0, "Stop", stop)
            .setPublicVersion(public)
            .build()
    }

    private fun baseBuilder(): NotificationCompat.Builder =
        NotificationCompat.Builder(this, CHANNEL_ID)
            // Framework icon: this module owns no drawable resources.
            .setSmallIcon(android.R.drawable.presence_audio_online)
            // Non-dismissable while the service runs.
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            // Elapsed session time, ticked by the system rather than by us.
            .setUsesChronometer(true)
            .setWhen(System.currentTimeMillis() - (SystemClock.elapsedRealtime() - sessionBaseRealtime))
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            // Private: the full version (with transcript) is withheld on a
            // locked screen; setPublicVersion supplies the redacted stand-in.
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setLocalOnly(true)

    private fun startForegroundCompat(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    /**
     * Posts an update, tolerating a missing POST_NOTIFICATIONS grant.
     *
     * On Android 13+ the user can deny notifications outright. That must not
     * stop recording: the foreground service still runs (and still keeps mic
     * capture legal) — the indicator simply is not drawn.
     */
    private fun notifyIfPermitted(notification: Notification) {
        try {
            NotificationManagerCompat.from(this).notify(NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
            // No POST_NOTIFICATIONS grant. Recording continues regardless.
        }
    }

    private fun stopForegroundAndRemoveNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        notificationManager()?.cancel(NOTIFICATION_ID)
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            // LOW: visible and persistent, but never buzzes — this notification
            // updates continuously while recording.
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = CHANNEL_DESCRIPTION
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
            lockscreenVisibility = Notification.VISIBILITY_PRIVATE
        }
        notificationManager()?.createNotificationChannel(channel)
    }

    private fun notificationManager(): NotificationManager? =
        getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager

    private fun bridge() = (application as? HelixApplication)?.bridge

    companion object {
        private const val CHANNEL_ID = "helix_recording"
        private const val CHANNEL_NAME = "Recording"
        private const val CHANNEL_DESCRIPTION =
            "Shows while Helix is listening, so recording is never silent or hidden."
        private const val NOTIFICATION_ID = 1001
        private const val REQUEST_OPEN = 0
        private const val REQUEST_STOP = 1

        const val ACTION_STOP = "com.artjiang.helix.action.STOP_RECORDING"

        /** Starts the indicator. Safe to call when already running. */
        fun start(context: Context) {
            val intent = Intent(context, RecordingService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /** Tears the indicator down without touching the session. */
        fun stop(context: Context) {
            context.stopService(Intent(context, RecordingService::class.java))
        }
    }
}
