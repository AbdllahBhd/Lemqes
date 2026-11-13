package com.example.ui.components

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
import androidx.compose.runtime.Composable
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
import com.example.model.TargetAudience
import com.example.model.WorkplaceType
import com.example.ui.theme.*

@Composable
fun BarberCard(
    barber: BarberProfile,
    onBarberClick: () -> Unit,
    onBookClick: () -> Unit,
    onToggleFollow: () -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
        modifier = modifier
            .fillMaxWidth()
            .clickable { onBarberClick() }
            .testTag("barber_card_${barber.id}")
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            // Header: Name, Verified, Status, and Rating
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top
            ) {
                val isWomenAudience = barber.targetAudience == TargetAudience.WOMEN
                val audienceColor = if (isWomenAudience) BeautyFuchsia else BarberGoldPrimary
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.weight(1f)) {
                    ProfileAvatarImage(
                        avatarUrl = barber.avatarUrl,
                        fallbackIcon = if (isWomenAudience) Icons.Default.Spa else Icons.Default.Person,
                        contentDescription = barber.name,
                        accentColor = audienceColor,
                        size = 52.dp
                    )

                    Spacer(modifier = Modifier.width(12.dp))

                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                text = barber.name,
                                fontSize = 16.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            if (barber.isVerified) {
                                Spacer(modifier = Modifier.width(4.dp))
                                Icon(
                                    imageVector = Icons.Default.CheckCircle,
                                    contentDescription = "Vérifié",
                                    tint = BarberBlue,
                                    modifier = Modifier.size(16.dp)
                                )
                            }
                        }

                        // Audience badge & Speciality Title
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                text = if (isWomenAudience) "💄 Salon Dames" else "🧔 Barbier",
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold,
                                color = audienceColor
                            )
                            Text(
                                text = " • ${barber.specialtyTitle}",
                                fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }

                        // Current location & distance
                        val isMobileOnly = barber.currentWorkplace.type == WorkplaceType.FREELANCE_MOBILE
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                imageVector = if (isMobileOnly) Icons.Default.HomeRepairService else Icons.Default.LocationOn,
                                contentDescription = null,
                                tint = if (isMobileOnly) BarberEmerald else BarberRose,
                                modifier = Modifier.size(13.dp)
                            )
                            Spacer(modifier = Modifier.width(3.dp))
                            Text(
                                text = if (isMobileOnly) {
                                    "À domicile • ${barber.homeServiceZones.ifBlank { barber.currentWorkplace.address }}"
                                } else {
                                    "${barber.currentWorkplace.shopName} • 📍 ~0.4 km"
                                },
                                fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }

                // Status Badge
                val (statusColor, statusBg, statusText) = when (barber.status) {
                    BarberStatus.ONLINE -> Triple(BarberEmerald, BarberEmerald.copy(alpha = 0.15f), "En service")
                    BarberStatus.ON_BREAK -> Triple(BarberAmber, BarberAmber.copy(alpha = 0.15f), "En pause")
                    BarberStatus.OFFLINE -> Triple(BarberRose, BarberRose.copy(alpha = 0.15f), "Fermé")
                }

                Surface(
                    shape = RoundedCornerShape(8.dp),
                    color = statusBg
                ) {
                    Text(
                        text = statusText,
                        color = statusColor,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                    )
                }
            }

            // Active Promotion Banner
            if (barber.activePromotion != null) {
                Spacer(modifier = Modifier.height(10.dp))
                Surface(
                    shape = RoundedCornerShape(10.dp),
                    color = BarberRose.copy(alpha = 0.15f),
                    modifier = Modifier
                        .fillMaxWidth()
                        .border(1.dp, BarberRose.copy(alpha = 0.6f), RoundedCornerShape(10.dp))
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(Icons.Default.LocalOffer, contentDescription = null, tint = BarberRose, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = "🏷️ PROMO -${barber.activePromotion.discountPercent}% : ${barber.activePromotion.title} (${barber.activePromotion.expiresAt})",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            color = BarberRose
                        )
                    }
                }
            }

            // Home Service Mobility Banner (Men & Women)
            val isHomeArtist = barber.offersHomeService || barber.currentWorkplace.type == WorkplaceType.FREELANCE_MOBILE
            if (isHomeArtist) {
                Spacer(modifier = Modifier.height(10.dp))
                val feeLabel = if (barber.homeServiceFeeDzd == 0) "Dépl. offert" else "+${barber.homeServiceFeeDzd} DA dépl."
                Surface(
                    shape = RoundedCornerShape(10.dp),
                    color = BarberEmerald.copy(alpha = 0.14f),
                    modifier = Modifier
                        .fillMaxWidth()
                        .border(1.dp, BarberEmerald.copy(alpha = 0.45f), RoundedCornerShape(10.dp))
                        .testTag("home_artist_badge_${barber.id}")
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.weight(1f)) {
                            Icon(Icons.Default.HomeRepairService, contentDescription = null, tint = BarberEmerald, modifier = Modifier.size(15.dp))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(
                                text = "🏠 À Domicile • Rayon ${barber.homeServiceRadiusKm} km • Kit stérilisé",
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold,
                                color = BarberEmerald
                            )
                        }
                        Surface(
                            shape = RoundedCornerShape(6.dp),
                            color = BarberEmerald.copy(alpha = 0.2f)
                        ) {
                            Text(
                                text = feeLabel,
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold,
                                color = BarberEmerald,
                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(10.dp))

            // Bio / Highlights
            Text(
                text = barber.bio,
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 2
            )

            if (barber.services.isNotEmpty()) {
                Spacer(modifier = Modifier.height(10.dp))
                val pillAccent = if (barber.targetAudience == TargetAudience.WOMEN) BeautyFuchsia else BarberGoldPrimary
                LazyRow(
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("barber_services_row_${barber.id}"),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    items(barber.services) { srv ->
                        Surface(
                            shape = RoundedCornerShape(8.dp),
                            color = pillAccent.copy(alpha = 0.12f),
                            modifier = Modifier.border(0.5.dp, pillAccent.copy(alpha = 0.45f), RoundedCornerShape(8.dp))
                        ) {
                            val labelText = if (barber.privacySettings.showCutPrices) {
                                "${srv.nameFr} • ${srv.priceDzd} DA"
                            } else {
                                srv.nameFr
                            }
                            Text(
                                text = labelText,
                                fontSize = 10.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = MaterialTheme.colorScheme.onSurface,
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            // Metric pills: Cut Price, Wait time, Rating, Subscribers
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                // Cut / Service Price Pill (Controlled by Barber's privacy setting: showCutPrices)
                val pillColor = if (barber.targetAudience == TargetAudience.WOMEN) BeautyFuchsia else BarberGoldPrimary
                val serviceIcon = if (barber.targetAudience == TargetAudience.WOMEN) Icons.Default.Spa else Icons.Default.ContentCut
                Surface(
                    shape = RoundedCornerShape(8.dp),
                    color = if (barber.privacySettings.showCutPrices) pillColor.copy(alpha = 0.15f) else MaterialTheme.colorScheme.surface,
                    modifier = Modifier.border(0.5.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(8.dp))
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 5.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = serviceIcon,
                            contentDescription = null,
                            tint = pillColor,
                            modifier = Modifier.size(14.dp)
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        if (barber.privacySettings.showCutPrices) {
                            val price = if (barber.activePromotion != null) {
                                barber.activePromotion.discountedPriceDzd
                            } else if (barber.services.isNotEmpty()) {
                                barber.services.first().priceDzd
                            } else {
                                600
                            }
                            val label = if (barber.targetAudience == TargetAudience.WOMEN) "Dès" else "Coupe:"
                            Text(
                                text = "$label $price DA",
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold,
                                color = pillColor
                            )
                        } else {
                            Text(
                                text = "Prix au salon",
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Normal,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }

                Surface(
                    shape = RoundedCornerShape(8.dp),
                    color = MaterialTheme.colorScheme.surface,
                    modifier = Modifier.border(0.5.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(8.dp))
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 5.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = Icons.Default.Timer,
                            contentDescription = null,
                            tint = BarberGoldPrimary,
                            modifier = Modifier.size(14.dp)
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = "File: ~25 min",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                    }
                }

                Surface(
                    shape = RoundedCornerShape(8.dp),
                    color = MaterialTheme.colorScheme.surface,
                    modifier = Modifier.border(0.5.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(8.dp))
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 5.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = Icons.Default.Star,
                            contentDescription = null,
                            tint = BarberGoldPrimary,
                            modifier = Modifier.size(14.dp)
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = "${barber.rating} (${barber.reviewCount})",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                    }
                }

                Surface(
                    shape = RoundedCornerShape(8.dp),
                    color = MaterialTheme.colorScheme.surface,
                    modifier = Modifier.border(0.5.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(8.dp))
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 5.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = Icons.Default.People,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(14.dp)
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = "${barber.subscribersCount} abonnés",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(14.dp))

            // Action Buttons: Book slot & Follow barber (portable profile)
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Button(
                    onClick = onBookClick,
                    modifier = Modifier
                        .weight(1.5f)
                        .height(44.dp)
                        .testTag("book_barber_${barber.id}"),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = BarberGoldPrimary,
                        contentColor = Color.Black
                    ),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.CalendarToday,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = if (barber.currentWorkplace.type == WorkplaceType.FREELANCE_MOBILE) "Réserver à domicile" else "Prendre RDV",
                        fontWeight = FontWeight.Bold,
                        fontSize = 13.sp
                    )
                }

                OutlinedButton(
                    onClick = onToggleFollow,
                    modifier = Modifier
                        .weight(1f)
                        .height(44.dp)
                        .testTag("follow_barber_${barber.id}"),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(
                        imageVector = if (barber.isSubscribed) Icons.Default.NotificationsActive else Icons.Default.NotificationsNone,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp),
                        tint = if (barber.isSubscribed) BarberGoldPrimary else MaterialTheme.colorScheme.onSurface
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = if (barber.isSubscribed) "Suivi ✓" else "Suivre",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }
    }
}
