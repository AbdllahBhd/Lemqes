package com.example.ui.components

import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.example.model.Country
import com.example.model.WalletAccount
import com.example.ui.theme.*

@Composable
fun WalletBillingDialog(
    wallet: WalletAccount,
    onTopUp: (Double) -> Unit,
    onWatchAd: () -> Unit,
    onDismiss: () -> Unit
) {
    var isWatchingAd by remember { mutableStateOf(false) }
    var adTimer by remember { mutableStateOf(30) }
    val scrollState = rememberScrollState()

    // 30 seconds non-skippable timer simulation
    LaunchedEffect(isWatchingAd) {
        if (isWatchingAd) {
            adTimer = 30
            while (adTimer > 0) {
                kotlinx.coroutines.delay(1000)
                adTimer--
            }
            onWatchAd()
            isWatchingAd = false
        }
    }

    Dialog(onDismissRequest = {
        // Prevent closing during unskippable 30s ad
        if (!isWatchingAd) {
            onDismiss()
        }
    }) {
        Card(
            shape = RoundedCornerShape(24.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 4.dp, vertical = 12.dp)
        ) {
            if (isWatchingAd) {
                // Full Screen Video Player Simulation (Non-skippable 30 seconds)
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(20.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Surface(
                            shape = RoundedCornerShape(8.dp),
                            color = BarberRose
                        ) {
                            Text(
                                text = "Pub non désactivable : ${adTimer}s",
                                color = Color.White,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Bold,
                                modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp)
                            )
                        }

                        Surface(
                            shape = RoundedCornerShape(8.dp),
                            color = BarberGoldPrimary.copy(alpha = 0.2f)
                        ) {
                            Text(
                                text = "+${String.format("%.2f", wallet.perAdRewardUsd)} $ en attente",
                                color = BarberGoldPrimary,
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold,
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(16.dp))

                    // Video canvas mockup
                    Surface(
                        shape = RoundedCornerShape(16.dp),
                        color = Color(0xFF0F172A),
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(200.dp)
                            .border(1.dp, BarberBlue, RoundedCornerShape(16.dp))
                    ) {
                        Column(
                            modifier = Modifier.fillMaxSize().padding(16.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.Center
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(54.dp)
                                    .clip(CircleShape)
                                    .background(BarberBlue.copy(alpha = 0.3f)),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(
                                    imageVector = Icons.Default.SmartDisplay,
                                    contentDescription = "Video Ad",
                                    tint = BarberBlue,
                                    modifier = Modifier.size(32.dp)
                                )
                            }
                            Spacer(modifier = Modifier.height(12.dp))
                            Text(
                                text = "Sponsor Algérien : 'Mobilis / Ooredoo 4G+'",
                                fontWeight = FontWeight.Bold,
                                fontSize = 13.sp,
                                color = Color.White
                            )
                            Text(
                                text = "Ne quittez pas cette page avant la fin du décompte",
                                fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(16.dp))

                    LinearProgressIndicator(
                        progress = { (30f - adTimer.toFloat()) / 30f },
                        modifier = Modifier.fillMaxWidth().height(8.dp).clip(RoundedCornerShape(4.dp)),
                        color = BarberGoldPrimary,
                        trackColor = MaterialTheme.colorScheme.surfaceVariant
                    )

                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "Récompense attribuée dans $adTimer secondes...",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            } else {
                // Regular Wallet View
                Column(
                    modifier = Modifier
                        .padding(20.dp)
                        .verticalScroll(scrollState)
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
                                    .size(36.dp)
                                    .clip(CircleShape)
                                    .background(BarberGoldPrimary),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(Icons.Default.AccountBalanceWallet, contentDescription = null, tint = Color.Black, modifier = Modifier.size(20.dp))
                            }
                            Spacer(modifier = Modifier.width(10.dp))
                            Text(
                                text = "Portefeuille & Crédits",
                                fontSize = 17.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                        }

                        IconButton(onClick = onDismiss) {
                            Icon(Icons.Default.Close, contentDescription = "Fermer")
                        }
                    }

                    Spacer(modifier = Modifier.height(14.dp))

                    // Wallet Balance Card
                    Card(
                        shape = RoundedCornerShape(18.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                        modifier = Modifier
                            .fillMaxWidth()
                            .border(1.dp, BarberGoldPrimary.copy(alpha = 0.5f), RoundedCornerShape(18.dp))
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.Top
                            ) {
                                Column {
                                    Text("Solde disponible", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    Text(
                                        text = String.format("%.2f $", wallet.balanceUsd),
                                        fontSize = 32.sp,
                                        fontWeight = FontWeight.Black,
                                        color = BarberGoldPrimary
                                    )
                                }

                                Surface(
                                    shape = RoundedCornerShape(10.dp),
                                    color = BarberEmerald.copy(alpha = 0.15f)
                                ) {
                                    Text(
                                        text = "${wallet.country.nameFr} (${wallet.country.localMonthlyPrice}/mois)",
                                        fontSize = 11.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = BarberEmerald,
                                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                                    )
                                }
                            }

                            Spacer(modifier = Modifier.height(10.dp))

                            // Counter of days remaining to cover month for free
                            Surface(
                                shape = RoundedCornerShape(12.dp),
                                color = MaterialTheme.colorScheme.surface,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .border(1.dp, BarberGoldPrimary.copy(alpha = 0.4f), RoundedCornerShape(12.dp))
                            ) {
                                Column(modifier = Modifier.padding(12.dp)) {
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.SpaceBetween
                                    ) {
                                        Row(verticalAlignment = Alignment.CenterVertically) {
                                            Box(
                                                modifier = Modifier
                                                    .size(38.dp)
                                                    .clip(CircleShape)
                                                    .background(BarberGoldPrimary),
                                                contentAlignment = Alignment.Center
                                            ) {
                                                Icon(Icons.Default.HourglassBottom, contentDescription = null, tint = Color.Black, modifier = Modifier.size(20.dp))
                                            }
                                            Spacer(modifier = Modifier.width(10.dp))
                                            Column {
                                                Text(
                                                    text = "Objectif mensuel gratuit (25 jours)",
                                                    fontSize = 11.sp,
                                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                                )
                                                Text(
                                                    text = "Encore ${wallet.daysRemainingToCoverMonth} jours de pubs",
                                                    fontSize = 15.sp,
                                                    fontWeight = FontWeight.Bold,
                                                    color = BarberGoldPrimary
                                                )
                                            }
                                        }

                                        Surface(
                                            shape = RoundedCornerShape(8.dp),
                                            color = BarberEmerald.copy(alpha = 0.15f)
                                        ) {
                                            Text(
                                                text = "${wallet.daysWatchedThisMonth}/25 jours validés",
                                                fontSize = 10.sp,
                                                fontWeight = FontWeight.Bold,
                                                color = BarberEmerald,
                                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 3.dp)
                                            )
                                        }
                                    }

                                    Spacer(modifier = Modifier.height(6.dp))

                                    LinearProgressIndicator(
                                        progress = { wallet.daysWatchedThisMonth.toFloat() / 25f },
                                        modifier = Modifier.fillMaxWidth().height(6.dp).clip(RoundedCornerShape(3.dp)),
                                        color = BarberGoldPrimary,
                                        trackColor = MaterialTheme.colorScheme.surfaceVariant
                                    )
                                }
                            }

                            Spacer(modifier = Modifier.height(8.dp))

                            Text(
                                text = "Tarif après mois gratuit : ${wallet.country.localMonthlyPrice} / mois (soit ${wallet.country.monthlyRateUsd.toInt()} $ - Objectif atteint en 25 jours avec 3 pubs/jour)",
                                fontSize = 10.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(14.dp))

                    // Grille des Tarifs par Pays (en devises locales)
                    Card(
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.padding(14.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = "Tarifs d'abonnement par pays",
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 12.sp,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                                Surface(
                                    shape = RoundedCornerShape(6.dp),
                                    color = BarberEmerald.copy(alpha = 0.2f)
                                ) {
                                    Text(
                                        text = "1er mois 100% offert",
                                        fontSize = 10.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = BarberEmerald,
                                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                    )
                                }
                            }
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = "Le 1er mois gratuit commence directement. Le tarif ci-dessous s'applique au renouvellement selon votre pays :",
                                fontSize = 10.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                for (c in Country.entries) {
                                    val isCurrent = c == wallet.country
                                    Row(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .clip(RoundedCornerShape(8.dp))
                                            .background(if (isCurrent) BarberEmerald.copy(alpha = 0.15f) else MaterialTheme.colorScheme.surface)
                                            .padding(horizontal = 10.dp, vertical = 6.dp),
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Row(verticalAlignment = Alignment.CenterVertically) {
                                            Text(
                                                text = when (c) {
                                                    Country.ALGERIA -> "🇩🇿 Algérie"
                                                    Country.TUNISIA -> "🇹🇳 Tunisie"
                                                    Country.MOROCCO -> "🇲🇦 Maroc"
                                                    Country.FRANCE -> "🇫🇷 France / Europe"
                                                    Country.OTHER -> "🌐 International"
                                                },
                                                fontWeight = if (isCurrent) FontWeight.Bold else FontWeight.Medium,
                                                fontSize = 12.sp,
                                                color = MaterialTheme.colorScheme.onSurface
                                            )
                                            if (isCurrent) {
                                                Spacer(modifier = Modifier.width(6.dp))
                                                Text(
                                                    text = "• Votre tarif",
                                                    fontSize = 10.sp,
                                                    fontWeight = FontWeight.Bold,
                                                    color = BarberEmerald
                                                )
                                            }
                                        }
                                        Text(
                                            text = "${c.localMonthlyPrice} / mois",
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 12.sp,
                                            color = if (isCurrent) BarberEmerald else BarberGoldPrimary
                                        )
                                    }
                                }
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(16.dp))

                    // Option A: Watch 30s Non-Skippable Ads to Earn Credits (3 ads per day = dynamic target)
                    val dailyGain = wallet.dailyAdGoalUsd
                    val perAdGain = wallet.perAdRewardUsd
                    Text("Option 1 : Gagner des crédits (3 pubs/jour = +${String.format("%.2f", dailyGain)} $)", fontSize = 13.sp, fontWeight = FontWeight.Bold)
                    Spacer(modifier = Modifier.height(6.dp))

                    Card(
                        shape = RoundedCornerShape(14.dp),
                        colors = CardDefaults.cardColors(containerColor = BarberBlue.copy(alpha = 0.1f)),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.padding(14.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(Icons.Default.SmartDisplay, contentDescription = null, tint = BarberBlue)
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Column {
                                        Text("3 vidéos par jour (30s)", fontWeight = FontWeight.Bold, fontSize = 12.sp)
                                        Text("3 vidéos = +${String.format("%.2f", dailyGain)} $ / jour (+${String.format("%.2f", perAdGain)} $/pub)", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    }
                                }
                                Surface(
                                    shape = RoundedCornerShape(8.dp),
                                    color = if (wallet.rewardedAdsWatchedToday >= 3) BarberEmerald.copy(alpha = 0.2f) else BarberBlue.copy(alpha = 0.2f)
                                ) {
                                    Text(
                                        text = "${wallet.rewardedAdsWatchedToday}/3 aujourd'hui",
                                        fontSize = 11.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = if (wallet.rewardedAdsWatchedToday >= 3) BarberEmerald else BarberBlue,
                                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 3.dp)
                                    )
                                }
                            }

                            Spacer(modifier = Modifier.height(10.dp))

                            Button(
                                onClick = { isWatchingAd = true },
                                enabled = wallet.rewardedAdsWatchedToday < 3,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(44.dp)
                                    .testTag("watch_rewarded_ad_btn"),
                                colors = ButtonDefaults.buttonColors(containerColor = BarberBlue, contentColor = Color.White),
                                shape = RoundedCornerShape(10.dp)
                            ) {
                                Icon(Icons.Default.PlayArrow, contentDescription = null, modifier = Modifier.size(16.dp))
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(
                                    text = if (wallet.rewardedAdsWatchedToday < 3) "Lancer la vidéo (${wallet.rewardedAdsWatchedToday + 1}/3) • +${String.format("%.2f", perAdGain)} $" else "Objectif du jour complété (+${String.format("%.2f", dailyGain)} $ reçu)",
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.Bold
                                )
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(16.dp))

                    // Option B: Buy Credits / Top Up
                    Text("Option 2 : Recharger par carte / paiement", fontSize = 13.sp, fontWeight = FontWeight.Bold)
                    Spacer(modifier = Modifier.height(6.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        // +3$ Pack (1 month DZ)
                        Button(
                            onClick = { onTopUp(3.0) },
                            modifier = Modifier
                                .weight(1f)
                                .height(56.dp)
                                .testTag("topup_3_usd_btn"),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = MaterialTheme.colorScheme.surfaceVariant,
                                contentColor = MaterialTheme.colorScheme.onSurface
                            ),
                            shape = RoundedCornerShape(12.dp),
                            border = androidx.compose.foundation.BorderStroke(1.dp, BarberGoldPrimary)
                        ) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Text("+3.00 $", fontWeight = FontWeight.Black, fontSize = 14.sp, color = BarberGoldPrimary)
                                Text("1 mois (DZ)", fontSize = 9.sp)
                            }
                        }

                        // +6$ Pack (2 months DZ / 1 month Europe)
                        Button(
                            onClick = { onTopUp(6.0) },
                            modifier = Modifier
                                .weight(1f)
                                .height(56.dp)
                                .testTag("topup_6_usd_btn"),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = MaterialTheme.colorScheme.surfaceVariant,
                                contentColor = MaterialTheme.colorScheme.onSurface
                            ),
                            shape = RoundedCornerShape(12.dp),
                            border = androidx.compose.foundation.BorderStroke(1.dp, BarberGoldPrimary)
                        ) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Text("+6.00 $", fontWeight = FontWeight.Black, fontSize = 14.sp, color = BarberGoldPrimary)
                                Text("2 mois (DZ)", fontSize = 9.sp)
                            }
                        }

                        // +18$ Pack (6 months DZ)
                        Button(
                            onClick = { onTopUp(18.0) },
                            modifier = Modifier
                                .weight(1.1f)
                                .height(56.dp)
                                .testTag("topup_18_usd_btn"),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = BarberGoldPrimary,
                                contentColor = Color.Black
                            ),
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Text("+18.00 $", fontWeight = FontWeight.Black, fontSize = 14.sp)
                                Text("Pack 6 mois", fontSize = 9.sp, fontWeight = FontWeight.Bold)
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(10.dp))

                    Text(
                        text = "Paiements acceptés : Edahabia / CIB (Chargily Pay), Carte Bancaire Visa/Mastercard.",
                        fontSize = 10.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}
