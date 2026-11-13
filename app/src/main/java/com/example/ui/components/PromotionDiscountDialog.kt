package com.example.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
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
import androidx.compose.ui.window.Dialog
import com.example.model.BarberProfile
import com.example.model.BarberPromotion
import com.example.model.ServiceItem
import com.example.ui.theme.*

@Composable
fun PromotionDiscountDialog(
    barber: BarberProfile,
    onDismiss: () -> Unit,
    onLaunchPromotion: (BarberPromotion) -> Unit
) {
    val services = barber.services.ifEmpty {
        listOf(
            ServiceItem("srv_1", "Classic Haircut", "قصة شعر", "Coupe classique & dégradé", 600, 25),
            ServiceItem("srv_2", "Beard Sculpt", "نحت اللحية", "Taille barbe & serviette chaude", 400, 15),
            ServiceItem("srv_3", "VIP Pack", "باك VIP", "Pack Royal: Coupe + Barbe", 1200, 45)
        )
    }

    var selectedService by remember { mutableStateOf(services.first()) }
    var discountPercent by remember { mutableStateOf(20) }
    var promoTitle by remember { mutableStateOf("−${discountPercent}% spécial abonnés LEMQES !") }
    var expiryText by remember { mutableStateOf("Ce soir 21:00") }

    val originalPrice = selectedService.priceDzd
    val discountedPrice = (originalPrice * (1.0 - discountPercent / 100.0)).toInt()

    Dialog(onDismissRequest = onDismiss) {
        Surface(
            shape = RoundedCornerShape(22.dp),
            color = MaterialTheme.colorScheme.surface,
            modifier = Modifier
                .fillMaxWidth()
                .padding(8.dp)
        ) {
            Column(
                modifier = Modifier
                    .padding(20.dp)
                    .verticalScroll(rememberScrollState())
            ) {
                // Header
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            modifier = Modifier
                                .size(40.dp)
                                .clip(CircleShape)
                                .background(BarberRose.copy(alpha = 0.2f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(Icons.Default.LocalOffer, contentDescription = null, tint = BarberRose, modifier = Modifier.size(22.dp))
                        }
                        Spacer(modifier = Modifier.width(10.dp))
                        Column {
                            Text(
                                text = "Lancer une Réduction",
                                fontSize = 16.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Text(
                                text = "Notification envoyée à vos ${barber.subscribersCount} abonnés",
                                fontSize = 11.sp,
                                color = BarberEmerald,
                                fontWeight = FontWeight.SemiBold
                            )
                        }
                    }

                    IconButton(onClick = onDismiss) {
                        Icon(Icons.Default.Close, contentDescription = "Fermer")
                    }
                }

                Spacer(modifier = Modifier.height(14.dp))

                // Service selection
                Text("1. Prestation concernée :", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                Spacer(modifier = Modifier.height(6.dp))
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    services.forEach { srv ->
                        val isSelected = srv.id == selectedService.id
                        Surface(
                            shape = RoundedCornerShape(10.dp),
                            color = if (isSelected) BarberGoldPrimary.copy(alpha = 0.15f) else MaterialTheme.colorScheme.surfaceVariant,
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    selectedService = srv
                                    promoTitle = "−${discountPercent}% sur ${srv.nameFr}"
                                }
                                .border(1.dp, if (isSelected) BarberGoldPrimary else Color.Transparent, RoundedCornerShape(10.dp))
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(srv.nameFr, fontSize = 12.sp, fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal)
                                Text("${srv.priceDzd} DA", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = BarberGoldPrimary)
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(12.dp))

                // Discount percentage picker
                Text("2. Pourcentage de réduction :", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                Spacer(modifier = Modifier.height(6.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    listOf(10, 20, 30, 50).forEach { pct ->
                        val isSelected = discountPercent == pct
                        Surface(
                            shape = RoundedCornerShape(10.dp),
                            color = if (isSelected) BarberRose else MaterialTheme.colorScheme.surfaceVariant,
                            modifier = Modifier
                                .weight(1f)
                                .clickable {
                                    discountPercent = pct
                                    promoTitle = "−${pct}% sur ${selectedService.nameFr}"
                                }
                        ) {
                            Box(
                                modifier = Modifier.padding(vertical = 10.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = "−$pct %",
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = if (isSelected) Color.White else MaterialTheme.colorScheme.onSurface
                                )
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(12.dp))

                // Price calculation preview
                Surface(
                    shape = RoundedCornerShape(12.dp),
                    color = BarberRose.copy(alpha = 0.12f),
                    modifier = Modifier
                        .fillMaxWidth()
                        .border(1.dp, BarberRose.copy(alpha = 0.4f), RoundedCornerShape(12.dp))
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(12.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text("Prix d'origine : $originalPrice DA", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text("Économie client : −${originalPrice - discountedPrice} DA", fontSize = 11.sp, color = BarberRose, fontWeight = FontWeight.Bold)
                        }
                        Column(horizontalAlignment = Alignment.End) {
                            Text("Nouveau Tarif Promo", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text(
                                text = "$discountedPrice DA",
                                fontSize = 20.sp,
                                fontWeight = FontWeight.Black,
                                color = BarberRose
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.height(12.dp))

                // Expiry
                Text("3. Valable jusqu'à :", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                Spacer(modifier = Modifier.height(6.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    listOf("Ce soir 21:00", "Demain soir", "Fin de semaine").forEach { exp ->
                        val isSelected = expiryText == exp
                        Surface(
                            shape = RoundedCornerShape(8.dp),
                            color = if (isSelected) BarberGoldPrimary else MaterialTheme.colorScheme.surfaceVariant,
                            modifier = Modifier
                                .weight(1f)
                                .clickable { expiryText = exp }
                        ) {
                            Box(
                                modifier = Modifier.padding(vertical = 8.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = exp,
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = if (isSelected) Color.Black else MaterialTheme.colorScheme.onSurface
                                )
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(14.dp))

                // Custom Promo Title
                OutlinedTextField(
                    value = promoTitle,
                    onValueChange = { promoTitle = it },
                    label = { Text("Titre de la promo (Notification push)") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    shape = RoundedCornerShape(12.dp)
                )

                Spacer(modifier = Modifier.height(14.dp))

                // Live Push notification mockup
                Surface(
                    shape = RoundedCornerShape(10.dp),
                    color = MaterialTheme.colorScheme.surfaceVariant,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier.padding(10.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(Icons.Default.NotificationsActive, contentDescription = null, tint = BarberGoldPrimary, modifier = Modifier.size(20.dp))
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = "Aperçu Push : '${promoTitle} ($discountedPrice DA) valable jusqu'à $expiryText'",
                            fontSize = 10.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                // Launch button
                Button(
                    onClick = {
                        val promo = BarberPromotion(
                            id = "promo_${System.currentTimeMillis()}",
                            title = promoTitle,
                            discountPercent = discountPercent,
                            serviceName = selectedService.nameFr,
                            originalPriceDzd = originalPrice,
                            discountedPriceDzd = discountedPrice,
                            expiresAt = expiryText,
                            active = true
                        )
                        onLaunchPromotion(promo)
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(50.dp)
                        .testTag("confirm_launch_promo_btn"),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = BarberRose,
                        contentColor = Color.White
                    ),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(Icons.Default.Send, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("Diffuser la Réduction aux Abonnés", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                }
            }
        }
    }
}
