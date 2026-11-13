package com.example.model

enum class UserRole {
    CUSTOMER,
    BARBER,
    HOME_ARTIST,
    SHOP_OWNER
}

enum class Country(
    val code: String,
    val nameFr: String,
    val monthlyRateUsd: Double,
    val currencyCode: String,
    val currencySymbol: String,
    val localMonthlyPrice: String,
    val initialTrialMonths: Int = 1
) {
    ALGERIA("DZ", "Algérie", 3.0, "DZD", "DA", "600 DA"),
    TUNISIA("TN", "Tunisie", 4.0, "TND", "DT", "12 TND"),
    MOROCCO("MA", "Maroc", 4.0, "MAD", "DH", "40 MAD"),
    FRANCE("FR", "France / Europe", 6.0, "EUR", "€", "6,00 €"),
    OTHER("GLOBAL", "International", 6.0, "USD", "$", "6.00 $");

    val dailyAdRewardUsd: Double
        get() = monthlyRateUsd / 25.0 // Reach full month subscription in exactly 25 days

    val perAdRewardUsd: Double
        get() = dailyAdRewardUsd / 3.0 // 3 ads per day complete the daily reward
}

data class WalletAccount(
    val balanceUsd: Double = 3.0, // 1 month free credit gift on creation
    val country: Country = Country.ALGERIA,
    val monthlyRateUsd: Double = 3.0,
    val nextDeductionDate: String = "11 Décembre 2026",
    val monthsRemaining: Int = 1,
    val daysCoveredRemaining: Int = 30, // How many days covered for free
    val daysWatchedThisMonth: Int = 0, // Out of 25 days target
    val rewardedAdsWatchedToday: Int = 0,
    val maxDailyAds: Int = 3 // Exactly 3 ads a day
) {
    val dailyAdGoalUsd: Double
        get() = country.dailyAdRewardUsd

    val perAdRewardUsd: Double
        get() = country.perAdRewardUsd

    // Days still needed to watch 3 ads to fully cover next month
    val daysRemainingToCoverMonth: Int
        get() = (25 - daysWatchedThisMonth).coerceAtLeast(0)
}

enum class TargetAudience(
    val id: String,
    val labelFr: String,
    val labelAr: String,
    val emoji: String,
    val descriptionFr: String
) {
    MEN("MEN", "Hommes & Garçons", "رجال وأولاد", "🧔", "Barbier, Dégradé, Barbe & Soins masculins"),
    WOMEN("WOMEN", "Femmes & Dames", "نساء وفتيات", "💄", "Coiffure dame, Manucure, Pédicure, Soins de visage, Maquillage")
}

enum class ServiceCategory(val labelFr: String, val labelAr: String, val emoji: String) {
    HAIR("Coiffure & Brushing", "قص واستشوار", "✂️"),
    BEARD("Barbe & Rasage", "لحية وحلاقة", "🧔"),
    NAILS("Manucure & Pédicure", "مانيكير وباديكير", "💅"),
    SKINCARE("Soin Visage & Skincare", "عناية بالبشرة", "✨"),
    MAKEUP("Maquillage & Épilation", "مكياج وإزالة شعر", "💄"),
    COLORING("Coloration & Lissage", "صبغة وكيراتين", "🎨"),
    SPA("Spa & Bien-être", "سبا واستجمام", "🧖‍♀️")
}

