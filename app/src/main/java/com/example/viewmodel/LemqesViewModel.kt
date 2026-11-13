package com.example.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.data.MockRepository
import com.example.i18n.SupportedLanguage
import com.example.model.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class MainUiState(
    val currentRole: UserRole = UserRole.BARBER,
    val isRegistered: Boolean = false,
    val currentUserAccount: UserAccount? = null,
    val currentLanguage: SupportedLanguage = SupportedLanguage.FR,
    val isDarkMode: Boolean = true,
    val selectedWilayaFilter: String = "16 - Alger",
    val searchQuery: String = "",
    val filterAudience: TargetAudience? = TargetAudience.MEN, // Strictly TargetAudience.MEN or TargetAudience.WOMEN (never mixed)
    val filterServiceCategory: ServiceCategory? = null,
    val activeTab: String = "home", // "home", "queue", "workplace", "profile", "explore", "shops"
    val showWorkplaceChangeDialog: Boolean = false,
    val showBroadcastDialog: Boolean = false,
    val showQrModal: Boolean = false,
    val showBookingSheet: Boolean = false,
    val showSwitchAccountDialog: Boolean = false,
    val showWalletModal: Boolean = false,
    val showCashInDialog: Boolean = false,
    val cashInPreFillCustomer: QueueCustomer? = null,
    val showExpenseDialog: Boolean = false,
    val showShopArrangementDialog: Boolean = false,
    val showPromotionDialog: Boolean = false,
    val shopOwnerActiveView: String = "MANAGEMENT", // "MANAGEMENT" (Shop dashboard) or "CHAIR" (Owner's Barber Chair)
    val selectedBarberForDetails: BarberProfile? = null,
    val selectedServiceForBooking: ServiceItem? = null,
    val showFeedbackDialog: Boolean = false,
    val feedbackTargetBarber: BarberProfile? = null,
    val feedbackTargetShop: Shop? = null,
    val lastBookedAppointment: BookingRecord? = null,
    val showHomeVisitBookingSheet: Boolean = false,
    val homeBookingTargetBarber: BarberProfile? = null,
    val homeBookingPreselectedService: ServiceItem? = null,
    val pendingSystemNotifications: List<AppNotification> = emptyList(),
    val statusSuccessMessage: String? = null
)

