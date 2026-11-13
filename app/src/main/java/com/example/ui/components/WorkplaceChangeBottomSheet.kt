package com.example.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.data.AlgeriaLocations
import com.example.model.*
import com.example.ui.theme.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WorkplaceChangeBottomSheet(
    currentWorkplace: BarberWorkplace,
    barberProfile: BarberProfile,
    availableShops: List<Shop>,
    pendingJoinRequests: List<ShopJoinRequest>,
    onRequestJoinShop: (Shop) -> Unit,
    onWorkplaceSelected: (BarberWorkplace) -> Unit,
    onDismiss: () -> Unit
) {
    var selectedTab by remember { mutableStateOf(0) } // 0: Salons partenaires (Request to join), 1: Emplacement sur Carte & Wilaya/Commune, 2: Freelance/Mobile
    var customShopName by remember { mutableStateOf("") }
    var customAddress by remember { mutableStateOf("") }
    var selectedWilaya by remember { mutableStateOf(AlgeriaLocations.wilayas.first()) }
    var selectedCommune by remember { mutableStateOf(selectedWilaya.communes.first()) }
    var freelanceRadius by remember { mutableStateOf(15f) }

    // Interactive Map Pin coordinates state
    var mapPinOffset by remember { mutableStateOf(Offset(220f, 160f)) }
    var isMapExpanded by remember { mutableStateOf(false) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = MaterialTheme.colorScheme.surface
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 12.dp)
        ) {
            Text(
                text = "📍 Localisation & Lieu de Travail",
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.primary
            )
            Text(
                text = "Définissez votre repère GPS sur la carte, choisissez votre wilaya et commune, ou envoyez une demande pour rejoindre un salon.",
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 4.dp, bottom = 12.dp)
            )

            // 3 Mode selection pills
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant)
                    .padding(4.dp),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                listOf("1. Rejoindre un Salon", "2. Ma Position sur Carte", "3. Service Mobile").forEachIndexed { index, label ->
                    val isSelected = selectedTab == index
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(8.dp))
                            .background(if (isSelected) BarberGoldPrimary else Color.Transparent)
                            .clickable { selectedTab = index }
                            .padding(vertical = 8.dp)
                            .testTag("workplace_tab_$index"),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = label,
                            fontSize = 11.sp,
                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                            color = if (isSelected) Color.Black else MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            when (selectedTab) {
                // Option 1: Request to be part of a barber shop & see status
                0 -> {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text(
                            text = "Demande d'affiliation à un salon partenaire :",
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Text(
                            text = "Envoyez une demande au propriétaire du salon. Une fois acceptée par le salon, votre profil sera affiché à cette adresse.",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )

                        LazyColumn(
                            modifier = Modifier.heightIn(max = 300.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            items(availableShops) { shop ->
                                val isCurrent = shop.id == currentWorkplace.shopId
                                val pendingRequest = pendingJoinRequests.find { it.shopId == shop.id && it.status == ShopJoinRequestStatus.PENDING }
                                val acceptedRequest = pendingJoinRequests.find { it.shopId == shop.id && it.status == ShopJoinRequestStatus.ACCEPTED }

                                Surface(
                                    shape = RoundedCornerShape(14.dp),
                                    color = if (isCurrent) BarberGoldPrimary.copy(alpha = 0.15f) else MaterialTheme.colorScheme.surfaceVariant,
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .border(
                                            width = if (isCurrent) 1.5.dp else 0.5.dp,
                                            color = if (isCurrent) BarberGoldPrimary else MaterialTheme.colorScheme.outline,
                                            shape = RoundedCornerShape(14.dp)
                                        )
                                ) {
                                    Column(modifier = Modifier.padding(14.dp)) {
                                        Row(
                                            modifier = Modifier.fillMaxWidth(),
                                            horizontalArrangement = Arrangement.SpaceBetween,
                                            verticalAlignment = Alignment.CenterVertically
                                        ) {
                                            Column(modifier = Modifier.weight(1f)) {
                                                Text(
                                                    text = shop.name,
                                                    fontWeight = FontWeight.Bold,
                                                    fontSize = 15.sp,
                                                    color = MaterialTheme.colorScheme.onSurface
                                                )
                                                Text(
                                                    text = "${shop.address} • ${shop.commune} (${shop.wilaya})",
                                                    fontSize = 12.sp,
                                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                                )
                                                Text(
                                                    text = "Gérant: ${shop.phone} • ${shop.openingHours}",
                                                    fontSize = 11.sp,
                                                    color = MaterialTheme.colorScheme.primary
                                                )
                                            }

                                            if (isCurrent) {
                                                Surface(
                                                    shape = RoundedCornerShape(8.dp),
                                                    color = BarberEmerald.copy(alpha = 0.2f)
                                                ) {
                                                    Text(
                                                        text = "Mon Salon Actuel",
                                                        fontWeight = FontWeight.Bold,
                                                        fontSize = 11.sp,
                                                        color = BarberEmerald,
                                                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                                                    )
                                                }
                                            } else if (pendingRequest != null) {
                                                Surface(
                                                    shape = RoundedCornerShape(8.dp),
                                                    color = BarberAmber.copy(alpha = 0.2f)
                                                ) {
                                                    Text(
                                                        text = "Demande en attente...",
                                                        fontWeight = FontWeight.Bold,
                                                        fontSize = 11.sp,
                                                        color = BarberAmber,
                                                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                                                    )
                                                }
                                            } else {
                                                Button(
                                                    onClick = { onRequestJoinShop(shop) },
                                                    colors = ButtonDefaults.buttonColors(containerColor = BarberGoldPrimary, contentColor = Color.Black),
                                                    shape = RoundedCornerShape(10.dp),
                                                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp),
                                                    modifier = Modifier.testTag("request_join_shop_${shop.id}")
                                                ) {
                                                    Icon(Icons.Default.Send, contentDescription = null, modifier = Modifier.size(14.dp))
                                                    Spacer(modifier = Modifier.width(4.dp))
                                                    Text("Demander à rejoindre", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Option 2: Set Location on Interactive Map + Wilaya & Commune
                1 -> {
                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        // Wilaya Selector Chips
                        Text("1. Sélectionnez votre Wilaya :", fontSize = 13.sp, fontWeight = FontWeight.Bold)
                        LazyRow(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            items(AlgeriaLocations.wilayas) { w ->
                                val isSelected = w == selectedWilaya
                                Surface(
                                    shape = RoundedCornerShape(18.dp),
                                    color = if (isSelected) BarberGoldPrimary else MaterialTheme.colorScheme.surfaceVariant,
                                    modifier = Modifier
                                        .clickable {
                                            selectedWilaya = w
                                            selectedCommune = w.communes.first()
                                        }
                                        .padding(vertical = 2.dp)
                                ) {
                                    Text(
                                        text = w.name,
                                        fontSize = 11.sp,
                                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                                        color = if (isSelected) Color.Black else MaterialTheme.colorScheme.onSurface,
                                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp)
                                    )
                                }
                            }
                        }

                        // Commune Selector Chips
                        Text("2. Commune (${selectedWilaya.communes.size} disponibles) :", fontSize = 13.sp, fontWeight = FontWeight.Bold)
                        LazyRow(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            items(selectedWilaya.communes) { c ->
                                val isSelected = c == selectedCommune
                                Surface(
                                    shape = RoundedCornerShape(18.dp),
                                    color = if (isSelected) BarberEmerald else MaterialTheme.colorScheme.surfaceVariant,
                                    modifier = Modifier
                                        .clickable { selectedCommune = c }
                                        .padding(vertical = 2.dp)
                                ) {
                                    Text(
                                        text = c,
                                        fontSize = 11.sp,
                                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                                        color = if (isSelected) Color.White else MaterialTheme.colorScheme.onSurface,
                                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 5.dp)
                                    )
                                }
                            }
                        }

                        // Interactive Map Area (Touch & Pin Placement)
                        Text(
                            text = "3. Pointez votre emplacement exact sur la carte :",
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Bold
                        )

                        Surface(
                            shape = RoundedCornerShape(16.dp),
                            color = Color(0xFF1E293B),
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(160.dp)
                                .border(1.5.dp, BarberGoldPrimary, RoundedCornerShape(16.dp))
                                .pointerInput(Unit) {
                                    detectTapGestures { offset ->
                                        mapPinOffset = offset
                                    }
                                }
                                .testTag("interactive_map_canvas")
                        ) {
                            Box(modifier = Modifier.fillMaxSize()) {
                                // Draw simulated map roads and grid
                                Canvas(modifier = Modifier.fillMaxSize()) {
                                    val w = size.width
                                    val h = size.height

                                    // Arteries
                                    drawLine(
                                        color = Color(0xFF334155),
                                        start = Offset(0f, h * 0.45f),
                                        end = Offset(w, h * 0.48f),
                                        strokeWidth = 14f
                                    )
                                    drawLine(
                                        color = Color(0xFF334155),
                                        start = Offset(w * 0.35f, 0f),
                                        end = Offset(w * 0.38f, h),
                                        strokeWidth = 12f
                                    )
                                    drawLine(
                                        color = Color(0xFF475569),
                                        start = Offset(w * 0.7f, 0f),
                                        end = Offset(w * 0.65f, h),
                                        strokeWidth = 8f
                                    )

                                    // Coastal Bay curve (Algiers bay aesthetic)
                                    drawCircle(
                                        color = Color(0xFF0F172A).copy(alpha = 0.6f),
                                        center = Offset(w * 0.9f, h * 0.1f),
                                        radius = 70f
                                    )
                                }

                                // Interactive Draggable / Tappable Map Pin
                                Box(
                                    modifier = Modifier
                                        .offset(
                                            x = (mapPinOffset.x / 2.6f).dp - 18.dp,
                                            y = (mapPinOffset.y / 2.6f).dp - 36.dp
                                        )
                                ) {
                                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                        Surface(
                                            shape = RoundedCornerShape(8.dp),
                                            color = BarberGoldPrimary
                                        ) {
                                            Text(
                                                text = "${selectedCommune} (GPS fixé)",
                                                fontSize = 9.sp,
                                                fontWeight = FontWeight.Bold,
                                                color = Color.Black,
                                                modifier = Modifier.padding(horizontal = 4.dp, vertical = 2.dp)
                                            )
                                        }
                                        Icon(
                                            imageVector = Icons.Default.LocationOn,
                                            contentDescription = "Pin",
                                            tint = BarberRose,
                                            modifier = Modifier.size(36.dp)
                                        )
                                    }
                                }

                                // Tap helper notice
                                Surface(
                                    shape = RoundedCornerShape(8.dp),
                                    color = Color.Black.copy(alpha = 0.65f),
                                    modifier = Modifier
                                        .align(Alignment.BottomStart)
                                        .padding(8.dp)
                                ) {
                                    Text(
                                        text = "👆 Touchez la carte pour déplacer votre épingle",
                                        fontSize = 10.sp,
                                        color = Color.White,
                                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 3.dp)
                                    )
                                }
                            }
                        }

                        // Custom Address / Place label input
                        OutlinedTextField(
                            value = customAddress,
                            onValueChange = { customAddress = it },
                            label = { Text("Nom du lieu ou repère exact") },
                            placeholder = { Text("ex. En face de la Poste, Rue principale") },
                            modifier = Modifier
                                .fillMaxWidth()
                                .testTag("input_map_address"),
                            shape = RoundedCornerShape(12.dp),
                            singleLine = true
                        )

                        Button(
                            onClick = {
                                val shopName = if (customShopName.isNotBlank()) customShopName else "Salon ${barberProfile.name}"
                                val addr = if (customAddress.isNotBlank()) customAddress else "Centre ${selectedCommune}"
                                val lat = 36.75 + (mapPinOffset.y % 100) * 0.001
                                val lng = 3.05 + (mapPinOffset.x % 100) * 0.001

                                onWorkplaceSelected(
                                    BarberWorkplace(
                                        type = WorkplaceType.CUSTOM_LOCATION,
                                        shopName = shopName,
                                        wilaya = selectedWilaya.name,
                                        commune = selectedCommune,
                                        address = addr,
                                        latitude = lat,
                                        longitude = lng
                                    )
                                )
                            },
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(50.dp)
                                .testTag("save_map_location_btn"),
                            colors = ButtonDefaults.buttonColors(containerColor = BarberGoldPrimary, contentColor = Color.Black),
                            shape = RoundedCornerShape(14.dp)
                        ) {
                            Icon(Icons.Default.CheckCircle, contentDescription = null, modifier = Modifier.size(18.dp))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("Enregistrer ma Position & Notifier mes Abonnés", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                        }
                    }
                }

                // Option 3: Freelance / Home visits
                2 -> {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Surface(
                            shape = RoundedCornerShape(12.dp),
                            color = BarberBlue.copy(alpha = 0.1f),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Row(
                                modifier = Modifier.padding(12.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(Icons.Default.DirectionsCar, contentDescription = null, tint = BarberBlue)
                                Spacer(modifier = Modifier.width(10.dp))
                                Text(
                                    text = "Mode Coiffeur Itinérant / À Domicile. Vos clients verront votre zone de couverture sans adresse fixe.",
                                    fontSize = 12.sp,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                            }
                        }

                        Text("Wilaya d'intervention : ${selectedWilaya.name}", fontSize = 13.sp, fontWeight = FontWeight.Bold)
                        Text("Rayon de déplacement : ${freelanceRadius.toInt()} km autour de ${selectedCommune}", fontSize = 13.sp, color = BarberGoldPrimary, fontWeight = FontWeight.Bold)
                        Slider(
                            value = freelanceRadius,
                            onValueChange = { freelanceRadius = it },
                            valueRange = 5f..50f,
                            steps = 8
                        )

                        Button(
                            onClick = {
                                onWorkplaceSelected(
                                    BarberWorkplace(
                                        type = WorkplaceType.FREELANCE_MOBILE,
                                        shopName = "Coiffure Mobile à Domicile",
                                        wilaya = selectedWilaya.name,
                                        commune = selectedCommune,
                                        address = "Intervention à domicile (Rayon ${freelanceRadius.toInt()} km)",
                                        serviceRadiusKm = freelanceRadius.toInt()
                                    )
                                )
                            },
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(48.dp)
                                .testTag("confirm_freelance_workplace_btn"),
                            colors = ButtonDefaults.buttonColors(containerColor = BarberGoldPrimary, contentColor = Color.Black),
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Text("Activer Mode Domicile (Rayon ${freelanceRadius.toInt()}km)", fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(24.dp))
        }
    }
}
