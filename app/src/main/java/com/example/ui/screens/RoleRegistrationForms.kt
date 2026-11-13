package com.example.ui.screens

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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.model.TargetAudience
import com.example.model.UserRole
import com.example.model.WorkplaceType
import com.example.ui.components.ProfilePhotoPickerCard
import com.example.ui.components.RegistrationServiceSelectorAndCustomInput
import com.example.ui.theme.*

@Composable
fun StartForFreeBanner(
    role: UserRole,
    accentColor: Color,
    modifier: Modifier = Modifier
) {
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = BarberEmerald.copy(alpha = 0.12f),
        modifier = modifier
            .fillMaxWidth()
            .border(1.dp, BarberEmerald.copy(alpha = 0.6f), RoundedCornerShape(16.dp))
    ) {
        Row(
            modifier = Modifier.padding(14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(BarberEmerald.copy(alpha = 0.2f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.CardGiftcard,
                    contentDescription = null,
                    tint = BarberEmerald,
                    modifier = Modifier.size(22.dp)
                )
            }
            Spacer(modifier = Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = if (role == UserRole.SHOP_OWNER) {
                        "Commencez gratuitement — 1er mois offert"
                    } else {
                        "Commencez gratuitement — Sans engagement"
                    },
                    fontWeight = FontWeight.Bold,
                    fontSize = 13.sp,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Text(
                    text = "Démarrez votre activité dès maintenant gratuitement, sans carte bancaire ni paiement requis à l'inscription.",
                    fontSize = 11.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    lineHeight = 15.sp
                )
            }
        }
    }
}

@Composable
fun BarberProfileDetailsStep(
    selectedAudience: TargetAudience,
    onAudienceChange: (TargetAudience) -> Unit,
    experienceYears: Int,
    onExperienceChange: (Int) -> Unit,
    workplaceType: WorkplaceType,
    onWorkplaceTypeChange: (WorkplaceType) -> Unit,
    workplaceName: String,
    onWorkplaceNameChange: (String) -> Unit,
    avatarUrl: String,
    onAvatarChange: (String) -> Unit
) {
    val isWomen = selectedAudience == TargetAudience.WOMEN
    val accentCol = if (isWomen) BeautyFuchsia else BarberGoldPrimary

    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        ProfilePhotoPickerCard(
            avatarUrl = avatarUrl,
            title = if (isWomen) "Photo de profil Coiffeuse / Esthéticienne" else "Photo de profil Barbier",
            subtitle = "Ajoutez votre photo pour rassurer vos futurs clients",
            accentColor = accentCol,
            fallbackIcon = if (isWomen) Icons.Default.Spa else Icons.Default.Person,
            testTagPrefix = "reg_barber",
            onPhotoPicked = onAvatarChange,
            onRemovePhoto = if (avatarUrl.isNotBlank()) ({ onAvatarChange("") }) else null
        )

        AudienceSelectorCard(
            title = "Votre domaine & clientèle :",
            role = UserRole.BARBER,
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
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(
                modifier = Modifier.padding(14.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    text = "Mode d'exercice actuel :",
                    fontWeight = FontWeight.Bold,
                    fontSize = 13.sp,
                    color = MaterialTheme.colorScheme.onSurface
                )
                val modes = listOf(
                    Triple(WorkplaceType.REGISTERED_SHOP, "🏢 En Salon", "Salon partenaire"),
                    Triple(WorkplaceType.FREELANCE_MOBILE, "🚗 À Domicile", "Mobile / VIP"),
                    Triple(WorkplaceType.CUSTOM_LOCATION, "📍 Studio Perso", "Local privé")
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    modes.forEach { (type, title, _) ->
                        val isSel = workplaceType == type
                        Surface(
                            shape = RoundedCornerShape(10.dp),
                            color = if (isSel) accentCol else MaterialTheme.colorScheme.surface,
                            modifier = Modifier
                                .weight(1f)
                                .heightIn(min = 48.dp)
                                .clickable { onWorkplaceTypeChange(type) }
                                .border(1.dp, if (isSel) accentCol else MaterialTheme.colorScheme.outline, RoundedCornerShape(10.dp))
                        ) {
                            Box(
                                modifier = Modifier.padding(vertical = 9.dp, horizontal = 4.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = title,
                                    fontSize = 11.sp,
                                    fontWeight = if (isSel) FontWeight.Bold else FontWeight.Medium,
                                    color = if (isSel) (if (isWomen) Color.White else Color.Black) else MaterialTheme.colorScheme.onSurface
                                )
                            }
                        }
                    }
                }

                OutlinedTextField(
                    value = workplaceName,
                    onValueChange = onWorkplaceNameChange,
                    label = {
                        Text(
                            when (workplaceType) {
                                WorkplaceType.REGISTERED_SHOP -> if (isWomen) "Nom de l'institut / salon (optionnel)" else "Nom du salon actuel (optionnel)"
                                WorkplaceType.FREELANCE_MOBILE -> "Zone desservie (ex: Grand Alger, Hydra...)"
                                WorkplaceType.CUSTOM_LOCATION -> "Nom ou adresse de votre local / cabine"
                            }
                        )
                    },
                    leadingIcon = { Icon(Icons.Default.Workspaces, contentDescription = null, tint = accentCol) },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    singleLine = true
                )
            }
        }
    }
}

