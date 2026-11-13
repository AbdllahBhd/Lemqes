package com.example.ui.screens

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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.model.TargetAudience
import com.example.model.UserRole
import com.example.ui.components.ProfilePhotoPickerCard
import com.example.ui.components.RegistrationServiceSelectorAndCustomInput
import com.example.ui.theme.*

@Composable
fun HomeArtistMobilityStep(
    selectedAudience: TargetAudience,
    onAudienceChange: (TargetAudience) -> Unit,
    experienceYears: Int,
    onExperienceChange: (Int) -> Unit,
    serviceRadiusKm: Int,
    onServiceRadiusChange: (Int) -> Unit,
    travelFeeDzd: Int,
    onTravelFeeChange: (Int) -> Unit,
    coveredZones: String,
    onCoveredZonesChange: (String) -> Unit,
    avatarUrl: String,
    onAvatarChange: (String) -> Unit
) {
    val isWomen = selectedAudience == TargetAudience.WOMEN
    val accentCol = if (isWomen) BeautyFuchsia else BarberGoldPrimary

    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        ProfilePhotoPickerCard(
            avatarUrl = avatarUrl,
            title = if (isWomen) "Photo de profil Artiste Beauté" else "Photo de profil Barbier à Domicile",
            subtitle = "Montrez votre visage ou vos réalisations aux clients",
            accentColor = accentCol,
            fallbackIcon = if (isWomen) Icons.Default.Spa else Icons.Default.HomeRepairService,
            testTagPrefix = "reg_home_artist",
            onPhotoPicked = onAvatarChange,
            onRemovePhoto = if (avatarUrl.isNotBlank()) ({ onAvatarChange("") }) else null
        )

        AudienceSelectorCard(
            title = "Clientèle de vos déplacements à domicile :",
            role = UserRole.HOME_ARTIST,
            selectedAudience = selectedAudience,
            onAudienceChange = onAudienceChange
        )

        Card(
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(modifier = Modifier.padding(14.dp)) {
                Text(
                    text = "Années d'expérience :",
                    fontWeight = FontWeight.Bold,
                    fontSize = 13.sp,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Spacer(modifier = Modifier.height(8.dp))
                val expOptions = listOf(1 to "< 2 ans", 3 to "2 - 5 ans", 7 to "5 - 10 ans", 12 to "10+ ans")
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    expOptions.forEach { (yrs, label) ->
                        val isSel = experienceYears == yrs
                        Surface(
                            shape = RoundedCornerShape(10.dp),
                            color = if (isSel) accentCol else MaterialTheme.colorScheme.surface,
                            modifier = Modifier
                                .weight(1f)
                                .heightIn(min = 48.dp)
                                .clickable { onExperienceChange(yrs) }
                                .border(1.dp, if (isSel) accentCol else MaterialTheme.colorScheme.outline, RoundedCornerShape(10.dp))
                        ) {
                            Box(
                                modifier = Modifier.padding(vertical = 8.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = label,
                                    fontSize = 11.sp,
                                    fontWeight = if (isSel) FontWeight.Bold else FontWeight.Medium,
                                    color = if (isSel) (if (isWomen) Color.White else Color.Black) else MaterialTheme.colorScheme.onSurface
                                )
                            }
                        }
                    }
                }
            }
        }

        Card(
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
            modifier = Modifier
                .fillMaxWidth()
                .border(1.dp, accentCol.copy(alpha = 0.4f), RoundedCornerShape(16.dp))
        ) {
            Column(
                modifier = Modifier.padding(14.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.DirectionsCar, contentDescription = null, tint = accentCol, modifier = Modifier.size(18.dp))
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = "Zone d'intervention & Frais de déplacement :",
                        fontWeight = FontWeight.Bold,
                        fontSize = 13.sp,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                }

                Text("Rayon maximal autour de votre GPS :", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                val radiusOptions = listOf(5, 10, 20, 30)
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    radiusOptions.forEach { km ->
                        val isSel = serviceRadiusKm == km
                        Surface(
                            shape = RoundedCornerShape(10.dp),
                            color = if (isSel) accentCol else MaterialTheme.colorScheme.surface,
                            modifier = Modifier
                                .weight(1f)
                                .heightIn(min = 48.dp)
                                .clickable { onServiceRadiusChange(km) }
                                .border(1.dp, if (isSel) accentCol else MaterialTheme.colorScheme.outline, RoundedCornerShape(10.dp))
                        ) {
                            Box(modifier = Modifier.padding(vertical = 8.dp), contentAlignment = Alignment.Center) {
                                Text(
                                    text = "$km km",
                                    fontSize = 12.sp,
                                    fontWeight = if (isSel) FontWeight.Bold else FontWeight.Medium,
                                    color = if (isSel) (if (isWomen) Color.White else Color.Black) else MaterialTheme.colorScheme.onSurface
                                )
                            }
                        }
                    }
                }

                Text("Tarif de déplacement (en plus de la prestation) :", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                val feeOptions = listOf(0 to "Offert", 300 to "300 DA", 500 to "500 DA", 800 to "800 DA")
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    feeOptions.forEach { (fee, label) ->
                        val isSel = travelFeeDzd == fee
                        Surface(
                            shape = RoundedCornerShape(10.dp),
                            color = if (isSel) BarberEmerald else MaterialTheme.colorScheme.surface,
                            modifier = Modifier
                                .weight(1f)
                                .heightIn(min = 48.dp)
                                .clickable { onTravelFeeChange(fee) }
                                .border(1.dp, if (isSel) BarberEmerald else MaterialTheme.colorScheme.outline, RoundedCornerShape(10.dp))
                        ) {
                            Box(modifier = Modifier.padding(vertical = 8.dp), contentAlignment = Alignment.Center) {
                                Text(
                                    text = label,
                                    fontSize = 11.sp,
                                    fontWeight = if (isSel) FontWeight.Bold else FontWeight.Medium,
                                    color = if (isSel) Color.White else MaterialTheme.colorScheme.onSurface
                                )
                            }
                        }
                    }
                }

                OutlinedTextField(
                    value = coveredZones,
                    onValueChange = onCoveredZonesChange,
                    label = { Text("Quartiers / Zones desservies") },
                    placeholder = { Text("ex. Hydra, El Biar, Kouba, Dely Ibrahim") },
                    leadingIcon = { Icon(Icons.Default.Map, contentDescription = null, tint = accentCol) },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    singleLine = true
                )
            }
        }
    }
}

