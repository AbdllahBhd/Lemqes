package com.example.ui.screens

import androidx.activity.compose.BackHandler
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
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.i18n.SupportedLanguage
import com.example.model.*
import com.example.ui.theme.*

@Composable
fun AccountRegistrationScreen(
    currentLanguage: SupportedLanguage,
    onRegisterComplete: (UserAccount) -> Unit,
    savedAccounts: List<UserAccount> = emptyList(),
    onLoginCredentials: (phone: String, password: String) -> Boolean = { _, _ -> false },
    onQuickLogin: (UserAccount) -> Unit = {},
    onLangSelected: (SupportedLanguage) -> Unit = {},
    isDarkMode: Boolean = true,
    onToggleDarkMode: () -> Unit = {},
    modifier: Modifier = Modifier
) {
    // Auth Mode: 0 = Log In (Connexion), 1 = Create Account (Step-by-step Wizard)
    var authMode by remember { mutableStateOf(0) }
    var regStep by remember { mutableStateOf(1) }

    // Create Account State
    var selectedGender by remember { mutableStateOf<TargetAudience?>(null) }
    var selectedRole by remember { mutableStateOf<UserRole?>(null) }
    var selectedAudience by remember { mutableStateOf(TargetAudience.MEN) }
    var customerPreferredAudience by remember { mutableStateOf<TargetAudience?>(TargetAudience.MEN) }
    var customerInterests by remember { mutableStateOf(setOf<String>()) }
    var customerGpsEnabled by remember { mutableStateOf(true) }

    var fullName by remember { mutableStateOf("") }
    var phoneNumber by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var confirmPassword by remember { mutableStateOf("") }

    // Barber-specific state
    var experienceYears by remember { mutableStateOf(3) }
    var workplaceType by remember { mutableStateOf(WorkplaceType.REGISTERED_SHOP) }
    var workplaceName by remember { mutableStateOf("") }
    var barberSpecialties by remember { mutableStateOf(setOf<String>()) }

    // Shop-Owner-specific state
    var shopName by remember { mutableStateOf("") }
    var chairCountLabel by remember { mutableStateOf("3 - 5 postes") }
    var openingHours by remember { mutableStateOf("09:00 - 21:00") }
    var shopAmenities by remember { mutableStateOf(setOf<String>()) }
    var ownerAlsoWorksChair by remember { mutableStateOf(true) }
    var addressLandmark by remember { mutableStateOf("") }

    // Home-artist-specific state
    var homeServiceRadiusKm by remember { mutableStateOf(15) }
    var homeTravelFeeDzd by remember { mutableStateOf(500) }
    var homeCoveredZones by remember { mutableStateOf("Hydra, El Biar, Alger Centre") }

    // Shared Pro Photo & Shop Services state
    var avatarUrl by remember { mutableStateOf("") }
    var shopServices by remember { mutableStateOf(setOf<String>()) }

    var errorMessage by remember { mutableStateOf<String?>(null) }
    val scrollState = rememberScrollState()

    // Support Android back gesture / button inside step-by-step sign up
    BackHandler(enabled = authMode == 1 && regStep > 1) {
        regStep = (regStep - 1).coerceAtLeast(1)
        errorMessage = null
    }

    val wizardAccent = when {
        selectedRole == UserRole.CUSTOMER && customerPreferredAudience == TargetAudience.WOMEN -> BeautyFuchsia
        selectedGender == TargetAudience.WOMEN || selectedAudience == TargetAudience.WOMEN -> BeautyFuchsia
        selectedRole == UserRole.BARBER -> BarberEmerald
        selectedRole == UserRole.SHOP_OWNER -> BarberBlue
        else -> BarberGoldPrimary
    }
    val wizardAccentTextColor = if (wizardAccent == BarberGoldPrimary) Color.Black else Color.White

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .verticalScroll(scrollState)
            .padding(horizontal = 20.dp, vertical = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Top Utility Bar: Language & Theme Switch
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                modifier = Modifier
                    .clip(RoundedCornerShape(18.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant)
                    .padding(3.dp),
                horizontalArrangement = Arrangement.spacedBy(2.dp)
            ) {
                SupportedLanguage.entries.forEach { lang ->
                    val isSel = lang == currentLanguage
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(14.dp))
                            .background(if (isSel) BarberGoldPrimary else Color.Transparent)
                            .clickable { onLangSelected(lang) }
                            .padding(horizontal = 10.dp, vertical = 6.dp)
                    ) {
                        Text(
                            text = lang.code.uppercase(),
                            fontSize = 11.sp,
                            fontWeight = if (isSel) FontWeight.Bold else FontWeight.Medium,
                            color = if (isSel) Color.Black else MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            IconButton(
                onClick = onToggleDarkMode,
                modifier = Modifier
                    .size(48.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.surfaceVariant)
            ) {
                Icon(
                    imageVector = if (isDarkMode) Icons.Default.LightMode else Icons.Default.DarkMode,
                    contentDescription = "Changer de thème",
                    tint = BarberGoldPrimary,
                    modifier = Modifier.size(20.dp)
                )
            }
        }

        Spacer(modifier = Modifier.height(10.dp))

        // Compact Luxury Brand Card
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(22.dp))
                .background(
                    Brush.linearGradient(
                        colors = listOf(
                            BarberGoldPrimary.copy(alpha = 0.16f),
                            BeautyFuchsia.copy(alpha = 0.10f),
                            MaterialTheme.colorScheme.surfaceVariant
                        )
                    )
                )
                .border(1.dp, BarberGoldPrimary.copy(alpha = 0.35f), RoundedCornerShape(22.dp))
                .padding(vertical = 14.dp, horizontal = 16.dp),
            contentAlignment = Alignment.Center
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(48.dp)
                        .clip(CircleShape)
                        .background(Brush.linearGradient(colors = listOf(BarberGoldPrimary, BarberGoldVariant))),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.ContentCut,
                        contentDescription = "Lemqes",
                        tint = Color.Black,
                        modifier = Modifier.size(24.dp)
                    )
                }

                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = "LEMQES • المقص",
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Black,
                        letterSpacing = 1.sp,
                        color = MaterialTheme.colorScheme.primary
                    )
                    Text(
                        text = "Barbiers • Instituts Beauté Dames • Artistes à Domicile",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(14.dp))

        // Auth Mode Segmented Tabs: Se connecter / Créer un compte
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(14.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant)
                .padding(4.dp),
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Box(
                modifier = Modifier
                    .weight(1f)
                    .heightIn(min = 48.dp)
                    .clip(RoundedCornerShape(11.dp))
                    .background(if (authMode == 0) BarberGoldPrimary else Color.Transparent)
                    .clickable {
                        authMode = 0
                        errorMessage = null
                    }
                    .padding(vertical = 11.dp)
                    .testTag("auth_tab_login"),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "Se connecter",
                    fontSize = 13.sp,
                    fontWeight = if (authMode == 0) FontWeight.Bold else FontWeight.Medium,
                    color = if (authMode == 0) Color.Black else MaterialTheme.colorScheme.onSurface
                )
            }

            Box(
                modifier = Modifier
                    .weight(1f)
                    .heightIn(min = 48.dp)
                    .clip(RoundedCornerShape(11.dp))
                    .background(if (authMode == 1) BarberGoldPrimary else Color.Transparent)
                    .clickable {
                        authMode = 1
                        errorMessage = null
                    }
                    .padding(vertical = 11.dp)
                    .testTag("auth_tab_register"),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "Créer un compte",
                    fontSize = 13.sp,
                    fontWeight = if (authMode == 1) FontWeight.Bold else FontWeight.Medium,
                    color = if (authMode == 1) Color.Black else MaterialTheme.colorScheme.onSurface
                )
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Main Auth Flow: Login vs Step-by-Step Sign-Up Wizard
        AnimatedContent(
            targetState = authMode,
            label = "auth_mode_transition"
        ) { mode ->
            if (mode == 0) {
                LoginFormSection(
                    savedAccounts = savedAccounts,
                    onLoginSubmit = onLoginCredentials,
                    onQuickLogin = onQuickLogin,
                    onSwitchToRegister = {
                        authMode = 1
                        regStep = 1
                        errorMessage = null
                    }
                )
            } else {
                val totalSteps = totalStepsForRole(selectedRole)
                val safeStep = regStep.coerceIn(1, totalSteps)

                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    RegistrationStepProgressHeader(
                        currentStep = safeStep,
                        totalSteps = totalSteps,
                        stepTitle = stepTitleForRole(safeStep, selectedRole, selectedGender),
                        accentColor = wizardAccent,
                        canGoBack = safeStep > 1,
                        onBackClick = {
                            if (safeStep > 1) {
                                regStep = safeStep - 1
                                errorMessage = null
                            }
                        }
                    )

                    AnimatedContent(
                        targetState = safeStep,
                        transitionSpec = {
                            if (targetState > initialState) {
                                (slideInHorizontally { it / 3 } + fadeIn()).togetherWith(slideOutHorizontally { -it / 3 } + fadeOut())
                            } else {
                                (slideInHorizontally { -it / 3 } + fadeIn()).togetherWith(slideOutHorizontally { it / 3 } + fadeOut())
                            }
                        },
                        label = "wizard_step_transition"
                    ) { step ->
                        when (step) {
                            // STEP 1: Homme or Femme
                            1 -> {
                                Step1GenderSelectionScreen(
                                    selectedGender = selectedGender,
                                    onSelectGender = { gender ->
                                        selectedGender = gender
                                        selectedAudience = gender
                                        customerPreferredAudience = gender
                                        customerInterests = emptySet()
                                        barberSpecialties = emptySet()
                                        shopServices = emptySet()
                                        shopAmenities = emptySet()
                                        errorMessage = null
                                    }
                                )
                            }

                            // STEP 2: Role Selection adapted to Homme / Femme
                            2 -> {
                                Step2RoleSelectionScreen(
                                    selectedGender = selectedGender ?: TargetAudience.MEN,
                                    selectedRole = selectedRole,
                                    onSelectRole = { role ->
                                        selectedRole = role
                                        if (role == UserRole.HOME_ARTIST) {
                                            workplaceType = WorkplaceType.FREELANCE_MOBILE
                                        }
                                        errorMessage = null
                                    }
                                )
                            }

                            // STEP 3: Credentials, Password & Confirm Password
                            3 -> {
                                AccountCredentialsAndSecurityStep(
                                    role = selectedRole ?: UserRole.CUSTOMER,
                                    selectedAudience = selectedAudience,
                                    shopName = shopName,
                                    onShopNameChange = { shopName = it; errorMessage = null },
                                    fullName = fullName,
                                    onFullNameChange = { fullName = it; errorMessage = null },
                                    phoneNumber = phoneNumber,
                                    onPhoneChange = { phoneNumber = it; errorMessage = null },
                                    password = password,
                                    onPasswordChange = { password = it; errorMessage = null },
                                    confirmPassword = confirmPassword,
                                    onConfirmPasswordChange = { confirmPassword = it; errorMessage = null },
                                    accentColor = wizardAccent
                                )
                            }

                            // STEP 4: Role-specific Profile, Photo & Preferences
                            4 -> {
                                when (selectedRole) {
                                    UserRole.CUSTOMER -> {
                                        CustomerPreferencesStep(
                                            preferredAudience = customerPreferredAudience,
                                            onPreferredAudienceChange = {
                                                if (it != null) {
                                                    selectedGender = it
                                                    selectedAudience = it
                                                    customerPreferredAudience = it
                                                }
                                                customerInterests = emptySet()
                                            },
                                            selectedInterests = customerInterests,
                                            onToggleInterest = { item ->
                                                customerInterests = if (customerInterests.contains(item)) {
                                                    customerInterests - item
                                                } else {
                                                    customerInterests + item
                                                }
                                            },
                                            gpsRadarEnabled = customerGpsEnabled,
                                            onGpsRadarToggle = { customerGpsEnabled = it }
                                        )
                                    }

                                    UserRole.BARBER -> {
                                        BarberProfileDetailsStep(
                                            selectedAudience = selectedAudience,
                                            onAudienceChange = {
                                                selectedGender = it
                                                selectedAudience = it
                                                customerPreferredAudience = it
                                                barberSpecialties = emptySet()
                                            },
                                            experienceYears = experienceYears,
                                            onExperienceChange = { experienceYears = it },
                                            workplaceType = workplaceType,
                                            onWorkplaceTypeChange = { workplaceType = it },
                                            workplaceName = workplaceName,
                                            onWorkplaceNameChange = { workplaceName = it },
                                            avatarUrl = avatarUrl,
                                            onAvatarChange = { avatarUrl = it }
                                        )
                                    }

                                    UserRole.HOME_ARTIST -> {
                                        HomeArtistMobilityStep(
                                            selectedAudience = selectedAudience,
                                            onAudienceChange = {
                                                selectedGender = it
                                                selectedAudience = it
                                                customerPreferredAudience = it
                                                barberSpecialties = emptySet()
                                            },
                                            experienceYears = experienceYears,
                                            onExperienceChange = { experienceYears = it },
                                            serviceRadiusKm = homeServiceRadiusKm,
                                            onServiceRadiusChange = { homeServiceRadiusKm = it },
                                            travelFeeDzd = homeTravelFeeDzd,
                                            onTravelFeeChange = { homeTravelFeeDzd = it },
                                            coveredZones = homeCoveredZones,
                                            onCoveredZonesChange = { homeCoveredZones = it },
                                            avatarUrl = avatarUrl,
                                            onAvatarChange = { avatarUrl = it }
                                        )
                                    }

                                    UserRole.SHOP_OWNER -> {
                                        ShopOwnerSetupStep(
                                            selectedAudience = selectedAudience,
                                            onAudienceChange = {
                                                selectedGender = it
                                                selectedAudience = it
                                                customerPreferredAudience = it
                                                shopAmenities = emptySet()
                                                shopServices = emptySet()
                                            },
                                            chairCountLabel = chairCountLabel,
                                            onChairCountChange = { chairCountLabel = it },
                                            openingHours = openingHours,
                                            onOpeningHoursChange = { openingHours = it },
                                            selectedAmenities = shopAmenities,
                                            onToggleAmenity = { am ->
                                                shopAmenities = if (shopAmenities.contains(am)) {
                                                    shopAmenities - am
                                                } else {
                                                    shopAmenities + am
                                                }
                                            },
                                            ownerAlsoWorksChair = ownerAlsoWorksChair,
                                            onOwnerChairToggle = { ownerAlsoWorksChair = it },
                                            addressLandmark = addressLandmark,
                                            onAddressLandmarkChange = { addressLandmark = it },
                                            avatarUrl = avatarUrl,
                                            onAvatarChange = { avatarUrl = it }
                                        )
                                    }

                                    null -> {}
                                }
                            }

                            // STEP 5: Offered Services (List + Typed Custom) & GPS Location for Professionals
                            5 -> {
                                when (selectedRole) {
                                    UserRole.BARBER -> {
                                        BarberServicesAndLocationStep(
                                            selectedAudience = selectedAudience,
                                            selectedSpecialties = barberSpecialties,
                                            onToggleSpecialty = { spec ->
                                                barberSpecialties = if (barberSpecialties.contains(spec)) {
                                                    barberSpecialties - spec
                                                } else {
                                                    barberSpecialties + spec
                                                }
                                            },
                                            onAddCustomSpecialty = { custom ->
                                                val clean = custom.trim()
                                                if (clean.isNotBlank()) barberSpecialties = barberSpecialties + clean
                                            }
                                        )
                                    }

                                    UserRole.HOME_ARTIST -> {
                                        HomeArtistServicesStep(
                                            selectedAudience = selectedAudience,
                                            selectedSpecialties = barberSpecialties,
                                            onToggleSpecialty = { spec ->
                                                barberSpecialties = if (barberSpecialties.contains(spec)) {
                                                    barberSpecialties - spec
                                                } else {
                                                    barberSpecialties + spec
                                                }
                                            },
                                            onAddCustomSpecialty = { custom ->
                                                val clean = custom.trim()
                                                if (clean.isNotBlank()) barberSpecialties = barberSpecialties + clean
                                            }
                                        )
                                    }

                                    UserRole.SHOP_OWNER -> {
                                        ShopOwnerServicesAndLocationStep(
                                            selectedAudience = selectedAudience,
                                            selectedShopServices = shopServices,
                                            onToggleShopService = { srv ->
                                                shopServices = if (shopServices.contains(srv)) {
                                                    shopServices - srv
                                                } else {
                                                    shopServices + srv
                                                }
                                            },
                                            onAddCustomShopService = { custom ->
                                                val clean = custom.trim()
                                                if (clean.isNotBlank()) shopServices = shopServices + clean
                                            }
                                        )
                                    }

                                    else -> {}
                                }
                            }
                        }
                    }

                    // Error Banner
                    if (errorMessage != null) {
                        Surface(
                            shape = RoundedCornerShape(10.dp),
                            color = BarberRose.copy(alpha = 0.14f),
                            modifier = Modifier
                                .fillMaxWidth()
                                .border(1.dp, BarberRose.copy(alpha = 0.4f), RoundedCornerShape(10.dp))
                                .testTag("reg_error_banner")
                        ) {
                            Row(
                                modifier = Modifier.padding(10.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(Icons.Default.ErrorOutline, contentDescription = null, tint = BarberRose, modifier = Modifier.size(18.dp))
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = errorMessage!!,
                                    color = BarberRose,
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.SemiBold
                                )
                            }
                        }
                    }

                    // Step Navigation Buttons (Précédent / Continuer or Final Submit)
                    val isFinalStep = safeStep >= totalSteps
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        if (safeStep > 1) {
                            OutlinedButton(
                                onClick = {
                                    regStep = safeStep - 1
                                    errorMessage = null
                                },
                                modifier = Modifier
                                    .weight(0.9f)
                                    .height(52.dp)
                                    .testTag("wizard_prev_btn"),
                                shape = RoundedCornerShape(14.dp)
                            ) {
                                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null, modifier = Modifier.size(18.dp))
                                Spacer(modifier = Modifier.width(6.dp))
                                Text("Précédent", fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                            }
                        }

                        Button(
                            onClick = {
                                if (!isFinalStep) {
                                    when (safeStep) {
                                        1 -> {
                                            if (selectedGender == null) {
                                                errorMessage = "Veuillez choisir Homme ou Femme pour continuer."
                                            } else {
                                                errorMessage = null
                                                regStep = 2
                                            }
                                        }
                                        2 -> {
                                            if (selectedRole == null) {
                                                errorMessage = "Veuillez choisir votre type de compte."
                                            } else {
                                                errorMessage = null
                                                regStep = 3
                                            }
                                        }
                                        3 -> {
                                            val err = validateCredentialsStep(
                                                role = selectedRole,
                                                shopName = shopName,
                                                fullName = fullName,
                                                phoneNumber = phoneNumber,
                                                password = password,
                                                confirmPassword = confirmPassword
                                            )
                                            if (err != null) {
                                                errorMessage = err
                                            } else {
                                                errorMessage = null
                                                regStep = 4
                                            }
                                        }
                                        4 -> {
                                            errorMessage = null
                                            regStep = 5
                                        }
                                    }
                                } else {
                                    val credError = validateCredentialsStep(
                                        role = selectedRole,
                                        shopName = shopName,
                                        fullName = fullName,
                                        phoneNumber = phoneNumber,
                                        password = password,
                                        confirmPassword = confirmPassword
                                    )
                                    if (credError != null) {
                                        errorMessage = credError
                                    } else {
                                        val defaultCountry = Country.ALGERIA
                                        val wallet = WalletAccount(
                                            balanceUsd = defaultCountry.monthlyRateUsd,
                                            country = defaultCountry,
                                            monthlyRateUsd = defaultCountry.monthlyRateUsd,
                                            monthsRemaining = 1,
                                            daysCoveredRemaining = 30
                                        )
                                        val isWomen = selectedAudience == TargetAudience.WOMEN
                                        val account = UserAccount(
                                            id = "user_${System.currentTimeMillis()}",
                                            fullName = fullName.trim(),
                                            phoneNumber = phoneNumber.trim(),
                                            role = selectedRole!!,
                                            password = password,
                                            country = defaultCountry,
                                            targetAudience = if (selectedRole == UserRole.CUSTOMER) {
                                                customerPreferredAudience ?: TargetAudience.MEN
                                            } else selectedAudience,
                                            preferredAudience = if (selectedRole == UserRole.CUSTOMER) {
                                                customerPreferredAudience ?: TargetAudience.MEN
                                            } else null,
                                            latitude = 36.7538,
                                            longitude = 3.0588,
                                            locationLabel = addressLandmark.ifBlank { "Position GPS Définie" },
                                            avatarUrl = avatarUrl,
                                            shopOrBarberName = when (selectedRole) {
                                                UserRole.SHOP_OWNER -> shopName.trim()
                                                UserRole.HOME_ARTIST -> if (isWomen) "Beauté Mobile à Domicile (Dames)" else "Service Mobile à Domicile"
                                                UserRole.BARBER -> workplaceName.ifBlank {
                                                    if (isWomen) "Coiffeuse & Esthéticienne Dames" else "Barbier Indépendant"
                                                }
                                                else -> ""
                                            },
                                            experienceYears = experienceYears,
                                            workplaceType = if (selectedRole == UserRole.HOME_ARTIST) WorkplaceType.FREELANCE_MOBILE else workplaceType,
                                            selectedSpecialties = when (selectedRole) {
                                                UserRole.CUSTOMER -> customerInterests.toList()
                                                UserRole.SHOP_OWNER -> shopServices.toList()
                                                else -> barberSpecialties.toList()
                                            },
                                            chairCountLabel = chairCountLabel,
                                            openingHours = openingHours.ifBlank { "09:00 - 21:00" },
                                            amenities = shopAmenities.toList(),
                                            ownerAlsoWorksChair = ownerAlsoWorksChair,
                                            gpsRadarEnabled = customerGpsEnabled,
                                            serviceRadiusKm = homeServiceRadiusKm,
                                            travelFeeDzd = homeTravelFeeDzd,
                                            coveredZones = homeCoveredZones.ifBlank { "Grand Alger" },
                                            wallet = wallet
                                        )
                                        onRegisterComplete(account)
                                    }
                                }
                            },
                            modifier = Modifier
                                .weight(1.4f)
                                .height(52.dp)
                                .testTag(if (isFinalStep) "submit_registration_btn" else "wizard_next_btn"),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = wizardAccent,
                                contentColor = wizardAccentTextColor
                            ),
                            shape = RoundedCornerShape(14.dp)
                        ) {
                            Text(
                                text = if (!isFinalStep) {
                                    "Continuer"
                                } else {
                                    when (selectedRole) {
                                        UserRole.BARBER -> "Commencer gratuitement"
                                        UserRole.HOME_ARTIST -> "Lancer mon service à domicile"
                                        UserRole.SHOP_OWNER -> "Démarrer mon salon gratuitement"
                                        else -> "Créer mon compte client"
                                    }
                                },
                                fontWeight = FontWeight.Bold,
                                fontSize = 14.sp
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Icon(
                                imageVector = if (isFinalStep) Icons.Default.CheckCircle else Icons.AutoMirrored.Filled.ArrowForward,
                                contentDescription = null,
                                modifier = Modifier.size(18.dp)
                            )
                        }
                    }

                    // Bottom link back to Login
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 6.dp),
                        horizontalArrangement = Arrangement.Center,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "Vous avez déjà un compte ?",
                            fontSize = 13.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = "Se connecter",
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Bold,
                            color = BarberGoldPrimary,
                            modifier = Modifier
                                .clip(RoundedCornerShape(8.dp))
                                .clickable {
                                    authMode = 0
                                    errorMessage = null
                                }
                                .padding(horizontal = 8.dp, vertical = 6.dp)
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(20.dp))
    }
}