@Composable
fun BarberServicesAndLocationStep(
    selectedAudience: TargetAudience,
    selectedSpecialties: Set<String>,
    onToggleSpecialty: (String) -> Unit,
    onAddCustomSpecialty: (String) -> Unit
) {
    val isWomen = selectedAudience == TargetAudience.WOMEN
    val accentCol = if (isWomen) BeautyFuchsia else BarberGoldPrimary

    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        RegistrationServiceSelectorAndCustomInput(
            title = if (isWomen) "Vos prestations beauté & coiffure :" else "Vos spécialités & prestations :",
            selectedAudience = selectedAudience,
            isHomeArtist = false,
            accentColor = accentCol,
            selectedServices = selectedSpecialties,
            onToggleService = onToggleSpecialty,
            onAddCustomService = onAddCustomSpecialty
        )

        GpsLocationCard(
            title = "Localisation GPS de votre poste",
            subtitle = "Pour apparaître dans le radar « Autour de moi »",
            accentColor = accentCol
        )
    }
}

@Composable
fun ShopOwnerSetupStep(
    selectedAudience: TargetAudience,
    onAudienceChange: (TargetAudience) -> Unit,
    chairCountLabel: String,
    onChairCountChange: (String) -> Unit,
    openingHours: String,
    onOpeningHoursChange: (String) -> Unit,
    selectedAmenities: Set<String>,
    onToggleAmenity: (String) -> Unit,
    ownerAlsoWorksChair: Boolean,
    onOwnerChairToggle: (Boolean) -> Unit,
    addressLandmark: String,
    onAddressLandmarkChange: (String) -> Unit,
    avatarUrl: String,
    onAvatarChange: (String) -> Unit
) {
    val isWomen = selectedAudience == TargetAudience.WOMEN
    val accentCol = if (isWomen) BeautyFuchsia else BarberBlue

    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        ProfilePhotoPickerCard(
            avatarUrl = avatarUrl,
            title = if (isWomen) "Photo / Logo de votre Institut" else "Photo / Logo de votre Salon",
            subtitle = "Affichez votre vitrine ou logo dans la recherche",
            accentColor = accentCol,
            fallbackIcon = Icons.Default.Storefront,
            testTagPrefix = "reg_shop",
            onPhotoPicked = onAvatarChange,
            onRemovePhoto = if (avatarUrl.isNotBlank()) ({ onAvatarChange("") }) else null
        )

        AudienceSelectorCard(
            title = "Orientation de votre établissement :",
            role = UserRole.SHOP_OWNER,
            selectedAudience = selectedAudience,
            onAudienceChange = onAudienceChange
        )

        Card(
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(
                modifier = Modifier.padding(14.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Text(
                    text = if (isWomen) "Capacité & Horaires de l'institut :" else "Capacité & Horaires du salon :",
                    fontWeight = FontWeight.Bold,
                    fontSize = 13.sp,
                    color = MaterialTheme.colorScheme.onSurface
                )

                val chairOpts = listOf("1 - 2 postes", "3 - 5 postes", "6+ postes")
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    chairOpts.forEach { opt ->
                        val isSel = chairCountLabel == opt
                        Surface(
                            shape = RoundedCornerShape(10.dp),
                            color = if (isSel) accentCol else MaterialTheme.colorScheme.surface,
                            modifier = Modifier
                                .weight(1f)
                                .heightIn(min = 48.dp)
                                .clickable { onChairCountChange(opt) }
                                .border(1.dp, if (isSel) accentCol else MaterialTheme.colorScheme.outline, RoundedCornerShape(10.dp))
                        ) {
                            Box(
                                modifier = Modifier.padding(vertical = 8.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = opt,
                                    fontSize = 11.sp,
                                    fontWeight = if (isSel) FontWeight.Bold else FontWeight.Medium,
                                    color = if (isSel) Color.White else MaterialTheme.colorScheme.onSurface
                                )
                            }
                        }
                    }
                }

                OutlinedTextField(
                    value = openingHours,
                    onValueChange = onOpeningHoursChange,
                    label = { Text("Horaires d'ouverture") },
                    placeholder = { Text("ex. 09:00 - 21:00") },
                    leadingIcon = { Icon(Icons.Default.Schedule, contentDescription = null, tint = accentCol) },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    singleLine = true
                )

                Text(
                    text = "Atouts & Équipements :",
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                val amenitiesList = if (isWomen) {
                    listOf("100% Femmes", "Espace Voile Privé", "Onglerie Russe", "Cabine Skincare", "Espace Mariée", "BaridiMob & Cash")
                } else {
                    listOf("Climatisation", "Wi-Fi Gratuit", "Espace Enfants", "Café / TV", "Parking", "Paiement Cash / BaridiMob")
                }
                LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    items(amenitiesList) { am ->
                        val isSel = selectedAmenities.contains(am)
                        FilterChip(
                            selected = isSel,
                            onClick = { onToggleAmenity(am) },
                            label = { Text(am, fontSize = 11.sp) },
                            colors = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = accentCol.copy(alpha = 0.22f),
                                selectedLabelColor = accentCol
                            )
                        )
                    }
                }
            }
        }

        Surface(
            shape = RoundedCornerShape(14.dp),
            color = MaterialTheme.colorScheme.surfaceVariant,
            modifier = Modifier.fillMaxWidth()
        ) {
            Row(
                modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = if (isWomen) "Je travaille aussi sur ma propre cabine / chaise" else "Je coiffe aussi sur ma propre chaise",
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Text(
                        text = "Active votre profil personnel de coiffeur en plus de la gérance",
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                Switch(
                    checked = ownerAlsoWorksChair,
                    onCheckedChange = onOwnerChairToggle,
                    colors = SwitchDefaults.colors(checkedThumbColor = accentCol, checkedTrackColor = accentCol.copy(alpha = 0.3f))
                )
            }
        }

        OutlinedTextField(
            value = addressLandmark,
            onValueChange = onAddressLandmarkChange,
            label = { Text("Rue ou repère précis (optionnel)") },
            placeholder = { Text("ex. Face arrêt tramway / Rue Sidi Yahia") },
            leadingIcon = { Icon(Icons.Default.EditLocationAlt, contentDescription = null, tint = BarberGoldPrimary) },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(14.dp),
            singleLine = true
        )
    }
}

