package com.example.ui.components

import android.content.Intent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.example.model.ServiceItem
import com.example.model.TargetAudience
import com.example.ui.theme.BarberEmerald
import com.example.ui.theme.BarberGoldPrimary
import com.example.ui.theme.BarberRose

fun presetServiceCatalogFor(
    audience: TargetAudience,
    isHomeArtist: Boolean = false
): List<String> {
    return when (audience) {
        TargetAudience.WOMEN -> if (isHomeArtist) {
            listOf(
                "Coiffure & Brushing à domicile",
                "Manucure Russe & Gel",
                "Pédicure Spa Mobile",
                "Maquillage Soirée / Mariée",
                "Soin Visage & Hydrafacial",
                "Lissage Kératine & Protéine"
            )
        } else {
            listOf(
                "Coupe & Brushing",
                "Lissage Kératine & Protéine",
                "Balayage & Coloration",
                "Manucure Russe",
                "Pédicure Spa Balnéo",
                "Soin Visage Hydrafacial",
                "Maquillage & Épilation"
            )
        }
        TargetAudience.MEN -> if (isHomeArtist) {
            listOf(
                "Coupe & Dégradé à domicile",
                "Barbe & Serviette Chaude",
                "Pack Marié / Événements VIP",
                "Coupe Enfant à domicile",
                "Soin Visage Express"
            )
        } else {
            listOf(
                "Dégradé Américain",
                "Coupe Classique",
                "Taille Barbe",
                "Serviette Chaude",
                "Soin Vapeur & Masque",
                "Coupe Enfant"
            )
        }
    }
}

@Composable
fun ProfileAvatarImage(
    avatarUrl: String,
    fallbackIcon: ImageVector,
    contentDescription: String,
    accentColor: Color,
    iconTint: Color = accentColor,
    size: Dp = 50.dp,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .size(size)
            .clip(CircleShape)
            .background(accentColor.copy(alpha = 0.2f))
            .border(1.5.dp, accentColor.copy(alpha = 0.65f), CircleShape),
        contentAlignment = Alignment.Center
    ) {
        if (avatarUrl.isNotBlank()) {
            AsyncImage(
                model = avatarUrl,
                contentDescription = contentDescription,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .fillMaxSize()
                    .clip(CircleShape)
            )
        } else {
            Icon(
                imageVector = fallbackIcon,
                contentDescription = contentDescription,
                tint = iconTint,
                modifier = Modifier.size(size * 0.54f)
            )
        }
    }
}