class LemqesViewModel(
    private val repository: MockRepository = MockRepository()
) : ViewModel() {

    private val _uiState = MutableStateFlow(MainUiState())
    val uiState: StateFlow<MainUiState> = _uiState.asStateFlow()

    val barberProfile = repository.barberProfile
    val allBarbers = repository.allBarbers
    val shops = repository.shops
    val queue = repository.queue
    val bookings = repository.bookings
    val notifications = repository.notifications
    val shopJoinRequests = repository.shopJoinRequests
    val workTransactions = repository.workTransactions
    val shopArrangement = repository.shopArrangement
    val registeredAccounts = repository.registeredAccounts
    val reviews = repository.reviews

    fun setShowPromotionDialog(show: Boolean) {
        _uiState.update { it.copy(showPromotionDialog = show) }
    }

    fun toggleShowCutPrices(show: Boolean) {
        repository.toggleShowCutPrices(show)
        showToast(if (show) "Les prix de vos coupes sont visibles aux clients" else "Les prix sont masqués aux clients")
    }

    fun launchPromotion(promotion: BarberPromotion) {
        repository.launchPromotion(promotion)
        _uiState.update { it.copy(showPromotionDialog = false) }
        showToast("🏷️ Promotion lancée ! Vos abonnés ont reçu une notification.")
    }

    fun endPromotion() {
        repository.endPromotion()
        showToast("Promotion clôturée.")
    }

    fun setShopOwnerActiveView(view: String) {
        _uiState.update { it.copy(shopOwnerActiveView = view) }
    }

    fun openCashIn(customer: QueueCustomer? = null) {
        _uiState.update { it.copy(showCashInDialog = true, cashInPreFillCustomer = customer) }
    }

    fun closeCashIn() {
        _uiState.update { it.copy(showCashInDialog = false, cashInPreFillCustomer = null) }
    }

    fun confirmIncome(
        customerName: String?,
        serviceName: String,
        serviceAmountDzd: Int,
        tipAmountDzd: Int,
        paymentMethod: PaymentMethod = PaymentMethod.CASH,
        linkedBookingId: String? = null,
        linkedQueueTicket: Int? = null,
        finishQueueCustomer: Boolean = false
    ) {
        repository.addIncomeTransaction(
            customerName = customerName,
            serviceName = serviceName,
            serviceAmountDzd = serviceAmountDzd,
            tipAmountDzd = tipAmountDzd,
            paymentMethod = paymentMethod,
            linkedBookingId = linkedBookingId,
            linkedQueueTicket = linkedQueueTicket
        )
        if (finishQueueCustomer) {
            repository.finishCurrentCustomer()
        }
        _uiState.update { it.copy(showCashInDialog = false, cashInPreFillCustomer = null) }
        showToast("Encaissement enregistré : ${serviceAmountDzd + tipAmountDzd} DA (dont $tipAmountDzd DA pourboire)")
    }

    fun openAddExpense() {
        _uiState.update { it.copy(showExpenseDialog = true) }
    }

    fun closeAddExpense() {
        _uiState.update { it.copy(showExpenseDialog = false) }
    }

    fun confirmExpense(
        category: ExpenseCategory,
        amountDzd: Int,
        note: String,
        paymentMethod: PaymentMethod = PaymentMethod.CASH
    ) {
        repository.addExpenseTransaction(
            category = category,
            amountDzd = amountDzd,
            note = note,
            paymentMethod = paymentMethod
        )
        _uiState.update { it.copy(showExpenseDialog = false) }
        showToast("Dépense enregistrée : −$amountDzd DA ($note)")
    }

    fun deleteTransaction(id: String) {
        repository.deleteTransaction(id)
        showToast("Ligne supprimée.")
    }

    fun updateShopArrangement(arrangement: ShopArrangement) {
        repository.updateShopArrangement(arrangement)
        val text = when (arrangement.type) {
            ShopArrangementType.PERCENTAGE -> "Commission fixée à ${arrangement.percentageRate.toInt()}% des services"
            ShopArrangementType.FLAT_MONTHLY -> "Loyer fixe fixé à ${arrangement.flatMonthlyRentDzd} DA / mois"
            ShopArrangementType.NO_COMMISSION -> "Arrangement fixé à Sans commission"
        }
        showToast("Arrangement salon mis à jour : $text")
    }

    fun setShowShopArrangementDialog(show: Boolean) {
        _uiState.update { it.copy(showShopArrangementDialog = show) }
    }

    fun requestJoinShop(barber: BarberProfile, shop: Shop) {
        repository.requestJoinShop(barber, shop)
        showToast("Demande envoyée au salon ${shop.name} !")
    }

    fun respondToShopJoinRequest(requestId: String, accept: Boolean) {
        repository.respondToShopJoinRequest(requestId, accept)
        if (accept) {
            showToast("Demande acceptée ! Le barbier a rejoint le salon.")
        } else {
            showToast("Demande refusée.")
        }
    }

    fun setRole(role: UserRole) {
        val nextTab = when (role) {
            UserRole.BARBER, UserRole.HOME_ARTIST -> "home"
            UserRole.CUSTOMER -> "explore"
            UserRole.SHOP_OWNER -> "shops"
        }
        _uiState.update { it.copy(currentRole = role, activeTab = nextTab) }
    }

    fun registerUser(account: UserAccount) {
        repository.registerNewAccount(account)
        _uiState.update {
            it.copy(
                currentUserAccount = account,
                currentRole = account.role,
                isRegistered = true,
                filterAudience = if (account.role == UserRole.CUSTOMER) (account.preferredAudience ?: TargetAudience.MEN) else account.targetAudience,
                activeTab = when (account.role) {
                    UserRole.BARBER, UserRole.HOME_ARTIST -> "home"
                    UserRole.CUSTOMER -> "explore"
                    UserRole.SHOP_OWNER -> "shops"
                }
            )
        }
        showToast("Compte créé avec succès ! Bienvenue ${account.fullName}")
    }

    fun loginWithCredentials(phone: String, password: String): Boolean {
        val matched = repository.authenticateUser(phone, password)
        if (matched != null) {
            _uiState.update {
                it.copy(
                    currentUserAccount = matched,
                    currentRole = matched.role,
                    isRegistered = true,
                    filterAudience = if (matched.role == UserRole.CUSTOMER) (matched.preferredAudience ?: TargetAudience.MEN) else matched.targetAudience,
                    activeTab = when (matched.role) {
                        UserRole.BARBER, UserRole.HOME_ARTIST -> "home"
                        UserRole.CUSTOMER -> "explore"
                        UserRole.SHOP_OWNER -> "shops"
                    }
                )
            }
            showToast("Connexion réussie ! Bon retour ${matched.fullName}")
            return true
        }
        return false
    }

    fun quickLoginAccount(account: UserAccount) {
        repository.applyAccountToWorkspace(account)
        _uiState.update {
            it.copy(
                currentUserAccount = account,
                currentRole = account.role,
                isRegistered = true,
                filterAudience = if (account.role == UserRole.CUSTOMER) (account.preferredAudience ?: TargetAudience.MEN) else account.targetAudience,
                activeTab = when (account.role) {
                    UserRole.BARBER, UserRole.HOME_ARTIST -> "home"
                    UserRole.CUSTOMER -> "explore"
                    UserRole.SHOP_OWNER -> "shops"
                }
            )
        }
        showToast("Connecté en tant que ${account.fullName}")
    }

    fun logoutOrSwitchRole() {
        _uiState.update { it.copy(isRegistered = false) }
    }

    fun setShowSwitchAccountDialog(show: Boolean) {
        _uiState.update { it.copy(showSwitchAccountDialog = show) }
    }

    fun setShowWalletModal(show: Boolean) {
        _uiState.update { it.copy(showWalletModal = show) }
    }

    fun topUpCredits(amountUsd: Double) {
        val currentAccount = _uiState.value.currentUserAccount ?: return
        val currentWallet = currentAccount.wallet
        val newBalance = currentWallet.balanceUsd + amountUsd
        val newMonths = (newBalance / currentWallet.monthlyRateUsd).toInt()
        val dailyCost = currentWallet.monthlyRateUsd / 30.0
        val newDays = (newBalance / dailyCost).toInt()
        val updatedWallet = currentWallet.copy(
            balanceUsd = newBalance,
            monthsRemaining = newMonths,
            daysCoveredRemaining = newDays
        )
        _uiState.update {
            it.copy(
                currentUserAccount = currentAccount.copy(wallet = updatedWallet)
            )
        }
        showToast("Recharge réussie ! +$amountUsd $ ajoutés (~$newDays jours couverts).")
    }

    fun watchRewardAd() {
        val currentAccount = _uiState.value.currentUserAccount ?: return
        val currentWallet = currentAccount.wallet
        if (currentWallet.rewardedAdsWatchedToday >= currentWallet.maxDailyAds) {
            showToast("Limite du jour atteinte (3/3 vidéos complétées aujourd'hui).")
            return
        }
        val perAdReward = currentWallet.perAdRewardUsd
        val newBalance = currentWallet.balanceUsd + perAdReward
        val newMonths = (newBalance / currentWallet.monthlyRateUsd).toInt().coerceAtLeast(1)
        val dailyCost = currentWallet.monthlyRateUsd / 30.0
        val newDays = (newBalance / dailyCost).toInt()
        val newAdsWatched = currentWallet.rewardedAdsWatchedToday + 1
        val newDaysWatchedThisMonth = if (newAdsWatched == 3) {
            (currentWallet.daysWatchedThisMonth + 1).coerceAtMost(25)
        } else {
            currentWallet.daysWatchedThisMonth
        }

        val updatedWallet = currentWallet.copy(
            balanceUsd = newBalance,
            monthsRemaining = newMonths,
            daysCoveredRemaining = newDays,
            daysWatchedThisMonth = newDaysWatchedThisMonth,
            rewardedAdsWatchedToday = newAdsWatched
        )
        _uiState.update {
            it.copy(
                currentUserAccount = currentAccount.copy(wallet = updatedWallet)
            )
        }
        val daysStillNeeded = updatedWallet.daysRemainingToCoverMonth
        val progressText = if (newAdsWatched == 3) {
            "Objectif du jour atteint (+${String.format("%.2f", currentWallet.dailyAdGoalUsd)} $) ! Encore $daysStillNeeded jours pour couvrir le mois gratuit."
        } else {
            "$newAdsWatched/3 vidéos complétées"
        }
        showToast("Vidéo terminée ! +${String.format("%.2f", perAdReward)} $ crédités ($progressText)")
    }

    fun setLanguage(language: SupportedLanguage) {
        _uiState.update { it.copy(currentLanguage = language) }
    }

    fun toggleDarkMode() {
        _uiState.update { it.copy(isDarkMode = !it.isDarkMode) }
    }

    fun setActiveTab(tab: String) {
        _uiState.update { it.copy(activeTab = tab) }
    }

    fun setWilayaFilter(wilaya: String) {
        _uiState.update { it.copy(selectedWilayaFilter = wilaya) }
    }

    fun setSearchQuery(query: String) {
        _uiState.update { it.copy(searchQuery = query) }
    }

    fun setFilterAudience(audience: TargetAudience?) {
        _uiState.update { it.copy(filterAudience = audience) }
    }

    fun setFilterServiceCategory(category: ServiceCategory?) {
        _uiState.update { it.copy(filterServiceCategory = category) }
    }

    fun updateCustomerPreference(audience: TargetAudience?) {
        val current = _uiState.value.currentUserAccount ?: return
        val updated = current.copy(preferredAudience = audience)
        _uiState.update { it.copy(currentUserAccount = updated, filterAudience = audience) }
        showToast("Préférence enregistrée : ${audience?.labelFr ?: "Tous les salons"}")
    }

    // Barber fast actions
    fun setBarberStatus(status: BarberStatus, note: String = "") {
        repository.updateBarberStatus(status, note)
        showToast("Statut mis à jour : ${status.name}")
    }

    fun addWalkIn() {
        repository.addWalkInToQueue()
        showToast("+1 Client sans rdv ajouté au ticket")
    }

    fun finishCustomer() {
        repository.finishCurrentCustomer()
        showToast("Client terminé (-1 dans la file)")
    }

    fun callNext() {
        repository.callNextCustomer()
        showToast("Notification envoyée au client suivant")
    }

    fun removeQueueItem(id: String) {
        repository.removeQueueCustomer(id)
    }

    fun updateWorkplace(workplace: BarberWorkplace) {
        repository.updateWorkplace(workplace, notifyFollowers = true)
        _uiState.update { it.copy(showWorkplaceChangeDialog = false) }
        showToast("Lieu de travail mis à jour et abonnés notifiés !")
    }

    fun broadcast(message: String) {
        if (message.isNotBlank()) {
            repository.broadcastToFollowers(message)
            _uiState.update { it.copy(showBroadcastDialog = false) }
            showToast("Notification diffusée à tous les abonnés")
        }
    }

    fun toggleFollow(barberId: String) {
        repository.toggleSubscription(barberId)
        val updatedBarber = repository.allBarbers.value.find { it.id == barberId }
        if (updatedBarber != null) {
            _uiState.update { state ->
                state.copy(
                    selectedBarberForDetails = if (state.selectedBarberForDetails?.id == barberId) updatedBarber else state.selectedBarberForDetails,
                    feedbackTargetBarber = if (state.feedbackTargetBarber?.id == barberId) updatedBarber else state.feedbackTargetBarber
                )
            }
        }
    }

    fun openBarberDetails(barber: BarberProfile) {
        _uiState.update { it.copy(selectedBarberForDetails = barber) }
    }

    fun closeBarberDetails() {
        _uiState.update { it.copy(selectedBarberForDetails = null) }
    }

    fun openBookingSheet(service: ServiceItem, barber: BarberProfile) {
        _uiState.update {
            it.copy(
                selectedServiceForBooking = service,
                selectedBarberForDetails = barber,
                showBookingSheet = true
            )
        }
    }

    fun updateHomeServiceSettings(
        offersHomeService: Boolean,
        feeDzd: Int,
        radiusKm: Int,
        zones: String
    ) {
        repository.updateHomeServiceSettings(offersHomeService, feeDzd, radiusKm, zones)
        showToast("Paramètres À Domicile mis à jour (Rayon $radiusKm km • Dépl. $feeDzd DA)")
    }

    fun updateBarberAvatar(avatarUri: String) {
        repository.updateBarberAvatar(avatarUri)
        _uiState.update { state ->
            state.copy(
                currentUserAccount = state.currentUserAccount?.copy(avatarUrl = avatarUri),
                selectedBarberForDetails = if (state.selectedBarberForDetails?.id == repository.barberProfile.value.id) {
                    repository.barberProfile.value
                } else state.selectedBarberForDetails
            )
        }
        showToast(if (avatarUri.isNotBlank()) "📸 Photo de profil mise à jour !" else "Photo de profil supprimée.")
    }

    fun togglePresetBarberService(serviceName: String) {
        repository.togglePresetBarberService(serviceName)
        _uiState.update { state ->
            state.copy(
                selectedBarberForDetails = if (state.selectedBarberForDetails?.id == repository.barberProfile.value.id) {
                    repository.barberProfile.value
                } else state.selectedBarberForDetails
            )
        }
    }

    fun addCustomBarberService(serviceName: String, priceDzd: Int, durationMinutes: Int) {
        if (serviceName.isBlank()) return
        repository.addCustomBarberService(serviceName, priceDzd, durationMinutes)
        _uiState.update { state ->
            state.copy(
                selectedBarberForDetails = if (state.selectedBarberForDetails?.id == repository.barberProfile.value.id) {
                    repository.barberProfile.value
                } else state.selectedBarberForDetails
            )
        }
        showToast("✅ Service « ${serviceName.trim()} » ajouté (${priceDzd} DA)")
    }

    fun removeBarberService(serviceId: String) {
        repository.removeBarberService(serviceId)
        _uiState.update { state ->
            state.copy(
                selectedBarberForDetails = if (state.selectedBarberForDetails?.id == repository.barberProfile.value.id) {
                    repository.barberProfile.value
                } else state.selectedBarberForDetails
            )
        }
        showToast("Service retiré de votre carte.")
    }

    fun updateShopAvatar(shopId: String, avatarUri: String) {
        repository.updateShopAvatar(shopId, avatarUri)
        _uiState.update { state ->
            state.copy(currentUserAccount = state.currentUserAccount?.copy(avatarUrl = avatarUri))
        }
        showToast(if (avatarUri.isNotBlank()) "📸 Photo du salon mise à jour !" else "Photo du salon supprimée.")
    }

    fun togglePresetShopService(shopId: String, serviceName: String) {
        repository.togglePresetShopService(shopId, serviceName)
    }

    fun addCustomShopService(shopId: String, serviceName: String, priceDzd: Int, durationMinutes: Int) {
        if (serviceName.isBlank()) return
        repository.addCustomShopService(shopId, serviceName, priceDzd, durationMinutes)
        showToast("✅ Service salon « ${serviceName.trim()} » ajouté (${priceDzd} DA)")
    }

    fun removeShopService(shopId: String, serviceId: String) {
        repository.removeShopService(shopId, serviceId)
        showToast("Service retiré du salon.")
    }

    fun confirmBooking(
        date: String,
        timeSlot: String,
        isHomeService: Boolean = false,
        customerAddress: String? = null
    ) {
        val service = _uiState.value.selectedServiceForBooking
        val barber = _uiState.value.selectedBarberForDetails
        if (service != null && barber != null) {
            val customerName = _uiState.value.currentUserAccount?.fullName ?: "Moi (Client connecté)"
            val travelFee = if (isHomeService || barber.currentWorkplace.type == WorkplaceType.FREELANCE_MOBILE) {
                barber.homeServiceFeeDzd
            } else 0
            val created = repository.bookAppointment(
                service = service,
                date = date,
                slot = timeSlot,
                barber = barber,
                customerName = customerName,
                isHomeService = isHomeService,
                customerAddress = customerAddress,
                travelFeeDzd = travelFee
            )
            _uiState.update {
                it.copy(
                    showBookingSheet = false,
                    selectedServiceForBooking = null,
                    lastBookedAppointment = created
                )
            }
            showToast(
                if (created.isHomeService) {
                    "🏠 RDV à domicile réservé ! Rappels -1h et -30m activés."
                } else {
                    "RDV réservé ! Rappels à -1h et -30 min. Arrivée requise 15 min avant."
                }
            )
        }
    }

    fun clearLastBookedAppointment() {
        _uiState.update { it.copy(lastBookedAppointment = null) }
    }

    fun clearPendingSystemNotifications() {
        _uiState.update { it.copy(pendingSystemNotifications = emptyList()) }
    }

    fun openHomeVisitBookingSheet(barber: BarberProfile, preselectedService: ServiceItem? = null) {
        _uiState.update {
            it.copy(
                showBookingSheet = false,
                showHomeVisitBookingSheet = true,
                homeBookingTargetBarber = barber,
                homeBookingPreselectedService = preselectedService
            )
        }
    }

    fun closeHomeVisitBookingSheet() {
        _uiState.update {
            it.copy(
                showHomeVisitBookingSheet = false,
                homeBookingTargetBarber = null,
                homeBookingPreselectedService = null
            )
        }
    }

    fun getAvailableHomeSlots(barber: BarberProfile, date: String): List<HomeSlotAvailability> {
        return repository.getAvailableHomeSlots(barber, date)
    }

    fun toggleArtistBlockedSlot(date: String, slot: String) {
        repository.toggleArtistBlockedSlot(date, slot)
        showToast("Disponibilité mise à jour ($date • $slot)")
    }

    fun computeDistanceKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        return repository.computeDistanceKm(lat1, lon1, lat2, lon2)
    }

    fun submitHomeVisitRequest(
        barber: BarberProfile,
        selectedServices: List<ServiceItem>,
        date: String,
        slot: String,
        customerName: String,
        customerPhone: String,
        customerAddress: String,
        clientLatitude: Double,
        clientLongitude: Double,
        customerNotes: String = "",
        paymentMethod: PaymentMethod = PaymentMethod.CASH
    ): BookingRecord {
        val (created, notifs) = repository.submitHomeVisitRequest(
            barber = barber,
            selectedServices = selectedServices,
            date = date,
            slot = slot,
            customerName = customerName,
            customerPhone = customerPhone,
            customerAddress = customerAddress,
            clientLatitude = clientLatitude,
            clientLongitude = clientLongitude,
            customerNotes = customerNotes,
            paymentMethod = paymentMethod
        )
        _uiState.update {
            it.copy(
                showHomeVisitBookingSheet = false,
                homeBookingTargetBarber = null,
                homeBookingPreselectedService = null,
                pendingSystemNotifications = notifs
            )
        }
        showToast("⏳ Demande à domicile envoyée (${created.date} à ${created.timeSlot}) ! Client et artiste notifiés.")
        return created
    }

    fun confirmHomeBooking(bookingId: String): List<AppNotification> {
        val notifs = repository.confirmHomeBooking(bookingId)
        val updatedBooking = repository.bookings.value.find { it.id == bookingId }
        _uiState.update {
            it.copy(
                lastBookedAppointment = updatedBooking ?: it.lastBookedAppointment,
                pendingSystemNotifications = notifs
            )
        }
        showToast("✅ Visite à domicile confirmée ! Notifications envoyées au client et à l'artiste.")
        return notifs
    }

    fun declineHomeBooking(bookingId: String, reason: String = "Créneau indisponible pour déplacement"): List<AppNotification> {
        val notifs = repository.declineHomeBooking(bookingId, reason)
        _uiState.update { it.copy(pendingSystemNotifications = notifs) }
        showToast("Demande déclinée. Le créneau a été libéré et le client notifié.")
        return notifs
    }

    fun notifyArtistOnTheWay(bookingId: String, etaMinutes: Int): List<AppNotification> {
        val notifs = repository.notifyArtistOnTheWay(bookingId, etaMinutes)
        if (notifs.isNotEmpty()) {
            _uiState.update { it.copy(pendingSystemNotifications = notifs) }
            showToast("🚗 Départ notifié au client (arrivée estimée : ~$etaMinutes min).")
        }
        return notifs
    }

    fun confirmArtistArrivedAtClient(bookingId: String): List<AppNotification> {
        val notifs = repository.confirmArtistArrivedAtClient(bookingId)
        if (notifs.isNotEmpty()) {
            _uiState.update { it.copy(pendingSystemNotifications = notifs) }
            showToast("📍 Arrivée chez le client confirmée !")
        }
        return notifs
    }

    fun completeHomeBooking(bookingId: String): List<AppNotification> {
        val notifs = repository.completeHomeBooking(bookingId)
        if (notifs.isNotEmpty()) {
            _uiState.update { it.copy(pendingSystemNotifications = notifs) }
            showToast("✨ Prestation à domicile terminée ! Notifications envoyées.")
        }
        return notifs
    }

    fun triggerBookingReminder1h(bookingId: String): AppNotification? {
        val notif = repository.triggerBookingReminder1h(bookingId)
        if (notif != null) {
            showToast("⏰ Rappel -1h envoyé : arrivez 15 min avant pour confirmer votre place.")
        }
        return notif
    }

    fun triggerBookingReminder30m(bookingId: String): AppNotification? {
        val notif = repository.triggerBookingReminder30m(bookingId)
        if (notif != null) {
            showToast("⚠️ Rappel -30 min envoyé !")
        }
        return notif
    }

    fun evaluate15MinArrivalDeadline(bookingId: String): AppNotification? {
        val notif = repository.evaluate15MinArrivalDeadline(bookingId)
        if (notif != null) {
            showToast("❌ RDV annulé automatiquement (non arrivé 15 min avant).")
        } else {
            showToast("✅ Place maintenue : arrivée déjà confirmée au salon.")
        }
        return notif
    }

    fun confirmArrivalAtShop(bookingId: String): AppNotification? {
        val notif = repository.confirmArrivalAtShop(bookingId)
        if (notif != null) {
            showToast("✅ Arrivée confirmée au salon ! Votre place est sécurisée.")
        }
        return notif
    }

    fun notifyOnTheWay(bookingId: String, etaMinutes: Int): AppNotification? {
        val notif = repository.notifyOnTheWay(bookingId, etaMinutes)
        if (notif != null) {
            showToast("🚗 Le barbier a été notifié : en route (~$etaMinutes min).")
        }
        return notif
    }

    fun cancelBooking(bookingId: String) {
        repository.cancelBooking(bookingId)
        showToast("Rendez-vous annulé.")
    }

    fun openFeedbackDialog(barber: BarberProfile?, shop: Shop?) {
        _uiState.update {
            it.copy(
                showFeedbackDialog = true,
                feedbackTargetBarber = barber,
                feedbackTargetShop = shop
            )
        }
    }

    fun openFeedbackForBooking(booking: BookingRecord) {
        val barber = repository.allBarbers.value.find { it.id == booking.barberId }
        val shop = repository.shops.value.find { it.id == booking.shopId || it.name == booking.shopName }
        openFeedbackDialog(barber, shop)
    }

    fun closeFeedbackDialog() {
        _uiState.update {
            it.copy(
                showFeedbackDialog = false,
                feedbackTargetBarber = null,
                feedbackTargetShop = null
            )
        }
    }

    fun submitFeedback(
        barberRating: Int?,
        shopRating: Int?,
        comment: String,
        isAnonymousRequested: Boolean
    ) {
        val targetBarber = _uiState.value.feedbackTargetBarber
        val targetShop = _uiState.value.feedbackTargetShop
        val customerName = _uiState.value.currentUserAccount?.fullName ?: "Client LEMQES"
        val isSubscribedCustomer = targetBarber?.isSubscribed
            ?: repository.allBarbers.value.any { b ->
                b.isSubscribed && (targetShop == null || targetShop.barberIds.contains(b.id))
            }

        repository.submitFeedbackReview(
            barberId = targetBarber?.id,
            barberName = targetBarber?.name,
            barberRating = barberRating,
            shopId = targetShop?.id,
            shopName = targetShop?.name,
            shopRating = shopRating,
            comment = comment,
            isAnonymousRequested = isAnonymousRequested,
            customerName = customerName,
            isSubscribedCustomer = isSubscribedCustomer
        )

        val updatedSelected = targetBarber?.id?.let { id -> repository.allBarbers.value.find { it.id == id } }
        _uiState.update {
            it.copy(
                showFeedbackDialog = false,
                feedbackTargetBarber = null,
                feedbackTargetShop = null,
                selectedBarberForDetails = if (it.selectedBarberForDetails?.id == targetBarber?.id && updatedSelected != null) {
                    updatedSelected
                } else it.selectedBarberForDetails
            )
        }
        val modeLabel = if (isAnonymousRequested && isSubscribedCustomer) "anonymement" else "publiquement"
        showToast("⭐ Avis publié $modeLabel ! Merci pour votre retour.")
    }

    fun joinQueueRemotely(barber: BarberProfile, service: ServiceItem) {
        repository.joinQueueRemotely(barber, service)
        showToast("Vous avez rejoint la file d'attente !")
    }

    fun setShowWorkplaceDialog(show: Boolean) {
        _uiState.update { it.copy(showWorkplaceChangeDialog = show) }
    }

    fun setShowBroadcastDialog(show: Boolean) {
        _uiState.update { it.copy(showBroadcastDialog = show) }
    }

    fun setShowQrModal(show: Boolean) {
        _uiState.update { it.copy(showQrModal = show) }
    }

    fun setShowBookingSheet(show: Boolean) {
        _uiState.update { it.copy(showBookingSheet = show) }
    }

    private fun showToast(msg: String) {
        _uiState.update { it.copy(statusSuccessMessage = msg) }
    }

    fun clearToast() {
        _uiState.update { it.copy(statusSuccessMessage = null) }
    }
}