@Composable
private fun Step1GenderSelectionScreen(
    selectedGender: TargetAudience?,
    onSelectGender: (TargetAudience) -> Unit
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(
            text = "Choisissez votre espace (Homme ou Femme) :",
            fontSize = 15.sp,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface
        )
        Text(
            text = "LEMQES sépare strictement l'espace Hommes et l'espace Dames pour votre confort et confidentialité.",
            fontSize = 12.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            lineHeight = 16.sp
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            val isMale = selectedGender == TargetAudience.MEN
            val isFemale = selectedGender == TargetAudience.WOMEN

            Surface(
                shape = RoundedCornerShape(18.dp),
                color = if (isMale) BarberGoldPrimary.copy(alpha = 0.16f) else MaterialTheme.colorScheme.surfaceVariant,
                modifier = Modifier
                    .weight(1f)
                    .heightIn(min = 132.dp)
                    .clip(RoundedCornerShape(18.dp))
                    .border(
                        width = if (isMale) 2.dp else 1.dp,
                        color = if (isMale) BarberGoldPrimary else MaterialTheme.colorScheme.outline.copy(alpha = 0.5f),
                        shape = RoundedCornerShape(18.dp)
                    )
                    .clickable { onSelectGender(TargetAudience.MEN) }
                    .testTag("reg_gender_male")
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    Box(
                        modifier = Modifier
                            .size(46.dp)
                            .clip(CircleShape)
                            .background(if (isMale) BarberGoldPrimary else BarberGoldPrimary.copy(alpha = 0.18f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.Face,
                            contentDescription = "Homme",
                            tint = if (isMale) Color.Black else BarberGoldPrimary,
                            modifier = Modifier.size(24.dp)
                        )
                    }
                    Spacer(modifier = Modifier.height(10.dp))
                    Text(
                        text = "🧔 Homme",
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                        color = if (isMale) BarberGoldPrimary else MaterialTheme.colorScheme.onSurface
                    )
                    Text(
                        text = "رجال • Espace Hommes",
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center
                    )
                }
            }

            Surface(
                shape = RoundedCornerShape(18.dp),
                color = if (isFemale) BeautyFuchsia.copy(alpha = 0.16f) else MaterialTheme.colorScheme.surfaceVariant,
                modifier = Modifier
                    .weight(1f)
                    .heightIn(min = 132.dp)
                    .clip(RoundedCornerShape(18.dp))
                    .border(
                        width = if (isFemale) 2.dp else 1.dp,
                        color = if (isFemale) BeautyFuchsia else MaterialTheme.colorScheme.outline.copy(alpha = 0.5f),
                        shape = RoundedCornerShape(18.dp)
                    )
                    .clickable { onSelectGender(TargetAudience.WOMEN) }
                    .testTag("reg_gender_female")
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    Box(
                        modifier = Modifier
                            .size(46.dp)
                            .clip(CircleShape)
                            .background(if (isFemale) BeautyFuchsia else BeautyFuchsia.copy(alpha = 0.18f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.Spa,
                            contentDescription = "Femme",
                            tint = if (isFemale) Color.White else BeautyFuchsia,
                            modifier = Modifier.size(24.dp)
                        )
                    }
                    Spacer(modifier = Modifier.height(10.dp))
                    Text(
                        text = "💄 Femme",
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                        color = if (isFemale) BeautyFuchsia else MaterialTheme.colorScheme.onSurface
                    )
                    Text(
                        text = "نساء • Espace Dames",
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center
                    )
                }
            }
        }
    }
}

