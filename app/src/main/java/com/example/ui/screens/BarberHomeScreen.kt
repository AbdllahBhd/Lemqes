package com.example.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
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
import com.example.ui.components.ArtistHomeVisitRequestsCard
import com.example.ui.components.ArtistNotificationsBannerCard
import com.example.ui.components.ArtistSlotAvailabilityManagerCard
import com.example.ui.components.BarberQueueControlsCard
import com.example.ui.components.BarberWorkplaceHeroCard
import com.example.ui.components.DashboardServiceManagerCard
import com.example.ui.components.FastStatusToggle
import com.example.ui.components.ProfileAvatarImage
import com.example.ui.components.ProfilePhotoPickerCard
import com.example.ui.theme.*

@Composable
fun BarberHomeScreen(
    barber: BarberProfile,
    queue: List<QueueCustomer>,
    bookings: List<BookingRecord>,
    onStatusChange: (BarberStatus) -> Unit,
    onChangeWorkplaceClick: () -> Unit,
    onBroadcastClick: () -> Unit,
    onShowQrClick: () -> Unit,
    onAddWalkIn: () -> Unit,
    onCustomerDone: () -> Unit,
    onCallNext: () -> Unit,
    onRemoveQueueItem: (String) -> Unit,
    onOpenCashIn: ((QueueCustomer?) -> Unit)? = null,
    onNavigateToFinances: (() -> Unit)? = null,
    onToggleShowCutPrices: ((Boolean) -> Unit)? = null,
    onOpenPromotionDialog: (() -> Unit)? = null,
    onEndPromotion: (() -> Unit)? = null,
    onUpdateHomeServiceSettings: ((offersHomeService: Boolean, feeDzd: Int, radiusKm: Int, zones: String) -> Unit)? = null,
    onUpdateAvatar: ((String) -> Unit)? = null,
    onTogglePresetService: ((String) -> Unit)? = null,
    onAddCustomService: ((name: String, priceDzd: Int, durationMinutes: Int) -> Unit)? = null,
    onRemoveService: ((serviceId: String) -> Unit)? = null,
    notifications: List<AppNotification> = emptyList(),
    onConfirmHomeBooking: ((String) -> Unit)? = null,
    onDeclineHomeBooking: ((String) -> Unit)? = null,
    onArtistOnTheWay: ((String, Int) -> Unit)? = null,
    onArtistArrived: ((String) -> Unit)? = null,
    onCompleteHomeBooking: ((String) -> Unit)? = null,
    onToggleBlockedHomeSlot: ((date: String, slot: String) -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
        contentPadding = PaddingValues(top = 12.dp, bottom = 80.dp)
    ) {
        // 1. Portable Barber Banner
        item {
            Surface(
                shape = RoundedCornerShape(12.dp),
                color = BarberGoldPrimary.copy(alpha = 0.12f),
                modifier = Modifier
                    .fillMaxWidth()
                    .border(1.dp, BarberGoldPrimary.copy(alpha = 0.3f), RoundedCornerShape(12.dp))
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.VerifiedUser,
                        contentDescription = null,
                        tint = BarberGoldPrimary,
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "Profil 100% indépendant : vos clients, avis et historique vous suivent partout.",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                }
            }
        }

        // 1b. Profile Picture Card (Barber / Artiste à Domicile)
        item {
            val isWomen = barber.targetAudience == TargetAudience.WOMEN
            val accentCol = if (isWomen) BeautyFuchsia else BarberGoldPrimary
            if (onUpdateAvatar != null) {
                ProfilePhotoPickerCard(
                    avatarUrl = barber.avatarUrl,
                    title = "${barber.name} • Photo de profil",
                    subtitle = "Choisissez une photo depuis votre galerie",
                    accentColor = accentCol,
                    fallbackIcon = if (isWomen) Icons.Default.Spa else Icons.Default.Person,
                    testTagPrefix = "dashboard_barber",
                    onPhotoPicked = onUpdateAvatar,
                    onRemovePhoto = if (barber.avatarUrl.isNotBlank()) ({ onUpdateAvatar("") }) else null
                )
            } else {
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                    ProfileAvatarImage(
                        avatarUrl = barber.avatarUrl,
                        fallbackIcon = if (isWomen) Icons.Default.Spa else Icons.Default.Person,
                        contentDescription = barber.name,
                        accentColor = accentCol,
                        size = 48.dp
                    )
                    Spacer(modifier = Modifier.width(10.dp))
                    Text(barber.name, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                }
            }
        }

        // 2. Ultra-Fast Status Selector (🟢 Dispo / 🟡 Pause / 🔴 Fermé)
        item {
            FastStatusToggle(
                currentStatus = barber.status,
                onStatusChange = onStatusChange
            )
        }

        // 2b. Artist Notifications Banner (Home Requests, Arrivals, Confirmations)
        if (notifications.isNotEmpty()) {
            item {
                val accentCol = if (barber.targetAudience == TargetAudience.WOMEN) BeautyFuchsia else BarberGoldPrimary
                ArtistNotificationsBannerCard(
                    notifications = notifications,
                    accentColor = accentCol
                )
            }
        }

        // 2c. Pending & Active Home Visit Requests Confirmation Console
        if (barber.offersHomeService || barber.currentWorkplace.type == WorkplaceType.FREELANCE_MOBILE) {
            val hasHomeBookings = bookings.any {
                it.isHomeService && (it.barberId == barber.id || it.status == BookingStatus.WAITING_APPROVAL)
            }
            if (hasHomeBookings && onConfirmHomeBooking != null && onDeclineHomeBooking != null) {
                item {
                    val accentCol = if (barber.targetAudience == TargetAudience.WOMEN) BeautyFuchsia else BarberGoldPrimary
                    ArtistHomeVisitRequestsCard(
                        barberId = barber.id,
                        homeBookings = bookings,
                        accentColor = accentCol,
                        onConfirmBooking = onConfirmHomeBooking,
                        onDeclineBooking = onDeclineHomeBooking,
                        onArtistOnTheWay = { id, eta -> onArtistOnTheWay?.invoke(id, eta) },
                        onArtistArrived = { id -> onArtistArrived?.invoke(id) },
                        onCompleteHomeBooking = { id -> onCompleteHomeBooking?.invoke(id) }
                    )
                }
            }
        }

        // 3. Tarifs & Promotions (Toggle show cut prices + Launch promo with push notification)
        item {
            Card(
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(14.dp)) {
                    // Row 1: Toggle show prices to customers
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.weight(1f)) {
                            Icon(
                                Icons.Default.Visibility,
                                contentDescription = null,
                                tint = BarberGoldPrimary,
                                modifier = Modifier.size(20.dp)
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Column {
                                val isWomenAudience = barber.targetAudience == TargetAudience.WOMEN
                                Text(
                                    text = if (isWomenAudience) "Afficher le prix de mes prestations" else "Afficher le prix de mes coupes",
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                                Text(
                                    text = if (barber.privacySettings.showCutPrices) {
                                        if (isWomenAudience) "Visible aux clientes" else "Visible aux clients (Coupe dès 600 DA)"
                                    } else {
                                        "Masqué aux clients (Tarif au salon)"
                                    },
                                    fontSize = 11.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }

                        Switch(
                            checked = barber.privacySettings.showCutPrices,
                            onCheckedChange = { onToggleShowCutPrices?.invoke(it) },
                            colors = SwitchDefaults.colors(
                                checkedThumbColor = BarberGoldPrimary,
                                checkedTrackColor = BarberGoldPrimary.copy(alpha = 0.3f)
                            )
                        )
                    }

                    Spacer(modifier = Modifier.height(10.dp))

                    // Promotion Area
                    if (barber.activePromotion != null) {
                        Surface(
                            shape = RoundedCornerShape(12.dp),
                            color = BarberRose.copy(alpha = 0.15f),
                            modifier = Modifier
                                .fillMaxWidth()
                                .border(1.dp, BarberRose.copy(alpha = 0.5f), RoundedCornerShape(12.dp))
                        ) {
                            Row(
                                modifier = Modifier.padding(12.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Icon(Icons.Default.LocalOffer, contentDescription = null, tint = BarberRose, modifier = Modifier.size(16.dp))
                                        Spacer(modifier = Modifier.width(6.dp))
                                        Text(
                                            text = "PROMO EN COURS (−${barber.activePromotion.discountPercent}%)",
                                            fontSize = 11.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = BarberRose
                                        )
                                    }
                                    Text(
                                        text = "${barber.activePromotion.title} • ${barber.activePromotion.discountedPriceDzd} DA",
                                        fontSize = 13.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = MaterialTheme.colorScheme.onSurface
                                    )
                                    Text(
                                        text = "Valable jusqu'à ${barber.activePromotion.expiresAt} (Notifié aux abonnés)",
                                        fontSize = 10.sp,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }

                                TextButton(
                                    onClick = { onEndPromotion?.invoke() },
                                    colors = ButtonDefaults.textButtonColors(contentColor = BarberRose)
                                ) {
                                    Text("Arrêter", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                                }
                            }
                        }
                    } else {
                        Button(
                            onClick = { onOpenPromotionDialog?.invoke() },
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(44.dp)
                                .testTag("btn_launch_promo"),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = BarberRose,
                                contentColor = Color.White
                            ),
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Icon(Icons.Default.LocalOffer, contentDescription = null, modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(
                                text = "Lancer une promotion / Réduction aux abonnés",
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }
                }
            }
        }

        // 4. Current Workplace Hero Card (Change in 30s)
        item {
            BarberWorkplaceHeroCard(
                workplace = barber.currentWorkplace,
                onChangeWorkplaceClick = onChangeWorkplaceClick,
                onBroadcastClick = onBroadcastClick,
                subscribersCount = barber.subscribersCount
            )
        }

        // 4a. Services Manager Card (Select from list or type custom services)
        if (onTogglePresetService != null && onAddCustomService != null && onRemoveService != null) {
            item {
                val isWomen = barber.targetAudience == TargetAudience.WOMEN
                val accentCol = if (isWomen) BeautyFuchsia else BarberGoldPrimary
                DashboardServiceManagerCard(
                    title = if (barber.offersHomeService) "Services proposés à domicile" else "Services proposés",
                    targetAudience = barber.targetAudience,
                    accentColor = accentCol,
                    currentServices = barber.services,
                    isHomeArtist = barber.offersHomeService || barber.currentWorkplace.type == WorkplaceType.FREELANCE_MOBILE,
                    onTogglePresetService = onTogglePresetService,
                    onAddCustomService = onAddCustomService,
                    onRemoveService = onRemoveService
                )
            }
        }

        // 4b. Dedicated Home Service Mobility Card (For Artiste à Domicile & Home-capable pros)
        if (barber.offersHomeService || barber.currentWorkplace.type == WorkplaceType.FREELANCE_MOBILE) {
            item {
                var editingMobility by remember { mutableStateOf(false) }
                var draftRadius by remember(barber.id, barber.homeServiceRadiusKm) { mutableStateOf(barber.homeServiceRadiusKm) }
                var draftFee by remember(barber.id, barber.homeServiceFeeDzd) { mutableStateOf(barber.homeServiceFeeDzd) }
                var draftZones by remember(barber.id, barber.homeServiceZones) { mutableStateOf(barber.homeServiceZones) }

                Card(
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = BarberEmerald.copy(alpha = 0.12f)),
                    modifier = Modifier
                        .fillMaxWidth()
                        .border(1.dp, BarberEmerald.copy(alpha = 0.45f), RoundedCornerShape(16.dp))
                        .testTag("home_artist_mobility_card")
                ) {
                    Column(modifier = Modifier.padding(14.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.weight(1f)) {
                                Icon(Icons.Default.HomeRepairService, contentDescription = null, tint = BarberEmerald, modifier = Modifier.size(20.dp))
                                Spacer(modifier = Modifier.width(8.dp))
                                Column {
                                    Text(
                                        text = "🏠 Mode Artiste à Domicile (${if (barber.targetAudience == TargetAudience.WOMEN) "Dames" else "Hommes"})",
                                        fontSize = 13.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = BarberEmerald
                                    )
                                    Text(
                                        text = "Rayon ${barber.homeServiceRadiusKm} km • Dépl. ${if (barber.homeServiceFeeDzd == 0) "Offert" else "${barber.homeServiceFeeDzd} DA"} • Kit stérilisé ✓",
                                        fontSize = 11.sp,
                                        color = MaterialTheme.colorScheme.onSurface
                                    )
                                }
                            }
                            TextButton(
                                onClick = { editingMobility = !editingMobility },
                                modifier = Modifier.testTag("btn_edit_home_mobility")
                            ) {
                                Text(if (editingMobility) "Fermer" else "Configurer", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = BarberEmerald)
                            }
                        }

                        if (barber.homeServiceZones.isNotBlank() && !editingMobility) {
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = "Quartiers couverts : ${barber.homeServiceZones}",
                                fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }

                        if (editingMobility) {
                            Spacer(modifier = Modifier.height(10.dp))
                            Text("Rayon de déplacement :", fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                            Spacer(modifier = Modifier.height(4.dp))
                            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                listOf(5, 10, 20, 30).forEach { r ->
                                    val sel = draftRadius == r
                                    Surface(
                                        shape = RoundedCornerShape(8.dp),
                                        color = if (sel) BarberEmerald else MaterialTheme.colorScheme.surface,
                                        modifier = Modifier.clickable { draftRadius = r }
                                    ) {
                                        Text(
                                            text = "$r km",
                                            fontSize = 11.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = if (sel) Color.White else MaterialTheme.colorScheme.onSurface,
                                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)
                                        )
                                    }
                                }
                            }

                            Spacer(modifier = Modifier.height(8.dp))
                            Text("Frais de déplacement :", fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                            Spacer(modifier = Modifier.height(4.dp))
                            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                listOf(0, 300, 500, 800).forEach { f ->
                                    val sel = draftFee == f
                                    Surface(
                                        shape = RoundedCornerShape(8.dp),
                                        color = if (sel) BarberGoldPrimary else MaterialTheme.colorScheme.surface,
                                        modifier = Modifier.clickable { draftFee = f }
                                    ) {
                                        Text(
                                            text = if (f == 0) "Offert" else "$f DA",
                                            fontSize = 11.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = if (sel) Color.Black else MaterialTheme.colorScheme.onSurface,
                                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)
                                        )
                                    }
                                }
                            }

                            Spacer(modifier = Modifier.height(8.dp))
                            OutlinedTextField(
                                value = draftZones,
                                onValueChange = { draftZones = it },
                                label = { Text("Zones & quartiers desservis", fontSize = 11.sp) },
                                singleLine = true,
                                modifier = Modifier.fillMaxWidth()
                            )

                            Spacer(modifier = Modifier.height(8.dp))
                            Button(
                                onClick = {
                                    onUpdateHomeServiceSettings?.invoke(true, draftFee, draftRadius, draftZones)
                                    editingMobility = false
                                },
                                colors = ButtonDefaults.buttonColors(containerColor = BarberEmerald, contentColor = Color.White),
                                shape = RoundedCornerShape(10.dp),
                                modifier = Modifier.fillMaxWidth().testTag("btn_save_home_mobility")
                            ) {
                                Text("Enregistrer rayon & tarif", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                }
            }

            if (onToggleBlockedHomeSlot != null) {
                item {
                    val accentCol = if (barber.targetAudience == TargetAudience.WOMEN) BeautyFuchsia else BarberGoldPrimary
                    ArtistSlotAvailabilityManagerCard(
                        barber = barber,
                        accentColor = accentCol,
                        onToggleSlot = onToggleBlockedHomeSlot
                    )
                }
            }
        }

        // 4. Live Queue Counter + Big 1-Tap Buttons (+1 Sans rdv / -1 Terminé / Suivant)
        item {
            val totalWaitMins = queue.sumOf { it.durationMinutes }
            BarberQueueControlsCard(
                waitingCount = queue.size,
                estimatedWaitMins = if (totalWaitMins == 0) 10 else totalWaitMins,
                onAddWalkIn = onAddWalkIn,
                onCustomerDone = onCustomerDone,
                onCallNext = onCallNext
            )
        }

        // 5. Today's Overview Metrics & Permanent QR Shortcut
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                // Today Stats Card
                Card(
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                    modifier = Modifier
                        .weight(1.2f)
                        .clickable { onNavigateToFinances?.invoke() }
                ) {
                    Column(modifier = Modifier.padding(12.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text("Aujourd'hui", fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text("Compta ➜", fontSize = 10.sp, fontWeight = FontWeight.Bold, color = BarberGoldPrimary)
                        }
                        Spacer(modifier = Modifier.height(4.dp))
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text("12", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurface)
                            Text(" servis • ", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text("7,200 DA", fontSize = 14.sp, fontWeight = FontWeight.Bold, color = BarberEmerald)
                        }
                    }
                }

                // Permanent QR Quick Button
                Button(
                    onClick = onShowQrClick,
                    modifier = Modifier
                        .weight(1f)
                        .height(68.dp)
                        .testTag("open_qr_btn"),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.surfaceVariant,
                        contentColor = MaterialTheme.colorScheme.primary
                    ),
                    shape = RoundedCornerShape(16.dp),
                    border = androidx.compose.foundation.BorderStroke(1.dp, BarberGoldPrimary.copy(alpha = 0.4f))
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(Icons.Default.QrCode2, contentDescription = null, modifier = Modifier.size(24.dp))
                        Text("Mon QR Code", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }

        // 6. Real-Time Waiting List (Live Queue Details)
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Liste des personnes qui attendent (${queue.size})",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )
            }
        }

        if (queue.isEmpty()) {
            item {
                Card(
                    shape = RoundedCornerShape(14.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(24.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "Chaise libre ! Ajoutez un client direct avec le bouton '+1 Sans Rdv'.",
                            fontSize = 13.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        } else {
            items(queue) { customer ->
                Card(
                    shape = RoundedCornerShape(14.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = if (customer.isNext) BarberGoldPrimary.copy(alpha = 0.15f) else MaterialTheme.colorScheme.surfaceVariant
                    ),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier.padding(14.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(
                                modifier = Modifier
                                    .size(36.dp)
                                    .clip(CircleShape)
                                    .background(if (customer.isNext) BarberGoldPrimary else MaterialTheme.colorScheme.surface),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = "#${customer.ticketNumber}",
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 12.sp,
                                    color = if (customer.isNext) Color.Black else MaterialTheme.colorScheme.onSurface
                                )
                            }
                            Spacer(modifier = Modifier.width(10.dp))
                            Column {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text(
                                        text = customer.customerName,
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 14.sp,
                                        color = MaterialTheme.colorScheme.onSurface
                                    )
                                    if (customer.type == QueueItemType.BOOKED_APP) {
                                        Spacer(modifier = Modifier.width(6.dp))
                                        Surface(
                                            shape = RoundedCornerShape(4.dp),
                                            color = BarberBlue.copy(alpha = 0.2f)
                                        ) {
                                            Text(
                                                text = "Via App",
                                                color = BarberBlue,
                                                fontSize = 9.sp,
                                                fontWeight = FontWeight.Bold,
                                                modifier = Modifier.padding(horizontal = 4.dp, vertical = 2.dp)
                                            )
                                        }
                                    }
                                }
                                Text(
                                    text = "${customer.serviceName} • ${customer.durationMinutes} min",
                                    fontSize = 12.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }

                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                text = "${customer.priceDzd} DA",
                                fontWeight = FontWeight.Bold,
                                fontSize = 13.sp,
                                color = BarberGoldPrimary
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Button(
                                onClick = { onOpenCashIn?.invoke(customer) },
                                modifier = Modifier
                                    .height(34.dp)
                                    .testTag("cash_in_customer_${customer.id}"),
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = BarberEmerald,
                                    contentColor = Color.White
                                ),
                                shape = RoundedCornerShape(8.dp),
                                contentPadding = PaddingValues(horizontal = 8.dp)
                            ) {
                                Icon(Icons.Default.AttachMoney, contentDescription = null, modifier = Modifier.size(14.dp))
                                Text("Encaisser", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                            }
                            IconButton(
                                onClick = { onRemoveQueueItem(customer.id) },
                                modifier = Modifier.size(32.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Close,
                                    contentDescription = "Supprimer",
                                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.size(16.dp)
                                )
                            }
                        }
                    }
                }
            }
        }

        // 7. Today's Scheduled Appointments
        item {
            val enRouteCount = bookings.count { it.isOnTheWay && it.status == com.example.model.BookingStatus.CONFIRMED }
            Column(modifier = Modifier.padding(top = 8.dp)) {
                Text(
                    text = "Rendez-vous programmés aujourd'hui (${bookings.size})",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )
                if (enRouteCount > 0) {
                    Spacer(modifier = Modifier.height(6.dp))
                    Surface(
                        shape = RoundedCornerShape(10.dp),
                        color = BarberBlue.copy(alpha = 0.16f),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Row(
                            modifier = Modifier.padding(10.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(Icons.Default.DirectionsCar, contentDescription = null, tint = BarberBlue, modifier = Modifier.size(18.dp))
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "🚗 $enRouteCount client(s) actuellement en route vers votre salon !",
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Bold,
                                color = BarberBlue
                            )
                        }
                    }
                }
            }
        }

        items(bookings) { booking ->
            val (badgeText, badgeColor) = when {
                booking.status == com.example.model.BookingStatus.WAITING_APPROVAL ->
                    Pair("⏳ À confirmer", BarberAmber)
                booking.status == com.example.model.BookingStatus.AUTO_CANCELLED ->
                    Pair("Annulé auto (-15m)", BarberRose)
                booking.status == com.example.model.BookingStatus.CANCELLED ->
                    Pair("Annulé", MaterialTheme.colorScheme.onSurfaceVariant)
                booking.status == com.example.model.BookingStatus.COMPLETED ->
                    Pair("Terminé ✓", BarberEmerald)
                booking.hasArrivedAtShop || booking.status == com.example.model.BookingStatus.ARRIVED_CONFIRMED ->
                    Pair(if (booking.isHomeService) "Sur place ✓" else "Arrivé au salon ✓", BarberEmerald)
                booking.artistOnTheWay ->
                    Pair("🚗 Artiste en route (~${booking.artistEtaMinutes ?: 15}m)", BarberBlue)
                booking.isOnTheWay ->
                    Pair("🚗 En route (~${booking.etaMinutes ?: 10}m)", BarberBlue)
                else ->
                    Pair("Confirmé", BarberGoldPrimary)
            }

            Card(
                shape = RoundedCornerShape(12.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier.padding(12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                text = booking.timeSlot,
                                fontWeight = FontWeight.Bold,
                                fontSize = 14.sp,
                                color = BarberGoldPrimary
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = booking.customerName,
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 13.sp,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                        }
                        Text(
                            text = "${booking.serviceName} • ${booking.locationSnapshot}",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        if (booking.isHomeService) {
                            Spacer(modifier = Modifier.height(2.dp))
                            Text(
                                text = "🏠 Visite à domicile : ${booking.customerAddress ?: "Adresse client"} (+${booking.travelFeeDzd} DA dépl.)",
                                fontSize = 11.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = BarberEmerald
                            )
                        }
                    }

                    Spacer(modifier = Modifier.width(8.dp))

                    Surface(
                        shape = RoundedCornerShape(6.dp),
                        color = badgeColor.copy(alpha = 0.16f)
                    ) {
                        Text(
                            text = badgeText,
                            color = badgeColor,
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 3.dp)
                        )
                    }
                }
            }
        }
    }
}
