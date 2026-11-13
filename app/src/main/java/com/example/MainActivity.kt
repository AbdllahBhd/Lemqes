package com.example

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.model.BarberStatus
import com.example.model.TargetAudience
import com.example.model.UserRole
import com.example.model.WorkplaceType
import com.example.notifications.LemqesNotificationHelper
import com.example.ui.components.*
import com.example.ui.screens.*
import com.example.ui.theme.BarberGoldPrimary
import com.example.ui.theme.LemqesTheme
import com.example.viewmodel.LemqesViewModel

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            val viewModel: LemqesViewModel = viewModel()
            val uiState by viewModel.uiState.collectAsStateWithLifecycle()
            val barberProfile by viewModel.barberProfile.collectAsStateWithLifecycle()
            val allBarbers by viewModel.allBarbers.collectAsStateWithLifecycle()
            val shops by viewModel.shops.collectAsStateWithLifecycle()
            val queue by viewModel.queue.collectAsStateWithLifecycle()
            val bookings by viewModel.bookings.collectAsStateWithLifecycle()
            val notifications by viewModel.notifications.collectAsStateWithLifecycle()
            val shopJoinRequests by viewModel.shopJoinRequests.collectAsStateWithLifecycle()
            val workTransactions by viewModel.workTransactions.collectAsStateWithLifecycle()
            val shopArrangement by viewModel.shopArrangement.collectAsStateWithLifecycle()
            val registeredAccounts by viewModel.registeredAccounts.collectAsStateWithLifecycle()
            val reviews by viewModel.reviews.collectAsStateWithLifecycle()
            val context = LocalContext.current

            val notificationPermissionLauncher = rememberLauncherForActivityResult(
                contract = ActivityResultContracts.RequestPermission(),
                onResult = { /* Handled gracefully whether granted or denied */ }
            )

            LaunchedEffect(uiState.isRegistered) {
                if (uiState.isRegistered && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    val granted = ContextCompat.checkSelfPermission(
                        context,
                        Manifest.permission.POST_NOTIFICATIONS
                    ) == PackageManager.PERMISSION_GRANTED
                    if (!granted) {
                        notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                    }
                }
            }

            LaunchedEffect(uiState.lastBookedAppointment) {
                val booked = uiState.lastBookedAppointment
                if (booked != null) {
                    LemqesNotificationHelper.scheduleBookingReminders(
                        context = context,
                        bookingId = booked.id,
                        barberName = booked.barberName,
                        shopName = booked.shopName.ifBlank { booked.locationSnapshot },
                        timeSlot = booked.timeSlot,
                        appointmentTimestampMillis = booked.appointmentTimestampMillis
                    )
                    LemqesNotificationHelper.showNotification(
                        context = context,
                        notificationId = booked.id.hashCode(),
                        title = "RDV confirmé avec ${booked.barberName}",
                        message = "Rendez-vous le ${booked.date} à ${booked.timeSlot}. Rappels à -1h et -30 min : arrivez 15 min avant au salon pour confirmer votre place."
                    )
                    viewModel.clearLastBookedAppointment()
                }
            }

            LaunchedEffect(uiState.pendingSystemNotifications) {
                val pending = uiState.pendingSystemNotifications
                if (pending.isNotEmpty()) {
                    pending.forEach { notif ->
                        LemqesNotificationHelper.showNotification(
                            context = context,
                            notificationId = notif.id.hashCode(),
                            title = notif.title,
                            message = notif.message
                        )
                    }
                    viewModel.clearPendingSystemNotifications()
                }
            }

            // RTL support for Arabic
            val layoutDirection = if (uiState.currentLanguage.isRtl) LayoutDirection.Rtl else LayoutDirection.Ltr

            CompositionLocalProvider(LocalLayoutDirection provides layoutDirection) {
                LemqesTheme(darkTheme = uiState.isDarkMode) {
                    if (!uiState.isRegistered) {
                        // Auth Portal: Login + Role-Specific Account Creation
                        AccountRegistrationScreen(
                            currentLanguage = uiState.currentLanguage,
                            onRegisterComplete = { account ->
                                viewModel.registerUser(account)
                            },
                            savedAccounts = registeredAccounts,
                            onLoginCredentials = { phone, pwd ->
                                viewModel.loginWithCredentials(phone, pwd)
                            },
                            onQuickLogin = { account ->
                                viewModel.quickLoginAccount(account)
                            },
                            onLangSelected = { viewModel.setLanguage(it) },
                            isDarkMode = uiState.isDarkMode,
                            onToggleDarkMode = { viewModel.toggleDarkMode() },
                            modifier = Modifier.statusBarsPadding().navigationBarsPadding()
                        )
                    } else {
                        // Main Application with Distinct Interfaces per Role
                        Scaffold(
                            modifier = Modifier.fillMaxSize(),
                            topBar = {
                                TopRoleAndLangBar(
                                    currentRole = uiState.currentRole,
                                    userAccount = uiState.currentUserAccount,
                                    onSwitchAccountClick = { viewModel.setShowSwitchAccountDialog(true) },
                                    onWalletClick = { viewModel.setShowWalletModal(true) },
                                    currentLang = uiState.currentLanguage,
                                    onLangSelected = { viewModel.setLanguage(it) },
                                    isDarkMode = uiState.isDarkMode,
                                    onToggleDarkMode = { viewModel.toggleDarkMode() },
                                    modifier = Modifier.statusBarsPadding()
                                )
                            },
                            bottomBar = {
                                NavigationBar(
                                    modifier = Modifier.navigationBarsPadding(),
                                    containerColor = MaterialTheme.colorScheme.surface,
                                    tonalElevation = 8.dp
                                ) {
                                    when (uiState.currentRole) {
                                        UserRole.BARBER, UserRole.HOME_ARTIST -> {
                                            NavigationBarItem(
                                                selected = uiState.activeTab == "home",
                                                onClick = { viewModel.setActiveTab("home") },
                                                icon = {
                                                    Icon(
                                                        if (uiState.currentRole == UserRole.HOME_ARTIST) Icons.Default.HomeRepairService else Icons.Default.Dashboard,
                                                        contentDescription = "Dashboard"
                                                    )
                                                },
                                                label = {
                                                    Text(
                                                        if (uiState.currentRole == UserRole.HOME_ARTIST) "Domicile" else "Mon Salon",
                                                        fontSize = 11.sp
                                                    )
                                                },
                                                colors = NavigationBarItemDefaults.colors(selectedIconColor = Color.Black, indicatorColor = BarberGoldPrimary)
                                            )
                                            NavigationBarItem(
                                                selected = uiState.activeTab == "finance",
                                                onClick = { viewModel.setActiveTab("finance") },
                                                icon = { Icon(Icons.Default.AccountBalanceWallet, contentDescription = "Finances") },
                                                label = { Text("Finances", fontSize = 11.sp) },
                                                colors = NavigationBarItemDefaults.colors(selectedIconColor = Color.Black, indicatorColor = BarberGoldPrimary)
                                            )
                                            NavigationBarItem(
                                                selected = uiState.activeTab == "explore",
                                                onClick = { viewModel.setActiveTab("explore") },
                                                icon = { Icon(Icons.Default.Explore, contentDescription = "Explore") },
                                                label = { Text("Découvrir", fontSize = 11.sp) },
                                                colors = NavigationBarItemDefaults.colors(selectedIconColor = Color.Black, indicatorColor = BarberGoldPrimary)
                                            )
                                            NavigationBarItem(
                                                selected = uiState.activeTab == "profile",
                                                onClick = {
                                                    viewModel.openBarberDetails(barberProfile)
                                                    viewModel.setActiveTab("profile")
                                                },
                                                icon = { Icon(Icons.Default.Person, contentDescription = "Profil") },
                                                label = { Text("Mon Profil", fontSize = 11.sp) },
                                                colors = NavigationBarItemDefaults.colors(selectedIconColor = Color.Black, indicatorColor = BarberGoldPrimary)
                                            )
                                        }
                                        UserRole.CUSTOMER -> {
                                            NavigationBarItem(
                                                selected = uiState.activeTab == "explore",
                                                onClick = { viewModel.setActiveTab("explore") },
                                                icon = { Icon(Icons.Default.Search, contentDescription = "Chercher") },
                                                label = { Text("Recherche", fontSize = 11.sp) },
                                                colors = NavigationBarItemDefaults.colors(selectedIconColor = Color.Black, indicatorColor = BarberGoldPrimary)
                                            )
                                            NavigationBarItem(
                                                selected = uiState.activeTab == "bookings",
                                                onClick = { viewModel.setActiveTab("bookings") },
                                                icon = { Icon(Icons.Default.Event, contentDescription = "Mes RDV") },
                                                label = { Text("Mes RDV (${bookings.size})", fontSize = 11.sp) },
                                                colors = NavigationBarItemDefaults.colors(selectedIconColor = Color.Black, indicatorColor = BarberGoldPrimary)
                                            )
                                        }
                                        UserRole.SHOP_OWNER -> {
                                            NavigationBarItem(
                                                selected = uiState.activeTab == "shops",
                                                onClick = { viewModel.setActiveTab("shops") },
                                                icon = { Icon(Icons.Default.Store, contentDescription = "Salon") },
                                                label = { Text("Mon Salon", fontSize = 11.sp) },
                                                colors = NavigationBarItemDefaults.colors(selectedIconColor = Color.Black, indicatorColor = BarberGoldPrimary)
                                            )
                                            NavigationBarItem(
                                                selected = uiState.activeTab == "finance",
                                                onClick = { viewModel.setActiveTab("finance") },
                                                icon = { Icon(Icons.Default.AccountBalanceWallet, contentDescription = "Finances") },
                                                label = { Text("Finances", fontSize = 11.sp) },
                                                colors = NavigationBarItemDefaults.colors(selectedIconColor = Color.Black, indicatorColor = BarberGoldPrimary)
                                            )
                                            NavigationBarItem(
                                                selected = uiState.activeTab == "explore",
                                                onClick = { viewModel.setActiveTab("explore") },
                                                icon = { Icon(Icons.Default.People, contentDescription = "Barbiers") },
                                                label = { Text("Coiffeurs", fontSize = 11.sp) },
                                                colors = NavigationBarItemDefaults.colors(selectedIconColor = Color.Black, indicatorColor = BarberGoldPrimary)
                                            )
                                        }
                                    }
                                }
                            },
                            snackbarHost = {
                                uiState.statusSuccessMessage?.let { msg ->
                                    Snackbar(
                                        modifier = Modifier.padding(16.dp),
                                        action = {
                                            TextButton(onClick = { viewModel.clearToast() }) {
                                                Text("OK", color = BarberGoldPrimary)
                                            }
                                        }
                                    ) {
                                        Text(msg)
                                    }
                                }
                            }
                        ) { innerPadding ->
                            Box(
                                modifier = Modifier
                                    .fillMaxSize()
                                    .padding(innerPadding)
                            ) {
                                if (uiState.selectedBarberForDetails != null) {
                                    BackHandler {
                                        viewModel.closeBarberDetails()
                                    }
                                    val detailBarber = uiState.selectedBarberForDetails!!
                                    val detailShop = shops.find {
                                        it.id == detailBarber.currentWorkplace.shopId ||
                                                it.name == detailBarber.currentWorkplace.shopName
                                    }
                                    BarberProfileDetailScreen(
                                        barber = detailBarber,
                                        shop = detailShop,
                                        reviews = reviews,
                                        onBack = { viewModel.closeBarberDetails() },
                                        onBookService = { srv ->
                                            if (detailBarber.currentWorkplace.type == WorkplaceType.FREELANCE_MOBILE) {
                                                viewModel.openHomeVisitBookingSheet(detailBarber, srv)
                                            } else {
                                                viewModel.openBookingSheet(srv, detailBarber)
                                            }
                                        },
                                        onJoinQueueRemotely = { srv ->
                                            viewModel.joinQueueRemotely(detailBarber, srv)
                                        },
                                        onToggleFollow = {
                                            viewModel.toggleFollow(detailBarber.id)
                                        },
                                        onShowQr = { viewModel.setShowQrModal(true) },
                                        onOpenFeedback = {
                                            viewModel.openFeedbackDialog(detailBarber, detailShop)
                                        },
                                        onBookHomeVisit = if (detailBarber.offersHomeService || detailBarber.currentWorkplace.type == WorkplaceType.FREELANCE_MOBILE) {
                                            { viewModel.openHomeVisitBookingSheet(detailBarber) }
                                        } else null
                                    )
                                } else {
                                    when (uiState.currentRole) {
                                        // 1. BARBER & HOME ARTIST INTERFACE
                                        UserRole.BARBER, UserRole.HOME_ARTIST -> {
                                            when (uiState.activeTab) {
                                                "home" -> {
                                                    BarberHomeScreen(
                                                        barber = barberProfile,
                                                        queue = queue,
                                                        bookings = bookings,
                                                        onStatusChange = { viewModel.setBarberStatus(it) },
                                                        onChangeWorkplaceClick = { viewModel.setShowWorkplaceDialog(true) },
                                                        onBroadcastClick = { viewModel.setShowBroadcastDialog(true) },
                                                        onShowQrClick = { viewModel.setShowQrModal(true) },
                                                        onAddWalkIn = { viewModel.addWalkIn() },
                                                        onCustomerDone = { viewModel.finishCustomer() },
                                                        onCallNext = { viewModel.callNext() },
                                                        onRemoveQueueItem = { viewModel.removeQueueItem(it) },
                                                        onOpenCashIn = { viewModel.openCashIn(it) },
                                                        onNavigateToFinances = { viewModel.setActiveTab("finance") },
                                                        onToggleShowCutPrices = { viewModel.toggleShowCutPrices(it) },
                                                        onOpenPromotionDialog = { viewModel.setShowPromotionDialog(true) },
                                                        onEndPromotion = { viewModel.endPromotion() },
                                                         onUpdateHomeServiceSettings = { offers, fee, radius, zones ->
                                                             viewModel.updateHomeServiceSettings(offers, fee, radius, zones)
                                                         },
                                                         onUpdateAvatar = { uri -> viewModel.updateBarberAvatar(uri) },
                                                         onTogglePresetService = { name -> viewModel.togglePresetBarberService(name) },
                                                         onAddCustomService = { name, price, duration ->
                                                             viewModel.addCustomBarberService(name, price, duration)
                                                         },
                                                         onRemoveService = { id -> viewModel.removeBarberService(id) },
                                                          notifications = notifications,
                                                          onConfirmHomeBooking = { bookingId -> viewModel.confirmHomeBooking(bookingId) },
                                                          onDeclineHomeBooking = { bookingId -> viewModel.declineHomeBooking(bookingId) },
                                                          onArtistOnTheWay = { bookingId, eta -> viewModel.notifyArtistOnTheWay(bookingId, eta) },
                                                          onArtistArrived = { bookingId -> viewModel.confirmArtistArrivedAtClient(bookingId) },
                                                          onCompleteHomeBooking = { bookingId -> viewModel.completeHomeBooking(bookingId) },
                                                          onToggleBlockedHomeSlot = { date, slot -> viewModel.toggleArtistBlockedSlot(date, slot) }
                                                     )
                                                }
                                                "finance" -> {
                                                    BarberFinanceScreen(
                                                        transactions = workTransactions,
                                                        shopArrangement = shopArrangement,
                                                        currentWorkplaceName = barberProfile.currentWorkplace.shopName,
                                                        onOpenCashIn = { viewModel.openCashIn() },
                                                        onOpenAddExpense = { viewModel.openAddExpense() },
                                                        onOpenArrangementSettings = { viewModel.setShowShopArrangementDialog(true) },
                                                        onDeleteTransaction = { viewModel.deleteTransaction(it) }
                                                    )
                                                }
                                                "explore" -> {
                                                    CustomerExploreScreen(
                                                        barbers = allBarbers,
                                                        shops = shops,
                                                        selectedWilaya = uiState.selectedWilayaFilter,
                                                        onSelectWilaya = { viewModel.setWilayaFilter(it) },
                                                        searchQuery = uiState.searchQuery,
                                                        onSearchChange = { viewModel.setSearchQuery(it) },
                                                        selectedAudience = uiState.filterAudience ?: uiState.currentUserAccount?.preferredAudience ?: TargetAudience.MEN,
                                                        onSelectAudience = { viewModel.setFilterAudience(it) },
                                                        onBarberClick = { viewModel.openBarberDetails(it) },
                                                        onBookBarber = { viewModel.openBarberDetails(it) },
                                                        onToggleFollow = { viewModel.toggleFollow(it) },
                                                        onRateShop = { shop ->
                                                            val leadBarber = allBarbers.firstOrNull { shop.barberIds.contains(it.id) }
                                                            viewModel.openFeedbackDialog(leadBarber, shop)
                                                        }
                                                    )
                                                }
                                                else -> {
                                                    val profileShop = shops.find {
                                                        it.id == barberProfile.currentWorkplace.shopId ||
                                                                it.name == barberProfile.currentWorkplace.shopName
                                                    }
                                                    BarberProfileDetailScreen(
                                                        barber = barberProfile,
                                                        shop = profileShop,
                                                        reviews = reviews,
                                                        onBack = { viewModel.setActiveTab("home") },
                                                        onBookService = { srv -> viewModel.openBookingSheet(srv, barberProfile) },
                                                        onJoinQueueRemotely = { srv -> viewModel.joinQueueRemotely(barberProfile, srv) },
                                                        onToggleFollow = { viewModel.toggleFollow(barberProfile.id) },
                                                        onShowQr = { viewModel.setShowQrModal(true) },
                                                        onOpenFeedback = {
                                                            viewModel.openFeedbackDialog(barberProfile, profileShop)
                                                        }
                                                    )
                                                }
                                            }
                                        }

                                        // 2. CUSTOMER INTERFACE
                                        UserRole.CUSTOMER -> {
                                            when (uiState.activeTab) {
                                                "bookings" -> {
                                                    CustomerBookingsAndNotificationsScreen(
                                                        bookings = bookings,
                                                        notifications = notifications,
                                                        onNotifyOnTheWay = { bookingId, eta ->
                                                            val n = viewModel.notifyOnTheWay(bookingId, eta)
                                                            if (n != null) {
                                                                LemqesNotificationHelper.showNotification(context, (bookingId + "_way").hashCode(), n.title, n.message)
                                                            }
                                                        },
                                                        onConfirmArrivalAtShop = { bookingId ->
                                                            val n = viewModel.confirmArrivalAtShop(bookingId)
                                                            LemqesNotificationHelper.cancelBookingReminders(context, bookingId)
                                                            if (n != null) {
                                                                LemqesNotificationHelper.showNotification(context, (bookingId + "_arr").hashCode(), n.title, n.message)
                                                            }
                                                        },
                                                        onCancelBooking = { bookingId ->
                                                            viewModel.cancelBooking(bookingId)
                                                            LemqesNotificationHelper.cancelBookingReminders(context, bookingId)
                                                        },
                                                        onTriggerReminder1h = { bookingId ->
                                                            val n = viewModel.triggerBookingReminder1h(bookingId)
                                                            if (n != null) {
                                                                LemqesNotificationHelper.showNotification(context, (bookingId + "_1h").hashCode(), n.title, n.message)
                                                            }
                                                        },
                                                        onTriggerReminder30m = { bookingId ->
                                                            val n = viewModel.triggerBookingReminder30m(bookingId)
                                                            if (n != null) {
                                                                LemqesNotificationHelper.showNotification(context, (bookingId + "_30m").hashCode(), n.title, n.message)
                                                            }
                                                        },
                                                        onEvaluate15mDeadline = { bookingId ->
                                                            val n = viewModel.evaluate15MinArrivalDeadline(bookingId)
                                                            if (n != null) {
                                                                LemqesNotificationHelper.showNotification(context, (bookingId + "_15m").hashCode(), n.title, n.message)
                                                            }
                                                        },
                                                        onOpenFeedbackForBooking = { booking ->
                                                            viewModel.openFeedbackForBooking(booking)
                                                        }
                                                    )
                                                }
                                                else -> {
                                                    CustomerExploreScreen(
                                                        barbers = allBarbers,
                                                        shops = shops,
                                                        selectedWilaya = uiState.selectedWilayaFilter,
                                                        onSelectWilaya = { viewModel.setWilayaFilter(it) },
                                                        searchQuery = uiState.searchQuery,
                                                        onSearchChange = { viewModel.setSearchQuery(it) },
                                                        selectedAudience = uiState.filterAudience ?: uiState.currentUserAccount?.preferredAudience ?: TargetAudience.MEN,
                                                        onSelectAudience = { viewModel.setFilterAudience(it) },
                                                        onBarberClick = { viewModel.openBarberDetails(it) },
                                                        onBookBarber = {
                                                            if (it.currentWorkplace.type == WorkplaceType.FREELANCE_MOBILE || it.offersHomeService) {
                                                                viewModel.openHomeVisitBookingSheet(it)
                                                            } else {
                                                                viewModel.openBarberDetails(it)
                                                            }
                                                        },
                                                        onToggleFollow = { viewModel.toggleFollow(it) },
                                                        onRateShop = { shop ->
                                                            val leadBarber = allBarbers.firstOrNull { shop.barberIds.contains(it.id) }
                                                            viewModel.openFeedbackDialog(leadBarber, shop)
                                                        }
                                                    )
                                                }
                                            }
                                        }

                                        // 3. SHOP OWNER INTERFACE
                                        UserRole.SHOP_OWNER -> {
                                            when (uiState.activeTab) {
                                                "finance" -> {
                                                    BarberFinanceScreen(
                                                        transactions = workTransactions,
                                                        shopArrangement = shopArrangement,
                                                        currentWorkplaceName = shops.firstOrNull()?.name ?: "Mon Salon",
                                                        onOpenCashIn = { viewModel.openCashIn() },
                                                        onOpenAddExpense = { viewModel.openAddExpense() },
                                                        onOpenArrangementSettings = { viewModel.setShowShopArrangementDialog(true) },
                                                        onDeleteTransaction = { viewModel.deleteTransaction(it) }
                                                    )
                                                }
                                                "explore" -> {
                                                    CustomerExploreScreen(
                                                        barbers = allBarbers,
                                                        shops = shops,
                                                        selectedWilaya = uiState.selectedWilayaFilter,
                                                        onSelectWilaya = { viewModel.setWilayaFilter(it) },
                                                        searchQuery = uiState.searchQuery,
                                                        onSearchChange = { viewModel.setSearchQuery(it) },
                                                        selectedAudience = uiState.filterAudience ?: uiState.currentUserAccount?.preferredAudience ?: TargetAudience.MEN,
                                                        onSelectAudience = { viewModel.setFilterAudience(it) },
                                                        onBarberClick = { viewModel.openBarberDetails(it) },
                                                        onBookBarber = {
                                                            if (it.currentWorkplace.type == WorkplaceType.FREELANCE_MOBILE || it.offersHomeService) {
                                                                viewModel.openHomeVisitBookingSheet(it)
                                                            } else {
                                                                viewModel.openBarberDetails(it)
                                                            }
                                                        },
                                                        onToggleFollow = { viewModel.toggleFollow(it) },
                                                        onRateShop = { shop ->
                                                            val leadBarber = allBarbers.firstOrNull { shop.barberIds.contains(it.id) }
                                                            viewModel.openFeedbackDialog(leadBarber, shop)
                                                        }
                                                    )
                                                }
                                                else -> {
                                                    ShopOwnerScreen(
                                                        shops = shops,
                                                        allBarbers = allBarbers,
                                                        joinRequests = shopJoinRequests,
                                                        onRespondToJoinRequest = { reqId, accept ->
                                                            viewModel.respondToShopJoinRequest(reqId, accept)
                                                        },
                                                        ownerBarberProfile = barberProfile,
                                                        ownerQueue = queue,
                                                        ownerBookings = bookings,
                                                        onOwnerStatusChange = { viewModel.setBarberStatus(it) },
                                                        onOwnerAddWalkIn = { viewModel.addWalkIn() },
                                                        onOwnerCustomerDone = { viewModel.finishCustomer() },
                                                        onOwnerCallNext = { viewModel.callNext() },
                                                        onOwnerRemoveQueueItem = { viewModel.removeQueueItem(it) },
                                                        onOpenCashIn = { viewModel.openCashIn(it) },
                                                        onShowQrClick = { viewModel.setShowQrModal(true) },
                                                        onChangeWorkplaceClick = { viewModel.setShowWorkplaceDialog(true) },
                                                        onBroadcastClick = { viewModel.setShowBroadcastDialog(true) },
                                                        onNavigateToFinances = { viewModel.setActiveTab("finance") },
                                                        onToggleShowCutPrices = { viewModel.toggleShowCutPrices(it) },
                                                        onOpenPromotionDialog = { viewModel.setShowPromotionDialog(true) },
                                                        onEndPromotion = { viewModel.endPromotion() },
                                                        onUpdateShopAvatar = { shopId, uri -> viewModel.updateShopAvatar(shopId, uri) },
                                                        onTogglePresetShopService = { shopId, name -> viewModel.togglePresetShopService(shopId, name) },
                                                        onAddCustomShopService = { shopId, name, price, duration ->
                                                            viewModel.addCustomShopService(shopId, name, price, duration)
                                                        },
                                                        onRemoveShopService = { shopId, id -> viewModel.removeShopService(shopId, id) },
                                                        onOwnerUpdateAvatar = { uri -> viewModel.updateBarberAvatar(uri) },
                                                        onOwnerTogglePresetService = { name -> viewModel.togglePresetBarberService(name) },
                                                        onOwnerAddCustomService = { name, price, duration ->
                                                            viewModel.addCustomBarberService(name, price, duration)
                                                        },
                                                        onOwnerRemoveService = { id -> viewModel.removeBarberService(id) }
                                                    )
                                                }
                                            }
                                        }
                                    }
                                }

                                // Modals and Bottom Sheets
                                if (uiState.showPromotionDialog) {
                                    PromotionDiscountDialog(
                                        barber = barberProfile,
                                        onDismiss = { viewModel.setShowPromotionDialog(false) },
                                        onLaunchPromotion = { promo ->
                                            viewModel.launchPromotion(promo)
                                        }
                                    )
                                }

                                if (uiState.showCashInDialog) {
                                    FastCashInBottomSheet(
                                        preFillCustomer = uiState.cashInPreFillCustomer,
                                        queue = queue,
                                        bookings = bookings,
                                        services = barberProfile.services,
                                        onDismiss = { viewModel.closeCashIn() },
                                        onConfirm = { name, srv, srvAmount, tipAmount, method, finishQueue ->
                                            viewModel.confirmIncome(
                                                customerName = name,
                                                serviceName = srv,
                                                serviceAmountDzd = srvAmount,
                                                tipAmountDzd = tipAmount,
                                                paymentMethod = method,
                                                finishQueueCustomer = finishQueue
                                            )
                                        }
                                    )
                                }

                                if (uiState.showExpenseDialog) {
                                    AddExpenseBottomSheet(
                                        onDismiss = { viewModel.closeAddExpense() },
                                        onConfirm = { cat, amount, note, method ->
                                            viewModel.confirmExpense(cat, amount, note, method)
                                        }
                                    )
                                }

                                if (uiState.showShopArrangementDialog) {
                                    ShopArrangementDialog(
                                        currentArrangement = shopArrangement,
                                        onDismiss = { viewModel.setShowShopArrangementDialog(false) },
                                        onSave = { arr ->
                                            viewModel.updateShopArrangement(arr)
                                            viewModel.setShowShopArrangementDialog(false)
                                        }
                                    )
                                }

                                // Modals and Bottom Sheets
                                if (uiState.showWorkplaceChangeDialog) {
                                    WorkplaceChangeBottomSheet(
                                        currentWorkplace = barberProfile.currentWorkplace,
                                        barberProfile = barberProfile,
                                        availableShops = shops,
                                        pendingJoinRequests = shopJoinRequests,
                                        onRequestJoinShop = { shop ->
                                            viewModel.requestJoinShop(barberProfile, shop)
                                        },
                                        onWorkplaceSelected = { viewModel.updateWorkplace(it) },
                                        onDismiss = { viewModel.setShowWorkplaceDialog(false) }
                                    )
                                }

                                if (uiState.showBroadcastDialog) {
                                    BroadcastNotificationDialog(
                                        subscribersCount = barberProfile.subscribersCount,
                                        onBroadcast = { viewModel.broadcast(it) },
                                        onDismiss = { viewModel.setShowBroadcastDialog(false) }
                                    )
                                }

                                if (uiState.showQrModal) {
                                    PermanentQrCodeModal(
                                        barber = uiState.selectedBarberForDetails ?: barberProfile,
                                        onDismiss = { viewModel.setShowQrModal(false) }
                                    )
                                }

                                if (uiState.showBookingSheet && uiState.selectedBarberForDetails != null && uiState.selectedServiceForBooking != null) {
                                    BookingBottomSheet(
                                        barber = uiState.selectedBarberForDetails!!,
                                        service = uiState.selectedServiceForBooking!!,
                                        onConfirmBooking = { date, slot, isHomeService, customerAddress ->
                                            viewModel.confirmBooking(date, slot, isHomeService, customerAddress)
                                        },
                                        onJoinQueueRemotely = {
                                            viewModel.joinQueueRemotely(
                                                uiState.selectedBarberForDetails!!,
                                                uiState.selectedServiceForBooking!!
                                            )
                                            viewModel.setShowBookingSheet(false)
                                        },
                                        onDismiss = { viewModel.setShowBookingSheet(false) },
                                        onOpenFullHomeVisitFlow = if (uiState.selectedBarberForDetails!!.offersHomeService || uiState.selectedBarberForDetails!!.currentWorkplace.type == WorkplaceType.FREELANCE_MOBILE) {
                                            {
                                                viewModel.openHomeVisitBookingSheet(
                                                    uiState.selectedBarberForDetails!!,
                                                    uiState.selectedServiceForBooking
                                                )
                                            }
                                        } else null
                                    )
                                }

                                if (uiState.showHomeVisitBookingSheet && uiState.homeBookingTargetBarber != null) {
                                    val targetBarber = uiState.homeBookingTargetBarber!!
                                    HomeServiceBookingSheet(
                                        barber = targetBarber,
                                        preselectedService = uiState.homeBookingPreselectedService,
                                        currentUser = uiState.currentUserAccount,
                                        getAvailableSlots = { date ->
                                            viewModel.getAvailableHomeSlots(targetBarber, date)
                                        },
                                        onSubmitHomeBooking = { services, date, slot, name, phone, address, lat, lng, notes, payment ->
                                            viewModel.submitHomeVisitRequest(
                                                barber = targetBarber,
                                                selectedServices = services,
                                                date = date,
                                                slot = slot,
                                                customerName = name,
                                                customerPhone = phone,
                                                customerAddress = address,
                                                clientLatitude = lat,
                                                clientLongitude = lng,
                                                customerNotes = notes,
                                                paymentMethod = payment
                                            )
                                        },
                                        onDismiss = { viewModel.closeHomeVisitBookingSheet() }
                                    )
                                }

                                if (uiState.showSwitchAccountDialog) {
                                    SwitchAccountRoleDialog(
                                        currentRole = uiState.currentRole,
                                        onRoleSelected = { viewModel.setRole(it) },
                                        onNewAccountClick = { viewModel.logoutOrSwitchRole() },
                                        onDismiss = { viewModel.setShowSwitchAccountDialog(false) }
                                    )
                                }

                                if (uiState.showWalletModal && uiState.currentUserAccount != null) {
                                    WalletBillingDialog(
                                        wallet = uiState.currentUserAccount!!.wallet,
                                        onTopUp = { amount -> viewModel.topUpCredits(amount) },
                                        onWatchAd = { viewModel.watchRewardAd() },
                                        onDismiss = { viewModel.setShowWalletModal(false) }
                                    )
                                }

                                if (uiState.showFeedbackDialog) {
                                    val targetBarber = uiState.feedbackTargetBarber
                                    val targetShop = uiState.feedbackTargetShop
                                    val isSubscribedCustomer = targetBarber?.isSubscribed
                                        ?: allBarbers.any { b ->
                                            b.isSubscribed && (targetShop == null || targetShop.barberIds.contains(b.id))
                                        }
                                    FeedbackReviewDialog(
                                        barber = targetBarber,
                                        shop = targetShop,
                                        isSubscribedCustomer = isSubscribedCustomer,
                                        onSubscribeNow = {
                                            val subId = targetBarber?.id ?: targetShop?.barberIds?.firstOrNull()
                                            if (subId != null) {
                                                viewModel.toggleFollow(subId)
                                            }
                                        },
                                        onSubmit = { bRate, sRate, comment, isAnon ->
                                            viewModel.submitFeedback(bRate, sRate, comment, isAnon)
                                        },
                                        onDismiss = { viewModel.closeFeedbackDialog() }
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
