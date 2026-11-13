package com.example.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
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
import com.example.model.*
import com.example.ui.theme.*

@Composable
fun ArtistNotificationsBannerCard(
    notifications: List<AppNotification>,
    accentColor: Color,
    modifier: Modifier = Modifier
) {
    val artistNotifs = notifications.filter { it.recipientRole == "ARTIST" || it.recipientRole == "ALL" }
    var expanded by remember { mutableStateOf(false) }

    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
        modifier = modifier
            .fillMaxWidth()
            .border(1.dp, accentColor.copy(alpha = 0.3f), RoundedCornerShape(16.dp))
            .testTag("artist_notifications_card")
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { expanded = !expanded },
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.weight(1f)) {
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .clip(CircleShape)
                            .background(accentColor.copy(alpha = 0.18f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(Icons.Default.NotificationsActive, contentDescription = null, tint = accentColor, modifier = Modifier.size(19.dp))
                    }
                    Spacer(modifier = Modifier.width(10.dp))
                    Column {
                        Text(
                            text = "Notifications Artiste (${artistNotifs.size})",
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        val latest = artistNotifs.firstOrNull()
                        Text(
                            text = latest?.title ?: "Aucune notification pour le moment",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 1
                        )
                    }
                }
                Icon(
                    imageVector = if (expanded) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
                    contentDescription = "Afficher les notifications",
                    tint = accentColor
                )
            }

            AnimatedVisibility(visible = expanded && artistNotifs.isNotEmpty()) {
                Column(
                    modifier = Modifier.padding(top = 10.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    artistNotifs.take(6).forEach { notif ->
                        Surface(
                            shape = RoundedCornerShape(10.dp),
                            color = MaterialTheme.colorScheme.surface,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(modifier = Modifier.padding(10.dp)) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Text(
                                        text = notif.title,
                                        fontSize = 12.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = accentColor,
                                        modifier = Modifier.weight(1f)
                                    )
                                    Spacer(modifier = Modifier.width(6.dp))
                                    Text(notif.timestamp, fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                                Spacer(modifier = Modifier.height(2.dp))
                                Text(
                                    text = notif.message,
                                    fontSize = 11.sp,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun ArtistHomeVisitRequestsCard(
    barberId: String,
    homeBookings: List<BookingRecord>,
    accentColor: Color,
    onConfirmBooking: (bookingId: String) -> Unit,
    onDeclineBooking: (bookingId: String) -> Unit,
    onArtistOnTheWay: (bookingId: String, etaMinutes: Int) -> Unit,
    onArtistArrived: (bookingId: String) -> Unit,
    onCompleteHomeBooking: (bookingId: String) -> Unit,
    modifier: Modifier = Modifier
) {
    val relevantBookings = homeBookings.filter {
        it.isHomeService && (it.barberId == barberId || it.status == BookingStatus.WAITING_APPROVAL)
    }
    val pendingRequests = relevantBookings.filter { it.status == BookingStatus.WAITING_APPROVAL }
    val activeHomeVisits = relevantBookings.filter {
        it.status == BookingStatus.CONFIRMED || it.status == BookingStatus.ARRIVED_CONFIRMED
    }
    var etaSelectorBookingId by remember { mutableStateOf<String?>(null) }

    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Pending Approval Requests
        if (pendingRequests.isNotEmpty()) {
            Card(
                shape = RoundedCornerShape(18.dp),
                colors = CardDefaults.cardColors(containerColor = BarberAmber.copy(alpha = 0.12f)),
                modifier = Modifier
                    .fillMaxWidth()
                    .border(1.5.dp, BarberAmber.copy(alpha = 0.55f), RoundedCornerShape(18.dp))
                    .testTag("pending_home_requests_card")
            ) {
                Column(
                    modifier = Modifier.padding(14.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.PendingActions, contentDescription = null, tint = BarberAmber, modifier = Modifier.size(20.dp))
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = "Demandes À Domicile à confirmer (${pendingRequests.size})",
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Bold,
                            color = BarberAmber
                        )
                    }

                    pendingRequests.forEach { req ->
                        Surface(
                            shape = RoundedCornerShape(14.dp),
                            color = MaterialTheme.colorScheme.surface,
                            modifier = Modifier
                                .fillMaxWidth()
                                .border(0.5.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.45f), RoundedCornerShape(14.dp))
                        ) {
                            Column(
                                modifier = Modifier.padding(12.dp),
                                verticalArrangement = Arrangement.spacedBy(6.dp)
                            ) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(
                                            text = "${req.customerName} • ${req.date} à ${req.timeSlot}",
                                            fontSize = 14.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = MaterialTheme.colorScheme.onSurface
                                        )
                                        if (req.customerPhone.isNotBlank()) {
                                            Text(
                                                text = "📞 ${req.customerPhone} • ${req.paymentMethod.labelFr}",
                                                fontSize = 11.sp,
                                                fontWeight = FontWeight.SemiBold,
                                                color = BarberEmerald
                                            )
                                        }
                                    }
                                    Surface(
                                        shape = RoundedCornerShape(8.dp),
                                        color = accentColor.copy(alpha = 0.16f)
                                    ) {
                                        Text(
                                            text = "${req.priceDzd} DA",
                                            fontSize = 13.sp,
                                            fontWeight = FontWeight.Black,
                                            color = accentColor,
                                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                                        )
                                    }
                                }

                                val servicesLabel = if (req.selectedServices.isNotEmpty()) {
                                    req.selectedServices.joinToString(" + ")
                                } else {
                                    req.serviceName
                                }
                                Text(
                                    text = "Prestations : $servicesLabel",
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.Medium,
                                    color = MaterialTheme.colorScheme.onSurface
                                )

                                // Client Map & Address Summary
                                Surface(
                                    shape = RoundedCornerShape(10.dp),
                                    color = MaterialTheme.colorScheme.surfaceVariant,
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Column(modifier = Modifier.padding(8.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                        Row(verticalAlignment = Alignment.CenterVertically) {
                                            Icon(Icons.Default.LocationOn, contentDescription = null, tint = BarberRose, modifier = Modifier.size(15.dp))
                                            Spacer(modifier = Modifier.width(4.dp))
                                            Text(
                                                text = req.customerAddress ?: req.locationSnapshot,
                                                fontSize = 11.sp,
                                                fontWeight = FontWeight.SemiBold,
                                                color = MaterialTheme.colorScheme.onSurface
                                            )
                                        }
                                        val coordsText = if (req.clientLatitude != null && req.clientLongitude != null) {
                                            "Carte : ${String.format("%.4f", req.clientLatitude)}°N, ${String.format("%.4f", req.clientLongitude)}°E"
                                        } else ""
                                        val distText = req.distanceKm?.let { " • Distance ~$it km" } ?: ""
                                        if (coordsText.isNotBlank() || distText.isNotBlank()) {
                                            Text(
                                                text = "$coordsText$distText",
                                                fontSize = 10.sp,
                                                color = MaterialTheme.colorScheme.onSurfaceVariant
                                            )
                                        }
                                        if (req.customerNotes.isNotBlank()) {
                                            Text(
                                                text = "Notes : ${req.customerNotes}",
                                                fontSize = 10.sp,
                                                color = MaterialTheme.colorScheme.onSurfaceVariant
                                            )
                                        }
                                    }
                                }

                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                                ) {
                                    OutlinedButton(
                                        onClick = { onDeclineBooking(req.id) },
                                        modifier = Modifier
                                            .weight(0.9f)
                                            .height(48.dp)
                                            .testTag("btn_decline_home_booking_${req.id}"),
                                        shape = RoundedCornerShape(12.dp),
                                        border = BorderStroke(1.dp, BarberRose.copy(alpha = 0.6f))
                                    ) {
                                        Icon(Icons.Default.Close, contentDescription = null, tint = BarberRose, modifier = Modifier.size(16.dp))
                                        Spacer(modifier = Modifier.width(4.dp))
                                        Text("Refuser", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = BarberRose)
                                    }

                                    Button(
                                        onClick = { onConfirmBooking(req.id) },
                                        modifier = Modifier
                                            .weight(1.3f)
                                            .height(48.dp)
                                            .testTag("btn_confirm_home_booking_${req.id}"),
                                        colors = ButtonDefaults.buttonColors(containerColor = BarberEmerald, contentColor = Color.White),
                                        shape = RoundedCornerShape(12.dp)
                                    ) {
                                        Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(17.dp))
                                        Spacer(modifier = Modifier.width(6.dp))
                                        Text("Confirmer", fontSize = 13.sp, fontWeight = FontWeight.Bold)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Confirmed Active Home Visits
        if (activeHomeVisits.isNotEmpty()) {
            Card(
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = BarberEmerald.copy(alpha = 0.1f)),
                modifier = Modifier
                    .fillMaxWidth()
                    .border(1.dp, BarberEmerald.copy(alpha = 0.4f), RoundedCornerShape(16.dp))
            ) {
                Column(
                    modifier = Modifier.padding(14.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Text(
                        text = "Visites à domicile confirmées (${activeHomeVisits.size})",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold,
                        color = BarberEmerald
                    )

                    activeHomeVisits.forEach { visit ->
                        Surface(
                            shape = RoundedCornerShape(12.dp),
                            color = MaterialTheme.colorScheme.surface,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(
                                modifier = Modifier.padding(12.dp),
                                verticalArrangement = Arrangement.spacedBy(6.dp)
                            ) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Text(
                                        text = "${visit.date} ${visit.timeSlot} • ${visit.customerName}",
                                        fontSize = 13.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = MaterialTheme.colorScheme.onSurface
                                    )
                                    Text(
                                        text = "${visit.priceDzd} DA",
                                        fontSize = 12.sp,
                                        fontWeight = FontWeight.Black,
                                        color = BarberGoldPrimary
                                    )
                                }
                                Text(
                                    text = "${visit.serviceName} • ${visit.customerAddress ?: visit.locationSnapshot}",
                                    fontSize = 11.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                                if (visit.customerPhone.isNotBlank()) {
                                    Text(
                                        text = "📞 ${visit.customerPhone}",
                                        fontSize = 11.sp,
                                        fontWeight = FontWeight.SemiBold,
                                        color = BarberEmerald
                                    )
                                }

                                if (visit.status == BookingStatus.ARRIVED_CONFIRMED) {
                                    Button(
                                        onClick = { onCompleteHomeBooking(visit.id) },
                                        modifier = Modifier.fillMaxWidth().height(44.dp),
                                        colors = ButtonDefaults.buttonColors(containerColor = BarberEmerald, contentColor = Color.White),
                                        shape = RoundedCornerShape(10.dp)
                                    ) {
                                        Text("Terminer la prestation ✓", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                                    }
                                } else {
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                                    ) {
                                        OutlinedButton(
                                            onClick = {
                                                etaSelectorBookingId = if (etaSelectorBookingId == visit.id) null else visit.id
                                            },
                                            modifier = Modifier.weight(1f).height(42.dp),
                                            shape = RoundedCornerShape(10.dp)
                                        ) {
                                            Icon(Icons.Default.DirectionsCar, contentDescription = null, modifier = Modifier.size(15.dp))
                                            Spacer(modifier = Modifier.width(4.dp))
                                            Text(
                                                text = if (visit.artistOnTheWay) "En route (${visit.artistEtaMinutes}m)" else "En route",
                                                fontSize = 11.sp,
                                                fontWeight = FontWeight.Bold
                                            )
                                        }
                                        Button(
                                            onClick = { onArtistArrived(visit.id) },
                                            modifier = Modifier.weight(1f).height(42.dp),
                                            colors = ButtonDefaults.buttonColors(containerColor = BarberBlue, contentColor = Color.White),
                                            shape = RoundedCornerShape(10.dp)
                                        ) {
                                            Icon(Icons.Default.WhereToVote, contentDescription = null, modifier = Modifier.size(15.dp))
                                            Spacer(modifier = Modifier.width(4.dp))
                                            Text("Arrivé sur place", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                                        }
                                    }

                                    if (etaSelectorBookingId == visit.id) {
                                        Row(
                                            modifier = Modifier.fillMaxWidth(),
                                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                                            verticalAlignment = Alignment.CenterVertically
                                        ) {
                                            Text("Arrivée dans :", fontSize = 11.sp)
                                            listOf(10, 20, 30).forEach { eta ->
                                                AssistChip(
                                                    onClick = {
                                                        onArtistOnTheWay(visit.id, eta)
                                                        etaSelectorBookingId = null
                                                    },
                                                    label = { Text("$eta min", fontSize = 11.sp) }
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun ArtistSlotAvailabilityManagerCard(
    barber: BarberProfile,
    accentColor: Color,
    onToggleSlot: (date: String, slot: String) -> Unit,
    modifier: Modifier = Modifier
) {
    val dates = listOf("Aujourd'hui", "Demain", "Jeudi", "Vendredi", "Samedi")
    var selectedDate by remember { mutableStateOf(dates.first()) }
    val blockedForDay = barber.blockedHomeSlots[selectedDate].orEmpty()

    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
        modifier = modifier.fillMaxWidth()
    ) {
        Column(
            modifier = Modifier.padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                text = "Créneaux disponibles à domicile",
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface
            )
            Text(
                text = "Touchez un horaire pour l'ouvrir ou le bloquer aux réservations clients.",
                fontSize = 11.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                items(dates) { day ->
                    val sel = day == selectedDate
                    Surface(
                        shape = RoundedCornerShape(8.dp),
                        color = if (sel) accentColor else MaterialTheme.colorScheme.surface,
                        modifier = Modifier.clickable { selectedDate = day }
                    ) {
                        Text(
                            text = day,
                            fontSize = 11.sp,
                            fontWeight = if (sel) FontWeight.Bold else FontWeight.Medium,
                            color = if (sel) (if (accentColor == BarberGoldPrimary) Color.Black else Color.White) else MaterialTheme.colorScheme.onSurface,
                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)
                        )
                    }
                }
            }

            barber.availableHomeSlots.chunked(4).forEach { rowSlots ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    rowSlots.forEach { slot ->
                        val isBlocked = blockedForDay.contains(slot)
                        Surface(
                            shape = RoundedCornerShape(8.dp),
                            color = if (isBlocked) BarberRose.copy(alpha = 0.14f) else BarberEmerald.copy(alpha = 0.14f),
                            border = BorderStroke(
                                1.dp,
                                if (isBlocked) BarberRose.copy(alpha = 0.5f) else BarberEmerald.copy(alpha = 0.5f)
                            ),
                            modifier = Modifier
                                .weight(1f)
                                .clickable { onToggleSlot(selectedDate, slot) }
                        ) {
                            Column(
                                modifier = Modifier.padding(vertical = 6.dp),
                                horizontalAlignment = Alignment.CenterHorizontally
                            ) {
                                Text(
                                    text = slot,
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = if (isBlocked) BarberRose else BarberEmerald
                                )
                                Text(
                                    text = if (isBlocked) "Bloqué" else "Ouvert",
                                    fontSize = 9.sp,
                                    color = if (isBlocked) BarberRose else BarberEmerald
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
