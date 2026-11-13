package com.example.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.model.BarberProfile
import com.example.model.Shop
import com.example.model.TargetAudience
import com.example.ui.theme.*

@Composable
fun FeedbackReviewDialog(
    barber: BarberProfile?,
    shop: Shop?,
    isSubscribedCustomer: Boolean,
    onSubscribeNow: (() -> Unit)? = null,
    onSubmit: (barberRating: Int?, shopRating: Int?, comment: String, isAnonymous: Boolean) -> Unit,
    onDismiss: () -> Unit
) {
    var rateBarber by remember { mutableStateOf(barber != null) }
    var barberStars by remember { mutableIntStateOf(5) }
    var rateShop by remember { mutableStateOf(shop != null) }
    var shopStars by remember { mutableIntStateOf(5) }
    var comment by remember { mutableStateOf("") }
    var isAnonymous by remember(isSubscribedCustomer) { mutableStateOf(isSubscribedCustomer) }

    val isWomenMode = (barber?.targetAudience == TargetAudience.WOMEN) || (shop?.targetAudience == TargetAudience.WOMEN)
    val accentColor = if (isWomenMode) BeautyFuchsia else BarberGoldPrimary

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = MaterialTheme.colorScheme.surface,
        title = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.Star, contentDescription = null, tint = accentColor)
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = "Noter & Donner votre avis",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold
                )
            }
        },
        text = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                // 1. Barber / Stylist Rating Section
                if (barber != null) {
                    Surface(
                        shape = RoundedCornerShape(12.dp),
                        color = MaterialTheme.colorScheme.surfaceVariant,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.padding(12.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        text = if (isWomenMode) "Coiffeuse / Esthéticienne" else "Barbier / Coiffeur",
                                        fontSize = 11.sp,
                                        color = accentColor,
                                        fontWeight = FontWeight.Bold
                                    )
                                    Text(
                                        text = barber.name,
                                        fontSize = 14.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = MaterialTheme.colorScheme.onSurface
                                    )
                                }
                                Checkbox(
                                    checked = rateBarber,
                                    onCheckedChange = { rateBarber = it }
                                )
                            }
                            if (rateBarber) {
                                Spacer(modifier = Modifier.height(6.dp))
                                StarRatingSelector(
                                    rating = barberStars,
                                    accentColor = accentColor,
                                    onRatingSelected = { barberStars = it },
                                    testTagPrefix = "barber_star"
                                )
                            }
                        }
                    }
                }

                // 2. Shop / Beauty Salon Rating Section
                if (shop != null) {
                    Surface(
                        shape = RoundedCornerShape(12.dp),
                        color = MaterialTheme.colorScheme.surfaceVariant,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.padding(12.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        text = if (isWomenMode) "Salon de Beauté / Institut" else "Salon / Barber Shop",
                                        fontSize = 11.sp,
                                        color = BarberBlue,
                                        fontWeight = FontWeight.Bold
                                    )
                                    Text(
                                        text = shop.name,
                                        fontSize = 14.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = MaterialTheme.colorScheme.onSurface
                                    )
                                }
                                Checkbox(
                                    checked = rateShop,
                                    onCheckedChange = { rateShop = it }
                                )
                            }
                            if (rateShop) {
                                Spacer(modifier = Modifier.height(6.dp))
                                StarRatingSelector(
                                    rating = shopStars,
                                    accentColor = BarberGoldPrimary,
                                    onRatingSelected = { shopStars = it },
                                    testTagPrefix = "shop_star"
                                )
                            }
                        }
                    }
                }

                // 3. Feedback Comment Input
                OutlinedTextField(
                    value = comment,
                    onValueChange = { comment = it },
                    label = { Text("Votre commentaire (qualité, propreté, ponctualité...)") },
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("feedback_comment_input"),
                    minLines = 2,
                    maxLines = 4,
                    shape = RoundedCornerShape(12.dp)
                )

                // 4. Subscriber Anonymous Feedback Toggle
                Surface(
                    shape = RoundedCornerShape(12.dp),
                    color = if (isSubscribedCustomer) {
                        BarberEmerald.copy(alpha = 0.12f)
                    } else {
                        BarberAmber.copy(alpha = 0.12f)
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .border(
                            1.dp,
                            if (isSubscribedCustomer) BarberEmerald.copy(alpha = 0.4f) else BarberAmber.copy(alpha = 0.4f),
                            RoundedCornerShape(12.dp)
                        )
                ) {
                    Column(modifier = Modifier.padding(12.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier.weight(1f)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.VisibilityOff,
                                    contentDescription = null,
                                    tint = if (isSubscribedCustomer) BarberEmerald else BarberAmber,
                                    modifier = Modifier.size(18.dp)
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Column {
                                    Text(
                                        text = "Publier anonymement",
                                        fontSize = 13.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = MaterialTheme.colorScheme.onSurface
                                    )
                                    Text(
                                        text = if (isSubscribedCustomer) {
                                            "Client abonné ✓ — Nom affiché : « Client abonné anonyme »"
                                        } else {
                                            "Réservé aux clients abonnés"
                                        },
                                        fontSize = 11.sp,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                            Switch(
                                checked = isSubscribedCustomer && isAnonymous,
                                onCheckedChange = { checked ->
                                    if (isSubscribedCustomer) {
                                        isAnonymous = checked
                                    }
                                },
                                enabled = isSubscribedCustomer,
                                modifier = Modifier.testTag("anonymous_feedback_switch")
                            )
                        }

                        if (!isSubscribedCustomer && onSubscribeNow != null) {
                            Spacer(modifier = Modifier.height(8.dp))
                            OutlinedButton(
                                onClick = onSubscribeNow,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(38.dp)
                                    .testTag("subscribe_for_anonymous_btn"),
                                shape = RoundedCornerShape(10.dp)
                            ) {
                                Icon(Icons.Default.NotificationsActive, contentDescription = null, modifier = Modifier.size(15.dp))
                                Spacer(modifier = Modifier.width(6.dp))
                                Text("S'abonner maintenant pour noter anonymement", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {
            val canSubmit = (rateBarber && barber != null) || (rateShop && shop != null)
            Button(
                onClick = {
                    onSubmit(
                        if (rateBarber && barber != null) barberStars else null,
                        if (rateShop && shop != null) shopStars else null,
                        comment,
                        isSubscribedCustomer && isAnonymous
                    )
                },
                enabled = canSubmit,
                colors = ButtonDefaults.buttonColors(
                    containerColor = accentColor,
                    contentColor = if (isWomenMode) Color.White else Color.Black
                ),
                modifier = Modifier.testTag("submit_feedback_btn")
            ) {
                Text("Publier l'avis", fontWeight = FontWeight.Bold)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Fermer")
            }
        }
    )
}

@Composable
private fun StarRatingSelector(
    rating: Int,
    accentColor: Color,
    onRatingSelected: (Int) -> Unit,
    testTagPrefix: String
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        for (star in 1..5) {
            IconButton(
                onClick = { onRatingSelected(star) },
                modifier = Modifier
                    .size(40.dp)
                    .testTag("${testTagPrefix}_$star")
            ) {
                Icon(
                    imageVector = if (star <= rating) Icons.Default.Star else Icons.Default.StarBorder,
                    contentDescription = "$star étoiles",
                    tint = if (star <= rating) accentColor else MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(26.dp)
                )
            }
        }
        Spacer(modifier = Modifier.width(6.dp))
        Text(
            text = "$rating/5",
            fontWeight = FontWeight.Bold,
            fontSize = 13.sp,
            color = accentColor
        )
    }
}