data class UserAccount(
    val id: String,
    val fullName: String,
    val phoneNumber: String,
    val role: UserRole,
    val password: String = "1234",
    val country: Country = Country.ALGERIA,
    val targetAudience: TargetAudience = TargetAudience.MEN,
    val preferredAudience: TargetAudience? = null,
    val wilaya: String = "16 - Alger",
    val commune: String = "Hydra",
    val latitude: Double = 36.7538,
    val longitude: Double = 3.0588,
    val locationLabel: String = "Localisation GPS active",
    val avatarUrl: String = "",
    val shopOrBarberName: String = "",
    val experienceYears: Int = 3,
    val workplaceType: WorkplaceType = WorkplaceType.REGISTERED_SHOP,
    val selectedSpecialties: List<String> = emptyList(),
    val chairCountLabel: String = "3 - 5 postes",
    val openingHours: String = "09:00 - 21:00",
    val amenities: List<String> = emptyList(),
    val ownerAlsoWorksChair: Boolean = true,
    val gpsRadarEnabled: Boolean = true,
    val serviceRadiusKm: Int = 15,
    val travelFeeDzd: Int = 500,
    val coveredZones: String = "Hydra, El Biar, Alger Centre",
    val wallet: WalletAccount = WalletAccount()
)

enum class BarberStatus(val labelKey: String) {
    ONLINE("status_online"),
    ON_BREAK("status_break"),
    OFFLINE("status_offline")
}

enum class WorkplaceType {
    REGISTERED_SHOP,
    CUSTOM_LOCATION,
    FREELANCE_MOBILE
}

enum class CustomerTypeAccepted {
    MEN_ONLY,
    WOMEN_ONLY,
    KIDS_ONLY,
    MEN_AND_KIDS,
    WOMEN_AND_KIDS
}

enum class PhoneVisibility {
    PUBLIC,
    SUBSCRIBERS_ONLY,
    HIDDEN
}

enum class QueueJoinMode {
    OPEN_TO_ALL,
    SUBSCRIBERS_ONLY,
    PAUSED
}

enum class BookingStatus {
    CONFIRMED,
    ARRIVED_CONFIRMED,
    WAITING_APPROVAL,
    COMPLETED,
    CANCELLED,
    AUTO_CANCELLED,
    NO_SHOW
}

enum class QueueItemType {
    WALK_IN,
    BOOKED_APP
}

data class ServiceItem(
    val id: String,
    val nameEn: String,
    val nameAr: String,
    val nameFr: String,
    val priceDzd: Int,
    val durationMinutes: Int,
    val iconName: String = "content_cut",
    val category: ServiceCategory = ServiceCategory.HAIR,
    val targetAudience: TargetAudience = TargetAudience.MEN
)

data class WeeklyWorkplaceSchedule(
    val dayOfWeek: String, // "Sat", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri"
    val workplaceName: String,
    val wilaya: String,
    val commune: String,
    val hours: String
)

data class BarberWorkplace(
    val type: WorkplaceType,
    val shopId: String? = null,
    val shopName: String,
    val wilaya: String,
    val commune: String,
    val address: String,
    val latitude: Double = 36.7538, // Algiers center default
    val longitude: Double = 3.0588,
    val serviceRadiusKm: Int = 10,
    val sinceDate: String = "2024"
)

data class BarberProfile(
    val id: String,
    val name: String,
    val phone: String,
    val phoneVisibility: PhoneVisibility = PhoneVisibility.PUBLIC,
    val bio: String,
    val avatarUrl: String = "",
    val coverUrl: String = "",
    val experienceYears: Int,
    val isVerified: Boolean = true,
    val rating: Double = 4.9,
    val reviewCount: Int = 142,
    val status: BarberStatus = BarberStatus.ONLINE,
    val statusNote: String = "Dispo pour coupe & barbe",
    val customerTypes: CustomerTypeAccepted = CustomerTypeAccepted.MEN_AND_KIDS,
    val currentWorkplace: BarberWorkplace,
    val services: List<ServiceItem> = emptyList(),
    val multiShopSchedule: List<WeeklyWorkplaceSchedule> = emptyList(),
    val instagramHandle: String = "@hajjam_dz",
    val tiktokHandle: String = "@lemqes_dz",
    val facebookHandle: String = "BarberAlgiers",
    val personalSlug: String = "karim-barber",
    val queueOpenMode: QueueJoinMode = QueueJoinMode.OPEN_TO_ALL,
    val subscribersCount: Int = 384,
    val isSubscribed: Boolean = false,
    val targetAudience: TargetAudience = TargetAudience.MEN,
    val specialtyTitle: String = "Maître Barbier",
    val activePromotion: BarberPromotion? = null,
    val privacySettings: BarberPrivacySettings = BarberPrivacySettings(),
    val offersHomeService: Boolean = false,
    val homeServiceFeeDzd: Int = 500,
    val homeServiceRadiusKm: Int = 15,
    val homeServiceZones: String = "",
    val availableHomeSlots: List<String> = listOf("09:30", "11:00", "13:30", "15:00", "16:30", "18:00", "19:30", "21:00"),
    val blockedHomeSlots: Map<String, List<String>> = emptyMap()
)

