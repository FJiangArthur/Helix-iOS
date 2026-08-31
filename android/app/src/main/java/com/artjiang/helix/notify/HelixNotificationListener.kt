// (B) Optional mirroring of OTHER apps' notifications to the glasses.
//
// Android only binds this service after the user grants notification access in
// system settings (Settings > Notifications > Device & app notifications), so
// nothing here runs until they do. The decision logic lives in the pure
// [NotificationMirrorFilter]; this class is only the adapter that turns a
// StatusBarNotification into an [IncomingNotification].
//
// PRIVACY: notification titles and bodies are never logged — not at debug
// level, not in a crash breadcrumb. The only thing that leaves this class is
// the forwarded call into the bridge.
package com.artjiang.helix.notify

import android.app.Notification
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import com.artjiang.helix.HelixApplication

class HelixNotificationListener : NotificationListenerService() {

    private val filter = NotificationMirrorFilter()

    private val bridge get() = (applicationContext as? HelixApplication)?.bridge

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val helix = bridge ?: return
        // Never mirror our own notifications back to the glasses: Helix already
        // pushes its own events through forwardNotificationToGlasses, and this
        // would double-post every one of them.
        if (sbn.packageName == packageName) return

        val extras = sbn.notification.extras
        val incoming = IncomingNotification(
            packageName = sbn.packageName,
            title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty().trim(),
            text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString().orEmpty().trim(),
            isOngoing = sbn.isOngoing,
            isGroupSummary =
                sbn.notification.flags and Notification.FLAG_GROUP_SUMMARY != 0,
            postedAtMillis = sbn.postTime,
        )

        val enabled = helix.notificationMirrorEnabled.value
        if (!enabled) {
            // Turning mirroring off clears the dedupe memory so re-enabling it
            // does not silently swallow the next notification.
            filter.reset()
            return
        }
        if (!filter.shouldForward(incoming, enabled = true, whitelist = helix.notificationWhitelist.value)) {
            return
        }

        helix.forwardMirroredNotification(
            packageName = incoming.packageName,
            appLabel = appLabelFor(incoming.packageName),
            title = incoming.title,
            message = incoming.text,
        )
    }

    override fun onListenerDisconnected() {
        filter.reset()
        super.onListenerDisconnected()
    }

    /** Human label for the posting app; falls back to the package id. */
    private fun appLabelFor(pkg: String): String = runCatching {
        val info = packageManager.getApplicationInfo(pkg, 0)
        packageManager.getApplicationLabel(info).toString()
    }.getOrDefault(pkg)

    companion object {
        /**
         * Whether the user has granted notification access to this app.
         *
         * Reads the system's enabled-listeners list rather than
         * `isNotificationListenerAccessGranted`, which needs a bound service.
         */
        fun isAccessGranted(context: Context): Boolean {
            val enabled = Settings.Secure.getString(
                context.contentResolver,
                ENABLED_LISTENERS_SETTING,
            ).orEmpty()
            if (enabled.isEmpty()) return false
            val target = ComponentName(context, HelixNotificationListener::class.java)
            return enabled.split(':').any { entry ->
                val component = ComponentName.unflattenFromString(entry)
                component == target ||
                    (component?.packageName == target.packageName &&
                        component.className == target.className)
            }
        }

        /** The system screen where notification access is granted. */
        fun accessSettingsIntent(): Intent =
            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        private const val ENABLED_LISTENERS_SETTING = "enabled_notification_listeners"
    }
}