@Composable
fun ShopOwnerServicesAndLocationStep(
    selectedAudience: TargetAudience,
    selectedShopServices: Set<String>,
    onToggleShopService: (String) -> Unit,
    onAddCustomShopService: (String) -> Unit
) {
    val isWomen = selectedAudience == TargetAudience.WOMEN
    val accentCol = if (isWomen) BeautyFuchsia else BarberBlue

    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        RegistrationServiceSelectorAndCustomInput(
            title = if (isWomen) "Prestations & Soins proposés dans votre institut :" else "Services & Coupes proposés dans votre salon :",
            selectedAudience = selectedAudience,
            isHomeArtist = false,
            accentColor = accentCol,
            selectedServices = selectedShopServices,
            onToggleService = onToggleShopService,
            onAddCustomService = onAddCustomShopService
        )

        GpsLocationCard(
            title = "Localisation GPS exacte du Salon",
            subtitle = "Les clients vous trouvent directement par distance",
            accentColor = accentCol
        )
    }
}

@Composable
internal fun AudienceSelectorCard(
    title: String,
    role: UserRole,
    selectedAudience: TargetAudience,
    onAudienceChange: (TargetAudience) -> Unit
) {
    Card(
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            Text(
                text = title,
                fontWeight = FontWeight.Bold,
                fontSize = 13.sp,
                color = MaterialTheme.colorScheme.onSurface
            )
            Spacer(modifier = Modifier.height(8.dp))
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                TargetAudience.entries.forEach { aud ->
                    val isSel = selectedAudience == aud
                    val accentCol = if (aud == TargetAudience.WOMEN) BeautyFuchsia else BarberGoldPrimary
                    Surface(
                        shape = RoundedCornerShape(10.dp),
                        color = if (isSel) accentCol.copy(alpha = 0.16f) else MaterialTheme.colorScheme.surface,
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(min = 48.dp)
                            .clickable { onAudienceChange(aud) }
                            .border(
                                width = if (isSel) 1.5.dp else 0.5.dp,
                                color = if (isSel) accentCol else MaterialTheme.colorScheme.outline,
                                shape = RoundedCornerShape(10.dp)
                            )
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(text = aud.emoji, fontSize = 20.sp)
                            Spacer(modifier = Modifier.width(10.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = when (role) {
                                        UserRole.SHOP_OWNER -> when (aud) {
                                            TargetAudience.MEN -> "Salon Hommes uniquement (Barbier & Coiffure)"
                                            TargetAudience.WOMEN -> "Salon Dames & Institut de Beauté uniquement"
                                        }
                                        UserRole.BARBER -> when (aud) {
                                            TargetAudience.MEN -> "Coiffeur / Barbier Hommes uniquement"
                                            TargetAudience.WOMEN -> "Coiffeuse / Esthéticienne Dames uniquement"
                                        }
                                        UserRole.HOME_ARTIST -> when (aud) {
                                            TargetAudience.MEN -> "Barbier à Domicile Hommes uniquement"
                                            TargetAudience.WOMEN -> "Beauté & Coiffure à Domicile Dames uniquement"
                                        }
                                        else -> aud.labelFr
                                    },
                                    fontWeight = if (isSel) FontWeight.Bold else FontWeight.SemiBold,
                                    fontSize = 12.sp,
                                    color = if (isSel) accentCol else MaterialTheme.colorScheme.onSurface
                                )
                                Text(
                                    text = aud.descriptionFr,
                                    fontSize = 10.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            if (isSel) {
                                Icon(Icons.Default.CheckCircle, contentDescription = null, tint = accentCol, modifier = Modifier.size(18.dp))
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
internal fun GpsLocationCard(
    title: String,
    subtitle: String,
    accentColor: Color
) {
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surfaceVariant,
        modifier = Modifier
            .fillMaxWidth()
            .border(1.dp, accentColor.copy(alpha = 0.45f), RoundedCornerShape(16.dp))
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier
                        .size(34.dp)
                        .clip(CircleShape)
                        .background(accentColor),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        Icons.Default.MyLocation,
                        contentDescription = null,
                        tint = if (accentColor == BarberGoldPrimary) Color.Black else Color.White,
                        modifier = Modifier.size(18.dp)
                    )
                }
                Spacer(modifier = Modifier.width(10.dp))
                Column {
                    Text(
                        text = title,
                        fontWeight = FontWeight.Bold,
                        fontSize = 13.sp,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Text(
                        text = subtitle,
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            Spacer(modifier = Modifier.height(10.dp))

            Surface(
                shape = RoundedCornerShape(10.dp),
                color = MaterialTheme.colorScheme.surface,
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier.padding(10.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(Icons.Default.LocationOn, contentDescription = null, tint = BarberRose, modifier = Modifier.size(20.dp))
                    Spacer(modifier = Modifier.width(8.dp))
                    Column {
                        Text(
                            text = "Point GPS actif (36.7538° N, 3.0588° E)",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Text(
                            text = "✓ Position détectée • Visible par distance en km",
                            fontSize = 10.sp,
                            color = BarberEmerald,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            }
        }
    }
}
