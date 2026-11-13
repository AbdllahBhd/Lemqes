package com.example.ui.components

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.example.ui.theme.*
import kotlin.math.*

data class MapLandmark(
    val name: String,
    val latitude: Double,
    val longitude: Double
)

private val AlgiersMapLandmarks = listOf(
    MapLandmark("Hydra", 36.7456, 3.0421),
    MapLandmark("Sidi Yahia", 36.7410, 3.0390),
    MapLandmark("El Biar", 36.7660, 3.0310),
    MapLandmark("Alger Centre", 36.7685, 3.0588),
    MapLandmark("Kouba", 36.7270, 3.0840),
    MapLandmark("Dely Ibrahim", 36.7580, 2.9850),
    MapLandmark("Birkhadem", 36.7150, 3.0490),
    MapLandmark("Cheraga", 36.7650, 2.9580)
)

fun calculateHaversineKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
    val earthRadiusKm = 6371.0
    val dLat = Math.toRadians(lat2 - lat1)
    val dLon = Math.toRadians(lon2 - lon1)
    val a = sin(dLat / 2).pow(2) +
        cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) *
        sin(dLon / 2).pow(2)
    val c = 2 * atan2(sqrt(a), sqrt(1 - a))
    return (round((earthRadiusKm * c) * 10.0) / 10.0)
}

@SuppressLint("MissingPermission")
private fun readLastKnownLocation(context: Context): Pair<Double, Double>? {
    val manager = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return null
    val providers = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER, LocationManager.PASSIVE_PROVIDER)
    for (provider in providers) {
        val loc = runCatching { manager.getLastKnownLocation(provider) }.getOrNull()
        if (loc != null) {
            return loc.latitude to loc.longitude
        }
    }
    return null
}