@Composable
private fun Step2RoleSelectionScreen(
    selectedGender: TargetAudience,
    selectedRole: UserRole?,
    onSelectRole: (UserRole) -> Unit
) {
    val isWomen = selectedGender == TargetAudience.WOMEN
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(
            text = if (isWomen) "Sélectionnez votre profil dans l'espace Dames :" else "Sélectionnez votre profil dans l'espace Hommes :",
            fontSize = 15.sp,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface
        )

        RoleSelectionCard(
            title = if (isWomen) "Je suis Cliente" else "Je suis Client",
            titleAr = if (isWomen) "أنا زبونة" else "أنا زبون",
            description = if (isWomen) {
                "Trouvez les meilleurs instituts de beauté, coiffeuses et soins à domicile pour dames."
            } else {
                "Trouvez les meilleurs barbiers, salons et prestations à domicile pour hommes."
            },
            icon = Icons.Default.Person,
            isSelected = selectedRole == UserRole.CUSTOMER,
            accentColor = if (isWomen) BeautyFuchsia else BarberGoldPrimary,
            badge = "Gratuit",
            testTag = "role_choice_customer",
            onClick = { onSelectRole(UserRole.CUSTOMER) }
        )

        RoleSelectionCard(
            title = if (isWomen) "Coiffeuse / Esthéticienne / Nail Artist" else "Coiffeur / Barbier Hommes",
            titleAr = if (isWomen) "كوافيرة / أخصائية تجميل وأظافر" else "حلاق ومصفف شعر للرجال",
            description = if (isWomen) {
                "Votre profil beauté dames (coiffure, onglerie, soins) et vos clientes vous suivent partout."
            } else {
                "Votre profil barbier (coupe, dégradé, barbe) et vos clients vous suivent partout."
            },
            icon = if (isWomen) Icons.Default.Spa else Icons.Default.ContentCut,
            isSelected = selectedRole == UserRole.BARBER,
            accentColor = if (isWomen) BeautyFuchsia else BarberEmerald,
            badge = "Gratuit 1 mois",
            testTag = "role_choice_barber",
            onClick = { onSelectRole(UserRole.BARBER) }
        )

        RoleSelectionCard(
            title = if (isWomen) "Artiste Beauté à Domicile (Dames)" else "Barbier à Domicile (Hommes)",
            titleAr = if (isWomen) "مختصة تجميل وكوافيرة في المنزل للنساء" else "حلاق متنقل في المنزل للرجال",
            description = if (isWomen) {
                "Service mobile 100% dames : brushing, manucure, pédicure spa, soins visage & maquillage."
            } else {
                "Service mobile 100% hommes : coupe, dégradé, barbe sculptée & pack marié à domicile."
            },
            icon = Icons.Default.HomeRepairService,
            isSelected = selectedRole == UserRole.HOME_ARTIST,
            accentColor = if (isWomen) BeautyFuchsia else BarberGoldPrimary,
            badge = "Gratuit 1 mois",
            testTag = "role_choice_home_artist",
            onClick = { onSelectRole(UserRole.HOME_ARTIST) }
        )

        RoleSelectionCard(
            title = if (isWomen) "Propriétaire d'Institut / Salon Dames" else "Propriétaire de Barber Shop Hommes",
            titleAr = if (isWomen) "صاحبة صالون تجميل وحلاقة للنساء" else "صاحب صالون حلاقة للرجال",
            description = if (isWomen) {
                "Gérez votre institut de beauté dames, vos cabines, prestations et votre équipe."
            } else {
                "Gérez votre salon hommes, vos chaises actives, réservations et votre équipe."
            },
            icon = Icons.Default.Storefront,
            isSelected = selectedRole == UserRole.SHOP_OWNER,
            accentColor = if (isWomen) BeautyFuchsia else BarberBlue,
            badge = "Gratuit 1 mois",
            testTag = "role_choice_shop",
            onClick = { onSelectRole(UserRole.SHOP_OWNER) }
        )
    }
}