data class HomeSlotAvailability(
    val slot: String,
    val isAvailable: Boolean,
    val reason: String? = null
)

data class BarberPromotion(
    val id: String,
    val title: String,
    val discountPercent: Int = 20,
    val serviceName: String = "Coupe classique & dégradé",
    val discountedPriceDzd: Int = 480,
    val originalPriceDzd: Int = 600,
    val expiresAt: String = "Ce soir 21:00",
    val active: Boolean = true
)

data class BarberPrivacySettings(
    val showPhone: Boolean = true,
    val showQueueCount: Boolean = true,
    val showReviews: Boolean = true,
    val showWorkHistory: Boolean = true,
    val showCutPrices: Boolean = true, // Barber chooses to show price of his cut to customers
    val requireSubscriberApproval: Boolean = false
)

data class Shop(
    val id: String,
    val name: String,
    val targetAudience: TargetAudience = TargetAudience.MEN,
    val categorySubtitle: String = "Salon de Coiffure & Barbier",
    val wilaya: String,
    val commune: String,
    val address: String,
    val latitude: Double,
    val longitude: Double,
    val phone: String,
    val openingHours: String,
    val amenities: List<String>,
    val barberIds: List<String>,
    val rating: Double = 4.8,
    val reviewCount: Int = 48,
    val photoCount: Int = 6,
    val avatarUrl: String = "",
    val services: List<ServiceItem> = emptyList()
)

data class QueueCustomer(
    val id: String,
    val ticketNumber: Int,
    val customerName: String,
    val customerPhone: String,
    val serviceName: String,
    val priceDzd: Int,
    val durationMinutes: Int,
    val type: QueueItemType,
    val arrivalTime: String,
    val isNext: Boolean = false,
    val isCalled: Boolean = false,
    val isCustomerSelf: Boolean = false
)

data class BookingRecord(
    val id: String,
    val barberId: String,
    val barberName: String,
    val shopId: String? = null,
    val shopName: String = "",
    val customerName: String,
    val serviceName: String,
    val priceDzd: Int,
    val date: String,
    val timeSlot: String,
    val locationSnapshot: String,
    val status: BookingStatus,
    val isDepositPaid: Boolean = false,
    val notified1hBefore: Boolean = false,
    val notified30mBefore: Boolean = false,
    val hasArrivedAtShop: Boolean = false,
    val isOnTheWay: Boolean = false,
    val etaMinutes: Int? = null,
    val autoCancelReason: String? = null,
    val appointmentTimestampMillis: Long = 0L,
    val isHomeService: Boolean = false,
    val customerAddress: String? = null,
    val travelFeeDzd: Int = 0,
    val customerPhone: String = "",
    val customerNotes: String = "",
    val selectedServices: List<String> = emptyList(),
    val clientLatitude: Double? = null,
    val clientLongitude: Double? = null,
    val distanceKm: Double? = null,
    val paymentMethod: PaymentMethod = PaymentMethod.CASH,
    val targetAudience: TargetAudience = TargetAudience.MEN,
    val artistOnTheWay: Boolean = false,
    val artistEtaMinutes: Int? = null,
    val artistConfirmedAt: String? = null,
    val declineReason: String? = null
)

enum class FeedbackTargetType {
    BARBER,
    SHOP
}