@Composable
fun HomeMapLocationPicker(
    artistLatitude: Double,
    artistLongitude: Double,
    artistRadiusKm: Int,
    clientLatitude: Double,
    clientLongitude: Double,
    accentColor: Color,
    onLocationPicked: (lat: Double, lng: Double, suggestedZone: String?) -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    var gpsStatusMessage by remember { mutableStateOf<String?>(null) }
    var canvasSize by remember { mutableStateOf(IntSize(1, 1)) }

    // Map viewport bounds centered near artist / Algiers
    val centerLat = artistLatitude
    val centerLng = artistLongitude
    val latSpan = 0.085
    val lngSpan = 0.135

    fun offsetToLatLng(offset: Offset, size: IntSize): Pair<Double, Double> {
        val nx = (offset.x / size.width.coerceAtLeast(1)).coerceIn(0.05f, 0.95f)
        val ny = (offset.y / size.height.coerceAtLeast(1)).coerceIn(0.05f, 0.95f)
        val lat = (centerLat + latSpan / 2.0) - ny * latSpan
        val lng = (centerLng - lngSpan / 2.0) + nx * lngSpan
        return (round(lat * 10000.0) / 10000.0) to (round(lng * 10000.0) / 10000.0)
    }

    fun latLngToOffset(lat: Double, lng: Double, width: Float, height: Float): Offset {
        val nx = ((lng - (centerLng - lngSpan / 2.0)) / lngSpan).toFloat().coerceIn(0.05f, 0.95f)
        val ny = (((centerLat + latSpan / 2.0) - lat) / latSpan).toFloat().coerceIn(0.05f, 0.95f)
        return Offset(nx * width, ny * height)
    }

    val locationLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestMultiplePermissions()
    ) { grants ->
        val granted = grants[Manifest.permission.ACCESS_FINE_LOCATION] == true ||
            grants[Manifest.permission.ACCESS_COARSE_LOCATION] == true
        if (granted) {
            val coords = readLastKnownLocation(context)
            if (coords != null) {
                onLocationPicked(coords.first, coords.second, "Ma position GPS actuelle")
                gpsStatusMessage = "Position GPS détectée ✓"
            } else {
                onLocationPicked(36.7485, 3.0468, "Position GPS (Hydra Centre)")
                gpsStatusMessage = "Position GPS centrée à proximité • Ajustez sur la carte si besoin."
            }
        } else {
            gpsStatusMessage = "Autorisation GPS refusée • Touchez la carte ou choisissez un quartier."
        }
    }

    val distanceKm = remember(artistLatitude, artistLongitude, clientLatitude, clientLongitude) {
        calculateHaversineKm(artistLatitude, artistLongitude, clientLatitude, clientLongitude)
    }
    val isWithinRadius = distanceKm <= artistRadiusKm.toDouble()

    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "Localisation sur la carte *",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Text(
                    text = "Touchez ou glissez le marqueur jusqu'à votre domicile",
                    fontSize = 11.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            OutlinedButton(
                onClick = {
                    val hasFine = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
                    val hasCoarse = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
                    if (hasFine || hasCoarse) {
                        val coords = readLastKnownLocation(context)
                        if (coords != null) {
                            onLocationPicked(coords.first, coords.second, "Ma position GPS actuelle")
                            gpsStatusMessage = "Position GPS détectée ✓"
                        } else {
                            onLocationPicked(36.7485, 3.0468, "Position GPS (Hydra Centre)")
                            gpsStatusMessage = "Position GPS centrée • Ajustez le point sur la carte."
                        }
                    } else {
                        locationLauncher.launch(
                            arrayOf(
                                Manifest.permission.ACCESS_FINE_LOCATION,
                                Manifest.permission.ACCESS_COARSE_LOCATION
                            )
                        )
                    }
                },
                contentPadding = PaddingValues(horizontal = 10.dp, vertical = 6.dp),
                shape = RoundedCornerShape(10.dp),
                modifier = Modifier
                    .minimumInteractiveComponentSize()
                    .testTag("btn_use_gps_map")
            ) {
                Icon(Icons.Default.MyLocation, contentDescription = null, tint = BarberEmerald, modifier = Modifier.size(16.dp))
                Spacer(modifier = Modifier.width(4.dp))
                Text("Ma position", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = BarberEmerald)
            }
        }

        // Interactive Map Canvas
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(200.dp)
                .clip(RoundedCornerShape(16.dp))
                .border(1.5.dp, accentColor.copy(alpha = 0.5f), RoundedCornerShape(16.dp))
                .background(
                    Brush.linearGradient(
                        colors = listOf(
                            Color(0xFF0F172A),
                            Color(0xFF17253B),
                            Color(0xFF1E293B)
                        )
                    )
                )
                .onSizeChanged { canvasSize = it }
                .pointerInput(artistLatitude, artistLongitude) {
                    detectTapGestures { tapOffset ->
                        val (lat, lng) = offsetToLatLng(tapOffset, canvasSize)
                        onLocationPicked(lat, lng, null)
                    }
                }
                .pointerInput(artistLatitude, artistLongitude) {
                    detectDragGestures { change, _ ->
                        change.consume()
                        val (lat, lng) = offsetToLatLng(change.position, canvasSize)
                        onLocationPicked(lat, lng, null)
                    }
                }
                .testTag("home_map_canvas")
        ) {
            Canvas(modifier = Modifier.fillMaxSize()) {
                val w = size.width
                val h = size.height

                // Subtle map grid lines
                val gridStepX = w / 8f
                val gridStepY = h / 6f
                for (i in 1 until 8) {
                    drawLine(
                        color = Color.White.copy(alpha = 0.06f),
                        start = Offset(i * gridStepX, 0f),
                        end = Offset(i * gridStepX, h),
                        strokeWidth = 1f
                    )
                }
                for (j in 1 until 6) {
                    drawLine(
                        color = Color.White.copy(alpha = 0.06f),
                        start = Offset(0f, j * gridStepY),
                        end = Offset(w, j * gridStepY),
                        strokeWidth = 1f
                    )
                }

                // Stylized main avenues / boulevards
                drawLine(
                    color = Color(0xFF334155),
                    start = Offset(0f, h * 0.62f),
                    end = Offset(w, h * 0.34f),
                    strokeWidth = 6f
                )
                drawLine(
                    color = Color(0xFF334155),
                    start = Offset(w * 0.25f, 0f),
                    end = Offset(w * 0.68f, h),
                    strokeWidth = 5f
                )
                drawLine(
                    color = Color(0xFF475569).copy(alpha = 0.65f),
                    start = Offset(0f, h * 0.22f),
                    end = Offset(w, h * 0.78f),
                    strokeWidth = 3f
                )

                // Artist base point & service coverage radius
                val artistOffset = latLngToOffset(artistLatitude, artistLongitude, w, h)
                val radiusFraction = (artistRadiusKm.toFloat() / 18f).coerceIn(0.18f, 0.48f)
                val radiusPx = min(w, h) * radiusFraction

                drawCircle(
                    color = BarberEmerald.copy(alpha = 0.12f),
                    radius = radiusPx,
                    center = artistOffset
                )
                drawCircle(
                    color = BarberEmerald.copy(alpha = 0.55f),
                    radius = radiusPx,
                    center = artistOffset,
                    style = Stroke(
                        width = 2.5f,
                        pathEffect = PathEffect.dashPathEffect(floatArrayOf(12f, 8f), 0f)
                    )
                )

                // Neighborhood landmark dots
                AlgiersMapLandmarks.forEach { lm ->
                    val lmOffset = latLngToOffset(lm.latitude, lm.longitude, w, h)
                    drawCircle(
                        color = Color.White.copy(alpha = 0.35f),
                        radius = 4f,
                        center = lmOffset
                    )
                }

                // Line connecting Artist -> Client Home
                val clientOffset = latLngToOffset(clientLatitude, clientLongitude, w, h)
                drawLine(
                    color = accentColor.copy(alpha = 0.7f),
                    start = artistOffset,
                    end = clientOffset,
                    strokeWidth = 3f,
                    pathEffect = PathEffect.dashPathEffect(floatArrayOf(10f, 8f), 0f)
                )

                // Artist marker
                drawCircle(color = BarberEmerald, radius = 11f, center = artistOffset)
                drawCircle(color = Color.White, radius = 5f, center = artistOffset)

                // Client Home Pin
                drawCircle(color = accentColor.copy(alpha = 0.28f), radius = 26f, center = clientOffset)
                drawCircle(color = accentColor, radius = 14f, center = clientOffset)
                drawCircle(color = Color.White, radius = 6f, center = clientOffset)
            }

            // Legend overlays
            Surface(
                shape = RoundedCornerShape(8.dp),
                color = Color(0xCC0F172A),
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .padding(8.dp)
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(RoundedCornerShape(4.dp))
                            .background(accentColor)
                    )
                    Spacer(modifier = Modifier.width(5.dp))
                    Text(
                        text = "Votre domicile",
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(RoundedCornerShape(4.dp))
                            .background(BarberEmerald)
                    )
                    Spacer(modifier = Modifier.width(5.dp))
                    Text(
                        text = "Artiste",
                        fontSize = 10.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )
                }
            }

            Surface(
                shape = RoundedCornerShape(8.dp),
                color = Color(0xCC0F172A),
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .padding(8.dp)
            ) {
                Text(
                    text = "${String.format("%.4f", clientLatitude)}° N, ${String.format("%.4f", clientLongitude)}° E",
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Medium,
                    color = Color(0xFFE2E8F0),
                    modifier = Modifier
                        .padding(horizontal = 8.dp, vertical = 4.dp)
                        .testTag("map_coords_label")
                )
            }
        }

        // Distance & radius validation badge
        Surface(
            shape = RoundedCornerShape(10.dp),
            color = if (isWithinRadius) BarberEmerald.copy(alpha = 0.14f) else BarberAmber.copy(alpha = 0.16f),
            modifier = Modifier.fillMaxWidth()
        ) {
            Row(
                modifier = Modifier.padding(horizontal = 10.dp, vertical = 7.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = if (isWithinRadius) Icons.Default.CheckCircle else Icons.Default.WarningAmber,
                    contentDescription = null,
                    tint = if (isWithinRadius) BarberEmerald else BarberAmber,
                    modifier = Modifier.size(16.dp)
                )
                Spacer(modifier = Modifier.width(6.dp))
                Text(
                    text = if (isWithinRadius) {
                        "Distance estimée : $distanceKm km (dans le rayon de $artistRadiusKm km ✓)"
                    } else {
                        "Distance : $distanceKm km (au-delà du rayon habituel de $artistRadiusKm km — soumis à confirmation)"
                    },
                    fontSize = 11.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = if (isWithinRadius) BarberEmerald else BarberAmber,
                    modifier = Modifier.testTag("map_distance_label")
                )
            }
        }

        if (gpsStatusMessage != null) {
            Text(
                text = gpsStatusMessage!!,
                fontSize = 11.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        // Quick neighborhood jump pills
        LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            items(AlgiersMapLandmarks) { lm ->
                Surface(
                    shape = RoundedCornerShape(8.dp),
                    color = MaterialTheme.colorScheme.surfaceVariant,
                    modifier = Modifier
                        .border(0.5.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.5f), RoundedCornerShape(8.dp))
                        .clickable { onLocationPicked(lm.latitude, lm.longitude, lm.name) }
                ) {
                    Text(
                        text = "📍 ${lm.name}",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.onSurface,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 5.dp)
                    )
                }
            }
        }
    }
}
