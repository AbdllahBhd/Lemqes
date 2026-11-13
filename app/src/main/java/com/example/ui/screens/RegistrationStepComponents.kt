package com.example.ui.screens

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.model.TargetAudience
import com.example.model.UserRole
import com.example.ui.theme.*

fun totalStepsForRole(role: UserRole?): Int {
    return when (role) {
        UserRole.CUSTOMER -> 4
        UserRole.BARBER, UserRole.HOME_ARTIST, UserRole.SHOP_OWNER -> 5
        null -> 4
    }
}

fun stepTitleForRole(step: Int, role: UserRole?, audience: TargetAudience?): String {
    val isWomen = audience == TargetAudience.WOMEN
    return when (step) {
        1 -> "Votre espace dédié"
        2 -> if (isWomen) "Votre rôle • Espace Dames" else "Votre rôle • Espace Hommes"
        3 -> "Identité & Mot de passe"
        4 -> when (role) {
            UserRole.CUSTOMER -> "Préférences & Radar GPS"
            UserRole.BARBER -> "Photo, Expérience & Atelier"
            UserRole.HOME_ARTIST -> "Photo & Zone à Domicile"
            UserRole.SHOP_OWNER -> "Photo, Capacité & Horaires"
            null -> "Détails du profil"
        }
        5 -> when (role) {
            UserRole.HOME_ARTIST -> "Prestations à Domicile & GPS"
            UserRole.SHOP_OWNER -> "Services du Salon & GPS"
            else -> "Services proposés & GPS"
        }
        else -> "Création du compte"
    }
}

fun validateCredentialsStep(
    role: UserRole?,
    shopName: String,
    fullName: String,
    phoneNumber: String,
    password: String,
    confirmPassword: String
): String? {
    return when {
        role == null -> "Veuillez d'abord sélectionner votre type de compte."
        role == UserRole.SHOP_OWNER && shopName.isBlank() -> "Veuillez saisir le nom de votre salon ou institut."
        fullName.isBlank() -> "Veuillez saisir votre nom complet."
        phoneNumber.isBlank() -> "Veuillez saisir votre numéro de téléphone."
        password.length < 4 -> "Veuillez choisir un mot de passe d'au moins 4 caractères."
        confirmPassword.isBlank() -> "Veuillez confirmer votre mot de passe."
        password != confirmPassword -> "Les mots de passe ne correspondent pas."
        else -> null
    }
}

@Composable
fun RegistrationStepProgressHeader(
    currentStep: Int,
    totalSteps: Int,
    stepTitle: String,
    accentColor: Color,
    canGoBack: Boolean,
    onBackClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val progress by animateFloatAsState(
        targetValue = (currentStep.toFloat() / totalSteps.coerceAtLeast(1).toFloat()).coerceIn(0f, 1f),
        label = "wizard_progress"
    )

    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .border(1.dp, accentColor.copy(alpha = 0.25f), RoundedCornerShape(16.dp))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.weight(1f)) {
                if (canGoBack) {
                    IconButton(
                        onClick = onBackClick,
                        modifier = Modifier
                            .size(48.dp)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.surface)
                            .testTag("wizard_header_back_btn")
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Étape précédente",
                            tint = accentColor,
                            modifier = Modifier.size(20.dp)
                        )
                    }
                    Spacer(modifier = Modifier.width(10.dp))
                }
                Column {
                    Text(
                        text = "Étape $currentStep sur $totalSteps",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        color = accentColor,
                        modifier = Modifier.testTag("wizard_step_indicator")
                    )
                    Text(
                        text = stepTitle,
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                }
            }

            Surface(
                shape = RoundedCornerShape(10.dp),
                color = accentColor.copy(alpha = 0.16f)
            ) {
                Text(
                    text = "${(progress * 100).toInt()}%",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Black,
                    color = accentColor,
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                )
            }
        }

        // Segmented step progress bar
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(5.dp)
        ) {
            for (stepIdx in 1..totalSteps) {
                val isCompletedOrCurrent = stepIdx <= currentStep
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(5.dp)
                        .clip(RoundedCornerShape(4.dp))
                        .background(
                            if (isCompletedOrCurrent) accentColor
                            else MaterialTheme.colorScheme.outline.copy(alpha = 0.35f)
                        )
                )
            }
        }
    }
}

