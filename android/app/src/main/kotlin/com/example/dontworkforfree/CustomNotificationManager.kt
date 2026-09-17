package com.example.dontworkforfree

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat

object CustomNotificationManager {
    const val CHANNEL_ID = "custom_shift_channel"
    const val NOTIFICATION_ID = 50 // Same as _persistentTimerId in Dart
    const val JOKE_NOTIFICATION_ID = 30

    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Live Shift Timer"
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
            }
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    fun showActiveShiftNotification(
        context: Context,
        isOvertime: Boolean,
        anchorEpochMillis: Long,
        progressPercent: Int,
        isOnBreak: Boolean = false,
        breakStartEpochMillis: Long = 0L
    ) {
        createChannel(context)

        try {
            // ── Build the expanded custom layout ──────────────────────────────
            val bigView = RemoteViews(context.packageName, R.layout.notification_active_shift)

            if (isOnBreak) {
                bigView.setTextViewText(R.id.status_text, "On break")
                bigView.setTextViewText(R.id.subtitle_text, "Break duration")
                bigView.setTextViewText(R.id.left_text, "ELAPSED")
                
                bigView.setViewVisibility(R.id.progress_circle, android.view.View.GONE)
                bigView.setViewVisibility(R.id.progress_circle_break, android.view.View.VISIBLE)
                
                // Set to 100 so the grey ring is fully visible, or we could leave it empty and let the user see it empty.
                // Assuming we want a full grey ring:
                bigView.setProgressBar(R.id.progress_circle_break, 100, 100, false)
                
                // For break, count UP from break start time
                val nowEpoch = System.currentTimeMillis()
                val diffMs = nowEpoch - breakStartEpochMillis
                val chronometerBase = SystemClock.elapsedRealtime() - diffMs
                bigView.setChronometer(R.id.chronometer, chronometerBase, null, true)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    bigView.setChronometerCountDown(R.id.chronometer, false)
                }
                
                bigView.setTextViewText(R.id.btn_pause, "End Break")
            } else {
                if (isOvertime) {
                    bigView.setTextViewText(R.id.status_text, "Working overtime")
                    bigView.setTextViewText(R.id.subtitle_text, "Unpaid time elapsed")
                    bigView.setTextViewText(R.id.left_text, "OVER")
                } else {
                    bigView.setTextViewText(R.id.status_text, "Shift in progress")
                    bigView.setTextViewText(R.id.subtitle_text, "Time left until safe exit")
                    bigView.setTextViewText(R.id.left_text, "LEFT")
                }
                
                bigView.setViewVisibility(R.id.progress_circle, android.view.View.VISIBLE)
                bigView.setViewVisibility(R.id.progress_circle_break, android.view.View.GONE)
                
                bigView.setProgressBar(R.id.progress_circle, 100, progressPercent, false)

                val nowEpoch = System.currentTimeMillis()
                val diffMs = anchorEpochMillis - nowEpoch
                val chronometerBase = SystemClock.elapsedRealtime() + diffMs
                bigView.setChronometer(R.id.chronometer, chronometerBase, null, true)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    bigView.setChronometerCountDown(R.id.chronometer, !isOvertime)
                }
                
                bigView.setTextViewText(R.id.btn_pause, "Take a Break")
            }

            // ── Button intents ────────────────────────────────────────────────
            val pauseIntent = Intent(context, MainActivity::class.java).apply {
                action = "ACTION_PAUSE"
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK
            }
            val pausePI = PendingIntent.getActivity(
                context, 1, pauseIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            bigView.setOnClickPendingIntent(R.id.btn_pause, pausePI)

            val clockOutIntent = Intent(context, MainActivity::class.java).apply {
                action = "ACTION_CLOCK_OUT"
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK
            }
            val clockOutPI = PendingIntent.getActivity(
                context, 2, clockOutIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            bigView.setOnClickPendingIntent(R.id.btn_clock_out, clockOutPI)

            // ── Launch app intent ─────────────────────────────────────────────
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val launchPI = PendingIntent.getActivity(
                context, 0, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // ── Build notification ────────────────────────────────────────────
            // Collapsed view: standard title + text + chronometer (reliable)
            // Expanded view:  our beautiful custom layout
            val builder = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.mipmap.launcher_icon)
                .setContentTitle(if (isOvertime) "🔴 Working overtime" else "🟢 Shift in progress")
                .setContentText(if (isOvertime) "Unpaid time elapsed" else "Time left until safe exit")
                .setWhen(anchorEpochMillis)
                .setUsesChronometer(true)
                .setChronometerCountDown(!isOvertime)
                .setCustomBigContentView(bigView)  // Only expanded = custom layout
                // Do NOT set setCustomContentView — let system handle collapsed view
                // Do NOT set DecoratedCustomViewStyle — it wraps and can break layout
                .setOngoing(true)
                .setAutoCancel(false)
                .setShowWhen(true)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setCategory(NotificationCompat.CATEGORY_STATUS)
                .setContentIntent(launchPI)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)

            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(NOTIFICATION_ID, builder.build())
        } catch (e: Exception) {
            // Log but don't crash — Dart's standard notification is the fallback
            e.printStackTrace()
        }
    }

    fun showJokeNotification(context: Context, title: String, joke: String) {
        createChannel(context)

        try {
            val bigView = RemoteViews(context.packageName, R.layout.notification_joke)
            bigView.setTextViewText(R.id.joke_title, title)
            bigView.setTextViewText(R.id.joke_text, joke)

            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val launchPI = PendingIntent.getActivity(
                context, 0, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val builder = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.mipmap.launcher_icon)
                .setContentTitle(title)
                .setContentText(joke)
                .setCustomBigContentView(bigView)
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setContentIntent(launchPI)

            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(JOKE_NOTIFICATION_ID, builder.build())
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun cancelActiveShiftNotification(context: Context) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(NOTIFICATION_ID)
    }
}
