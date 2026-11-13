package com.example.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.model.BarberProfile
import com.example.model.BarberStatus
import com.example.model.Shop
import com.example.model.TargetAudience
import com.example.model.WorkplaceType
import com.example.ui.components.BarberCard
import com.example.ui.components.ProfileAvatarImage
import com.example.ui.theme.*

@Composable
fun CustomerExploreScreen(
    barbers: List<BarberProfile>,
    shops: List<Shop>,
    selectedWilaya: String,
    onSelectWilaya: (String) -> Unit,
    searchQuery: String,
    onSearchChange: (String) -> Unit,
    selectedAudience: TargetAudience? = null,
    onSelectAudience: (TargetAudience?) -> Unit = {},
    onBarberClick: (BarberProfile) -> Unit,
    onBookBarber: (BarberProfile) -> Unit,
    onToggleFollow: (String) -> Unit,
    onRateShop: (Shop) -> Unit = {},
    modifier: Modifier = Modifier
) {
    val activeAudience = selectedAudience ?: TargetAudience.MEN
    var viewMode by remember { mutableStateOf(0) } // 0: Autour de moi (GPS), 1: Professionnels, 2: Salons, 3: À Domicile
    var filterOnlyOnline by remember { mutableStateOf(false) }
    var filterWithPromo by remember { mutableStateOf(false) }
    var filterHomeOnly by remember { mutableStateOf(false) }
    var activeCategoryFilter by remember { mutableStateOf<String?>(null) } // "HAIR", "NAILS", "SKINCARE", "BEARD"

    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
        contentPadding = PaddingValues(top = 12.dp, bottom = 80.dp)
    ) {
        // 1. Audience Category Selector Tabs: Hommes seuls / Dames seules (Jamais mixte)
        item {
            Card(
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(12.dp)) {
                    Text(
                        text = "Espace dédié (Hommes seuls / Dames seules) :",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp))
                            .background(MaterialTheme.colorScheme.surface)
                            .padding(3.dp),
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        // Option Men
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .clip(RoundedCornerShape(10.dp))
                                .background(if (activeAudience == TargetAudience.MEN) BarberGoldPrimary else Color.Transparent)
                                .clickable {
                                    onSelectAudience(TargetAudience.MEN)
                                    activeCategoryFilter = null
                                }
                                .padding(vertical = 9.dp)
                                .testTag("audience_tab_men"),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = "🧔 Hommes",
                                fontWeight = if (activeAudience == TargetAudience.MEN) FontWeight.Bold else FontWeight.Medium,
                                color = if (activeAudience == TargetAudience.MEN) Color.Black else MaterialTheme.colorScheme.onSurface,
                                fontSize = 13.sp
                            )
                        }

                        // Option Ladies
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .clip(RoundedCornerShape(10.dp))
                                .background(if (activeAudience == TargetAudience.WOMEN) BeautyFuchsia else Color.Transparent)
                                .clickable {
                                    onSelectAudience(TargetAudience.WOMEN)
                                    activeCategoryFilter = null
                                }
                                .padding(vertical = 9.dp)
                                .testTag("audience_tab_women"),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = "💄 Dames & Beauté",
                                fontWeight = if (activeAudience == TargetAudience.WOMEN) FontWeight.Bold else FontWeight.Medium,
                                color = if (activeAudience == TargetAudience.WOMEN) Color.White else MaterialTheme.colorScheme.onSurface,
                                fontSize = 13.sp
                            )
                        }
                    }
                }
            }
        }

        // 2. Hero: Salons & Professionnels Autour de Moi (GPS Radar)
        item {
            val isWomenMode = activeAudience == TargetAudience.WOMEN
            val accentColor = if (isWomenMode) BeautyFuchsia else BarberGoldPrimary
            Card(
                shape = RoundedCornerShape(20.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                modifier = Modifier
                    .fillMaxWidth()
                    .border(1.dp, accentColor.copy(alpha = 0.5f), RoundedCornerShape(20.dp))
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
                                    .size(38.dp)
                                    .clip(CircleShape)
                                    .background(accentColor),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(
                                    imageVector = if (isWomenMode) Icons.Default.Spa else Icons.Default.Radar,
                                    contentDescription = null,
                                    tint = if (isWomenMode) Color.White else Color.Black,
                                    modifier = Modifier.size(22.dp)
                                )
                            }
                            Spacer(modifier = Modifier.width(10.dp))
                            Column {
                                Text(
                                    text = if (isWomenMode) "Instituts & Beauté Autour de Moi" else "Salons & Barbiers Autour de Moi",
                                    fontSize = 15.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                                Text(
                                    text = "Localisation GPS active • Rayon 5 km",
                                    fontSize = 11.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }

                        Surface(
                            shape = RoundedCornerShape(8.dp),
                            color = BarberEmerald.copy(alpha = 0.2f)
                        ) {
                            Text(
                                text = "GPS Actif",
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold,
                                color = BarberEmerald,
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(10.dp))

                    Text(
                        text = if (isWomenMode) {
                            "Trouvez les meilleures coiffeuses, manucures et instituts de beauté pour femmes les plus proches."
                        } else {
                            "Trouvez instantanément le barbier disponible le plus proche sans choisir de commune manuellement."
                        },
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    Spacer(modifier = Modifier.height(10.dp))

                    // Quick filter tags
                    LazyRow(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        item {
                            Surface(
                                shape = RoundedCornerShape(8.dp),
                                color = if (filterOnlyOnline) BarberEmerald else MaterialTheme.colorScheme.surface,
                                modifier = Modifier
                                    .clickable { filterOnlyOnline = !filterOnlyOnline }
                                    .border(1.dp, if (filterOnlyOnline) BarberEmerald else MaterialTheme.colorScheme.outline, RoundedCornerShape(8.dp))
                            ) {
                                Text(
                                    text = "🟢 En service",
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    color = if (filterOnlyOnline) Color.White else MaterialTheme.colorScheme.onSurface,
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                                )
                            }
                        }

                        item {
                            Surface(
                                shape = RoundedCornerShape(8.dp),
                                color = if (filterHomeOnly) accentColor else MaterialTheme.colorScheme.surface,
                                modifier = Modifier
                                    .clickable { filterHomeOnly = !filterHomeOnly }
                                    .border(1.dp, if (filterHomeOnly) accentColor else MaterialTheme.colorScheme.outline, RoundedCornerShape(8.dp))
                                    .testTag("filter_home_service_chip")
                            ) {
                                Text(
                                    text = "🏠 À Domicile",
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    color = if (filterHomeOnly) (if (isWomenMode) Color.White else Color.Black) else MaterialTheme.colorScheme.onSurface,
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                                )
                            }
                        }

                        item {
                            Surface(
                                shape = RoundedCornerShape(8.dp),
                                color = if (filterWithPromo) BarberRose else MaterialTheme.colorScheme.surface,
                                modifier = Modifier
                                    .clickable { filterWithPromo = !filterWithPromo }
                                    .border(1.dp, if (filterWithPromo) BarberRose else MaterialTheme.colorScheme.outline, RoundedCornerShape(8.dp))
                            ) {
                                Text(
                                    text = "🏷️ Promotions",
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    color = if (filterWithPromo) Color.White else MaterialTheme.colorScheme.onSurface,
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                                )
                            }
                        }
                    }
                }
            }
        }

        // 3. Search Bar
        item {
            OutlinedTextField(
                value = searchQuery,
                onValueChange = onSearchChange,
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("explore_search_input"),
                placeholder = {
                    Text(
                        if (activeAudience == TargetAudience.WOMEN) {
                            "Rechercher: Manucure, Hydrafacial, Lissage, Balayage..."
                        } else {
                            "Rechercher un coiffeur, barbier ou salon..."
                        }
                    )
                },
                leadingIcon = { Icon(Icons.Default.Search, contentDescription = null, tint = MaterialTheme.colorScheme.primary) },
                shape = RoundedCornerShape(16.dp),
                singleLine = true,
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = if (activeAudience == TargetAudience.WOMEN) BeautyFuchsia else BarberGoldPrimary,
                    unfocusedContainerColor = MaterialTheme.colorScheme.surfaceVariant,
                    focusedContainerColor = MaterialTheme.colorScheme.surfaceVariant
                )
            )
        }

        // 4. Specialty Service Filter Chips
        item {
            val specialties = if (activeAudience == TargetAudience.WOMEN) {
                listOf(
                    Pair("ALL", "Tous les soins Dames"),
                    Pair("HAIR", "💇‍♀️ Coiffure & Kératine"),
                    Pair("NAILS", "💅 Manucure & Pédicure"),
                    Pair("SKINCARE", "✨ Soins & Hydrafacial"),
                    Pair("MAKEUP", "💄 Maquillage & Épilation")
                )
            } else {
                listOf(
                    Pair("ALL", "Tous les services Hommes"),
                    Pair("HAIR", "✂️ Coupe & Dégradé"),
                    Pair("BEARD", "🧔 Barbe & Rasage"),
                    Pair("SKINCARE", "💆‍♂️ Soins Vapeur & Masque")
                )
            }

            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(specialties) { (key, label) ->
                    val isSelected = (activeCategoryFilter == null && key == "ALL") || (activeCategoryFilter == key)
                    val chipColor = if (activeAudience == TargetAudience.WOMEN) BeautyFuchsia else BarberGoldPrimary
                    Surface(
                        shape = RoundedCornerShape(10.dp),
                        color = if (isSelected) chipColor else MaterialTheme.colorScheme.surfaceVariant,
                        modifier = Modifier
                            .clickable { activeCategoryFilter = if (key == "ALL") null else key }
                            .border(1.dp, if (isSelected) chipColor else MaterialTheme.colorScheme.outline.copy(alpha = 0.5f), RoundedCornerShape(10.dp))
                    ) {
                        Text(
                            text = label,
                            fontSize = 11.sp,
                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                            color = if (isSelected) (if (activeAudience == TargetAudience.WOMEN) Color.White else Color.Black) else MaterialTheme.colorScheme.onSurface,
                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)
                        )
                    }
                }
            }
        }

        // 5. Main Mode Tabs: Autour de moi / À Domicile / Professionnels / Salons
        item {
            val countBarbers = barbers.count { b -> b.targetAudience == activeAudience }
            val countHomeArtists = barbers.count { b ->
                (b.offersHomeService || b.currentWorkplace.type == WorkplaceType.FREELANCE_MOBILE) &&
                    b.targetAudience == activeAudience
            }
            val countShops = shops.count { s -> s.targetAudience == activeAudience }
            val accentColor = if (activeAudience == TargetAudience.WOMEN) BeautyFuchsia else BarberGoldPrimary
            val selectedTextColor = if (activeAudience == TargetAudience.WOMEN) Color.White else Color.Black

            LazyRow(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant)
                    .padding(4.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                item {
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(10.dp))
                            .background(if (viewMode == 0) accentColor else Color.Transparent)
                            .clickable { viewMode = 0 }
                            .padding(horizontal = 12.dp, vertical = 9.dp)
                            .testTag("explore_tab_around_me"),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "🎯 Autour",
                            fontWeight = if (viewMode == 0) FontWeight.Bold else FontWeight.Medium,
                            color = if (viewMode == 0) selectedTextColor else MaterialTheme.colorScheme.onSurface,
                            fontSize = 11.sp
                        )
                    }
                }

                item {
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(10.dp))
                            .background(if (viewMode == 3) accentColor else Color.Transparent)
                            .clickable { viewMode = 3 }
                            .padding(horizontal = 12.dp, vertical = 9.dp)
                            .testTag("explore_tab_home_service"),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "🏠 À Domicile ($countHomeArtists)",
                            fontWeight = if (viewMode == 3) FontWeight.Bold else FontWeight.Medium,
                            color = if (viewMode == 3) selectedTextColor else MaterialTheme.colorScheme.onSurface,
                            fontSize = 11.sp
                        )
                    }
                }

                item {
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(10.dp))
                            .background(if (viewMode == 1) accentColor else Color.Transparent)
                            .clickable { viewMode = 1 }
                            .padding(horizontal = 12.dp, vertical = 9.dp)
                            .testTag("explore_tab_pros"),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = if (activeAudience == TargetAudience.WOMEN) "💄 Coiffeuses ($countBarbers)" else "✂️ Coiffeurs ($countBarbers)",
                            fontWeight = if (viewMode == 1) FontWeight.Bold else FontWeight.Medium,
                            color = if (viewMode == 1) selectedTextColor else MaterialTheme.colorScheme.onSurface,
                            fontSize = 11.sp
                        )
                    }
                }

                item {
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(10.dp))
                            .background(if (viewMode == 2) accentColor else Color.Transparent)
                            .clickable { viewMode = 2 }
                            .padding(horizontal = 12.dp, vertical = 9.dp)
                            .testTag("explore_tab_shops"),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = if (activeAudience == TargetAudience.WOMEN) "💅 Instituts ($countShops)" else "🏢 Salons ($countShops)",
                            fontWeight = if (viewMode == 2) FontWeight.Bold else FontWeight.Medium,
                            color = if (viewMode == 2) selectedTextColor else MaterialTheme.colorScheme.onSurface,
                            fontSize = 11.sp
                        )
                    }
                }
            }
        }

        // Dedicated Home Service highlight banner when "À Domicile" tab is active
        if (viewMode == 3) {
            item {
                val isWomenMode = activeAudience == TargetAudience.WOMEN
                val bannerColor = if (isWomenMode) BeautyFuchsia else BarberGoldPrimary
                Surface(
                    shape = RoundedCornerShape(14.dp),
                    color = bannerColor.copy(alpha = 0.12f),
                    modifier = Modifier
                        .fillMaxWidth()
                        .border(1.dp, bannerColor.copy(alpha = 0.45f), RoundedCornerShape(14.dp))
                ) {
                    Row(
                        modifier = Modifier.padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(Icons.Default.HomeRepairService, contentDescription = null, tint = bannerColor, modifier = Modifier.size(22.dp))
                        Spacer(modifier = Modifier.width(10.dp))
                        Column {
                            Text(
                                text = if (isWomenMode) "Beauté & Coiffure à Domicile (Dames uniquement)" else "Barbiers à Domicile (Hommes uniquement)",
                                fontSize = 13.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Text(
                                text = if (isWomenMode) {
                                    "Coiffure, brushing, manucure russe, pédicure spa & maquillage directement chez vous avec kit stérilisé."
                                } else {
                                    "Coupe, dégradé, barbe sculptée & pack marié directement chez vous avec kit stérilisé."
                                },
                                fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }
        }

        // 6. Content Section
        if (viewMode == 0 || viewMode == 1 || viewMode == 3) {
            // Professionals List (Filtered strictly by activeAudience, search, category, home-service, and online/promo status)
            val filteredBarbers = barbers.filter { b ->
                val matchesAudience = b.targetAudience == activeAudience
                val isHomeCapable = b.offersHomeService || b.currentWorkplace.type == WorkplaceType.FREELANCE_MOBILE
                val matchesHomeFilter = (viewMode != 3 && !filterHomeOnly) || isHomeCapable
                val matchesSearch = searchQuery.isBlank() ||
                        b.name.contains(searchQuery, ignoreCase = true) ||
                        b.specialtyTitle.contains(searchQuery, ignoreCase = true) ||
                        b.currentWorkplace.shopName.contains(searchQuery, ignoreCase = true) ||
                        b.homeServiceZones.contains(searchQuery, ignoreCase = true) ||
                        b.bio.contains(searchQuery, ignoreCase = true) ||
                        b.services.any { s -> s.nameFr.contains(searchQuery, ignoreCase = true) }
                val matchesOnline = !filterOnlyOnline || b.status == BarberStatus.ONLINE
                val matchesPromo = !filterWithPromo || b.activePromotion != null
                val matchesCategory = activeCategoryFilter == null || when (activeCategoryFilter) {
                    "HAIR" -> b.services.any { it.category == com.example.model.ServiceCategory.HAIR || it.category == com.example.model.ServiceCategory.COLORING }
                    "NAILS" -> b.services.any { it.category == com.example.model.ServiceCategory.NAILS }
                    "SKINCARE" -> b.services.any { it.category == com.example.model.ServiceCategory.SKINCARE }
                    "BEARD" -> b.services.any { it.category == com.example.model.ServiceCategory.BEARD }
                    "MAKEUP" -> b.services.any { it.category == com.example.model.ServiceCategory.MAKEUP }
                    else -> true
                }
                matchesAudience && matchesHomeFilter && matchesSearch && matchesOnline && matchesPromo && matchesCategory
            }

            if (filteredBarbers.isEmpty()) {
                item {
                    Card(
                        shape = RoundedCornerShape(14.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(
                            modifier = Modifier.padding(24.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Icon(Icons.Default.SearchOff, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(36.dp))
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = "Aucun professionnel trouvé pour ces critères.",
                                fontSize = 14.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Text(
                                text = "Essayez d'élargir la recherche ou de changer de catégorie.",
                                fontSize = 12.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            } else {
                items(filteredBarbers) { barber ->
                    BarberCard(
                        barber = barber,
                        onBarberClick = { onBarberClick(barber) },
                        onBookClick = { onBookBarber(barber) },
                        onToggleFollow = { onToggleFollow(barber.id) }
                    )
                }
            }
        } else {
            // Salons / Beauty Institutes List (strictly Hommes or Dames)
            val filteredShops = shops.filter { s ->
                val matchesAudience = s.targetAudience == activeAudience
                val matchesSearch = searchQuery.isBlank() ||
                        s.name.contains(searchQuery, ignoreCase = true) ||
                        s.categorySubtitle.contains(searchQuery, ignoreCase = true) ||
                        s.address.contains(searchQuery, ignoreCase = true) ||
                        s.amenities.any { a -> a.contains(searchQuery, ignoreCase = true) } ||
                        s.services.any { srv -> srv.nameFr.contains(searchQuery, ignoreCase = true) }
                matchesAudience && matchesSearch
            }

            if (filteredShops.isEmpty()) {
                item {
                    Text("Aucun salon ne correspond à cette recherche.", modifier = Modifier.padding(16.dp))
                }
            } else {
                items(filteredShops) { shop ->
                    val isWomenShop = shop.targetAudience == TargetAudience.WOMEN
                    val shopBadgeColor = if (isWomenShop) BeautyFuchsia else BarberGoldPrimary
                    Card(
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                        modifier = Modifier
                            .fillMaxWidth()
                            .border(
                                1.dp,
                                if (isWomenShop) BeautyPink.copy(alpha = 0.4f) else BarberGoldPrimary.copy(alpha = 0.4f),
                                RoundedCornerShape(16.dp)
                            )
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.Top
                            ) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier.weight(1f)
                                ) {
                                    ProfileAvatarImage(
                                        avatarUrl = shop.avatarUrl,
                                        fallbackIcon = Icons.Default.Storefront,
                                        contentDescription = shop.name,
                                        accentColor = shopBadgeColor,
                                        size = 52.dp
                                    )
                                    Spacer(modifier = Modifier.width(10.dp))
                                    Column {
                                        // Audience Badge
                                        Surface(
                                            shape = RoundedCornerShape(6.dp),
                                            color = shopBadgeColor.copy(alpha = 0.15f)
                                        ) {
                                            Text(
                                                text = if (isWomenShop) "💄 Salon Dames & Institut de Beauté" else "🧔 Barbier & Coiffure Hommes",
                                                fontSize = 10.sp,
                                                fontWeight = FontWeight.Bold,
                                                color = shopBadgeColor,
                                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                            )
                                        }
                                        Spacer(modifier = Modifier.height(4.dp))
                                        Text(
                                            text = shop.name,
                                            fontSize = 16.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = MaterialTheme.colorScheme.onSurface
                                        )
                                        Text(
                                            text = shop.categorySubtitle,
                                            fontSize = 11.sp,
                                            fontWeight = FontWeight.Medium,
                                            color = shopBadgeColor
                                        )
                                        Text(
                                            text = "${shop.address} • 📍 ~0.5 km",
                                            fontSize = 12.sp,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }
                                }

                                Surface(
                                    shape = RoundedCornerShape(8.dp),
                                    color = BarberGoldPrimary.copy(alpha = 0.2f)
                                ) {
                                    Row(
                                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 4.dp),
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Icon(Icons.Default.Star, contentDescription = null, tint = BarberGoldPrimary, modifier = Modifier.size(14.dp))
                                        Spacer(modifier = Modifier.width(2.dp))
                                        Text("${shop.rating}", fontWeight = FontWeight.Bold, fontSize = 12.sp)
                                    }
                                }
                            }

                            Spacer(modifier = Modifier.height(10.dp))

                            Text(
                                text = "Horaires: ${shop.openingHours}",
                                fontSize = 12.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )

                            // Shop offered services
                            if (shop.services.isNotEmpty()) {
                                Spacer(modifier = Modifier.height(8.dp))
                                Text(
                                    text = "Prestations proposées :",
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                                Spacer(modifier = Modifier.height(4.dp))
                                LazyRow(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .testTag("shop_services_row_${shop.id}"),
                                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                                ) {
                                    items(shop.services) { srv ->
                                        Surface(
                                            shape = RoundedCornerShape(8.dp),
                                            color = shopBadgeColor.copy(alpha = 0.14f),
                                            modifier = Modifier.border(0.5.dp, shopBadgeColor.copy(alpha = 0.45f), RoundedCornerShape(8.dp))
                                        ) {
                                            Text(
                                                text = "${srv.nameFr} • ${srv.priceDzd} DA",
                                                fontSize = 10.sp,
                                                fontWeight = FontWeight.SemiBold,
                                                color = MaterialTheme.colorScheme.onSurface,
                                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                                            )
                                        }
                                    }
                                }
                            }

                            Spacer(modifier = Modifier.height(8.dp))

                            // Amenities tags
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(6.dp)
                            ) {
                                shop.amenities.take(3).forEach { am ->
                                    Surface(
                                        shape = RoundedCornerShape(6.dp),
                                        color = MaterialTheme.colorScheme.surface,
                                        modifier = Modifier.border(0.5.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(6.dp))
                                    ) {
                                        Text(
                                            text = am,
                                            fontSize = 10.sp,
                                            color = MaterialTheme.colorScheme.onSurface,
                                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                        )
                                    }
                                }
                            }

                            Spacer(modifier = Modifier.height(12.dp))

                            val staffLabel = if (isWomenShop) {
                                "💄 Coiffeuses & Esthéticiennes actives : Yasmine, Amel"
                            } else {
                                "💈 Barbiers actifs dans ce salon : Karim, Mehdi"
                            }
                            Text(
                                text = staffLabel,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = shopBadgeColor
                            )

                            Spacer(modifier = Modifier.height(10.dp))

                            OutlinedButton(
                                onClick = { onRateShop(shop) },
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(40.dp)
                                    .testTag("btn_rate_shop_${shop.id}"),
                                shape = RoundedCornerShape(10.dp)
                            ) {
                                Icon(Icons.Default.Star, contentDescription = null, tint = BarberGoldPrimary, modifier = Modifier.size(16.dp))
                                Spacer(modifier = Modifier.width(6.dp))
                                Text("Noter ce salon (${shop.reviewCount} avis)", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                            }
                        }
                    }
                }
            }
        }
    }
}
