package com.example.ui.screens

import androidx.compose.animation.AnimatedVisibility
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
import com.example.model.BarberProfile
import com.example.model.BarberStatus
import com.example.model.BookingRecord
import com.example.model.QueueCustomer
import com.example.model.Shop
import com.example.model.ShopJoinRequest
import com.example.model.ShopJoinRequestStatus
import com.example.model.TargetAudience
import com.example.ui.components.DashboardServiceManagerCard
import com.example.ui.components.ProfileAvatarImage
import com.example.ui.components.ProfilePhotoPickerCard
import com.example.ui.theme.*

@Composable
fun ShopOwnerScreen(
    shops: List<Shop>,
    allBarbers: List<BarberProfile>,
    joinRequests: List<ShopJoinRequest>,
    onRespondToJoinRequest: (requestId: String, accept: Boolean) -> Unit,
    ownerBarberProfile: BarberProfile,
    ownerQueue: List<QueueCustomer>,
    ownerBookings: List<BookingRecord>,
    onOwnerStatusChange: (BarberStatus) -> Unit,
    onOwnerAddWalkIn: () -> Unit,
    onOwnerCustomerDone: () -> Unit,
    onOwnerCallNext: () -> Unit,
    onOwnerRemoveQueueItem: (String) -> Unit,
    onOpenCashIn: ((QueueCustomer?) -> Unit)? = null,
    onShowQrClick: () -> Unit,
    onChangeWorkplaceClick: () -> Unit,
    onBroadcastClick: () -> Unit,
    onNavigateToFinances: (() -> Unit)? = null,
    onToggleShowCutPrices: ((Boolean) -> Unit)? = null,
    onOpenPromotionDialog: (() -> Unit)? = null,
    onEndPromotion: (() -> Unit)? = null,
    onUpdateShopAvatar: ((shopId: String, avatarUri: String) -> Unit)? = null,
    onTogglePresetShopService: ((shopId: String, serviceName: String) -> Unit)? = null,
    onAddCustomShopService: ((shopId: String, name: String, priceDzd: Int, durationMinutes: Int) -> Unit)? = null,
    onRemoveShopService: ((shopId: String, serviceId: String) -> Unit)? = null,
    onOwnerUpdateAvatar: ((String) -> Unit)? = null,
    onOwnerTogglePresetService: ((String) -> Unit)? = null,
    onOwnerAddCustomService: ((name: String, priceDzd: Int, durationMinutes: Int) -> Unit)? = null,
    onOwnerRemoveService: ((serviceId: String) -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    val shop = shops.firstOrNull() ?: return
    var activeOwnerTab by remember { mutableStateOf("MANAGEMENT") } // "MANAGEMENT" vs "CHAIR"
    var showInviteDialog by remember { mutableStateOf(false) }
    var inviteBarberName by remember { mutableStateOf("") }
    var inviteSuccessMessage by remember { mutableStateOf<String?>(null) }

    val pendingRequests = joinRequests.filter { it.shopId == shop.id && it.status == ShopJoinRequestStatus.PENDING }

    Column(modifier = modifier.fillMaxSize()) {
        // Top Switcher: Gérance du Salon VS Mon Fauteuil Barbier
        Surface(
            color = MaterialTheme.colorScheme.surface,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant)
                    .padding(4.dp),
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Surface(
                    shape = RoundedCornerShape(10.dp),
                    color = if (activeOwnerTab == "MANAGEMENT") BarberGoldPrimary else Color.Transparent,
                    modifier = Modifier
                        .weight(1f)
                        .clickable { activeOwnerTab = "MANAGEMENT" }
                        .testTag("tab_shop_management")
                ) {
                    Row(
                        modifier = Modifier.padding(vertical = 10.dp),
                        horizontalArrangement = Arrangement.Center,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            Icons.Default.Store,
                            contentDescription = null,
                            tint = if (activeOwnerTab == "MANAGEMENT") Color.Black else MaterialTheme.colorScheme.onSurface,
                            modifier = Modifier.size(16.dp)
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = "Gérance Salon",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold,
                            color = if (activeOwnerTab == "MANAGEMENT") Color.Black else MaterialTheme.colorScheme.onSurface
                        )
                    }
                }

                Surface(
                    shape = RoundedCornerShape(10.dp),
                    color = if (activeOwnerTab == "CHAIR") BarberGoldPrimary else Color.Transparent,
                    modifier = Modifier
                        .weight(1f)
                        .clickable { activeOwnerTab = "CHAIR" }
                        .testTag("tab_owner_barber_chair")
                ) {
                    Row(
                        modifier = Modifier.padding(vertical = 10.dp),
                        horizontalArrangement = Arrangement.Center,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            Icons.Default.ContentCut,
                            contentDescription = null,
                            tint = if (activeOwnerTab == "CHAIR") Color.Black else MaterialTheme.colorScheme.onSurface,
                            modifier = Modifier.size(16.dp)
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = "Mon Fauteuil Barbier",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold,
                            color = if (activeOwnerTab == "CHAIR") Color.Black else MaterialTheme.colorScheme.onSurface
                        )
                    }
                }
            }
        }

        if (activeOwnerTab == "CHAIR") {
            // THE SHOP OWNER HAS HIS OWN REAL BARBER PROFILE EXACTLY LIKE A NORMAL BARBER
            BarberHomeScreen(
                barber = ownerBarberProfile.copy(name = "${ownerBarberProfile.name} (Gérant & Barbier)"),
                queue = ownerQueue,
                bookings = ownerBookings,
                onStatusChange = onOwnerStatusChange,
                onChangeWorkplaceClick = onChangeWorkplaceClick,
                onBroadcastClick = onBroadcastClick,
                onShowQrClick = onShowQrClick,
                onAddWalkIn = onOwnerAddWalkIn,
                onCustomerDone = onOwnerCustomerDone,
                onCallNext = onOwnerCallNext,
                onRemoveQueueItem = onOwnerRemoveQueueItem,
                onOpenCashIn = onOpenCashIn,
                onNavigateToFinances = onNavigateToFinances,
                onToggleShowCutPrices = onToggleShowCutPrices,
                onOpenPromotionDialog = onOpenPromotionDialog,
                onEndPromotion = onEndPromotion,
                onUpdateAvatar = onOwnerUpdateAvatar,
                onTogglePresetService = onOwnerTogglePresetService,
                onAddCustomService = onOwnerAddCustomService,
                onRemoveService = onOwnerRemoveService,
                modifier = Modifier.fillMaxSize()
            )
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
                contentPadding = PaddingValues(top = 4.dp, bottom = 80.dp)
            ) {
        // Shop Hero Header
        item {
            val isWomenShop = shop.targetAudience == TargetAudience.WOMEN
            val shopAccent = if (isWomenShop) BeautyFuchsia else BarberGoldPrimary
            Card(
                shape = RoundedCornerShape(20.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(18.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.weight(1f)
                        ) {
                            ProfileAvatarImage(
                                avatarUrl = shop.avatarUrl,
                                fallbackIcon = Icons.Default.Storefront,
                                contentDescription = shop.name,
                                accentColor = shopAccent,
                                size = 54.dp
                            )
                            Spacer(modifier = Modifier.width(12.dp))
                            Column {
                                Text(
                                    text = if (isWomenShop) "Espace Propriétaire • Institut Dames" else "Espace Propriétaire de Salon",
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = shopAccent
                                )
                                Text(
                                    text = shop.name,
                                    fontSize = 18.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                                Text(
                                    text = "${shop.address} • ${shop.commune} (${shop.wilaya})",
                                    fontSize = 12.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }

                        Surface(
                            shape = RoundedCornerShape(8.dp),
                            color = BarberEmerald.copy(alpha = 0.2f)
                        ) {
                            Text(
                                text = "Ouvert",
                                color = BarberEmerald,
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold,
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(14.dp))

                    // Combined Queue Overview
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Surface(
                            shape = RoundedCornerShape(12.dp),
                            color = MaterialTheme.colorScheme.surface,
                            modifier = Modifier
                                .weight(1f)
                                .border(0.5.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(12.dp))
                        ) {
                            Column(modifier = Modifier.padding(10.dp)) {
                                Text("Chaises actives", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                Text("${shop.barberIds.size} Coiffeurs", fontSize = 15.sp, fontWeight = FontWeight.Bold)
                            }
                        }

                        Surface(
                            shape = RoundedCornerShape(12.dp),
                            color = MaterialTheme.colorScheme.surface,
                            modifier = Modifier
                                .weight(1f)
                                .border(0.5.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(12.dp))
                        ) {
                            Column(modifier = Modifier.padding(10.dp)) {
                                Text("Demandes d'adhésion", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                Text("${pendingRequests.size} En attente", fontSize = 15.sp, fontWeight = FontWeight.Bold, color = if (pendingRequests.isNotEmpty()) BarberAmber else BarberEmerald)
                            }
                        }
                    }
                }
            }
        }

        // Shop Profile Photo Picker Card
        if (onUpdateShopAvatar != null) {
            item {
                val isWomenShop = shop.targetAudience == TargetAudience.WOMEN
                val shopAccent = if (isWomenShop) BeautyFuchsia else BarberGoldPrimary
                ProfilePhotoPickerCard(
                    avatarUrl = shop.avatarUrl,
                    title = if (isWomenShop) "Photo / Logo de l'Institut" else "Photo / Logo du Salon",
                    subtitle = "Choisissez la photo affichée aux clients",
                    accentColor = shopAccent,
                    fallbackIcon = Icons.Default.Storefront,
                    testTagPrefix = "dashboard_shop",
                    onPhotoPicked = { uri -> onUpdateShopAvatar(shop.id, uri) },
                    onRemovePhoto = if (shop.avatarUrl.isNotBlank()) ({ onUpdateShopAvatar(shop.id, "") }) else null
                )
            }
        }

        // Shop Offered Services Manager (List + Custom typed input)
        if (onTogglePresetShopService != null && onAddCustomShopService != null && onRemoveShopService != null) {
            item {
                val isWomenShop = shop.targetAudience == TargetAudience.WOMEN
                val shopAccent = if (isWomenShop) BeautyFuchsia else BarberGoldPrimary
                DashboardServiceManagerCard(
                    title = if (isWomenShop) "Prestations & Soins de l'Institut" else "Services & Coupes du Salon",
                    targetAudience = shop.targetAudience,
                    accentColor = shopAccent,
                    currentServices = shop.services,
                    isHomeArtist = false,
                    onTogglePresetService = { srv -> onTogglePresetShopService(shop.id, srv) },
                    onAddCustomService = { name, price, dur -> onAddCustomShopService(shop.id, name, price, dur) },
                    onRemoveService = { srvId -> onRemoveShopService(shop.id, srvId) }
                )
            }
        }

        // Live incoming En-Route customers alert for the Shop
        val enRouteBookings = ownerBookings.filter { it.isOnTheWay && it.status == com.example.model.BookingStatus.CONFIRMED }
        if (enRouteBookings.isNotEmpty()) {
            item {
                Surface(
                    shape = RoundedCornerShape(12.dp),
                    color = BarberBlue.copy(alpha = 0.16f),
                    border = androidx.compose.foundation.BorderStroke(1.dp, BarberBlue.copy(alpha = 0.4f)),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(modifier = Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.DirectionsCar, contentDescription = null, tint = BarberBlue, modifier = Modifier.size(18.dp))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(
                                text = "Clients en route vers votre salon (${enRouteBookings.size})",
                                fontSize = 13.sp,
                                fontWeight = FontWeight.Bold,
                                color = BarberBlue
                            )
                        }
                        enRouteBookings.forEach { b ->
                            Text(
                                text = "• ${b.customerName} (${b.serviceName} à ${b.timeSlot}) — arrivée ~${b.etaMinutes ?: 10} min",
                                fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                        }
                    }
                }
            }
        }

        // Section: Barber Join Requests (The core requested feature: Barber requests, Shop Owner accepts)
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.NotificationImportant,
                        contentDescription = null,
                        tint = BarberAmber,
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = "Demandes de Barbiers pour rejoindre le salon (${pendingRequests.size})",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                }
            }
        }

        if (pendingRequests.isEmpty()) {
            item {
                Surface(
                    shape = RoundedCornerShape(12.dp),
                    color = MaterialTheme.colorScheme.surfaceVariant,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier.padding(14.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(Icons.Default.CheckCircle, contentDescription = null, tint = BarberEmerald)
                        Spacer(modifier = Modifier.width(10.dp))
                        Text(
                            text = "Aucune nouvelle demande. Les barbiers indépendants peuvent demander à rejoindre votre salon via leur interface.",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        } else {
            items(pendingRequests) { req ->
                Card(
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = BarberAmber.copy(alpha = 0.12f)),
                    modifier = Modifier
                        .fillMaxWidth()
                        .border(1.5.dp, BarberAmber, RoundedCornerShape(16.dp))
                        .testTag("shop_join_request_${req.id}")
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.Top
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Box(
                                    modifier = Modifier
                                        .size(44.dp)
                                        .clip(CircleShape)
                                        .background(BarberGoldPrimary),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Icon(Icons.Default.ContentCut, contentDescription = null, tint = Color.Black, modifier = Modifier.size(22.dp))
                                }
                                Spacer(modifier = Modifier.width(12.dp))
                                Column {
                                    Text(
                                        text = req.barberName,
                                        fontSize = 15.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = MaterialTheme.colorScheme.onSurface
                                    )
                                    Text(
                                        text = "${req.barberExperienceYears} ans d'expérience • ${req.barberPhone}",
                                        fontSize = 12.sp,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                    Text(
                                        text = "Demande envoyée: ${req.requestDate}",
                                        fontSize = 10.sp,
                                        color = BarberGoldPrimary,
                                        fontWeight = FontWeight.SemiBold
                                    )
                                }
                            }

                            Surface(
                                shape = RoundedCornerShape(6.dp),
                                color = BarberAmber.copy(alpha = 0.25f)
                            ) {
                                Text(
                                    text = "Nouveau",
                                    fontSize = 10.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = BarberAmber,
                                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(14.dp))

                        // Accept and Reject buttons
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Button(
                                onClick = { onRespondToJoinRequest(req.id, true) },
                                modifier = Modifier
                                    .weight(1.2f)
                                    .height(44.dp)
                                    .testTag("accept_join_request_${req.id}"),
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = BarberEmerald,
                                    contentColor = Color.White
                                ),
                                shape = RoundedCornerShape(10.dp)
                            ) {
                                Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(16.dp))
                                Spacer(modifier = Modifier.width(6.dp))
                                Text("Accepter le Barbier", fontWeight = FontWeight.Bold, fontSize = 12.sp)
                            }

                            OutlinedButton(
                                onClick = { onRespondToJoinRequest(req.id, false) },
                                modifier = Modifier
                                    .weight(0.8f)
                                    .height(44.dp)
                                    .testTag("reject_join_request_${req.id}"),
                                shape = RoundedCornerShape(10.dp)
                            ) {
                                Icon(Icons.Default.Close, contentDescription = null, modifier = Modifier.size(16.dp), tint = BarberRose)
                                Spacer(modifier = Modifier.width(4.dp))
                                Text("Refuser", color = BarberRose, fontSize = 12.sp)
                            }
                        }
                    }
                }
            }
        }

        // Section: Barbers currently working at this shop
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Barbiers rattachés au salon (${allBarbers.filter { shop.barberIds.contains(it.id) }.size})",
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )

                Button(
                    onClick = { showInviteDialog = true },
                    colors = ButtonDefaults.buttonColors(containerColor = BarberGoldPrimary, contentColor = Color.Black),
                    shape = RoundedCornerShape(10.dp),
                    contentPadding = PaddingValues(horizontal = 10.dp, vertical = 6.dp)
                ) {
                    Icon(Icons.Default.PersonAdd, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Inviter un coiffeur", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                }
            }
        }

        // List of Active Barbers in Shop
        val currentShopBarbers = allBarbers.filter { shop.barberIds.contains(it.id) }
        items(currentShopBarbers) { barber ->
            Card(
                shape = RoundedCornerShape(14.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier.padding(14.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        ProfileAvatarImage(
                            avatarUrl = barber.avatarUrl,
                            fallbackIcon = Icons.Default.Person,
                            contentDescription = barber.name,
                            accentColor = BarberGoldPrimary,
                            size = 42.dp
                        )
                        Spacer(modifier = Modifier.width(10.dp))
                        Column {
                            Text(barber.name, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                            Text("Statut: ${barber.status.name} • ${barber.experienceYears} ans exp", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }

                    Surface(
                        shape = RoundedCornerShape(6.dp),
                        color = BarberEmerald.copy(alpha = 0.2f)
                    ) {
                        Text(
                            text = "Affilié",
                            color = BarberEmerald,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                        )
                    }
                }
            }
        }

        // Principle reminder
        item {
            Surface(
                shape = RoundedCornerShape(12.dp),
                color = BarberBlue.copy(alpha = 0.1f),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(modifier = Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Info, contentDescription = null, tint = BarberBlue)
                    Spacer(modifier = Modifier.width(10.dp))
                    Text(
                        text = "Règle clé LEMQES : Lorsqu'un barbier est accepté, son profil personnel, son QR code et ses abonnés restent les siens. Son adresse de travail devient votre salon.",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                }
            }
            }
        }
    }

    if (showInviteDialog) {
        AlertDialog(
            onDismissRequest = { showInviteDialog = false },
            title = { Text("Inviter un coiffeur") },
            text = {
                Column {
                    Text("Entrez le numéro de téléphone ou l'identifiant du coiffeur sur LEMQES :", fontSize = 13.sp)
                    Spacer(modifier = Modifier.height(10.dp))
                    OutlinedTextField(
                        value = inviteBarberName,
                        onValueChange = { inviteBarberName = it },
                        label = { Text("Numéro / ID coiffeur (+213)") },
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        showInviteDialog = false
                        inviteSuccessMessage = "Invitation envoyée !"
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = BarberGoldPrimary, contentColor = Color.Black)
                ) {
                    Text("Envoyer l'invitation")
                }
            },
            dismissButton = {
                TextButton(onClick = { showInviteDialog = false }) {
                    Text("Annuler")
                }
            }
        )
    }
    }
}