@Composable
fun ProfilePhotoPickerCard(
    avatarUrl: String,
    title: String,
    subtitle: String,
    accentColor: Color,
    fallbackIcon: ImageVector,
    testTagPrefix: String = "profile",
    onPhotoPicked: (String) -> Unit,
    onRemovePhoto: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val photoPickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickVisualMedia()
    ) { uri ->
        if (uri != null) {
            try {
                context.contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION
                )
            } catch (_: Exception) {
                // Transient URI grant from Android Photo Picker still works for current session
            }
            onPhotoPicked(uri.toString())
        }
    }

    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
        modifier = modifier
            .fillMaxWidth()
            .border(1.dp, accentColor.copy(alpha = 0.4f), RoundedCornerShape(16.dp))
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Box(
                modifier = Modifier
                    .clickable {
                        photoPickerLauncher.launch(
                            PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                        )
                    }
                    .testTag("avatar_preview_$testTagPrefix"),
                contentAlignment = Alignment.BottomEnd
            ) {
                ProfileAvatarImage(
                    avatarUrl = avatarUrl,
                    fallbackIcon = fallbackIcon,
                    contentDescription = title,
                    accentColor = accentColor,
                    size = 64.dp
                )
                Box(
                    modifier = Modifier
                        .size(24.dp)
                        .clip(CircleShape)
                        .background(accentColor)
                        .border(1.5.dp, MaterialTheme.colorScheme.surface, CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.PhotoCamera,
                        contentDescription = "Choisir une photo",
                        tint = if (accentColor == BarberGoldPrimary) Color.Black else Color.White,
                        modifier = Modifier.size(14.dp)
                    )
                }
            }

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Text(
                    text = if (avatarUrl.isNotBlank()) "Photo définie ✓ (visible aux clients)" else subtitle,
                    fontSize = 11.sp,
                    color = if (avatarUrl.isNotBlank()) BarberEmerald else MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.height(8.dp))
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Button(
                        onClick = {
                            photoPickerLauncher.launch(
                                PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                            )
                        },
                        colors = ButtonDefaults.buttonColors(
                            containerColor = accentColor,
                            contentColor = if (accentColor == BarberGoldPrimary) Color.Black else Color.White
                        ),
                        shape = RoundedCornerShape(10.dp),
                        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 8.dp),
                        modifier = Modifier
                            .heightIn(min = 48.dp)
                            .testTag("btn_pick_${testTagPrefix}_photo")
                    ) {
                        Icon(Icons.Default.AddAPhoto, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = if (avatarUrl.isNotBlank()) "Changer photo" else "Choisir photo",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }

                    if (avatarUrl.isNotBlank() && onRemovePhoto != null) {
                        IconButton(
                            onClick = onRemovePhoto,
                            modifier = Modifier
                                .size(48.dp)
                                .testTag("btn_remove_${testTagPrefix}_photo")
                        ) {
                            Icon(
                                imageVector = Icons.Default.DeleteOutline,
                                contentDescription = "Retirer la photo",
                                tint = BarberRose
                            )
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun RegistrationServiceSelectorAndCustomInput(
    title: String,
    selectedAudience: TargetAudience,
    isHomeArtist: Boolean = false,
    accentColor: Color,
    selectedServices: Set<String>,
    onToggleService: (String) -> Unit,
    onAddCustomService: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    var customServiceDraft by remember { mutableStateOf("") }
    val presetList = remember(selectedAudience, isHomeArtist) {
        presetServiceCatalogFor(selectedAudience, isHomeArtist)
    }
    val customAddedServices = remember(selectedServices, presetList) {
        selectedServices.filterNot { sel -> presetList.any { it.equals(sel, ignoreCase = true) } }
    }

    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
        modifier = modifier.fillMaxWidth()
    ) {
        Column(
            modifier = Modifier.padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Text(
                text = title,
                fontWeight = FontWeight.Bold,
                fontSize = 13.sp,
                color = MaterialTheme.colorScheme.onSurface
            )

            Text(
                text = "Sélectionnez dans la liste ou saisissez vos propres prestations :",
                fontSize = 11.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                presetList.forEach { spec ->
                    val isSel = selectedServices.contains(spec)
                    FilterChip(
                        selected = isSel,
                        onClick = { onToggleService(spec) },
                        label = { Text(spec, fontSize = 11.sp) },
                        leadingIcon = if (isSel) {
                            { Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(14.dp)) }
                        } else null,
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = accentColor.copy(alpha = 0.22f),
                            selectedLabelColor = accentColor,
                            selectedLeadingIconColor = accentColor
                        )
                    )
                }

                customAddedServices.forEach { custom ->
                    InputChip(
                        selected = true,
                        onClick = { onToggleService(custom) },
                        label = { Text(custom, fontSize = 11.sp, fontWeight = FontWeight.SemiBold) },
                        trailingIcon = {
                            Icon(
                                imageVector = Icons.Default.Close,
                                contentDescription = "Retirer $custom",
                                modifier = Modifier.size(14.dp)
                            )
                        },
                        colors = InputChipDefaults.inputChipColors(
                            selectedContainerColor = BarberEmerald.copy(alpha = 0.2f),
                            selectedLabelColor = BarberEmerald,
                            selectedTrailingIconColor = BarberEmerald
                        )
                    )
                }
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                OutlinedTextField(
                    value = customServiceDraft,
                    onValueChange = { customServiceDraft = it },
                    label = { Text("Autre service personnalisé", fontSize = 12.sp) },
                    placeholder = {
                        Text(
                            if (selectedAudience == TargetAudience.WOMEN) "ex. Extension cils, Hammam..." else "ex. Lissage kératine, Contour laser...",
                            fontSize = 11.sp
                        )
                    },
                    singleLine = true,
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier
                        .weight(1f)
                        .testTag("input_custom_service_name")
                )

                Button(
                    onClick = {
                        val trimmed = customServiceDraft.trim()
                        if (trimmed.isNotBlank()) {
                            onAddCustomService(trimmed)
                            customServiceDraft = ""
                        }
                    },
                    enabled = customServiceDraft.isNotBlank(),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = accentColor,
                        contentColor = if (accentColor == BarberGoldPrimary) Color.Black else Color.White
                    ),
                    shape = RoundedCornerShape(12.dp),
                    contentPadding = PaddingValues(horizontal = 12.dp),
                    modifier = Modifier
                        .height(52.dp)
                        .testTag("btn_add_custom_service")
                ) {
                    Icon(Icons.Default.Add, contentDescription = "Ajouter service", modifier = Modifier.size(18.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Ajouter", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun DashboardServiceManagerCard(
    title: String,
    targetAudience: TargetAudience,
    accentColor: Color,
    currentServices: List<ServiceItem>,
    isHomeArtist: Boolean = false,
    onTogglePresetService: (String) -> Unit,
    onAddCustomService: (name: String, priceDzd: Int, durationMinutes: Int) -> Unit,
    onRemoveService: (serviceId: String) -> Unit,
    modifier: Modifier = Modifier
) {
    var customName by remember { mutableStateOf("") }
    var customPriceText by remember(targetAudience) {
        mutableStateOf(if (targetAudience == TargetAudience.WOMEN) "1500" else "600")
    }
    var customDurationText by remember { mutableStateOf("30") }
    var expandedEditor by remember { mutableStateOf(false) }

    val presetList = remember(targetAudience, isHomeArtist) {
        presetServiceCatalogFor(targetAudience, isHomeArtist)
    }

    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
        modifier = modifier
            .fillMaxWidth()
            .border(1.dp, accentColor.copy(alpha = 0.35f), RoundedCornerShape(16.dp))
            .testTag("dashboard_services_manager_card")
    ) {
        Column(
            modifier = Modifier.padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.weight(1f)) {
                    Icon(
                        imageVector = if (targetAudience == TargetAudience.WOMEN) Icons.Default.Spa else Icons.Default.ContentCut,
                        contentDescription = null,
                        tint = accentColor,
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Column {
                        Text(
                            text = "$title (${currentServices.size})",
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Text(
                            text = "Visibles sur votre fiche & recherche client",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                TextButton(
                    onClick = { expandedEditor = !expandedEditor },
                    modifier = Modifier
                        .heightIn(min = 48.dp)
                        .testTag("btn_toggle_services_editor")
                ) {
                    Text(
                        text = if (expandedEditor) "Masquer" else "+ Gérer",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        color = accentColor
                    )
                }
            }

            if (currentServices.isEmpty()) {
                Text(
                    text = "Aucun service actif. Appuyez sur « + Gérer » pour choisir ou taper vos services.",
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            } else {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    currentServices.forEach { srv ->
                        Surface(
                            shape = RoundedCornerShape(10.dp),
                            color = MaterialTheme.colorScheme.surface,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        text = srv.nameFr,
                                        fontSize = 13.sp,
                                        fontWeight = FontWeight.SemiBold,
                                        color = MaterialTheme.colorScheme.onSurface
                                    )
                                    Text(
                                        text = "${srv.priceDzd} DA • ${srv.durationMinutes} min",
                                        fontSize = 11.sp,
                                        color = accentColor,
                                        fontWeight = FontWeight.Bold
                                    )
                                }
                                IconButton(
                                    onClick = { onRemoveService(srv.id) },
                                    modifier = Modifier
                                        .size(48.dp)
                                        .testTag("btn_remove_service_${srv.id}")
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.DeleteOutline,
                                        contentDescription = "Supprimer ${srv.nameFr}",
                                        tint = BarberRose,
                                        modifier = Modifier.size(18.dp)
                                    )
                                }
                            }
                        }
                    }
                }
            }

            if (expandedEditor) {
                HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.25f))

                Text(
                    text = "1. Sélection rapide depuis la liste :",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )

                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    presetList.forEach { preset ->
                        val isSelected = currentServices.any { it.nameFr.equals(preset, ignoreCase = true) }
                        FilterChip(
                            selected = isSelected,
                            onClick = { onTogglePresetService(preset) },
                            label = { Text(preset, fontSize = 11.sp) },
                            leadingIcon = if (isSelected) {
                                { Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(14.dp)) }
                            } else null,
                            colors = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = accentColor.copy(alpha = 0.22f),
                                selectedLabelColor = accentColor,
                                selectedLeadingIconColor = accentColor
                            )
                        )
                    }
                }

                Text(
                    text = "2. Ajouter un autre service en le saisissant :",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )

                OutlinedTextField(
                    value = customName,
                    onValueChange = { customName = it },
                    label = { Text("Nom du service", fontSize = 12.sp) },
                    placeholder = {
                        Text(
                            if (targetAudience == TargetAudience.WOMEN) "ex. Pose Cils Volume Russe" else "ex. Soin Charbon Noir",
                            fontSize = 11.sp
                        )
                    },
                    singleLine = true,
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("dashboard_input_custom_service")
                )

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    OutlinedTextField(
                        value = customPriceText,
                        onValueChange = { customPriceText = it.filter { ch -> ch.isDigit() } },
                        label = { Text("Tarif (DA)", fontSize = 12.sp) },
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier
                            .weight(1f)
                            .testTag("dashboard_input_custom_price")
                    )

                    OutlinedTextField(
                        value = customDurationText,
                        onValueChange = { customDurationText = it.filter { ch -> ch.isDigit() } },
                        label = { Text("Durée (min)", fontSize = 12.sp) },
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier
                            .weight(1f)
                            .testTag("dashboard_input_custom_duration")
                    )
                }

                Button(
                    onClick = {
                        val trimmed = customName.trim()
                        if (trimmed.isNotBlank()) {
                            val price = customPriceText.toIntOrNull() ?: 600
                            val duration = (customDurationText.toIntOrNull() ?: 30).coerceIn(5, 300)
                            onAddCustomService(trimmed, price, duration)
                            customName = ""
                        }
                    },
                    enabled = customName.isNotBlank(),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = accentColor,
                        contentColor = if (accentColor == BarberGoldPrimary) Color.Black else Color.White
                    ),
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 48.dp)
                        .testTag("dashboard_btn_add_custom_service")
                ) {
                    Icon(Icons.Default.AddCircleOutline, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("Ajouter ce service à ma carte", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}
