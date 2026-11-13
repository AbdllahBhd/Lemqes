package com.example.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import com.example.model.BarberProfile
import com.example.model.BarberStatus
import com.example.model.BarberWorkplace
import com.example.ui.theme.*

@Composable
fun BarberWorkplaceHeroCard(
    workplace: BarberWorkplace,
    onChangeWorkplaceClick: () -> Unit,
    onBroadcastClick: () -> Unit,
    subscribersCount: Int,
    modifier: Modifier = Modifier
) {
    Card(
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
        modifier = modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
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
                            .background(BarberGoldPrimary.copy(alpha = 0.2f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.Place,
                            contentDescription = "Lieu actuel",
                            tint = BarberGoldPrimary,
                            modifier = Modifier.size(20.dp)
                        )
                    }
                    Spacer(modifier = Modifier.width(10.dp))
                    Column {
                        Text(
                            text = "Lieu de travail actuel",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Text(
                            text = workplace.shopName,
                            fontSize = 17.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                    }
                }

                Surface(
                    shape = RoundedCornerShape(10.dp),
                    color = BarberEmerald.copy(alpha = 0.15f)
                ) {
                    Text(
                        text = "Actif",
                        color = BarberEmerald,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(10.dp))

            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    imageVector = Icons.Default.LocationOn,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(16.dp)
                )
                Spacer(modifier = Modifier.width(6.dp))
                Text(
                    text = "${workplace.address} (${workplace.commune}, ${workplace.wilaya})",
                    fontSize = 13.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            Spacer(modifier = Modifier.height(14.dp))

            // Action row: Change workplace in under 30s + Notify followers
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                OutlinedButton(
                    onClick = onChangeWorkplaceClick,
                    modifier = Modifier
                        .weight(1.2f)
                        .height(44.dp)
                        .testTag("change_workplace_btn"),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.SwapHoriz,
                        contentDescription = null,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("Changer salon (30s)", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                }

                Button(
                    onClick = onBroadcastClick,
                    modifier = Modifier
                        .weight(1f)
                        .height(44.dp)
                        .testTag("broadcast_followers_btn"),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = BarberBlue.copy(alpha = 0.2f),
                        contentColor = BarberBlue
                    ),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Campaign,
                        contentDescription = null,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Notifier ($subscribersCount)", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

@Composable
fun BarberQueueControlsCard(
    waitingCount: Int,
    estimatedWaitMins: Int,
    onAddWalkIn: () -> Unit,
    onCustomerDone: () -> Unit,
    onCallNext: () -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
        modifier = modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "FILE EN DIRECT (LA MIENNE)",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 1.sp,
                        color = MaterialTheme.colorScheme.primary
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Row(verticalAlignment = Alignment.Bottom) {
                        Text(
                            text = "$waitingCount",
                            fontSize = 36.sp,
                            fontWeight = FontWeight.Black,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = "en attente",
                            fontSize = 14.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(bottom = 6.dp)
                        )
                    }
                }

                Surface(
                    shape = RoundedCornerShape(12.dp),
                    color = MaterialTheme.colorScheme.surface,
                    modifier = Modifier.border(1.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(12.dp))
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp)
                    ) {
                        Text(
                            text = "Attente estimée",
                            fontSize = 10.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Text(
                            text = "~$estimatedWaitMins min",
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold,
                            color = BarberGoldPrimary
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Big 10-second barber action buttons
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                // +1 Walk-in button
                Button(
                    onClick = onAddWalkIn,
                    modifier = Modifier
                        .weight(1f)
                        .height(54.dp)
                        .testTag("barber_add_walkin_btn"),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = BarberGoldPrimary,
                        contentColor = Color.Black
                    ),
                    shape = RoundedCornerShape(14.dp)
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("+1 Sans Rdv", fontSize = 14.sp, fontWeight = FontWeight.Black)
                        Text("Client direct", fontSize = 10.sp)
                    }
                }

                // -1 Customer Done button
                Button(
                    onClick = onCustomerDone,
                    modifier = Modifier
                        .weight(1f)
                        .height(54.dp)
                        .testTag("barber_customer_done_btn"),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = BarberEmerald,
                        contentColor = Color.White
                    ),
                    shape = RoundedCornerShape(14.dp)
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("−1 Terminé", fontSize = 14.sp, fontWeight = FontWeight.Black)
                        Text("Libère la chaise", fontSize = 10.sp)
                    }
                }

                // Call Next Push notification button
                Button(
                    onClick = onCallNext,
                    modifier = Modifier
                        .weight(1.1f)
                        .height(54.dp)
                        .testTag("barber_call_next_btn"),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = BarberBlue,
                        contentColor = Color.White
                    ),
                    shape = RoundedCornerShape(14.dp)
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("📢 Suivant !", fontSize = 14.sp, fontWeight = FontWeight.Black)
                        Text("Push notif 5m", fontSize = 10.sp)
                    }
                }
            }
        }
    }
}
