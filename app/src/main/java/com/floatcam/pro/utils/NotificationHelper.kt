package com.floatcam.pro.utils

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.floatcam.pro.MainActivity
import com.floatcam.pro.R
import com.floatcam.pro.service.FloatingCameraService

object NotificationHelper {

    const val CHANNEL_ID = "floatcam_pro_service_channel"
    const val NOTIFICATION_ID = 1001

    fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                context.getString(R.string.notification_channel_name),
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = context.getString(R.string.notification_channel_desc)
                setShowBadge(false)
                setSound(null, null)
                enableVibration(false)
            }
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    fun buildNotification(
        context: Context,
        isRecording: Boolean,
        recordingDurationText: String = "",
        isWindowVisible: Boolean = true
    ): Notification {
        val openAppIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openAppPendingIntent = PendingIntent.getActivity(
            context,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Show/Hide Toggle Intent
        val toggleWindowIntent = Intent(context, FloatingCameraService::class.java).apply {
            action = FloatingCameraService.ACTION_TOGGLE_WINDOW
        }
        val toggleWindowPendingIntent = PendingIntent.getService(
            context,
            1,
            toggleWindowIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Record / Stop Record Intent
        val toggleRecordIntent = Intent(context, FloatingCameraService::class.java).apply {
            action = FloatingCameraService.ACTION_TOGGLE_RECORD
        }
        val toggleRecordPendingIntent = PendingIntent.getService(
            context,
            2,
            toggleRecordIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Close / Stop Service Intent
        val closeIntent = Intent(context, FloatingCameraService::class.java).apply {
            action = FloatingCameraService.ACTION_STOP_SERVICE
        }
        val closePendingIntent = PendingIntent.getService(
            context,
            3,
            closeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val title = if (isRecording) {
            "🔴 Recording: $recordingDurationText"
        } else {
            context.getString(R.string.notification_title_active)
        }

        val content = if (isRecording) {
            "Tap Stop to finish video recording"
        } else {
            "FloatCam Pro is floating on screen"
        }

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_tile_camera)
            .setContentTitle(title)
            .setContentText(content)
            .setContentIntent(openAppPendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .addAction(
                0,
                if (isWindowVisible) "Hide Window" else "Show Window",
                toggleWindowPendingIntent
            )
            .addAction(
                0,
                if (isRecording) "Stop Rec" else "Start Rec",
                toggleRecordPendingIntent
            )
            .addAction(
                0,
                "Stop Service",
                closePendingIntent
            )

        return builder.build()
    }
}
