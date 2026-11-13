package com.example.notifications

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.example.MainActivity
import com.example.R

object LemqesNotificationHelper {
    const val CHANNEL_ID = "lemqes_appointments"
    private const val CHANNEL_NAME = "Rendez-vous & Rappels LEMQES"
    private const val CHANNEL_DESC = "Rappels 1h et 30min avant RDV, confirmation d'arrivée 15min avant, et alertes en route"

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(CHANNEL_ID, CHANNEL_NAME, importance).apply {
                description = CHANNEL_DESC
                enableVibration(true)
            }
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    fun showNotification(
        context: Context,
        notificationId: Int,
        title: String,
        message: String
    ) {
        ensureChannel(context)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) return
        }

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentPendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification_lemqes)
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(contentPendingIntent)

        NotificationManagerCompat.from(context).notify(notificationId, builder.build())
    }

    fun scheduleBookingReminders(
        context: Context,
        bookingId: String,
        barberName: String,
        shopName: String,
        timeSlot: String,
        appointmentTimestampMillis: Long
    ) {
        if (appointmentTimestampMillis <= 0L) return
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val now = System.currentTimeMillis()

        val oneHourBefore = appointmentTimestampMillis - 60 * 60 * 1000L
        val thirtyMinBefore = appointmentTimestampMillis - 30 * 60 * 1000L
        val fifteenMinBefore = appointmentTimestampMillis - 15 * 60 * 1000L

        if (oneHourBefore > now) {
            scheduleStageAlarm(
                context = context,
                alarmManager = alarmManager,
                triggerAtMillis = oneHourBefore,
                bookingId = bookingId,
                stage = AppointmentReminderReceiver.STAGE_1H,
                barberName = barberName,
                shopName = shopName,
                timeSlot = timeSlot,
                requestCode = (bookingId + "_1h").hashCode()
            )
        }
        if (thirtyMinBefore > now) {
            scheduleStageAlarm(
                context = context,
                alarmManager = alarmManager,
                triggerAtMillis = thirtyMinBefore,
                bookingId = bookingId,
                stage = AppointmentReminderReceiver.STAGE_30M,
                barberName = barberName,
                shopName = shopName,
                timeSlot = timeSlot,
                requestCode = (bookingId + "_30m").hashCode()
            )
        }
        if (fifteenMinBefore > now) {
            scheduleStageAlarm(
                context = context,
                alarmManager = alarmManager,
                triggerAtMillis = fifteenMinBefore,
                bookingId = bookingId,
                stage = AppointmentReminderReceiver.STAGE_15M_DEADLINE,
                barberName = barberName,
                shopName = shopName,
                timeSlot = timeSlot,
                requestCode = (bookingId + "_15m").hashCode()
            )
        }
    }

    fun cancelBookingReminders(context: Context, bookingId: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        listOf("_1h", "_30m", "_15m").forEach { suffix ->
            val intent = Intent(context, AppointmentReminderReceiver::class.java)
            val pi = PendingIntent.getBroadcast(
                context,
                (bookingId + suffix).hashCode(),
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (pi != null) {
                alarmManager.cancel(pi)
            }
        }
    }

    private fun scheduleStageAlarm(
        context: Context,
        alarmManager: AlarmManager,
        triggerAtMillis: Long,
        bookingId: String,
        stage: String,
        barberName: String,
        shopName: String,
        timeSlot: String,
        requestCode: Int
    ) {
        val intent = Intent(context, AppointmentReminderReceiver::class.java).apply {
            putExtra(AppointmentReminderReceiver.EXTRA_BOOKING_ID, bookingId)
            putExtra(AppointmentReminderReceiver.EXTRA_STAGE, stage)
            putExtra(AppointmentReminderReceiver.EXTRA_BARBER_NAME, barberName)
            putExtra(AppointmentReminderReceiver.EXTRA_SHOP_NAME, shopName)
            putExtra(AppointmentReminderReceiver.EXTRA_TIME_SLOT, timeSlot)
        }
        val pi = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
    }
}
