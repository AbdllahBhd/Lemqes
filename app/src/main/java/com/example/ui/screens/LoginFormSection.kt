package com.example.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
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
import androidx.compose.ui.window.Dialog
import com.example.model.TargetAudience
import com.example.model.UserAccount
import com.example.model.UserRole
import com.example.ui.components.ProfileAvatarImage
import com.example.ui.theme.*

@Composable
fun LoginFormSection(
    savedAccounts: List<UserAccount>,
    onLoginSubmit: (phone: String, password: String) -> Boolean,
    onQuickLogin: (UserAccount) -> Unit,
    onSwitchToRegister: () -> Unit,
    modifier: Modifier = Modifier
) {
    var phoneInput by remember { mutableStateOf("") }
    var passwordInput by remember { mutableStateOf("") }
    var passwordVisible by remember { mutableStateOf(false) }
    var loginError by remember { mutableStateOf<String?>(null) }
    var showForgotDialog by remember { mutableStateOf(false) }

    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        // Main Login Card
        Card(
            shape = RoundedCornerShape(20.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
            modifier = Modifier
                .fillMaxWidth()
                .border(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.6f), RoundedCornerShape(20.dp))
        ) {
            Column(
                modifier = Modifier.padding(18.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(
                    text = "Bon retour sur LEMQES",
                    fontSize = 17.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Text(
                    text = "Connectez-vous avec votre numéro de téléphone pour retrouver votre salon, vos rendez-vous ou votre file en direct.",
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    lineHeight = 16.sp
                )

                // Phone Number Field
                OutlinedTextField(
                    value = phoneInput,
                    onValueChange = {
                        phoneInput = it
                        loginError = null
                    },
                    label = { Text("Numéro de téléphone") },
                    placeholder = { Text("ex. 0550 12 34 56") },
                    leadingIcon = {
                        Icon(Icons.Default.Phone, contentDescription = null, tint = BarberEmerald)
                    },
                    trailingIcon = {
                        if (phoneInput.isNotEmpty()) {
                            IconButton(onClick = { phoneInput = "" }) {
                                Icon(Icons.Default.Clear, contentDescription = "Effacer", modifier = Modifier.size(18.dp))
                            }
                        }
                    },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                    singleLine = true,
                    shape = RoundedCornerShape(14.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("login_input_phone")
                )

                // Password / PIN Field
                OutlinedTextField(
                    value = passwordInput,
                    onValueChange = {
                        passwordInput = it
                        loginError = null
                    },
                    label = { Text("Mot de passe ou Code PIN") },
                    placeholder = { Text("••••") },
                    leadingIcon = {
                        Icon(Icons.Default.Lock, contentDescription = null, tint = BarberGoldPrimary)
                    },
                    trailingIcon = {
                        IconButton(
                            onClick = { passwordVisible = !passwordVisible },
                            modifier = Modifier.minimumInteractiveComponentSize()
                        ) {
                            Icon(
                                imageVector = if (passwordVisible) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                                contentDescription = if (passwordVisible) "Masquer" else "Afficher",
                                modifier = Modifier.size(20.dp)
                            )
                        }
                    },
                    visualTransformation = if (passwordVisible) VisualTransformation.None else PasswordVisualTransformation(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                    singleLine = true,
                    shape = RoundedCornerShape(14.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("login_input_password")
                )

                // Forgot Password link
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End
                ) {
                    Text(
                        text = "Mot de passe oublié ?",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = BarberGoldPrimary,
                        modifier = Modifier
                            .clip(RoundedCornerShape(6.dp))
                            .clickable { showForgotDialog = true }
                            .padding(horizontal = 6.dp, vertical = 4.dp)
                    )
                }

                // Error Banner
                if (loginError != null) {
                    Surface(
                        shape = RoundedCornerShape(10.dp),
                        color = BarberRose.copy(alpha = 0.14f),
                        modifier = Modifier
                            .fillMaxWidth()
                            .border(1.dp, BarberRose.copy(alpha = 0.4f), RoundedCornerShape(10.dp))
                    ) {
                        Row(
                            modifier = Modifier.padding(10.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(Icons.Default.ErrorOutline, contentDescription = null, tint = BarberRose, modifier = Modifier.size(18.dp))
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = loginError!!,
                                color = BarberRose,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Medium
                            )
                        }
                    }
                }

                // Submit Login Button
                Button(
                    onClick = {
                        when {
                            phoneInput.isBlank() -> loginError = "Veuillez saisir votre numéro de téléphone."
                            passwordInput.isBlank() -> loginError = "Veuillez saisir votre mot de passe."
                            else -> {
                                val success = onLoginSubmit(phoneInput.trim(), passwordInput)
                                if (!success) {
                                    loginError = "Numéro ou mot de passe incorrect. (Astuce démo : mot de passe 1234 ou utilisez l'accès rapide ci-dessous)"
                                }
                            }
                        }
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(50.dp)
                        .testTag("submit_login_btn"),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = BarberGoldPrimary,
                        contentColor = Color.Black
                    ),
                    shape = RoundedCornerShape(14.dp)
                ) {
                    Text(
                        text = "Se connecter",
                        fontWeight = FontWeight.Bold,
                        fontSize = 15.sp
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Icon(Icons.AutoMirrored.Filled.ArrowForward, contentDescription = null, modifier = Modifier.size(18.dp))
                }
            }
        }

        // Quick Demo Accounts Section (1-tap access per persona)
        if (savedAccounts.isNotEmpty()) {
            Card(
                shape = RoundedCornerShape(18.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.7f)),
                modifier = Modifier
                    .fillMaxWidth()
                    .border(0.5.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(18.dp))
            ) {
                Column(
                    modifier = Modifier.padding(14.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.Bolt, contentDescription = null, tint = BarberGoldPrimary, modifier = Modifier.size(18.dp))
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = "Accès rapide (Comptes enregistrés)",
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                    }
                    Text(
                        text = "Touchez un profil pour vous connecter instantanément :",
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    savedAccounts.forEach { acc ->
                        val isWomen = acc.targetAudience == TargetAudience.WOMEN || acc.preferredAudience == TargetAudience.WOMEN
                        val (accentColor, roleIcon, roleLabel) = when (acc.role) {
                            UserRole.BARBER -> Triple(
                                if (isWomen) BeautyFuchsia else BarberEmerald,
                                if (isWomen) Icons.Default.Spa else Icons.Default.ContentCut,
                                if (isWomen) "Coiffeuse / Esthéticienne Dames" else "Barbier Indépendant"
                            )
                            UserRole.HOME_ARTIST -> Triple(
                                if (isWomen) BeautyFuchsia else BarberGoldPrimary,
                                Icons.Default.HomeRepairService,
                                if (isWomen) "Beauté à Domicile (Dames)" else "Barbier à Domicile (Hommes)"
                            )
                            UserRole.SHOP_OWNER -> Triple(
                                if (isWomen) BeautyFuchsia else BarberBlue,
                                Icons.Default.Storefront,
                                if (isWomen) "Gérante Institut Dames" else "Propriétaire de Salon"
                            )
                            UserRole.CUSTOMER -> Triple(
                                BarberGoldPrimary,
                                Icons.Default.Person,
                                "Client / Cliente"
                            )
                        }

                        Surface(
                            shape = RoundedCornerShape(12.dp),
                            color = MaterialTheme.colorScheme.surface,
                            modifier = Modifier
                                .fillMaxWidth()
                                .border(0.5.dp, accentColor.copy(alpha = 0.45f), RoundedCornerShape(12.dp))
                                .clickable { onQuickLogin(acc) }
                                .testTag("quick_login_${acc.id}")
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                ProfileAvatarImage(
                                    avatarUrl = acc.avatarUrl,
                                    fallbackIcon = roleIcon,
                                    contentDescription = acc.fullName,
                                    accentColor = accentColor,
                                    size = 38.dp
                                )
                                Spacer(modifier = Modifier.width(10.dp))
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        text = acc.fullName,
                                        fontSize = 13.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = MaterialTheme.colorScheme.onSurface
                                    )
                                    Text(
                                        text = "$roleLabel • ${acc.phoneNumber}",
                                        fontSize = 11.sp,
                                        color = accentColor
                                    )
                                }
                                Icon(
                                    imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                                    contentDescription = "Connexion",
                                    tint = accentColor,
                                    modifier = Modifier.size(18.dp)
                                )
                            }
                        }
                    }
                }
            }
        }

        // Bottom switch to Create Account
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 4.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "Nouveau sur LEMQES ?",
                fontSize = 13.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Spacer(modifier = Modifier.width(6.dp))
            Text(
                text = "Créer un compte gratuitement",
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                color = BarberGoldPrimary,
                modifier = Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .clickable { onSwitchToRegister() }
                    .padding(horizontal = 6.dp, vertical = 4.dp)
            )
        }
    }

    if (showForgotDialog) {
        var recoveryPhone by remember { mutableStateOf(phoneInput) }
        var sentSuccess by remember { mutableStateOf(false) }
        Dialog(onDismissRequest = { showForgotDialog = false }) {
            Card(
                shape = RoundedCornerShape(20.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(
                    modifier = Modifier.padding(20.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Text(
                        text = "Réinitialiser le mot de passe",
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    if (!sentSuccess) {
                        Text(
                            text = "Entrez votre numéro de téléphone pour recevoir un code de réinitialisation par SMS.",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        OutlinedTextField(
                            value = recoveryPhone,
                            onValueChange = { recoveryPhone = it },
                            label = { Text("Téléphone") },
                            placeholder = { Text("0550 12 34 56") },
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                            singleLine = true,
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier.fillMaxWidth()
                        )
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.End
                        ) {
                            TextButton(onClick = { showForgotDialog = false }) {
                                Text("Annuler")
                            }
                            Spacer(modifier = Modifier.width(8.dp))
                            Button(
                                onClick = { if (recoveryPhone.isNotBlank()) sentSuccess = true },
                                colors = ButtonDefaults.buttonColors(containerColor = BarberGoldPrimary, contentColor = Color.Black),
                                shape = RoundedCornerShape(10.dp)
                            ) {
                                Text("Envoyer SMS", fontWeight = FontWeight.Bold)
                            }
                        }
                    } else {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.CheckCircle, contentDescription = null, tint = BarberEmerald)
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "Code envoyé au $recoveryPhone ! (Code démo : 1234)",
                                fontSize = 13.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = BarberEmerald
                            )
                        }
                        Button(
                            onClick = { showForgotDialog = false },
                            modifier = Modifier.fillMaxWidth(),
                            colors = ButtonDefaults.buttonColors(containerColor = BarberGoldPrimary, contentColor = Color.Black),
                            shape = RoundedCornerShape(10.dp)
                        ) {
                            Text("Compris", fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
        }
    }
}
