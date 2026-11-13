package com.example.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
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
import com.example.model.BarberProfile
import com.example.model.ServiceItem
import com.example.model.WorkplaceType
import com.example.ui.theme.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BookingBottomSheet(
    barber: BarberProfile,
    service: ServiceItem,
    onConfirmBooking: (date: String, slot: String, isHomeService: Boolean, customerAddress: String?) -> Unit,
    onJoinQueueRemotely: () -> Unit,
    onDismiss: () -> Unit,
    onOpenFullHomeVisitFlow: (() -> Unit)? = null
) {
    val dates = listOf("Aujourd'hui", "Demain", "Jeudi", "Vendredi")
    var selectedDate by remember { mutableStateOf(dates.first()) }

    val slots = listOf("15:00", "15:30", "16:00", "16:30", "17:30", "18:00", "19:00", "19:30")
    var selectedSlot by remember { mutableStateOf(slots[1]) }

    val isMobileOnly = barber.currentWorkplace.type == WorkplaceType.FREELANCE_MOBILE
    val supportsHome = barber.offersHomeService || isMobileOnly
    var isHomeService by remember(barber.id) { mutableStateOf(isMobileOnly) }
    var customerAddress by remember { mutableStateOf("") }

    val travelFee = if (isHomeService) barber.homeServiceFeeDzd else 0
    val totalPriceDzd = service.priceDzd + travelFee
    val canConfirm = !isHomeService || customerAddress.isNotBlank()

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = MaterialTheme.colorScheme.surface
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 12.dp)
        ) {
            // Header
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "Réservation avec ${barber.name}",
                        fontSize = 17.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Text(
                        text = "${service.nameFr} • ${service.priceDzd} DA (${service.durationMinutes} min)",
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = BarberGoldPrimary
                    )
                }
            }

            Spacer(modifier = Modifier.height(14.dp))

            // Service Mode Selector (Salon vs À Domicile)
            if (supportsHome) {
                if (isMobileOnly) {
                    Surface(
                        shape = RoundedCornerShape(12.dp),
                        color = BarberEmerald.copy(alpha = 0.14f),
                        border = androidx.compose.foundation.BorderStroke(1.dp, BarberEmerald.copy(alpha = 0.45f)),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Row(
                            modifier = Modifier.padding(12.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(Icons.Default.HomeRepairService, contentDescription = null, tint = BarberEmerald, modifier = Modifier.size(20.dp))
                            Spacer(modifier = Modifier.width(8.dp))
                            Column {
                                Text(
                                    text = "🏠 Prestation 100% à Domicile",
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = BarberEmerald
                                )
                                Text(
                                    text = "Rayon ${barber.homeServiceRadiusKm} km • Zones : ${barber.homeServiceZones.ifBlank { barber.currentWorkplace.address }}",
                                    fontSize = 11.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                } else {
                    Text("Mode de prestation", fontSize = 13.sp, fontWeight = FontWeight.Bold)
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Surface(
                            shape = RoundedCornerShape(12.dp),
                            color = if (!isHomeService) BarberGoldPrimary.copy(alpha = 0.2f) else MaterialTheme.colorScheme.surfaceVariant,
                            modifier = Modifier
                                .weight(1f)
                                .border(
                                    width = if (!isHomeService) 1.5.dp else 0.5.dp,
                                    color = if (!isHomeService) BarberGoldPrimary else MaterialTheme.colorScheme.outline,
                                    shape = RoundedCornerShape(12.dp)
                                )
                                .clickable { isHomeService = false }
                                .testTag("booking_mode_shop")
                        ) {
                            Column(modifier = Modifier.padding(10.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                                Text("🏢 Au salon", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                                Text("Sans frais dépl.", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }

                        Surface(
                            shape = RoundedCornerShape(12.dp),
                            color = if (isHomeService) BarberEmerald.copy(alpha = 0.2f) else MaterialTheme.colorScheme.surfaceVariant,
                            modifier = Modifier
                                .weight(1f)
                                .border(
                                    width = if (isHomeService) 1.5.dp else 0.5.dp,
                                    color = if (isHomeService) BarberEmerald else MaterialTheme.colorScheme.outline,
                                    shape = RoundedCornerShape(12.dp)
                                )
                                .clickable { isHomeService = true }
                                .testTag("booking_mode_home")
                        ) {
                            Column(modifier = Modifier.padding(10.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                                Text("🏠 À domicile", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = BarberEmerald)
                                Text(
                                    text = if (barber.homeServiceFeeDzd == 0) "Dépl. offert" else "+${barber.homeServiceFeeDzd} DA dépl.",
                                    fontSize = 10.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
                Spacer(modifier = Modifier.height(14.dp))
            }

            if (isHomeService) {
                if (onOpenFullHomeVisitFlow != null) {
                    Button(
                        onClick = onOpenFullHomeVisitFlow,
                        colors = ButtonDefaults.buttonColors(containerColor = BarberEmerald, contentColor = Color.White),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(48.dp)
                            .testTag("btn_switch_to_full_home_map")
                    ) {
                        Icon(Icons.Default.Map, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(modifier = Modifier.width(6.dp))
                        Text("Choisir position sur la carte, créneau & contact ➜", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    }
                    Spacer(modifier = Modifier.height(10.dp))
                }
                Text("Adresse complète pour la visite à domicile *", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                Spacer(modifier = Modifier.height(6.dp))
                OutlinedTextField(
                    value = customerAddress,
                    onValueChange = { customerAddress = it },
                    placeholder = { Text("Ex: Hydra, Rue Djemila Bât B, Apt 4 (repère)") },
                    leadingIcon = { Icon(Icons.Default.LocationOn, contentDescription = null, tint = BarberEmerald) },
                    singleLine = true,
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("home_booking_address_input")
                )
                if (customerAddress.isBlank()) {
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = "Indiquez votre quartier, rue et numéro d'appartement pour le déplacement.",
                        fontSize = 11.sp,
                        color = BarberAmber
                    )
                }

                Spacer(modifier = Modifier.height(10.dp))

                // Home service price breakdown
                Surface(
                    shape = RoundedCornerShape(12.dp),
                    color = MaterialTheme.colorScheme.surfaceVariant,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(modifier = Modifier.padding(12.dp)) {
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("Prestation (${service.nameFr})", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text("${service.priceDzd} DA", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                        }
                        Spacer(modifier = Modifier.height(4.dp))
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("Frais de déplacement", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text(
                                text = if (travelFee == 0) "Offert" else "+$travelFee DA",
                                fontSize = 12.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = BarberEmerald
                            )
                        }
                        HorizontalDivider(modifier = Modifier.padding(vertical = 6.dp))
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("Total à payer", fontSize = 13.sp, fontWeight = FontWeight.Bold)
                            Text("$totalPriceDzd DA", fontSize = 14.sp, fontWeight = FontWeight.Black, color = BarberGoldPrimary)
                        }
                    }
                }
            } else {
                // Location Snapshot Notice
                Surface(
                    shape = RoundedCornerShape(12.dp),
                    color = MaterialTheme.colorScheme.surfaceVariant,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier.padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = Icons.Default.Storefront,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(20.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Column {
                            Text(
                                text = "Lieu au moment du rendez-vous :",
                                fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Text(
                                text = "${barber.currentWorkplace.shopName} - ${barber.currentWorkplace.commune}",
                                fontSize = 13.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Select Date
            Text("1. Choisir le jour", fontSize = 13.sp, fontWeight = FontWeight.Bold)
            Spacer(modifier = Modifier.height(8.dp))
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(dates) { d ->
                    val isSelected = d == selectedDate
                    Surface(
                        shape = RoundedCornerShape(10.dp),
                        color = if (isSelected) BarberGoldPrimary else MaterialTheme.colorScheme.surfaceVariant,
                        modifier = Modifier
                            .clickable { selectedDate = d }
                            .padding(vertical = 2.dp)
                    ) {
                        Text(
                            text = d,
                            fontSize = 12.sp,
                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                            color = if (isSelected) Color.Black else MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp)
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Select Time Slot
            Text("2. Choisir l'heure du créneau", fontSize = 13.sp, fontWeight = FontWeight.Bold)
            Spacer(modifier = Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                slots.take(4).forEach { s ->
                    val isSelected = s == selectedSlot
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(10.dp))
                            .background(if (isSelected) BarberGoldPrimary else MaterialTheme.colorScheme.surfaceVariant)
                            .clickable { selectedSlot = s }
                            .padding(vertical = 10.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = s,
                            fontSize = 13.sp,
                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                            color = if (isSelected) Color.Black else MaterialTheme.colorScheme.onSurface
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(14.dp))

            // Appointment Reminder & 15-min Auto-Cancel Policy Notice
            Surface(
                shape = RoundedCornerShape(12.dp),
                color = BarberAmber.copy(alpha = 0.14f),
                border = androidx.compose.foundation.BorderStroke(1.dp, BarberAmber.copy(alpha = 0.45f)),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier.padding(12.dp),
                    verticalAlignment = Alignment.Top
                ) {
                    Icon(
                        imageVector = Icons.Default.NotificationsActive,
                        contentDescription = null,
                        tint = BarberAmber,
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Column {
                        Text(
                            text = if (isHomeService) "Rappels -1h / -30m & Confirmation d'accès" else "Règle d'arrivée obligatoire (-15 min)",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold,
                            color = BarberAmber
                        )
                        Spacer(modifier = Modifier.height(2.dp))
                        Text(
                            text = if (isHomeService) {
                                "Vous recevrez un rappel 1h et 30 min avant l'arrivée de l'artiste. Confirmez votre disponibilité 15 min avant pour éviter l'annulation automatique."
                            } else {
                                "Vous recevrez un rappel 1h et 30 min avant le RDV. Vous devez arriver au salon 15 min avant pour confirmer votre présence, sinon votre place est annulée automatiquement."
                            },
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Dual Action: Confirm Booking OR Direct Live Queue
            Button(
                onClick = {
                    onConfirmBooking(
                        selectedDate,
                        selectedSlot,
                        isHomeService,
                        if (isHomeService) customerAddress.trim() else null
                    )
                },
                enabled = canConfirm,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp)
                    .testTag("confirm_booking_btn"),
                colors = ButtonDefaults.buttonColors(containerColor = BarberGoldPrimary, contentColor = Color.Black),
                shape = RoundedCornerShape(12.dp)
            ) {
                Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(modifier = Modifier.width(6.dp))
                Text(
                    text = if (isHomeService) {
                        "Confirmer à domicile ($totalPriceDzd DA)"
                    } else {
                        "Confirmer le RDV ($selectedDate à $selectedSlot)"
                    },
                    fontWeight = FontWeight.Bold
                )
            }

            if (!isHomeService) {
                Spacer(modifier = Modifier.height(8.dp))

                // Quick live queue option
                OutlinedButton(
                    onClick = onJoinQueueRemotely,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(44.dp)
                        .testTag("join_queue_remotely_btn"),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(Icons.AutoMirrored.Filled.DirectionsRun, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("Ou : Rejoindre la file en direct maintenant", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                }
            }

            Spacer(modifier = Modifier.height(20.dp))
        }
    }
}

