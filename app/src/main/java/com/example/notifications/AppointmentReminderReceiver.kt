package com.example.notifications

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AppointmentReminderReceiver : BroadcastReceiver() {
    companion object {
        const val EXTRA_BOOKING_ID = "extra_booking_id"
        const val EXTRA_STAGE = "extra_stage"
        const val EXTRA_BARBER_NAME = "extra_barber_name"
        const val EXTRA_SHOP_NAME = "extra_shop_name"
        const val EXTRA_TIME_SLOT = "extra_time_slot"

        const val STAGE_1H = "STAGE_1H"
        const val STAGE_30M = "STAGE_30M"
        const val STAGE_15M_DEADLINE = "STAGE_15M_DEADLINE"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val bookingId = intent.getStringExtra(EXTRA_BOOKING_ID) ?: return
        val stage = intent.getStringExtra(EXTRA_STAGE) ?: return
        val barberName = intent.getStringExtra(EXTRA_BARBER_NAME) ?: "votre barbier"
        val shopName = intent.getStringExtra(EXTRA_SHOP_NAME) ?: "le salon"
        val timeSlot = intent.getStringExtra(EXTRA_TIME_SLOT) ?: ""

        val (title, body) = when (stage) {
            STAGE_1H -> Pair(
                "⏰ Rappel RDV dans 1 heure ($timeSlot)",
                "Vous devez arriver à $shopName 15 min avant votre rendez-vous avec $barberName pour le confirmer, sinon il sera annulé automatiquement et vous perdrez votre place."
            )
            STAGE_30M -> Pair(
                "⚠️ Plus que 30 min avant votre RDV ($timeSlot)",
                "Dernier rappel : présentez-vous chez $barberName ($shopName) au moins 15 min avant l'heure prévue pour garder votre place."
            )
            STAGE_15M_DEADLINE -> Pair(
                "❌ Délai d'arrivée (-15 min) dépassé",
                "Vous n'avez pas confirmé votre présence au salon 15 min avant votre RDV de $timeSlot chez $barberName. Le rendez-vous est annulé automatiquement."
            )
            else -> return
        }

        LemqesNotificationHelper.showNotification(
            context = context,
            notificationId = (bookingId + stage).hashCode(),
            title = title,
            message = body
        )
    }
}