@Composable
fun AccountCredentialsAndSecurityStep(
    role: UserRole,
    selectedAudience: TargetAudience,
    shopName: String,
    onShopNameChange: (String) -> Unit,
    fullName: String,
    onFullNameChange: (String) -> Unit,
    phoneNumber: String,
    onPhoneChange: (String) -> Unit,
    password: String,
    onPasswordChange: (String) -> Unit,
    confirmPassword: String,
    onConfirmPasswordChange: (String) -> Unit,
    accentColor: Color,
    modifier: Modifier = Modifier
) {
    var passwordVisible by remember { mutableStateOf(false) }
    var confirmPasswordVisible by remember { mutableStateOf(false) }
    val isWomen = selectedAudience == TargetAudience.WOMEN

    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        if (role == UserRole.CUSTOMER) {
            Surface(
                shape = RoundedCornerShape(14.dp),
                color = accentColor.copy(alpha = 0.12f),
                modifier = Modifier
                    .fillMaxWidth()
                    .border(1.dp, accentColor.copy(alpha = 0.45f), RoundedCornerShape(14.dp))
            ) {
                Row(
                    modifier = Modifier.padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(Icons.Default.Verified, contentDescription = null, tint = accentColor, modifier = Modifier.size(20.dp))
                    Spacer(modifier = Modifier.width(10.dp))
                    Text(
                        text = if (isWomen) "Espace Cliente 100% gratuit • Sécurisez votre accès" else "Espace Client 100% gratuit • Sécurisez votre accès",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                }
            }
        } else {
            StartForFreeBanner(role = role, accentColor = accentColor)
        }

        Card(
            shape = RoundedCornerShape(18.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
            modifier = Modifier
                .fillMaxWidth()
                .border(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.45f), RoundedCornerShape(18.dp))
        ) {
            Column(
                modifier = Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                if (role == UserRole.SHOP_OWNER) {
                    OutlinedTextField(
                        value = shopName,
                        onValueChange = onShopNameChange,
                        label = { Text(if (isWomen) "Nom du Salon / Institut de Beauté" else "Nom du Salon / Barber Shop") },
                        placeholder = { Text(if (isWomen) "ex. Institut Reine de Saba" else "ex. Salon Le Diplomate Alger") },
                        leadingIcon = { Icon(Icons.Default.Store, contentDescription = null, tint = accentColor) },
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("reg_input_shop_name"),
                        shape = RoundedCornerShape(14.dp),
                        singleLine = true
                    )
                }

                OutlinedTextField(
                    value = fullName,
                    onValueChange = onFullNameChange,
                    label = {
                        Text(
                            when (role) {
                                UserRole.SHOP_OWNER -> if (isWomen) "Nom complet de la Gérante" else "Nom complet du Gérant"
                                UserRole.BARBER -> if (isWomen) "Nom de la Coiffeuse / Esthéticienne" else "Nom du Barbier / Artiste"
                                UserRole.HOME_ARTIST -> if (isWomen) "Nom de l'Artiste Beauté à Domicile" else "Nom du Barbier à Domicile"
                                UserRole.CUSTOMER -> "Nom complet"
                            }
                        )
                    },
                    placeholder = {
                        Text(
                            when (role) {
                                UserRole.SHOP_OWNER -> if (isWomen) "ex. Sarah Benmansour" else "ex. Mohamed Khelifi"
                                UserRole.BARBER -> if (isWomen) "ex. Yasmine Coiffure" else "ex. Karim 'Le Ciseau d'Or'"
                                UserRole.HOME_ARTIST -> if (isWomen) "ex. Lina Beauté Mobile" else "ex. Amine VIP Mobile"
                                UserRole.CUSTOMER -> if (isWomen) "ex. Meriem K." else "ex. Amine Benali"
                            }
                        )
                    },
                    leadingIcon = {
                        Icon(
                            imageVector = if (isWomen && role != UserRole.CUSTOMER) Icons.Default.Spa else Icons.Default.Person,
                            contentDescription = null,
                            tint = accentColor
                        )
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("reg_input_name"),
                    shape = RoundedCornerShape(14.dp),
                    singleLine = true
                )

                OutlinedTextField(
                    value = phoneNumber,
                    onValueChange = onPhoneChange,
                    label = {
                        Text(
                            when (role) {
                                UserRole.SHOP_OWNER -> "Téléphone d'accueil du salon"
                                UserRole.CUSTOMER -> "Numéro de téléphone"
                                else -> "Téléphone professionnel"
                            }
                        )
                    },
                    placeholder = { Text("0550 12 34 56") },
                    leadingIcon = { Icon(Icons.Default.Phone, contentDescription = null, tint = BarberEmerald) },
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("reg_input_phone"),
                    shape = RoundedCornerShape(14.dp),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone)
                )

                HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.25f))

                Text(
                    text = "Sécurité du compte",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )

                OutlinedTextField(
                    value = password,
                    onValueChange = onPasswordChange,
                    label = { Text("Mot de passe") },
                    placeholder = { Text("Minimum 4 caractères") },
                    leadingIcon = { Icon(Icons.Default.Lock, contentDescription = null, tint = accentColor) },
                    trailingIcon = {
                        IconButton(
                            onClick = { passwordVisible = !passwordVisible },
                            modifier = Modifier.minimumInteractiveComponentSize()
                        ) {
                            Icon(
                                imageVector = if (passwordVisible) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                                contentDescription = if (passwordVisible) "Masquer" else "Afficher"
                            )
                        }
                    },
                    visualTransformation = if (passwordVisible) VisualTransformation.None else PasswordVisualTransformation(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("reg_input_password"),
                    shape = RoundedCornerShape(14.dp),
                    singleLine = true
                )

                val showMatchStatus = confirmPassword.isNotEmpty()
                val passwordsMatch = password == confirmPassword && password.length >= 4
                val passwordMismatch = showMatchStatus && password != confirmPassword

                OutlinedTextField(
                    value = confirmPassword,
                    onValueChange = onConfirmPasswordChange,
                    label = { Text("Confirmer le mot de passe") },
                    placeholder = { Text("Saisissez à nouveau votre mot de passe") },
                    leadingIcon = {
                        Icon(
                            imageVector = if (passwordsMatch) Icons.Default.VerifiedUser else Icons.Default.LockReset,
                            contentDescription = null,
                            tint = when {
                                passwordMismatch -> BarberRose
                                passwordsMatch -> BarberEmerald
                                else -> accentColor
                            }
                        )
                    },
                    trailingIcon = {
                        IconButton(
                            onClick = { confirmPasswordVisible = !confirmPasswordVisible },
                            modifier = Modifier.minimumInteractiveComponentSize()
                        ) {
                            Icon(
                                imageVector = if (confirmPasswordVisible) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                                contentDescription = if (confirmPasswordVisible) "Masquer" else "Afficher"
                            )
                        }
                    },
                    isError = passwordMismatch,
                    visualTransformation = if (confirmPasswordVisible) VisualTransformation.None else PasswordVisualTransformation(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("reg_input_confirm_password"),
                    shape = RoundedCornerShape(14.dp),
                    singleLine = true
                )

                if (passwordMismatch) {
                    Text(
                        text = "⚠ Les deux mots de passe ne sont pas identiques.",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = BarberRose,
                        modifier = Modifier.testTag("password_mismatch_label")
                    )
                } else if (passwordsMatch) {
                    Text(
                        text = "✓ Mot de passe confirmé",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = BarberEmerald,
                        modifier = Modifier.testTag("password_match_label")
                    )
                }
            }
        }
    }
}

