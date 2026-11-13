package com.example.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
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
import com.example.i18n.StringsManager
import com.example.i18n.SupportedLanguage
import com.example.model.BarberStatus
import com.example.model.UserAccount
import com.example.model.UserRole
import com.example.ui.theme.*

@Composable
fun TopRoleAndLangBar(
    currentRole: UserRole,
    userAccount: UserAccount?,
    onSwitchAccountClick: () -> Unit,
    onWalletClick: () -> Unit = {},
    currentLang: SupportedLanguage,
    onLangSelected: (SupportedLanguage) -> Unit,
    isDarkMode: Boolean,
    onToggleDarkMode: () -> Unit,
    modifier: Modifier = Modifier
) {
    Surface(
        color = MaterialTheme.colorScheme.surface,
        tonalElevation = 3.dp,
        modifier = modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
            // Brand & Language Header
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .size(32.dp)
                            .clip(CircleShape)
                            .background(BarberGoldPrimary),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.ContentCut,
                            contentDescription = "Lemqes Scissors",
                            tint = Color.Black,
                            modifier = Modifier.size(18.dp)
                        )
                    }
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "LEMQES",
                        fontWeight = FontWeight.Black,
                        fontSize = 18.sp,
                        letterSpacing = 1.sp,
                        color = MaterialTheme.colorScheme.primary
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = "DZ",
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                Row(verticalAlignment = Alignment.CenterVertically) {
                    // Dark / Light Mode Toggle
                    IconButton(
                        onClick = onToggleDarkMode,
                        modifier = Modifier
                            .testTag("theme_toggle_btn")
                            .size(36.dp)
                    ) {
                        Icon(
                            imageVector = if (isDarkMode) Icons.Default.LightMode else Icons.Default.DarkMode,
                            contentDescription = "Toggle theme",
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(20.dp)
                        )
                    }

                    // Language Selector Dropdown Pills
                    Row(
                        modifier = Modifier
                            .clip(RoundedCornerShape(20.dp))
                            .background(MaterialTheme.colorScheme.surfaceVariant)
                            .padding(2.dp)
                    ) {
                        SupportedLanguage.values().forEach { lang ->
                            val selected = lang == currentLang
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(16.dp))
                                    .background(if (selected) BarberGoldPrimary else Color.Transparent)
                                    .clickable { onLangSelected(lang) }
                                    .padding(horizontal = 8.dp, vertical = 4.dp)
                                    .testTag("lang_btn_${lang.code}")
                            ) {
                                Text(
                                    text = lang.code.uppercase(),
                                    fontSize = 11.sp,
                                    fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium,
                                    color = if (selected) Color.Black else MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Dedicated Account Identity Card & Role Context
            Surface(
                shape = RoundedCornerShape(12.dp),
                color = MaterialTheme.colorScheme.surfaceVariant,
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onSwitchAccountClick() }
                    .testTag("current_account_bar")
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        val (roleBadgeColor, roleTitle, roleIcon) = when (currentRole) {
                            UserRole.BARBER -> Triple(BarberEmerald, "Espace Barbier Indépendant", Icons.Default.ContentCut)
                            UserRole.HOME_ARTIST -> Triple(BarberGoldPrimary, "Espace Artiste à Domicile", Icons.Default.HomeRepairService)
                            UserRole.CUSTOMER -> Triple(BarberGoldPrimary, "Espace Client", Icons.Default.Person)
                            UserRole.SHOP_OWNER -> Triple(BarberBlue, "Espace Gérant de Salon", Icons.Default.Storefront)
                        }

                        Box(
                            modifier = Modifier
                                .size(28.dp)
                                .clip(CircleShape)
                                .background(roleBadgeColor.copy(alpha = 0.2f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = roleIcon,
                                contentDescription = null,
                                tint = roleBadgeColor,
                                modifier = Modifier.size(16.dp)
                            )
                        }

                        Spacer(modifier = Modifier.width(10.dp))

                        Column {
                            Text(
                                text = roleTitle,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Text(
                                text = userAccount?.let { "${it.fullName} • ${it.phoneNumber}" } ?: "Compte actif",
                                fontSize = 10.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }

                    Row(verticalAlignment = Alignment.CenterVertically) {
                        // Wallet Credits Pill (for Barber, Home Artist & Shop Owner)
                        if (userAccount != null && (currentRole == UserRole.BARBER || currentRole == UserRole.HOME_ARTIST || currentRole == UserRole.SHOP_OWNER)) {
                            Surface(
                                shape = RoundedCornerShape(8.dp),
                                color = BarberGoldPrimary.copy(alpha = 0.2f),
                                modifier = Modifier
                                    .clickable { onWalletClick() }
                                    .padding(end = 6.dp)
                                    .testTag("open_wallet_badge")
                            ) {
                                Row(
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Icon(Icons.Default.AccountBalanceWallet, contentDescription = null, tint = BarberGoldPrimary, modifier = Modifier.size(13.dp))
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text(
                                        text = String.format("%.1f $", userAccount.wallet.balanceUsd),
                                        fontSize = 11.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = BarberGoldPrimary
                                    )
                                }
                            }
                        }

                        Surface(
                            shape = RoundedCornerShape(8.dp),
                            color = MaterialTheme.colorScheme.surface
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(Icons.Default.SwapHoriz, contentDescription = null, modifier = Modifier.size(14.dp), tint = BarberGoldPrimary)
                                Spacer(modifier = Modifier.width(4.dp))
                                Text("Changer rôle", fontSize = 10.sp, fontWeight = FontWeight.Bold, color = BarberGoldPrimary)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun FastStatusToggle(
    currentStatus: BarberStatus,
    onStatusChange: (BarberStatus) -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
        modifier = modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Text(
                text = "⚡ Statut Rapide (1 Tap)",
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Spacer(modifier = Modifier.height(10.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                // Online Button
                val isOnline = currentStatus == BarberStatus.ONLINE
                Button(
                    onClick = { onStatusChange(BarberStatus.ONLINE) },
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp)
                        .testTag("status_online_btn"),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (isOnline) BarberEmerald else Color(0x3310B981),
                        contentColor = if (isOnline) Color.White else BarberEmerald
                    ),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Text("🟢 Dispo", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                }

                // Break Button
                val isBreak = currentStatus == BarberStatus.ON_BREAK
                Button(
                    onClick = { onStatusChange(BarberStatus.ON_BREAK) },
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp)
                        .testTag("status_break_btn"),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (isBreak) BarberAmber else Color(0x33F59E0B),
                        contentColor = if (isBreak) Color.Black else BarberAmber
                    ),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Text("🟡 Pause", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                }

                // Offline Button
                val isOffline = currentStatus == BarberStatus.OFFLINE
                Button(
                    onClick = { onStatusChange(BarberStatus.OFFLINE) },
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp)
                        .testTag("status_offline_btn"),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (isOffline) BarberRose else Color(0x33EF4444),
                        contentColor = if (isOffline) Color.White else BarberRose
                    ),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Text("🔴 Fermé", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                }
            }
        }
    }
}
