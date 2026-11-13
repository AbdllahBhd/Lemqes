package com.example.ui.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.model.*
import com.example.ui.theme.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeServiceBookingSheet(
    barber: BarberProfile,
    preselectedService: ServiceItem? = null,
    currentUser: UserAccount? = null,
    getAvailableSlots: (date: String) -> List<HomeSlotAvailability>,
    onSubmitHomeBooking: (
        selectedServices: List<ServiceItem>,
        date: String,
        slot: String,
        customerName: String,
        customerPhone: String,
        customerAddress: String,
        clientLat: Double,
        clientLng: Double,
        notes: String,
        paymentMethod: PaymentMethod
    ) -> Unit,
    onDismiss: () -> Unit
) {
    val isWomen = barber.targetAudience == TargetAudience.WOMEN
    val accentColor = if (isWomen) BeautyFuchsia else BarberGoldPrimary
    val accentTextColor = if (isWomen) Color.White else Color.Black

    // Selected services (supports multi-select from artist's priced list)
    var selectedServiceIds by remember(barber.id, preselectedService?.id) {
        mutableStateOf(
            when {
                preselectedService != null -> setOf(preselectedService.id)
                barber.services.isNotEmpty() -> setOf(barber.services.first().id)
                else -> emptySet()
            }
        )
    }

    val dates = listOf("Aujourd'hui", "Demain", "Jeudi", "Vendredi", "Samedi")
    var selectedDate by remember { mutableStateOf(dates.first()) }
    val slotAvailability = remember(barber, selectedDate) { getAvailableSlots(selectedDate) }
    var selectedSlot by remember(selectedDate, slotAvailability) {
        mutableStateOf(slotAvailability.firstOrNull { it.isAvailable }?.slot ?: "")
    }

    // Map coordinates & address
    var clientLat by remember(barber.id) { mutableStateOf(barber.currentWorkplace.latitude + 0.004) }
    var clientLng by remember(barber.id) { mutableStateOf(barber.currentWorkplace.longitude + 0.005) }
    var customerAddress by remember { mutableStateOf("") }

    // Contact details & extra info
    var customerName by remember(currentUser?.id) {
        mutableStateOf(currentUser?.fullName?.takeIf { it.isNotBlank() } ?: "")
    }
    var customerPhone by remember(currentUser?.id) {
        mutableStateOf(currentUser?.phoneNumber?.takeIf { it.isNotBlank() } ?: "")
    }
    var customerNotes by remember { mutableStateOf("") }
    var selectedVisitTags by remember { mutableStateOf(setOf("1 personne")) }
    var selectedPayment by remember { mutableStateOf(PaymentMethod.CASH) }

    val selectedServices = barber.services.filter { selectedServiceIds.contains(it.id) }
    val servicesSubtotal = selectedServices.sumOf { it.priceDzd }
    val totalDuration = selectedServices.sumOf { it.durationMinutes }
    val travelFee = barber.homeServiceFeeDzd.coerceAtLeast(0)
    val totalPriceDzd = servicesSubtotal + travelFee

    val canSubmit = selectedServices.isNotEmpty() &&
        selectedSlot.isNotBlank() &&
        customerName.isNotBlank() &&
        customerPhone.replace(" ", "").length >= 8 &&
        customerAddress.isNotBlank()

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = MaterialTheme.colorScheme.surface
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 10.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            // 1. Artist & Strict Audience Header
            Surface(
                shape = RoundedCornerShape(16.dp),
                color = accentColor.copy(alpha = 0.12f),
                border = BorderStroke(1.dp, accentColor.copy(alpha = 0.45f)),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier.padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    ProfileAvatarImage(
                        avatarUrl = barber.avatarUrl,
                        fallbackIcon = if (isWomen) Icons.Default.Spa else Icons.Default.ContentCut,
                        contentDescription = barber.name,
                        accentColor = accentColor,
                        size = 48.dp
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = if (isWomen) "🏠 Beauté à Domicile • Espace Dames" else "🏠 Barbier à Domicile • Espace Hommes",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            color = accentColor
                        )
                        Text(
                            text = barber.name,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Text(
                            text = "Rayon ${barber.homeServiceRadiusKm} km • Dépl. ${if (travelFee == 0) "Offert" else "+$travelFee DA"}",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            // 2. Service Selection (with Artist Prices shown)
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = if (isWomen) "1. Prestations Dames & Tarifs" else "1. Prestations Hommes & Tarifs",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        text = "${selectedServices.size} choisie(s)",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        color = accentColor
                    )
                }

                barber.services.forEach { srv ->
                    val isSelected = selectedServiceIds.contains(srv.id)
                    Surface(
                        shape = RoundedCornerShape(12.dp),
                        color = if (isSelected) accentColor.copy(alpha = 0.14f) else MaterialTheme.colorScheme.surfaceVariant,
                        border = BorderStroke(
                            width = if (isSelected) 1.5.dp else 0.5.dp,
                            color = if (isSelected) accentColor else MaterialTheme.colorScheme.outline.copy(alpha = 0.45f)
                        ),
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable {
                                selectedServiceIds = if (isSelected && selectedServiceIds.size > 1) {
                                    selectedServiceIds - srv.id
                                } else {
                                    selectedServiceIds + srv.id
                                }
                            }
                            .testTag("home_srv_pick_${srv.id}")
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                imageVector = if (isSelected) Icons.Default.CheckBox else Icons.Default.CheckBoxOutlineBlank,
                                contentDescription = null,
                                tint = if (isSelected) accentColor else MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.size(20.dp)
                            )
                            Spacer(modifier = Modifier.width(10.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = srv.nameFr,
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                                Text(
                                    text = "${srv.category.labelFr} • ${srv.durationMinutes} min",
                                    fontSize = 11.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            Text(
                                text = "${srv.priceDzd} DA",
                                fontSize = 13.sp,
                                fontWeight = FontWeight.Black,
                                color = accentColor
                            )
                        }
                    }
                }
            }

            // 3. Date & Available Spots
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                val openCount = slotAvailability.count { it.isAvailable }
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "2. Créneau disponible à domicile",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        text = "$openCount créneaux libres",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = if (openCount > 0) BarberEmerald else BarberRose
                    )
                }

                LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(dates) { day ->
                        val isDaySel = day == selectedDate
                        Surface(
                            shape = RoundedCornerShape(10.dp),
                            color = if (isDaySel) accentColor else MaterialTheme.colorScheme.surfaceVariant,
                            modifier = Modifier
                                .clickable { selectedDate = day }
                                .testTag("home_date_$day")
                        ) {
                            Text(
                                text = day,
                                fontSize = 12.sp,
                                fontWeight = if (isDaySel) FontWeight.Bold else FontWeight.Medium,
                                color = if (isDaySel) accentTextColor else MaterialTheme.colorScheme.onSurface,
                                modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp)
                            )
                        }
                    }
                }

                // 2-row grid of spots
                slotAvailability.chunked(4).forEach { rowSlots ->
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        rowSlots.forEach { slotItem ->
                            val isSel = slotItem.slot == selectedSlot && slotItem.isAvailable
                            Surface(
                                shape = RoundedCornerShape(10.dp),
                                color = when {
                                    !slotItem.isAvailable -> MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f)
                                    isSel -> accentColor
                                    else -> MaterialTheme.colorScheme.surfaceVariant
                                },
                                border = BorderStroke(
                                    width = if (isSel) 1.5.dp else 0.5.dp,
                                    color = when {
                                        !slotItem.isAvailable -> MaterialTheme.colorScheme.outline.copy(alpha = 0.2f)
                                        isSel -> accentColor
                                        else -> MaterialTheme.colorScheme.outline.copy(alpha = 0.5f)
                                    }
                                ),
                                modifier = Modifier
                                    .weight(1f)
                                    .heightIn(min = 48.dp)
                                    .clickable(enabled = slotItem.isAvailable) {
                                        selectedSlot = slotItem.slot
                                    }
                                    .testTag("home_slot_${slotItem.slot}")
                            ) {
                                Column(
                                    modifier = Modifier.padding(vertical = 7.dp),
                                    horizontalAlignment = Alignment.CenterHorizontally,
                                    verticalArrangement = Arrangement.Center
                                ) {
                                    Text(
                                        text = slotItem.slot,
                                        fontSize = 12.sp,
                                        fontWeight = if (isSel) FontWeight.Bold else FontWeight.SemiBold,
                                        color = when {
                                            !slotItem.isAvailable -> MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)
                                            isSel -> accentTextColor
                                            else -> MaterialTheme.colorScheme.onSurface
                                        }
                                    )
                                    if (!slotItem.isAvailable) {
                                        Text(
                                            text = "Occupé",
                                            fontSize = 9.sp,
                                            color = BarberRose
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 4. Interactive Map Location Picker + Exact Address
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = "3. Votre position sur la carte & Adresse *",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold
                )
                HomeMapLocationPicker(
                    artistLatitude = barber.currentWorkplace.latitude,
                    artistLongitude = barber.currentWorkplace.longitude,
                    artistRadiusKm = barber.homeServiceRadiusKm,
                    clientLatitude = clientLat,
                    clientLongitude = clientLng,
                    accentColor = accentColor,
                    onLocationPicked = { lat, lng, suggestedZone ->
                        clientLat = lat
                        clientLng = lng
                        if (!suggestedZone.isNullOrBlank() && customerAddress.isBlank()) {
                            customerAddress = suggestedZone
                        }
                    }
                )

                OutlinedTextField(
                    value = customerAddress,
                    onValueChange = { customerAddress = it },
                    label = { Text("Adresse exacte (Quartier, Rue, Bâtiment, Étage) *") },
                    placeholder = { Text("ex. Hydra, Rue Sidi Yahia, Bât B, 2ème étage") },
                    leadingIcon = { Icon(Icons.Default.Home, contentDescription = null, tint = BarberEmerald) },
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("home_booking_address_input")
                )
            }

            // 5. Contact Information & Visit Preferences
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    text = "4. Coordonnées de contact & Détails",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold
                )

                OutlinedTextField(
                    value = customerName,
                    onValueChange = { customerName = it },
                    label = { Text("Votre nom complet *") },
                    placeholder = { Text(if (isWomen) "ex. Meriem S." else "ex. Amine Benali") },
                    leadingIcon = { Icon(Icons.Default.Person, contentDescription = null, tint = accentColor) },
                    singleLine = true,
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("home_booking_name_input")
                )

                OutlinedTextField(
                    value = customerPhone,
                    onValueChange = { customerPhone = it },
                    label = { Text("Numéro de téléphone joignable *") },
                    placeholder = { Text("0550 12 34 56") },
                    leadingIcon = { Icon(Icons.Default.Phone, contentDescription = null, tint = BarberEmerald) },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                    singleLine = true,
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("home_booking_phone_input")
                )

                // Quick tags ("and other things")
                val extraOptions = listOf(
                    "1 personne",
                    "2 personnes",
                    "Matériel stérilisé requis",
                    "Parking devant l'immeuble",
                    "Appeler en arrivant"
                )
                LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    items(extraOptions) { tag ->
                        val isTagSel = selectedVisitTags.contains(tag)
                        FilterChip(
                            selected = isTagSel,
                            onClick = {
                                selectedVisitTags = if (isTagSel) selectedVisitTags - tag else selectedVisitTags + tag
                            },
                            label = { Text(tag, fontSize = 11.sp) }
                        )
                    }
                }

                OutlinedTextField(
                    value = customerNotes,
                    onValueChange = { customerNotes = it },
                    label = { Text("Précisions d'accès ou préférences (interphone, instructions...)") },
                    placeholder = { Text("ex. Code portail 2410, sonner à l'interphone 8") },
                    leadingIcon = { Icon(Icons.Default.EditNote, contentDescription = null, tint = accentColor) },
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("home_booking_notes_input")
                )

                Text("Mode de paiement à la visite :", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    listOf(PaymentMethod.CASH, PaymentMethod.BARIDIMOB, PaymentMethod.DAHABIA).forEach { pm ->
                        val sel = selectedPayment == pm
                        Surface(
                            shape = RoundedCornerShape(10.dp),
                            color = if (sel) accentColor.copy(alpha = 0.18f) else MaterialTheme.colorScheme.surfaceVariant,
                            border = BorderStroke(
                                width = if (sel) 1.5.dp else 0.5.dp,
                                color = if (sel) accentColor else MaterialTheme.colorScheme.outline.copy(alpha = 0.45f)
                            ),
                            modifier = Modifier
                                .weight(1f)
                                .clickable { selectedPayment = pm }
                        ) {
                            Box(
                                modifier = Modifier.padding(vertical = 8.dp, horizontal = 4.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = if (pm == PaymentMethod.CASH) "Espèces" else pm.labelFr,
                                    fontSize = 11.sp,
                                    fontWeight = if (sel) FontWeight.Bold else FontWeight.Medium,
                                    color = if (sel) accentColor else MaterialTheme.colorScheme.onSurface
                                )
                            }
                        }
                    }
                }
            }

            // 6. Total Breakdown + Confirmation Info
            Surface(
                shape = RoundedCornerShape(14.dp),
                color = MaterialTheme.colorScheme.surfaceVariant,
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text("Prestations ($totalDuration min)", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text("$servicesSubtotal DA", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                    }
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text("Frais de déplacement artiste", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text(
                            text = if (travelFee == 0) "Offert" else "+$travelFee DA",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = BarberEmerald
                        )
                    }
                    HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text("Total estimé", fontSize = 14.sp, fontWeight = FontWeight.Bold)
                        Text("$totalPriceDzd DA", fontSize = 15.sp, fontWeight = FontWeight.Black, color = accentColor)
                    }
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = "🔔 L'artiste recevra votre demande avec votre contact et localisation sur la carte pour confirmer. Vous serez notifié(e) dès sa confirmation.",
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        lineHeight = 15.sp
                    )
                }
            }

            if (!canSubmit) {
                Text(
                    text = "Complétez votre nom, téléphone (min 8 chiffres), adresse et choisissez un créneau libre pour envoyer la demande.",
                    fontSize = 11.sp,
                    color = BarberAmber
                )
            }

            Button(
                onClick = {
                    val combinedNotes = buildString {
                        if (selectedVisitTags.isNotEmpty()) {
                            append(selectedVisitTags.joinToString(" • "))
                        }
                        if (customerNotes.isNotBlank()) {
                            if (isNotEmpty()) append(" — ")
                            append(customerNotes.trim())
                        }
                    }
                    onSubmitHomeBooking(
                        selectedServices,
                        selectedDate,
                        selectedSlot,
                        customerName,
                        customerPhone,
                        customerAddress,
                        clientLat,
                        clientLng,
                        combinedNotes,
                        selectedPayment
                    )
                },
                enabled = canSubmit,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp)
                    .testTag("submit_home_booking_btn"),
                colors = ButtonDefaults.buttonColors(containerColor = accentColor, contentColor = accentTextColor),
                shape = RoundedCornerShape(14.dp)
            ) {
                Icon(Icons.Default.Send, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = "Envoyer la demande ($totalPriceDzd DA)",
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.sp
                )
            }

            Spacer(modifier = Modifier.height(16.dp))
        }
    }
}