data class FeedbackReview(
    val id: String,
    val targetType: FeedbackTargetType,
    val targetId: String,
    val targetName: String,
    val rating: Int,
    val comment: String,
    val authorDisplayName: String,
    val isAnonymous: Boolean,
    val isSubscribedCustomer: Boolean,
    val createdAt: String
)

data class AppNotification(
    val id: String,
    val title: String,
    val message: String,
    val timestamp: String,
    val type: String, // "QUEUE", "BOOKING", "WORKPLACE", "BROADCAST", "SHOP_REQUEST", "HOME_REQUEST", "HOME_CONFIRMED"
    val read: Boolean = false,
    val recipientRole: String = "ALL", // "CUSTOMER", "ARTIST", "ALL"
    val relatedBookingId: String? = null
)

enum class ShopJoinRequestStatus {
    PENDING,
    ACCEPTED,
    REJECTED
}

data class ShopJoinRequest(
    val id: String,
    val barberId: String,
    val barberName: String,
    val barberPhone: String,
    val barberExperienceYears: Int,
    val shopId: String,
    val shopName: String,
    val wilaya: String,
    val commune: String,
    val requestDate: String,
    val status: ShopJoinRequestStatus = ShopJoinRequestStatus.PENDING
)

enum class ShopArrangementType(val labelFr: String) {
    PERCENTAGE("Pourcentage sur les services"),
    FLAT_MONTHLY("Loyer fixe mensuel"),
    NO_COMMISSION("Sans commission (Salon propre / Indépendant)")
}

data class ShopArrangement(
    val type: ShopArrangementType = ShopArrangementType.PERCENTAGE,
    val percentageRate: Double = 30.0, // e.g., 30% of gross service sales
    val flatMonthlyRentDzd: Int = 15000 // e.g., 15,000 DZD per month
)

enum class PaymentMethod(val labelFr: String) {
    CASH("Espèces (Cash)"),
    BARIDIMOB("BaridiMob"),
    DAHABIA("Carte Dahabia"),
    OTHER("Autre")
}

enum class ExpenseCategory(val labelFr: String, val iconName: String) {
    BLADES_RAZORS("Lames & Rasoirs jetables", "content_cut"),
    HAIR_BEARD_PRODUCTS("Gels, Cires & Shampoings", "sanitizer"),
    BEAUTY_NAILS_SKINCARE("Produits Onglerie, Soins & Skincare", "spa"),
    DISINFECTANT_HYGIENE("Alcool, Serviettes & Désinfection", "cleaning_services"),
    SHOP_RENT("Loyer fauteuil / Salon", "store"),
    EQUIPMENT("Entretien Matériel (Tondeuses, Lampes UV)", "build"),
    TRANSPORT("Transport & Déplacement", "directions_car"),
    OTHER("Autre charge", "receipt")
}

enum class WorkTransactionType {
    INCOME,
    EXPENSE
}

data class WorkTransaction(
    val id: String,
    val type: WorkTransactionType,
    val customerName: String? = null,
    val serviceName: String = "",
    val serviceAmountDzd: Int = 0, // Service revenue (subject to shop percentage)
    val tipAmountDzd: Int = 0, // Tips (100% strictly for the barber, exempt from shop cut)
    val expenseCategory: ExpenseCategory? = null,
    val expenseAmountDzd: Int = 0,
    val note: String = "",
    val paymentMethod: PaymentMethod = PaymentMethod.CASH,
    val dateTime: String,
    val linkedBookingId: String? = null,
    val linkedQueueTicket: Int? = null,
    val barberId: String = "barber_karim"
) {
    val totalReceivedDzd: Int
        get() = if (type == WorkTransactionType.INCOME) serviceAmountDzd + tipAmountDzd else -expenseAmountDzd
}

data class BarberFinancialSummary(
    val totalServicesRevenueDzd: Int,
    val totalTipsDzd: Int,
    val shopDeductionDzd: Int,
    val totalExpensesDzd: Int,
    val netBarberProfitDzd: Int,
    val transactionCount: Int
)