@Composable
private fun RoleSelectionCard(
    title: String,
    titleAr: String,
    description: String,
    icon: ImageVector,
    isSelected: Boolean,
    accentColor: Color,
    badge: String? = null,
    testTag: String,
    onClick: () -> Unit
) {
    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = if (isSelected) accentColor.copy(alpha = 0.15f) else MaterialTheme.colorScheme.surfaceVariant
        ),
        modifier = Modifier
            .fillMaxWidth()
            .border(
                width = if (isSelected) 2.dp else 0.5.dp,
                color = if (isSelected) accentColor else MaterialTheme.colorScheme.outline,
                shape = RoundedCornerShape(16.dp)
            )
            .clickable { onClick() }
            .testTag(testTag)
    ) {
        Row(
            modifier = Modifier.padding(14.dp),
            verticalAlignment = Alignment.Top
        ) {
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .clip(CircleShape)
                    .background(if (isSelected) accentColor else MaterialTheme.colorScheme.surface),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = title,
                    tint = if (isSelected) Color.Black else accentColor,
                    modifier = Modifier.size(22.dp)
                )
            }

            Spacer(modifier = Modifier.width(12.dp))

            Column(modifier = Modifier.weight(1f)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = title,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Text(
                            text = titleAr,
                            fontSize = 11.sp,
                            color = accentColor,
                            fontWeight = FontWeight.SemiBold
                        )
                    }

                    if (badge != null) {
                        Surface(
                            shape = RoundedCornerShape(6.dp),
                            color = accentColor.copy(alpha = 0.2f)
                        ) {
                            Text(
                                text = badge,
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold,
                                color = accentColor,
                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                            )
                        }
                    } else if (isSelected) {
                        Icon(
                            imageVector = Icons.Default.CheckCircle,
                            contentDescription = "Sélectionné",
                            tint = accentColor,
                            modifier = Modifier.size(20.dp)
                        )
                    }
                }

                Spacer(modifier = Modifier.height(5.dp))

                Text(
                    text = description,
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    lineHeight = 16.sp
                )
            }
        }
    }
}
