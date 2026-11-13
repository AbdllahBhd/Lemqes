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
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import com.example.model.BarberProfile
import com.example.model.FeedbackReview
import com.example.model.FeedbackTargetType
import com.example.model.ServiceItem
import com.example.model.Shop
import com.example.model.TargetAudience
import com.example.model.WorkplaceType
import com.example.ui.components.ProfileAvatarImage
import com.example.ui.theme.*

@Composable
fun BarberProfileDetailScreen(
    barber: BarberProfile,
    shop: Shop? = null,
    reviews: List<FeedbackReview> = emptyList(),
    onBack: () -> Unit,
    onBookService: (ServiceItem) -> Unit,
    onJoinQueueRemotely: (ServiceItem) -> Unit,
    onToggleFollow: () -> Unit,
    onShowQr: () -> Unit,
    onOpenFeedback: () -> Unit = {},
    onBookHomeVisit: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    val isWomenMode = barber.targetAudience == TargetAudience.WOMEN
    val accentColor = if (isWomenMode) BeautyFuchsia else BarberGoldPrimary

    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
        contentPadding = PaddingValues(top = 12.dp, bottom = 80.dp)
    ) {
        // Back Bar
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onBack) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Retour")
                }
                Text(
                    text = if (isWomenMode) "Profil Salon de Beauté / Coiffure" else "Profil du Barbier",
                    fontWeight = FontWeight.Bold,
                    fontSize = 18.sp,
                    color = MaterialTheme.colorScheme.onSurface
                )
            }
        }

        // Hero Profile Card
        item {
            Card(
                shape = RoundedCornerShape(20.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(18.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.Top
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.weight(1f)) {
                            ProfileAvatarImage(
                                avatarUrl = barber.avatarUrl,
                                fallbackIcon = if (isWomenMode) Icons.Default.Spa else Icons.Default.Person,
                                contentDescription = barber.name,
                                accentColor = accentColor,
                                iconTint = accentColor,
                                size = 62.dp
                            )
                            Spacer(modifier = Modifier.width(14.dp))
                            Column {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text(
                                        text = barber.name,
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 18.sp,
                                        color = MaterialTheme.colorScheme.onSurface
                                    )
                                    if (barber.isVerified) {
                                        Spacer(modifier = Modifier.width(4.dp))
                                        Icon(Icons.Default.CheckCircle, contentDescription = null, tint = BarberBlue, modifier = Modifier.size(16.dp))
                                    }
                                }
                                Text(
                                    text = "${barber.specialtyTitle} • ${barber.experienceYears} ans d'expérience",
                                    fontSize = 12.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                                Text(
                                    text = "${barber.rating} ★ (${barber.reviewCount} avis)",
                                    fontSize = 12.sp,
                                    color = accentColor,
                                    fontWeight = FontWeight.Bold
                                )
                            }
                        }

                        IconButton(onClick = onShowQr) {
                            Icon(Icons.Default.QrCode2, contentDescription = "QR Code", tint = accentColor)
                        }
                    }

                    Spacer(modifier = Modifier.height(14.dp))

                    Text(
                        text = barber.bio,
                        fontSize = 13.sp,
                        color = MaterialTheme.colorScheme.onSurface
                    )

                    Spacer(modifier = Modifier.height(14.dp))

                    // Contact & Follow row
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        OutlinedButton(
                            onClick = onToggleFollow,
                            modifier = Modifier
                                .weight(1f)
                                .height(44.dp),
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Icon(
                                imageVector = if (barber.isSubscribed) Icons.Default.NotificationsActive else Icons.Default.NotificationsNone,
                                contentDescription = null,
                                modifier = Modifier.size(16.dp)
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(if (barber.isSubscribed) "Abonné ✓" else "S'abonner", fontSize = 12.sp)
                        }

                        Button(
                            onClick = { /* Call intent */ },
                            modifier = Modifier
                                .weight(1f)
                                .height(44.dp),
                            colors = ButtonDefaults.buttonColors(containerColor = BarberEmerald, contentColor = Color.White),
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Icon(Icons.Default.Call, contentDescription = null, modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Appel / WhatsApp", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
        }

        // Current Workplace Card
        item {
            Card(
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        text = "📍 Lieu de travail actuel",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.primary
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = barber.currentWorkplace.shopName,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Text(
                        text = "${barber.currentWorkplace.address} (${barber.currentWorkplace.commune}, ${barber.currentWorkplace.wilaya})",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    if (shop != null && shop.services.isNotEmpty()) {
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = "Prestations du salon :",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            color = accentColor
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            items(shop.services) { srv ->
                                Surface(
                                    shape = RoundedCornerShape(8.dp),
                                    color = accentColor.copy(alpha = 0.14f)
                                ) {
                                    Text(
                                        text = "${srv.nameFr} • ${srv.priceDzd} DA",
                                        fontSize = 10.sp,
                                        fontWeight = FontWeight.SemiBold,
                                        color = MaterialTheme.colorScheme.onSurface,
                                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }

        // Home Service Card (Zone, Rayon, Tarif de déplacement & Kit stérilisé)
        if (barber.offersHomeService || barber.currentWorkplace.type == WorkplaceType.FREELANCE_MOBILE) {
            item {
                Card(
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = BarberEmerald.copy(alpha = 0.12f)),
                    modifier = Modifier
                        .fillMaxWidth()
                        .border(1.dp, BarberEmerald.copy(alpha = 0.45f), RoundedCornerShape(16.dp))
                        .testTag("home_service_detail_card")
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.Default.HomeRepairService, contentDescription = null, tint = BarberEmerald, modifier = Modifier.size(20.dp))
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = "🏠 Service à Domicile — Zone, Rayon & Tarif",
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = BarberEmerald
                                )
                            }
                        }
                        Spacer(modifier = Modifier.height(8.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Surface(
                                shape = RoundedCornerShape(8.dp),
                                color = MaterialTheme.colorScheme.surface,
                                modifier = Modifier.weight(1f)
                            ) {
                                Column(modifier = Modifier.padding(10.dp)) {
                                    Text("Rayon GPS", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    Text("${barber.homeServiceRadiusKm} km", fontSize = 14.sp, fontWeight = FontWeight.Bold, color = BarberEmerald)
                                }
                            }
                            Surface(
                                shape = RoundedCornerShape(8.dp),
                                color = MaterialTheme.colorScheme.surface,
                                modifier = Modifier.weight(1f)
                            ) {
                                Column(modifier = Modifier.padding(10.dp)) {
                                    Text("Déplacement", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    Text(
                                        text = if (barber.homeServiceFeeDzd == 0) "Offert" else "+${barber.homeServiceFeeDzd} DA",
                                        fontSize = 14.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = BarberGoldPrimary
                                    )
                                }
                            }
                        }
                        if (barber.homeServiceZones.isNotBlank()) {
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = "Quartiers couverts : ${barber.homeServiceZones}",
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Medium,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                        }
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "✓ Matériel mobile complet & kit stérilisé avant chaque visite (${if (isWomenMode) "100% Dames" else "Hommes & Enfants"}).",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        if (onBookHomeVisit != null) {
                            Spacer(modifier = Modifier.height(10.dp))
                            Button(
                                onClick = onBookHomeVisit,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(48.dp)
                                    .testTag("btn_book_home_visit_detail"),
                                colors = ButtonDefaults.buttonColors(containerColor = BarberEmerald, contentColor = Color.White),
                                shape = RoundedCornerShape(12.dp)
                            ) {
                                Icon(Icons.Default.Map, contentDescription = null, modifier = Modifier.size(18.dp))
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(
                                    text = "Réserver à domicile (Carte, Créneau & Contact)",
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.Bold
                                )
                            }
                        }
                    }
                }
            }
        }

        // Services & Pricing List (Tarifs en DZD)
        item {
            Text(
                text = "Services & Tarifs (DZD)",
                fontSize = 15.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface
            )
        }

        items(barber.services) { srv ->
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
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = srv.nameFr,
                            fontWeight = FontWeight.Bold,
                            fontSize = 14.sp,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Text(
                            text = "${srv.durationMinutes} min • ${srv.nameAr}",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }

                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = "${srv.priceDzd} DA",
                            fontWeight = FontWeight.Black,
                            fontSize = 15.sp,
                            color = BarberGoldPrimary
                        )
                        Spacer(modifier = Modifier.width(10.dp))
                        Button(
                            onClick = { onBookService(srv) },
                            colors = ButtonDefaults.buttonColors(containerColor = BarberGoldPrimary, contentColor = Color.Black),
                            shape = RoundedCornerShape(10.dp),
                            contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp)
                        ) {
                            Text("Choisir", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
        }

        // Multi-Shop Weekly Schedule (Sat-Tue Shop A, Wed-Thu Shop B)
        if (barber.multiShopSchedule.isNotEmpty()) {
            item {
                Text(
                    text = "Planning multi-salons de la semaine",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.padding(top = 8.dp)
                )
            }

            items(barber.multiShopSchedule) { sched ->
                Surface(
                    shape = RoundedCornerShape(10.dp),
                    color = MaterialTheme.colorScheme.surfaceVariant,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier.padding(12.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text(sched.dayOfWeek, fontWeight = FontWeight.Bold, fontSize = 13.sp, color = BarberGoldPrimary)
                            Text(sched.workplaceName, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurface)
                        }
                        Text(sched.hours, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }

        // Ratings & Anonymous Feedback Section (Barber + Shop)
        item {
            Spacer(modifier = Modifier.height(6.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = "Avis & Notes clients",
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    val shopText = shop?.let { " • Salon ${it.rating} ★ (${it.reviewCount})" } ?: ""
                    Text(
                        text = "${barber.rating} ★ (${barber.reviewCount} avis)$shopText",
                        fontSize = 12.sp,
                        color = accentColor,
                        fontWeight = FontWeight.SemiBold
                    )
                }

                Button(
                    onClick = onOpenFeedback,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = accentColor,
                        contentColor = if (isWomenMode) Color.White else Color.Black
                    ),
                    shape = RoundedCornerShape(10.dp),
                    modifier = Modifier.testTag("btn_rate_barber_and_shop")
                ) {
                    Icon(Icons.Default.Star, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Noter / Avis", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                }
            }
        }

        val matchingReviews = reviews.filter {
            (it.targetType == FeedbackTargetType.BARBER && it.targetId == barber.id) ||
                    (shop != null && it.targetType == FeedbackTargetType.SHOP && it.targetId == shop.id)
        }
        if (matchingReviews.isEmpty()) {
            item {
                Text(
                    text = "Aucun avis pour le moment. Soyez le premier client abonné à donner votre avis !",
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        } else {
            items(matchingReviews, key = { it.id }) { rev ->
                Card(
                    shape = RoundedCornerShape(14.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(modifier = Modifier.padding(14.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                if (rev.isAnonymous) {
                                    Icon(Icons.Default.VisibilityOff, contentDescription = null, tint = BarberEmerald, modifier = Modifier.size(14.dp))
                                    Spacer(modifier = Modifier.width(4.dp))
                                }
                                Text(
                                    text = rev.authorDisplayName,
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = if (rev.isAnonymous) BarberEmerald else MaterialTheme.colorScheme.onSurface
                                )
                            }
                            Text(
                                text = "${"★".repeat(rev.rating)} (${rev.createdAt})",
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Bold,
                                color = BarberGoldPrimary
                            )
                        }
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = if (rev.targetType == FeedbackTargetType.SHOP) "🏢 Salon : ${rev.targetName}" else "✂️ Professionnel : ${rev.targetName}",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.primary
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = rev.comment,
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                    }
                }
            }
        }
    }
}