@Composable
fun CustomerPreferencesStep(
    preferredAudience: TargetAudience?,
    onPreferredAudienceChange: (TargetAudience?) -> Unit,
    selectedInterests: Set<String>,
    onToggleInterest: (String) -> Unit,
    gpsRadarEnabled: Boolean,
    onGpsRadarToggle: (Boolean) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Card(
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(modifier = Modifier.padding(14.dp)) {
                Text(
                    text = "Vos préférences de salons :",
                    fontWeight = FontWeight.Bold,
                    fontSize = 13.sp,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Spacer(modifier = Modifier.height(8.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    val opts = listOf(
                        Triple(TargetAudience.MEN, "🧔 Hommes", BarberGoldPrimary),
                        Triple(TargetAudience.WOMEN, "💄 Dames", BeautyFuchsia)
                    )
                    opts.forEach { (aud, lbl, col) ->
                        val isSel = (preferredAudience ?: TargetAudience.MEN) == aud
                        Surface(
                            shape = RoundedCornerShape(10.dp),
                            color = if (isSel) col else MaterialTheme.colorScheme.surface,
                            modifier = Modifier
                                .weight(1f)
                                .heightIn(min = 48.dp)
                                .clickable { onPreferredAudienceChange(aud) }
                                .border(1.dp, if (isSel) col else MaterialTheme.colorScheme.outline, RoundedCornerShape(10.dp))
                        ) {
                            Box(
                                modifier = Modifier.padding(vertical = 10.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = lbl,
                                    fontSize = 12.sp,
                                    fontWeight = if (isSel) FontWeight.Bold else FontWeight.Medium,
                                    color = if (isSel) (if (aud == TargetAudience.MEN) Color.Black else Color.White) else MaterialTheme.colorScheme.onSurface
                                )
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(12.dp))

                Text(
                    text = "Prestations qui vous intéressent :",
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.height(6.dp))

                val interestOptions = when (preferredAudience ?: TargetAudience.MEN) {
                    TargetAudience.WOMEN -> listOf("Coupe & Brushing", "Lissage Kératine", "Manucure & Gel", "Pédicure Spa", "Soin Hydrafacial", "Maquillage")
                    TargetAudience.MEN -> listOf("Dégradé Américain", "Coupe Classique", "Taille Barbe", "Soin Vapeur", "Coupe Enfant")
                }

                LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    items(interestOptions) { item ->
                        val isSel = selectedInterests.contains(item)
                        val chipAccent = if (preferredAudience == TargetAudience.WOMEN) BeautyFuchsia else BarberGoldPrimary
                        FilterChip(
                            selected = isSel,
                            onClick = { onToggleInterest(item) },
                            label = { Text(item, fontSize = 11.sp) },
                            colors = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = chipAccent.copy(alpha = 0.22f),
                                selectedLabelColor = chipAccent
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
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.weight(1f)) {
                    Icon(Icons.Default.MyLocation, contentDescription = null, tint = BarberEmerald, modifier = Modifier.size(20.dp))
                    Spacer(modifier = Modifier.width(10.dp))
                    Column {
                        Text(
                            text = "Radar GPS « Autour de moi »",
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Text(
                            text = "Affiche les salons et barbiers les plus proches",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
                Switch(
                    checked = gpsRadarEnabled,
                    onCheckedChange = onGpsRadarToggle,
                    colors = SwitchDefaults.colors(checkedThumbColor = BarberEmerald, checkedTrackColor = BarberEmerald.copy(alpha = 0.3f))
                )
            }
        }
    }
}
