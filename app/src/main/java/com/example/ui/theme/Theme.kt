package com.example.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val DarkColorScheme = darkColorScheme(
    primary = BarberGoldPrimary,
    onPrimary = Color(0xFF1A1500),
    primaryContainer = Color(0xFF3A3008),
    onPrimaryContainer = BarberGoldVariant,
    secondary = BarberGoldVariant,
    onSecondary = Color(0xFF221C00),
    background = BarberDarkBg,
    onBackground = Color(0xFFF1F5F9),
    surface = BarberDarkSurface,
    onSurface = Color(0xFFF1F5F9),
    surfaceVariant = BarberDarkCard,
    onSurfaceVariant = Color(0xFFCBD5E1),
    outline = BarberDarkBorder,
    error = BarberRose,
    onError = Color.White
)

private val LightColorScheme = lightColorScheme(
    primary = BarberGoldText,
    onPrimary = Color.White,
    primaryContainer = Color(0xFFFEF9C3),
    onPrimaryContainer = Color(0xFF713F12),
    secondary = Color(0xFF475569),
    onSecondary = Color.White,
    background = BarberLightBg,
    onBackground = BarberTextDark,
    surface = BarberLightSurface,
    onSurface = BarberTextDark,
    surfaceVariant = BarberLightCard,
    onSurfaceVariant = BarberTextMuted,
    outline = BarberLightBorder,
    error = BarberRose,
    onError = Color.White
)

@Composable
fun LemqesTheme(
    darkTheme: Boolean = true, // Default to sleek barber dark mode
    content: @Composable () -> Unit
) {
    val colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
