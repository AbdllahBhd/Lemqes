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
import androidx.compose.ui.window.Dialog
import com.example.model.UserRole
import com.example.ui.theme.*

@Composable
fun SwitchAccountRoleDialog(
    currentRole: UserRole,
    onRoleSelected: (UserRole) -> Unit,
    onNewAccountClick: () -> Unit,
    onDismiss: () -> Unit
) {
    Dialog(onDismissRequest = onDismiss) {
        Card(
            shape = RoundedCornerShape(20.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            Column(modifier = Modifier.padding(20.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Basculer d'interface",
                        fontSize = 17.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    IconButton(onClick = onDismiss) {
                        Icon(Icons.Default.Close, contentDescription = "Fermer")
                    }
                }

                Text(
                    text = "Chaque type de compte possède sa propre interface dédiée :",
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 4.dp, bottom = 16.dp)
                )

                // Barber Option
                RoleSwitchRow(
                    title = "Espace Barbier (Karim)",
                    subtitle = "Statut en direct, file <10s, gestion des salons",
                    icon = Icons.Default.ContentCut,
                    accentColor = BarberEmerald,
                    isSelected = currentRole == UserRole.BARBER,
                    onClick = {
                        onRoleSelected(UserRole.BARBER)
                        onDismiss()
                    }
                )

                Spacer(modifier = Modifier.height(10.dp))

                // Home Artist Option
                RoleSwitchRow(
                    title = "Espace Artiste à Domicile",
                    subtitle = "Services chez le client (Hommes & Dames), rayon GPS & tarif dépl.",
                    icon = Icons.Default.HomeRepairService,
                    accentColor = BarberGoldPrimary,
                    isSelected = currentRole == UserRole.HOME_ARTIST,
                    onClick = {
                        onRoleSelected(UserRole.HOME_ARTIST)
                        onDismiss()
                    }
                )

                Spacer(modifier = Modifier.height(10.dp))

                // Customer Option
                RoleSwitchRow(
                    title = "Espace Client",
                    subtitle = "Recherche par wilaya, suivi des barbiers, RDV",
                    icon = Icons.Default.Person,
                    accentColor = BarberGoldPrimary,
                    isSelected = currentRole == UserRole.CUSTOMER,
                    onClick = {
                        onRoleSelected(UserRole.CUSTOMER)
                        onDismiss()
                    }
                )

                Spacer(modifier = Modifier.height(10.dp))

                // Shop Owner Option
                RoleSwitchRow(
                    title = "Espace Propriétaire de Salon",
                    subtitle = "Chaises actives, invitations, file combinée",
                    icon = Icons.Default.Storefront,
                    accentColor = BarberBlue,
                    isSelected = currentRole == UserRole.SHOP_OWNER,
                    onClick = {
                        onRoleSelected(UserRole.SHOP_OWNER)
                        onDismiss()
                    }
                )

                Spacer(modifier = Modifier.height(20.dp))

                // Option to re-create account or register another
                OutlinedButton(
                    onClick = {
                        onDismiss()
                        onNewAccountClick()
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(44.dp)
                        .testTag("create_new_account_btn"),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(Icons.Default.PersonAdd, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("Connexion / Créer un compte", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

@Composable
private fun RoleSwitchRow(
    title: String,
    subtitle: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    accentColor: Color,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    Surface(
        shape = RoundedCornerShape(14.dp),
        color = if (isSelected) accentColor.copy(alpha = 0.15f) else MaterialTheme.colorScheme.surfaceVariant,
        modifier = Modifier
            .fillMaxWidth()
            .border(
                width = if (isSelected) 1.5.dp else 0.5.dp,
                color = if (isSelected) accentColor else MaterialTheme.colorScheme.outline,
                shape = RoundedCornerShape(14.dp)
            )
            .clickable { onClick() }
    ) {
        Row(
            modifier = Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(if (isSelected) accentColor else MaterialTheme.colorScheme.surface),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = if (isSelected) Color.Black else accentColor,
                    modifier = Modifier.size(20.dp)
                )
            }

            Spacer(modifier = Modifier.width(12.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Text(
                    text = subtitle,
                    fontSize = 11.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            if (isSelected) {
                Icon(
                    imageVector = Icons.Default.Check,
                    contentDescription = null,
                    tint = accentColor,
                    modifier = Modifier.size(18.dp)
                )
            }
        }
    }
}