@Composable
fun HomeArtistServicesStep(
    selectedAudience: TargetAudience,
    selectedSpecialties: Set<String>,
    onToggleSpecialty: (String) -> Unit,
    onAddCustomSpecialty: (String) -> Unit
) {
    val isWomen = selectedAudience == TargetAudience.WOMEN
    val accentCol = if (isWomen) BeautyFuchsia else BarberGoldPrimary

    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        RegistrationServiceSelectorAndCustomInput(
            title = if (isWomen) "Vos prestations beauté à domicile :" else "Vos prestations à domicile :",
            selectedAudience = selectedAudience,
            isHomeArtist = true,
            accentColor = accentCol,
            selectedServices = selectedSpecialties,
            onToggleService = onToggleSpecialty,
            onAddCustomService = onAddCustomSpecialty
        )

        Surface(
            shape = RoundedCornerShape(14.dp),
            color = BarberEmerald.copy(alpha = 0.12f),
            modifier = Modifier
                .fillMaxWidth()
                .border(1.dp, BarberEmerald.copy(alpha = 0.45f), RoundedCornerShape(14.dp))
        ) {
            Row(modifier = Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(34.dp)
                        .clip(CircleShape)
                        .background(BarberEmerald.copy(alpha = 0.2f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(Icons.Default.Sanitizer, contentDescription = null, tint = BarberEmerald, modifier = Modifier.size(18.dp))
                }
                Spacer(modifier = Modifier.width(10.dp))
                Column {
                    Text("Kit mobile complet & stérilisé", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = BarberEmerald)
                    Text(
                        "Un badge « Kit Stérilisé À Domicile » rassurera vos clients et clientes lors de la réservation.",
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }

        GpsLocationCard(
            title = "Point GPS de départ à domicile",
            subtitle = "Calcul automatique de votre rayon d'intervention",
            accentColor = accentCol
        )
    }
}
