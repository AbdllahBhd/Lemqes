package com.example.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.DirectionsRun
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.model.AppNotification
import com.example.model.BookingRecord
import com.example.model.BookingStatus
import com.example.ui.theme.*

@Composable
fun CustomerBookingsAndNotificationsScreen(
    bookings: List<BookingRecord>,
    notifications: List<AppNotification>,
    onNotifyOnTheWay: (bookingId: String, etaMinutes: Int) -> Unit = { _, _ -> },
    onConfirmArrivalAtShop: (bookingId: String) -> Unit = {},
    onCancelBooking: (bookingId: String) -> Unit = {},
    onTriggerReminder1h: (bookingId: String) -> Unit = {},
    onTriggerReminder30m: (bookingId: String) -> Unit = {},
    onEvaluate15mDeadline: (bookingId: String) -> Unit = {},
    onOpenFeedbackForBooking: (BookingRecord) -> Unit = {},
    modifier: Modifier = Modifier
) {
    var etaPickerBookingId by remember { mutableStateOf<String?>(null) }

    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
        contentPadding = PaddingValues(top = 12.dp, bottom = 80.dp)
    ) {
        // Active Bookings section
        item {
            Text(
                text = "Mes Rendez-vous & Rappels d'arrivée",
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface
            )
        }

        if (bookings.isEmpty()) {
            item {
                Text(
                    text = "Aucun rendez-vous pour le moment.",
                    fontSize = 13.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        } else {
            items(bookings, key = { it.id }) { b ->
                val (statusLabel, statusColor) = when (b.status) {
                    BookingStatus.WAITING_APPROVAL -> Pair("⏳ Attente confirmation", BarberAmber)
                    BookingStatus.CONFIRMED -> Pair("Confirmé ✓", BarberGoldPrimary)
                    BookingStatus.ARRIVED_CONFIRMED -> Pair(if (b.isHomeService) "Artiste sur place ✓" else "Arrivé au salon ✓", BarberEmerald)
                    BookingStatus.AUTO_CANCELLED -> Pair("Annulé auto (-15m)", BarberRose)
                    BookingStatus.CANCELLED -> Pair("Annulé / Refusé", MaterialTheme.colorScheme.onSurfaceVariant)
                    BookingStatus.COMPLETED -> Pair("Terminé ✓", BarberEmerald)
                    BookingStatus.NO_SHOW -> Pair("Absent", BarberRose)
                }

                Card(
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                    modifier = Modifier
                        .fillMaxWidth()
                        .border(
                            1.dp,
                            when (b.status) {
                                BookingStatus.AUTO_CANCELLED -> BarberRose.copy(alpha = 0.5f)
                                BookingStatus.ARRIVED_CONFIRMED -> BarberEmerald.copy(alpha = 0.5f)
                                else -> if (b.isOnTheWay) BarberBlue.copy(alpha = 0.5f) else Color.Transparent
                            },
                            RoundedCornerShape(16.dp)
                        )
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = b.barberName,
                                fontSize = 15.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onSurface,
                                modifier = Modifier.weight(1f)
                            )
                            Surface(
                                shape = RoundedCornerShape(8.dp),
                                color = statusColor.copy(alpha = 0.18f)
                            ) {
                                Text(
                                    text = statusLabel,
                                    color = statusColor,
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Bold,
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp)
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(6.dp))

                        Text(
                            text = "${b.serviceName} • ${b.date} à ${b.timeSlot}",
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = BarberGoldPrimary
                        )

                        if (b.isHomeService) {
                            Spacer(modifier = Modifier.height(6.dp))
                            Surface(
                                shape = RoundedCornerShape(8.dp),
                                color = BarberEmerald.copy(alpha = 0.14f),
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .testTag("booking_home_badge_${b.id}")
                            ) {
                                    Column(modifier = Modifier.padding(10.dp), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                                        Row(verticalAlignment = Alignment.CenterVertically) {
                                            Icon(Icons.Default.HomeRepairService, contentDescription = null, tint = BarberEmerald, modifier = Modifier.size(15.dp))
                                            Spacer(modifier = Modifier.width(6.dp))
                                            Text(
                                                text = "🏠 Prestation à Domicile (${b.targetAudience.labelFr}) • Total ${b.priceDzd} DA",
                                                fontSize = 11.sp,
                                                fontWeight = FontWeight.Bold,
                                                color = BarberEmerald
                                            )
                                        }
                                        if (b.selectedServices.isNotEmpty()) {
                                            Text(
                                                text = "Services : ${b.selectedServices.joinToString(" + ")}",
                                                fontSize = 11.sp,
                                                fontWeight = FontWeight.Medium,
                                                color = MaterialTheme.colorScheme.onSurface
                                            )
                                        }
                                        if (!b.customerAddress.isNullOrBlank()) {
                                            Text(
                                                text = "📍 Adresse : ${b.customerAddress}",
                                                fontSize = 11.sp,
                                                color = MaterialTheme.colorScheme.onSurface
                                            )
                                        }
                                        if (b.clientLatitude != null && b.clientLongitude != null) {
                                            val distLabel = b.distanceKm?.let { " • ~$it km" } ?: ""
                                            Text(
                                                text = "🗺️ Carte GPS : ${String.format("%.4f", b.clientLatitude)}°N, ${String.format("%.4f", b.clientLongitude)}°E$distLabel",
                                                fontSize = 10.sp,
                                                color = MaterialTheme.colorScheme.onSurfaceVariant
                                            )
                                        }
                                        if (b.customerPhone.isNotBlank()) {
                                            Text(
                                                text = "📞 Contact : ${b.customerPhone} • Paiement : ${b.paymentMethod.labelFr}",
                                                fontSize = 10.sp,
                                                color = MaterialTheme.colorScheme.onSurfaceVariant
                                            )
                                        }
                                        if (b.customerNotes.isNotBlank()) {
                                            Text(
                                                text = "📝 Détails : ${b.customerNotes}",
                                                fontSize = 10.sp,
                                                color = MaterialTheme.colorScheme.onSurfaceVariant
                                            )
                                        }
                                        Text(
                                            text = if (b.travelFeeDzd == 0) "Frais de déplacement offerts" else "Inclus frais de déplacement : +${b.travelFeeDzd} DA",
                                            fontSize = 10.sp,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }
                                }
                        } else {
                            Spacer(modifier = Modifier.height(4.dp))

                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.Default.Storefront, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(16.dp))
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(
                                    text = "Lieu garanti : ${b.locationSnapshot}",
                                    fontSize = 12.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }

                        // Pending Artist Approval notice
                        if (b.status == BookingStatus.WAITING_APPROVAL) {
                            Spacer(modifier = Modifier.height(8.dp))
                            Surface(
                                shape = RoundedCornerShape(10.dp),
                                color = BarberAmber.copy(alpha = 0.14f),
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .border(1.dp, BarberAmber.copy(alpha = 0.4f), RoundedCornerShape(10.dp))
                            ) {
                                Row(
                                    modifier = Modifier.padding(10.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Icon(Icons.Default.HourglassTop, contentDescription = null, tint = BarberAmber, modifier = Modifier.size(18.dp))
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Text(
                                        text = "En attente de confirmation de ${b.barberName}. Vous recevrez une notification dès que l'artiste valide votre demande.",
                                        fontSize = 11.sp,
                                        color = MaterialTheme.colorScheme.onSurface
                                    )
                                }
                            }
                            Spacer(modifier = Modifier.height(6.dp))
                            TextButton(
                                onClick = { onCancelBooking(b.id) },
                                modifier = Modifier.testTag("btn_cancel_booking_${b.id}")
                            ) {
                                Text("Annuler ma demande", fontSize = 12.sp, color = BarberRose, fontWeight = FontWeight.Bold)
                            }
                        }

                        // Artist on the way to client home banner
                        if (b.artistOnTheWay && b.status == BookingStatus.CONFIRMED) {
                            Spacer(modifier = Modifier.height(8.dp))
                            Surface(
                                shape = RoundedCornerShape(8.dp),
                                color = BarberEmerald.copy(alpha = 0.16f),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Row(
                                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 7.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Icon(Icons.Default.DirectionsCar, contentDescription = null, tint = BarberEmerald, modifier = Modifier.size(16.dp))
                                    Spacer(modifier = Modifier.width(6.dp))
                                    Text(
                                        text = "🚗 ${b.barberName} est en route chez vous (~${b.artistEtaMinutes ?: 15} min) !",
                                        fontSize = 11.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = BarberEmerald
                                    )
                                }
                            }
                        }

                        // En-route live status badge (customer heading to shop)
                        if (b.isOnTheWay && b.status == BookingStatus.CONFIRMED) {
                            Spacer(modifier = Modifier.height(8.dp))
                            Surface(
                                shape = RoundedCornerShape(8.dp),
                                color = BarberBlue.copy(alpha = 0.16f),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Row(
                                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Icon(Icons.Default.DirectionsCar, contentDescription = null, tint = BarberBlue, modifier = Modifier.size(16.dp))
                                    Spacer(modifier = Modifier.width(6.dp))
                                    Text(
                                        text = "En route vers le salon (~${b.etaMinutes ?: 10} min) • Barbier notifié ✓",
                                        fontSize = 11.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = BarberBlue
                                    )
                                }
                            }
                        }

                        // Auto-cancelled explanation box
                        if (b.status == BookingStatus.AUTO_CANCELLED) {
                            Spacer(modifier = Modifier.height(8.dp))
                            Surface(
                                shape = RoundedCornerShape(8.dp),
                                color = BarberRose.copy(alpha = 0.14f),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Text(
                                    text = b.autoCancelReason
                                        ?: "Annulé automatiquement : vous n'êtes pas arrivé 15 min avant votre rendez-vous et vous avez perdu votre place.",
                                    fontSize = 11.sp,
                                    color = BarberRose,
                                    fontWeight = FontWeight.Medium,
                                    modifier = Modifier.padding(10.dp)
                                )
                            }
                        }

                        // 3-step Reminder Timeline for active Confirmed bookings
                        if (b.status == BookingStatus.CONFIRMED) {
                            Spacer(modifier = Modifier.height(10.dp))
                            Surface(
                                shape = RoundedCornerShape(10.dp),
                                color = MaterialTheme.colorScheme.surface,
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Column(modifier = Modifier.padding(10.dp)) {
                                    Text(
                                        text = if (b.isHomeService) {
                                            "⏳ Visite à domicile confirmée (${b.timeSlot}) • Rappels -1h / -30m :"
                                        } else {
                                            "⏳ Confirmation requise au salon 15 min avant (${b.timeSlot}) :"
                                        },
                                        fontSize = 11.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = MaterialTheme.colorScheme.onSurface
                                    )
                                    Spacer(modifier = Modifier.height(6.dp))
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                                    ) {
                                        ReminderStageBadge(
                                            label = if (b.notified1hBefore) "1. Rappel -1h ✓" else "1. Rappel -1h",
                                            active = b.notified1hBefore,
                                            color = BarberAmber,
                                            modifier = Modifier.weight(1f)
                                        )
                                        ReminderStageBadge(
                                            label = if (b.notified30mBefore) "2. Rappel -30m ✓" else "2. Rappel -30m",
                                            active = b.notified30mBefore,
                                            color = BarberGoldPrimary,
                                            modifier = Modifier.weight(1f)
                                        )
                                        ReminderStageBadge(
                                            label = if (b.isHomeService) "3. Prêt(e) -15m" else "3. Arrivée -15m",
                                            active = b.hasArrivedAtShop,
                                            color = BarberRose,
                                            modifier = Modifier.weight(1f)
                                        )
                                    }
                                }
                            }

                            Spacer(modifier = Modifier.height(10.dp))

                            // Main interactive action buttons: On the way (in-shop only), Arrived / Ready, Cancel
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                if (!b.isHomeService) {
                                    Button(
                                        onClick = {
                                            etaPickerBookingId = if (etaPickerBookingId == b.id) null else b.id
                                        },
                                        modifier = Modifier
                                            .weight(1f)
                                            .height(44.dp)
                                            .testTag("btn_on_the_way_${b.id}"),
                                        colors = ButtonDefaults.buttonColors(containerColor = BarberBlue, contentColor = Color.White),
                                        shape = RoundedCornerShape(10.dp),
                                        contentPadding = PaddingValues(horizontal = 8.dp)
                                    ) {
                                        Icon(Icons.AutoMirrored.Filled.DirectionsRun, contentDescription = null, modifier = Modifier.size(16.dp))
                                        Spacer(modifier = Modifier.width(4.dp))
                                        Text(
                                            text = if (b.isOnTheWay) "Modifier ETA" else "Je suis en route",
                                            fontSize = 11.sp,
                                            fontWeight = FontWeight.Bold
                                        )
                                    }
                                }

                                Button(
                                    onClick = { onConfirmArrivalAtShop(b.id) },
                                    modifier = Modifier
                                        .weight(1f)
                                        .height(44.dp)
                                        .testTag("btn_arrived_shop_${b.id}"),
                                    colors = ButtonDefaults.buttonColors(containerColor = BarberEmerald, contentColor = Color.White),
                                    shape = RoundedCornerShape(10.dp),
                                    contentPadding = PaddingValues(horizontal = 8.dp)
                                ) {
                                    Icon(Icons.Default.CheckCircle, contentDescription = null, modifier = Modifier.size(16.dp))
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text(
                                        text = if (b.isHomeService) "Confirmer ma présence" else "Arrivé au salon",
                                        fontSize = 11.sp,
                                        fontWeight = FontWeight.Bold
                                    )
                                }
                            }

                            // Quick ETA selector row when "Je suis en route" is tapped
                            if (etaPickerBookingId == b.id) {
                                Spacer(modifier = Modifier.height(8.dp))
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text("Arrivée dans :", fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                                    listOf(5, 10, 15, 25).forEach { eta ->
                                        AssistChip(
                                            onClick = {
                                                onNotifyOnTheWay(b.id, eta)
                                                etaPickerBookingId = null
                                            },
                                            label = { Text("$eta min", fontSize = 11.sp, fontWeight = FontWeight.Bold) },
                                            modifier = Modifier.testTag("eta_chip_${b.id}_$eta")
                                        )
                                    }
                                }
                            }

                            Spacer(modifier = Modifier.height(8.dp))

                            // Simulation/testing controls for timed notifications + cancel button
                            LazyRow(
                                horizontalArrangement = Arrangement.spacedBy(6.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                item {
                                    OutlinedButton(
                                        onClick = { onTriggerReminder1h(b.id) },
                                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                                        modifier = Modifier.height(32.dp).testTag("sim_1h_${b.id}"),
                                        shape = RoundedCornerShape(8.dp)
                                    ) {
                                        Text("Tester rappel -1h", fontSize = 10.sp)
                                    }
                                }
                                item {
                                    OutlinedButton(
                                        onClick = { onTriggerReminder30m(b.id) },
                                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                                        modifier = Modifier.height(32.dp).testTag("sim_30m_${b.id}"),
                                        shape = RoundedCornerShape(8.dp)
                                    ) {
                                        Text("Tester rappel -30m", fontSize = 10.sp)
                                    }
                                }
                                item {
                                    OutlinedButton(
                                        onClick = { onEvaluate15mDeadline(b.id) },
                                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                                        modifier = Modifier.height(32.dp).testTag("sim_15m_cancel_${b.id}"),
                                        shape = RoundedCornerShape(8.dp)
                                    ) {
                                        Text("Simuler -15m absent", fontSize = 10.sp, color = BarberRose)
                                    }
                                }
                                item {
                                    TextButton(
                                        onClick = { onCancelBooking(b.id) },
                                        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp),
                                        modifier = Modifier.height(32.dp).testTag("btn_cancel_booking_${b.id}")
                                    ) {
                                        Text("Annuler", fontSize = 11.sp, color = BarberRose)
                                    }
                                }
                            }
                        }

                        // Feedback & rating button for confirmed, arrived, or completed bookings
                        if (b.status == BookingStatus.CONFIRMED || b.status == BookingStatus.ARRIVED_CONFIRMED || b.status == BookingStatus.COMPLETED) {
                            Spacer(modifier = Modifier.height(8.dp))
                            OutlinedButton(
                                onClick = { onOpenFeedbackForBooking(b) },
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(40.dp)
                                    .testTag("btn_rate_booking_${b.id}"),
                                shape = RoundedCornerShape(10.dp)
                            ) {
                                Icon(Icons.Default.Star, contentDescription = null, tint = BarberGoldPrimary, modifier = Modifier.size(16.dp))
                                Spacer(modifier = Modifier.width(6.dp))
                                Text("Noter & Laisser un avis (Barbier & Salon)", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                            }
                        }
                    }
                }
            }
        }

        // Push Notifications Feed
        item {
            Text(
                text = "Notifications & Alertes RDV (${notifications.size})",
                fontSize = 15.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.padding(top = 8.dp)
            )
        }

        items(notifications, key = { it.id }) { notif ->
            Card(
                shape = RoundedCornerShape(14.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier.padding(14.dp),
                    verticalAlignment = Alignment.Top
                ) {
                    val icon = when (notif.type) {
                        "QUEUE" -> Icons.Default.Timer
                        "WORKPLACE" -> Icons.Default.SwapHoriz
                        "BROADCAST" -> Icons.Default.Campaign
                        "REMINDER_1H", "REMINDER_30M" -> Icons.Default.Alarm
                        "AUTO_CANCEL" -> Icons.Default.EventBusy
                        "ON_THE_WAY" -> Icons.Default.DirectionsCar
                        "ARRIVED" -> Icons.Default.CheckCircle
                        "PROMOTION" -> Icons.Default.LocalOffer
                        "FEEDBACK" -> Icons.Default.Star
                        "HOME_REQUEST" -> Icons.Default.HomeRepairService
                        "HOME_CONFIRMED" -> Icons.Default.Verified
                        else -> Icons.Default.Notifications
                    }
                    val iconColor = when (notif.type) {
                        "QUEUE" -> BarberGoldPrimary
                        "WORKPLACE", "ARRIVED", "HOME_CONFIRMED" -> BarberEmerald
                        "BROADCAST", "ON_THE_WAY" -> BarberBlue
                        "REMINDER_1H", "REMINDER_30M", "HOME_REQUEST" -> BarberAmber
                        "AUTO_CANCEL", "PROMOTION" -> BarberRose
                        "FEEDBACK" -> BarberGoldPrimary
                        else -> MaterialTheme.colorScheme.primary
                    }

                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .clip(CircleShape)
                            .background(iconColor.copy(alpha = 0.2f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(icon, contentDescription = null, tint = iconColor, modifier = Modifier.size(20.dp))
                    }

                    Spacer(modifier = Modifier.width(12.dp))

                    Column(modifier = Modifier.weight(1f)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text(
                                text = notif.title,
                                fontWeight = FontWeight.Bold,
                                fontSize = 14.sp,
                                modifier = Modifier.weight(1f)
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(notif.timestamp, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        Spacer(modifier = Modifier.height(2.dp))
                        Text(
                            text = notif.message,
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ReminderStageBadge(
    label: String,
    active: Boolean,
    color: Color,
    modifier: Modifier = Modifier
) {
    Surface(
        shape = RoundedCornerShape(6.dp),
        color = if (active) color.copy(alpha = 0.2f) else MaterialTheme.colorScheme.surfaceVariant,
        modifier = modifier
    ) {
        Text(
            text = label,
            fontSize = 9.sp,
            fontWeight = if (active) FontWeight.Bold else FontWeight.Medium,
            color = if (active) color else MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(horizontal = 6.dp, vertical = 4.dp)
        )
    }
}
