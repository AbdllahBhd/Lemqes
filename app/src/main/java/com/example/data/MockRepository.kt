package com.example.data

import com.example.model.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

class MockRepository {
    private val defaultWorkplace = BarberWorkplace(
        type = WorkplaceType.REGISTERED_SHOP,
        shopId = "shop_1",
        shopName = "Salon Le Diplomate Alger",
        wilaya = "16 - Alger",
        commune = "Hydra",
        address = "14 Rue Djemila, Hydra, Alger",
        latitude = 36.7456,
        longitude = 3.0421,
        sinceDate = "Depuis Juin 2024"
    )

    private val initialBarber = BarberProfile(
        id = "barber_karim",
        name = "Karim 'Le Ciseau d'Or'",
        phone = "+213 550 12 34 56",
        phoneVisibility = PhoneVisibility.PUBLIC,
        bio = "Maître Barbier & Styliste avec 9 ans d'expérience. Spécialiste Dégradé Américain, Barbe sculptée à l'ancienne et soin vapeur.",
        experienceYears = 9,
        isVerified = true,
        rating = 4.9,
        reviewCount = 186,
        status = BarberStatus.ONLINE,
        statusNote = "En service ! File fluide",
        customerTypes = CustomerTypeAccepted.MEN_AND_KIDS,
        currentWorkplace = defaultWorkplace,
        services = listOf(
            ServiceItem("srv_1", "Classic Haircut / Dégradé", "قصة شعر كلاسيكية / ديغرادي", "Coupe classique & dégradé", 600, 25),
            ServiceItem("srv_2", "Beard Sculpt & Hot Towel", "نحت اللحية بالمنشفة الساخنة", "Taille barbe & serviette chaude", 400, 15),
            ServiceItem("srv_3", "VIP Pack: Hair + Beard + Mask", "باك VIP: قصة ولحية وماسك", "Pack Royal: Coupe + Barbe + Soin", 1200, 45),
            ServiceItem("srv_4", "Kids Haircut (<12 yrs)", "قصة أطفال خاصة", "Coupe enfant junior", 400, 20)
        ),
        multiShopSchedule = listOf(
            WeeklyWorkplaceSchedule("Sam - Mar", "Salon Le Diplomate", "Alger", "Hydra", "09:00 - 20:00"),
            WeeklyWorkplaceSchedule("Mer - Jeu", "Barber Lounge 16", "Alger", "Bab El Oued", "10:00 - 21:00"),
            WeeklyWorkplaceSchedule("Vendredi", "Repos / Domicile VIP sur rdv", "Alger", "Grand Alger", "14:30 - 22:00")
        ),
        instagramHandle = "@karim_lemqes",
        tiktokHandle = "@karim.barber.dz",
        personalSlug = "karim-alger",
        subscribersCount = 428,
        isSubscribed = true
    )

    private val initialOtherBarbers = listOf(
        BarberProfile(
            id = "barber_mehdi",
            name = "Mehdi Barber",
            phone = "+213 661 88 99 00",
            phoneVisibility = PhoneVisibility.PUBLIC,
            bio = "Spécialiste Fades et dessins tribaux. Ambiance urbaine.",
            experienceYears = 6,
            isVerified = true,
            rating = 4.8,
            reviewCount = 94,
            status = BarberStatus.ONLINE,
            statusNote = "Prêt pour vous recevoir",
            customerTypes = CustomerTypeAccepted.MEN_ONLY,
            targetAudience = TargetAudience.MEN,
            specialtyTitle = "Barbier Spécialiste Fades",
            currentWorkplace = BarberWorkplace(
                type = WorkplaceType.REGISTERED_SHOP,
                shopId = "shop_1",
                shopName = "Salon Le Diplomate Alger",
                wilaya = "16 - Alger",
                commune = "Hydra",
                address = "14 Rue Djemila, Hydra, Alger",
                latitude = 36.7456,
                longitude = 3.0421
            ),
            services = listOf(
                ServiceItem("m1", "Skin Fade Pro", "تصفيف وتسريحة عصرية", "Dégradé à blanc", 700, 30, "content_cut", ServiceCategory.HAIR, TargetAudience.MEN),
                ServiceItem("m2", "Beard Trim", "لحية سريعة", "Entretien barbe", 300, 10, "content_cut", ServiceCategory.BEARD, TargetAudience.MEN)
            ),
            subscribersCount = 210
        ),
        BarberProfile(
            id = "stylist_yasmine",
            name = "Yasmine - Coiffure & Beauté Dames",
            phone = "+213 551 22 33 44",
            phoneVisibility = PhoneVisibility.PUBLIC,
            bio = "Coiffeuse visagiste diplômée. Spécialiste Lissage Kératine & Protéine, Balayage Ombré et Brushing signature. Espace intime et voilé respecté.",
            experienceYears = 8,
            isVerified = true,
            rating = 4.95,
            reviewCount = 214,
            status = BarberStatus.ONLINE,
            statusNote = "En service • Soins & Brushings",
            customerTypes = CustomerTypeAccepted.WOMEN_ONLY,
            targetAudience = TargetAudience.WOMEN,
            specialtyTitle = "Coiffeuse Styliste & Visagiste Dames",
            currentWorkplace = BarberWorkplace(
                type = WorkplaceType.REGISTERED_SHOP,
                shopId = "shop_dames_1",
                shopName = "Institut & Salon Reine de Saba",
                wilaya = "16 - Alger",
                commune = "Hydra",
                address = "22 Boulevard Sidi Yahia, Hydra, Alger",
                latitude = 36.7410,
                longitude = 3.0390
            ),
            services = listOf(
                ServiceItem("y1", "Women Haircut & Blowdry", "قص واستشوار احترافي", "Coupe Dames & Brushing Signature", 1500, 40, "content_cut", ServiceCategory.HAIR, TargetAudience.WOMEN),
                ServiceItem("y2", "Keratin & Protein Treatment", "كيراتين وبروتين برازيلي", "Lissage Kératine & Protéine Brésilienne", 8000, 120, "spa", ServiceCategory.COLORING, TargetAudience.WOMEN),
                ServiceItem("y3", "Balayage Ombre Hair", "بالياج وصبغة مخصصة", "Coloration & Balayage Ombré", 6500, 90, "palette", ServiceCategory.COLORING, TargetAudience.WOMEN),
                ServiceItem("y4", "Glamour Blowdry", "تسريحة وبروشينغ سهرة", "Brushing Glamour & Ondulations", 1000, 25, "brush", ServiceCategory.HAIR, TargetAudience.WOMEN)
            ),
            subscribersCount = 512,
            activePromotion = BarberPromotion("promo_yasmine", "-20% Lissage Kératine & Brushing", 20, "Lissage Kératine", 6400, 8000, "Ce soir 20:00", true)
        ),
        BarberProfile(
            id = "stylist_amel",
            name = "Amel - Onglerie & Skincare",
            phone = "+213 772 33 44 55",
            phoneVisibility = PhoneVisibility.PUBLIC,
            bio = "Experte Manucure Russe, Pose Gel Semi-Permanent, Pédicure Spa Balnéothérapie et Soin Visage Hydrafacial pour une peau éclatante.",
            experienceYears = 7,
            isVerified = true,
            rating = 5.0,
            reviewCount = 178,
            status = BarberStatus.ONLINE,
            statusNote = "Cabine soins & ongles disponible",
            customerTypes = CustomerTypeAccepted.WOMEN_ONLY,
            targetAudience = TargetAudience.WOMEN,
            specialtyTitle = "Esthéticienne & Nail Artist Dames",
            currentWorkplace = BarberWorkplace(
                type = WorkplaceType.REGISTERED_SHOP,
                shopId = "shop_dames_2",
                shopName = "Maison de Beauté Lalla",
                wilaya = "16 - Alger",
                commune = "Dely Ibrahim",
                address = "Centre Commercial El Qods, Dely Ibrahim",
                latitude = 36.7580,
                longitude = 2.9850
            ),
            services = listOf(
                ServiceItem("a_nail_1", "Russian Manicure + Semi-Permanent", "مانيكير روسي وطلاء دائم", "Manucure Russe + Vernis Semi-Permanent", 2200, 45, "spa", ServiceCategory.NAILS, TargetAudience.WOMEN),
                ServiceItem("a_skin_1", "Hydrafacial Glow Treatment", "تنظيف عميق للبشرة وهيدرافيشل", "Soin Visage Hydrafacial & Nettoyage Profond", 3500, 50, "face", ServiceCategory.SKINCARE, TargetAudience.WOMEN),
                ServiceItem("a_pedi_1", "Pedicure Spa & Paraffin", "باديكير سبا وعناية كاملة بالأقدام", "Pédicure Spa Balnéo + Bain Paraffine", 2800, 55, "spa", ServiceCategory.NAILS, TargetAudience.WOMEN),
                ServiceItem("a_brow_1", "Threading Brows & Henna", "تحديد حواجب بالخيط وحنة", "Épilation Sourcils au Fil + Teinture", 800, 20, "face", ServiceCategory.MAKEUP, TargetAudience.WOMEN)
            ),
            subscribersCount = 430
        ),
        BarberProfile(
            id = "barber_amine",
            name = "Amine VIP • Barbier à Domicile",
            phone = "+213 770 45 67 89",
            phoneVisibility = PhoneVisibility.PUBLIC,
            bio = "Coiffure & Barbe VIP à domicile, préparatifs marié et déplacements privés dans tout Alger. Kit stérilisé complet.",
            experienceYears = 12,
            isVerified = true,
            rating = 5.0,
            reviewCount = 112,
            status = BarberStatus.ONLINE,
            statusNote = "Disponible à domicile • Rayon 25 km",
            customerTypes = CustomerTypeAccepted.MEN_AND_KIDS,
            targetAudience = TargetAudience.MEN,
            specialtyTitle = "Barbier à Domicile VIP",
            currentWorkplace = BarberWorkplace(
                type = WorkplaceType.FREELANCE_MOBILE,
                shopName = "Service Mobile à Domicile",
                wilaya = "16 - Alger",
                commune = "Alger Centre & Ouest",
                address = "Hydra, El Biar, Ben Aknoun, Dely Ibrahim",
                latitude = 36.7538,
                longitude = 3.0588,
                serviceRadiusKm = 25
            ),
            services = listOf(
                ServiceItem("a1", "Pack Domicile VIP Hair & Beard", "خدمة منزلية شاملة", "Coupe + Barbe + Serviette chaude à domicile", 2500, 60, "content_cut", ServiceCategory.HAIR, TargetAudience.MEN),
                ServiceItem("a2", "Kids Home Haircut", "حلاقة أطفال في المنزل", "Coupe enfant à domicile", 1200, 30, "content_cut", ServiceCategory.HAIR, TargetAudience.MEN),
                ServiceItem("a3", "Groom Home Pack", "باك العريس في المنزل", "Pack Marié VIP à domicile (Coupe + Soin + Barbe)", 4500, 90, "spa", ServiceCategory.SKINCARE, TargetAudience.MEN)
            ),
            subscribersCount = 650,
            offersHomeService = true,
            homeServiceFeeDzd = 500,
            homeServiceRadiusKm = 25,
            homeServiceZones = "Hydra, El Biar, Ben Aknoun, Dely Ibrahim"
        ),
        BarberProfile(
            id = "artist_lina_home",
            name = "Lina • Beauté & Coiffure à Domicile",
            phone = "+213 552 33 44 55",
            phoneVisibility = PhoneVisibility.PUBLIC,
            bio = "Coiffeuse, maquilleuse et esthéticienne diplômée se déplaçant chez vous : Brushing, Manucure Russe, Pédicure Spa, Hydrafacial & Maquillage soirée/mariée.",
            experienceYears = 7,
            isVerified = true,
            rating = 4.96,
            reviewCount = 148,
            status = BarberStatus.ONLINE,
            statusNote = "Disponible à domicile • Kit stérilisé 100% Dames",
            customerTypes = CustomerTypeAccepted.WOMEN_ONLY,
            targetAudience = TargetAudience.WOMEN,
            specialtyTitle = "Artiste Beauté à Domicile Dames",
            currentWorkplace = BarberWorkplace(
                type = WorkplaceType.FREELANCE_MOBILE,
                shopName = "Beauté Mobile à Domicile (Dames)",
                wilaya = "16 - Alger",
                commune = "Hydra & Grand Alger",
                address = "Hydra, Sidi Yahia, Kouba, Birkhadem",
                latitude = 36.7420,
                longitude = 3.0480,
                serviceRadiusKm = 20
            ),
            services = listOf(
                ServiceItem("lh_1", "Brushing & Hair Styling at Home", "استشوار وتسريحة في المنزل", "Coiffure & Brushing Signature à domicile", 2200, 50, "brush", ServiceCategory.HAIR, TargetAudience.WOMEN),
                ServiceItem("lh_2", "Russian Manicure + Gel at Home", "مانيكير روسي وطلاء دائم في المنزل", "Manucure Russe + Semi-Permanent à domicile", 2800, 60, "spa", ServiceCategory.NAILS, TargetAudience.WOMEN),
                ServiceItem("lh_3", "Spa Pedicure & Skincare at Home", "باديكير سبا وعناية بالبشرة في المنزل", "Pédicure Spa & Soin Visage Hydrafacial à domicile", 4200, 75, "face", ServiceCategory.SKINCARE, TargetAudience.WOMEN),
                ServiceItem("lh_4", "Bridal / Party Makeup at Home", "مكياج سهرة أو عروس في المنزل", "Maquillage Soirée / Mariée VIP à domicile", 6000, 90, "face", ServiceCategory.MAKEUP, TargetAudience.WOMEN)
            ),
            subscribersCount = 590,
            offersHomeService = true,
            homeServiceFeeDzd = 600,
            homeServiceRadiusKm = 20,
            homeServiceZones = "Hydra, Sidi Yahia, Kouba, Birkhadem"
        )
    )

    private val initialShops = listOf(
        Shop(
            id = "shop_1",
            name = "Salon Le Diplomate Alger",
            targetAudience = TargetAudience.MEN,
            categorySubtitle = "Salon de Coiffure & Barbier Hommes",
            wilaya = "16 - Alger",
            commune = "Hydra",
            address = "14 Rue Djemila, Hydra",
            latitude = 36.7456,
            longitude = 3.0421,
            phone = "+213 21 60 70 80",
            openingHours = "09:00 - 21:00 (Fermé Vendredi matin)",
            amenities = listOf("Climatisation", "Wi-Fi Gratuit", "Café Nespresso", "Espace Enfants", "Parking"),
            barberIds = listOf("barber_karim", "barber_mehdi"),
            rating = 4.9,
            services = listOf(
                ServiceItem("s1_1", "Classic Haircut & Fade", "قصة كلاسيكية وتدريج", "Coupe classique & dégradé", 600, 25, "content_cut", ServiceCategory.HAIR, TargetAudience.MEN),
                ServiceItem("s1_2", "Beard Sculpt & Hot Towel", "تحديد اللحية بالمنشفة الساخنة", "Taille barbe & serviette chaude", 400, 15, "content_cut", ServiceCategory.BEARD, TargetAudience.MEN),
                ServiceItem("s1_3", "VIP Groom Pack", "باك VIP كامل", "Pack Royal (Coupe + Barbe + Soin)", 1200, 45, "spa", ServiceCategory.SKINCARE, TargetAudience.MEN)
            )
        ),
        Shop(
            id = "shop_dames_1",
            name = "Institut & Salon Reine de Saba",
            targetAudience = TargetAudience.WOMEN,
            categorySubtitle = "Salon de Beauté, Coiffure & Soins Dames",
            wilaya = "16 - Alger",
            commune = "Hydra",
            address = "22 Boulevard Sidi Yahia, Hydra, Alger",
            latitude = 36.7410,
            longitude = 3.0390,
            phone = "+213 21 48 20 30",
            openingHours = "09:30 - 19:30 (100% Réservé aux Femmes)",
            amenities = listOf("100% Femmes", "Espace Voile Privé", "Onglerie Russe", "Soins Hydrafacial", "Thé & Tisanes", "BaridiMob & Cash"),
            barberIds = listOf("stylist_yasmine"),
            rating = 4.95,
            services = listOf(
                ServiceItem("sd1_1", "Women Haircut & Blowdry", "قص واستشوار", "Coupe Dames & Brushing Signature", 1500, 40, "content_cut", ServiceCategory.HAIR, TargetAudience.WOMEN),
                ServiceItem("sd1_2", "Keratin & Protein", "كيراتين وبروتين", "Lissage Kératine & Protéine", 8000, 120, "spa", ServiceCategory.COLORING, TargetAudience.WOMEN),
                ServiceItem("sd1_3", "Russian Manicure", "مانيكير روسي", "Manucure Russe + Semi-Permanent", 2200, 45, "spa", ServiceCategory.NAILS, TargetAudience.WOMEN)
            )
        ),
        Shop(
            id = "shop_dames_2",
            name = "Maison de Beauté Lalla",
            targetAudience = TargetAudience.WOMEN,
            categorySubtitle = "Institut d'Esthétique, Onglerie & Pédicure Spa",
            wilaya = "16 - Alger",
            commune = "Dely Ibrahim",
            address = "Centre Commercial El Qods, Dely Ibrahim",
            latitude = 36.7580,
            longitude = 2.9850,
            phone = "+213 23 35 12 12",
            openingHours = "10:00 - 20:00 (Fermé Dimanche)",
            amenities = listOf("Espace Mariée VIP", "Pédicure Spa Balnéo", "Cabine Skincare", "Climatisation"),
            barberIds = listOf("stylist_amel"),
            rating = 4.88,
            services = listOf(
                ServiceItem("sd2_1", "Hydrafacial Glow", "تنظيف عميق للبشرة", "Soin Visage Hydrafacial", 3500, 50, "face", ServiceCategory.SKINCARE, TargetAudience.WOMEN),
                ServiceItem("sd2_2", "Spa Pedicure", "باديكير سبا", "Pédicure Spa Balnéo", 2800, 55, "spa", ServiceCategory.NAILS, TargetAudience.WOMEN),
                ServiceItem("sd2_3", "Eyebrow Threading", "تحديد الحواجب", "Épilation Sourcils au Fil", 800, 20, "face", ServiceCategory.MAKEUP, TargetAudience.WOMEN)
            )
        ),
        Shop(
            id = "shop_2",
            name = "Barber Lounge 16",
            targetAudience = TargetAudience.MEN,
            categorySubtitle = "Barber Shop & Urban Cuts",
            wilaya = "16 - Alger",
            commune = "Bab El Oued",
            address = "Boulevard Colonel Lotfi, Bab El Oued",
            latitude = 36.7891,
            longitude = 3.0511,
            phone = "+213 21 96 11 22",
            openingHours = "10:00 - 22:00",
            amenities = listOf("Climatisation", "Écran TV Foot", "Paiement Cash / CIB"),
            barberIds = listOf("barber_karim"),
            rating = 4.7,
            services = listOf(
                ServiceItem("s2_1", "Skin Fade Pro", "ديغرادي أبيض", "Dégradé Américain / À Blanc", 700, 30, "content_cut", ServiceCategory.HAIR, TargetAudience.MEN),
                ServiceItem("s2_2", "Beard Trim", "تشذيب اللحية", "Taille Barbe & Contours", 350, 15, "content_cut", ServiceCategory.BEARD, TargetAudience.MEN)
            )
        )
    )

    private val initialQueue = listOf(
        QueueCustomer(
            id = "q_1",
            ticketNumber = 101,
            customerName = "Yacine Benali",
            customerPhone = "0554 ** ** 12",
            serviceName = "Coupe classique & dégradé",
            priceDzd = 600,
            durationMinutes = 25,
            type = QueueItemType.WALK_IN,
            arrivalTime = "14:10",
            isNext = true,
            isCalled = true
        ),
        QueueCustomer(
            id = "q_2",
            ticketNumber = 102,
            customerName = "Riad M.",
            customerPhone = "0770 ** ** 45",
            serviceName = "Taille barbe & serviette",
            priceDzd = 400,
            durationMinutes = 15,
            type = QueueItemType.BOOKED_APP,
            arrivalTime = "14:25",
            isNext = false,
            isCustomerSelf = true
        ),
        QueueCustomer(
            id = "q_3",
            ticketNumber = 103,
            customerName = "Sofiane (Sans rdv)",
            customerPhone = "Walk-in client",
            serviceName = "Pack Royal",
            priceDzd = 1200,
            durationMinutes = 40,
            type = QueueItemType.WALK_IN,
            arrivalTime = "14:35",
            isNext = false
        )
    )

    private val initialBookings = listOf(
        BookingRecord(
            id = "b_1",
            barberId = "barber_karim",
            barberName = "Karim 'Le Ciseau d'Or'",
            shopId = "shop_1",
            shopName = "Salon Le Diplomate Alger",
            customerName = "Moi (Client connecté)",
            serviceName = "Taille barbe & serviette",
            priceDzd = 400,
            date = "Aujourd'hui",
            timeSlot = "16:00",
            locationSnapshot = "Salon Le Diplomate, Hydra",
            status = BookingStatus.CONFIRMED,
            appointmentTimestampMillis = System.currentTimeMillis() + 90 * 60 * 1000L
        ),
        BookingRecord(
            id = "b_2",
            barberId = "barber_karim",
            barberName = "Karim 'Le Ciseau d'Or'",
            shopId = "shop_1",
            shopName = "Salon Le Diplomate Alger",
            customerName = "Kamel Z.",
            serviceName = "Classic Haircut",
            priceDzd = 600,
            date = "Aujourd'hui",
            timeSlot = "17:00",
            locationSnapshot = "Salon Le Diplomate, Hydra",
            status = BookingStatus.CONFIRMED,
            appointmentTimestampMillis = System.currentTimeMillis() + 150 * 60 * 1000L
        ),
        BookingRecord(
            id = "b_home_req_1",
            barberId = "artist_lina_home",
            barberName = "Lina • Beauté & Coiffure à Domicile",
            shopId = null,
            shopName = "Service à Domicile",
            customerName = "Meriem S.",
            customerPhone = "0554 88 22 10",
            customerNotes = "Résidence Les Pins, Bât C, 3ème étage • Sonner à l'interphone 14",
            serviceName = "Manucure Russe + Semi-Permanent à domicile",
            selectedServices = listOf("Manucure Russe + Semi-Permanent à domicile"),
            priceDzd = 3400,
            travelFeeDzd = 600,
            date = "Demain",
            timeSlot = "15:00",
            locationSnapshot = "🏠 À domicile : Hydra, Rue Sidi Yahia, Résidence Les Pins",
            customerAddress = "Hydra, Rue Sidi Yahia, Résidence Les Pins",
            clientLatitude = 36.7435,
            clientLongitude = 3.0445,
            distanceKm = 0.4,
            paymentMethod = PaymentMethod.CASH,
            targetAudience = TargetAudience.WOMEN,
            isHomeService = true,
            status = BookingStatus.WAITING_APPROVAL,
            appointmentTimestampMillis = System.currentTimeMillis() + 24 * 60 * 60 * 1000L
        )
    )

    private val initialNotifications = listOf(
        AppNotification(
            id = "n_1",
            title = "File en direct",
            message = "Vous êtes le prochain dans la file de Karim ! Préparez-vous à entrer.",
            timestamp = "Il y a 5 min",
            type = "QUEUE",
            recipientRole = "CUSTOMER"
        ),
        AppNotification(
            id = "n_2",
            title = "Lieu de travail actualisé",
            message = "Karim travaille aujourd'hui au Salon Le Diplomate (Hydra). Tous ses rendez-vous sont maintenus.",
            timestamp = "Il y a 2h",
            type = "WORKPLACE",
            recipientRole = "ALL"
        ),
        AppNotification(
            id = "n_home_pending_1",
            title = "🏠 Nouvelle demande à domicile (Demain 15:00)",
            message = "Meriem S. (0554 88 22 10) demande Manucure Russe à Hydra (0.4 km). En attente de votre confirmation.",
            timestamp = "Il y a 10 min",
            type = "HOME_REQUEST",
            recipientRole = "ARTIST",
            relatedBookingId = "b_home_req_1"
        )
    )

    // State flows
    private val _barberProfile = MutableStateFlow(initialBarber)
    val barberProfile: StateFlow<BarberProfile> = _barberProfile.asStateFlow()

    private val _allBarbers = MutableStateFlow(listOf(initialBarber) + initialOtherBarbers)
    val allBarbers: StateFlow<List<BarberProfile>> = _allBarbers.asStateFlow()

    private val _shops = MutableStateFlow(initialShops)
    val shops: StateFlow<List<Shop>> = _shops.asStateFlow()

    private val _queue = MutableStateFlow(initialQueue)
    val queue: StateFlow<List<QueueCustomer>> = _queue.asStateFlow()

    private val _bookings = MutableStateFlow(initialBookings)
    val bookings: StateFlow<List<BookingRecord>> = _bookings.asStateFlow()

    private val _notifications = MutableStateFlow(initialNotifications)
    val notifications: StateFlow<List<AppNotification>> = _notifications.asStateFlow()

    private val initialReviews = listOf(
        FeedbackReview(
            id = "rev_1",
            targetType = FeedbackTargetType.BARBER,
            targetId = "barber_karim",
            targetName = "Karim 'Le Ciseau d'Or'",
            rating = 5,
            comment = "Dégradé très propre et ponctualité exemplaire. Rien à dire !",
            authorDisplayName = "Client abonné anonyme",
            isAnonymous = true,
            isSubscribedCustomer = true,
            createdAt = "Hier"
        ),
        FeedbackReview(
            id = "rev_2",
            targetType = FeedbackTargetType.SHOP,
            targetId = "shop_1",
            targetName = "Salon Le Diplomate Alger",
            rating = 5,
            comment = "Salon climatisé, très hygiénique et café offert pendant l'attente.",
            authorDisplayName = "Client abonné anonyme",
            isAnonymous = true,
            isSubscribedCustomer = true,
            createdAt = "Il y a 2 jours"
        ),
        FeedbackReview(
            id = "rev_3",
            targetType = FeedbackTargetType.BARBER,
            targetId = "stylist_yasmine",
            targetName = "Yasmine - Coiffure & Beauté Dames",
            rating = 5,
            comment = "Lissage kératine magnifique et espace 100% privé respecté.",
            authorDisplayName = "Meriem S.",
            isAnonymous = false,
            isSubscribedCustomer = true,
            createdAt = "Il y a 3 jours"
        ),
        FeedbackReview(
            id = "rev_4",
            targetType = FeedbackTargetType.SHOP,
            targetId = "shop_dames_1",
            targetName = "Institut & Salon Reine de Saba",
            rating = 5,
            comment = "Accueil chaleureux, cabine propre et matériel stérilisé.",
            authorDisplayName = "Client abonné anonyme",
            isAnonymous = true,
            isSubscribedCustomer = true,
            createdAt = "Cette semaine"
        )
    )

    private val _reviews = MutableStateFlow(initialReviews)
    val reviews: StateFlow<List<FeedbackReview>> = _reviews.asStateFlow()

    private val initialShopJoinRequests = listOf(
        ShopJoinRequest(
            id = "req_1",
            barberId = "barber_karim",
            barberName = "Karim 'Le Ciseau d'Or'",
            barberPhone = "+213 550 12 34 56",
            barberExperienceYears = 9,
            shopId = "shop_1",
            shopName = "Salon Le Diplomate Alger",
            wilaya = "16 - Alger",
            commune = "Hydra",
            requestDate = "Aujourd'hui 10:15",
            status = ShopJoinRequestStatus.PENDING
        )
    )

    private val _shopJoinRequests = MutableStateFlow(initialShopJoinRequests)
    val shopJoinRequests: StateFlow<List<ShopJoinRequest>> = _shopJoinRequests.asStateFlow()

    // Barber quick actions (<10s)
    fun updateBarberStatus(newStatus: BarberStatus, note: String = "") {
        _barberProfile.update { it.copy(status = newStatus, statusNote = note.ifEmpty { it.statusNote }) }
        _allBarbers.update { list ->
            list.map { if (it.id == _barberProfile.value.id) it.copy(status = newStatus) else it }
        }
    }

    fun toggleShowCutPrices(show: Boolean) {
        _barberProfile.update {
            it.copy(privacySettings = it.privacySettings.copy(showCutPrices = show))
        }
        _allBarbers.update { list ->
            list.map {
                if (it.id == _barberProfile.value.id) {
                    it.copy(privacySettings = it.privacySettings.copy(showCutPrices = show))
                } else it
            }
        }
    }

    fun launchPromotion(promotion: BarberPromotion) {
        _barberProfile.update { it.copy(activePromotion = promotion) }
        _allBarbers.update { list ->
            list.map { if (it.id == _barberProfile.value.id) it.copy(activePromotion = promotion) else it }
        }
        // Broadcast push notification to all followers instantly
        _notifications.update { current ->
            listOf(
                AppNotification(
                    id = "promo_${System.currentTimeMillis()}",
                    title = "🏷️ Promotion de ${_barberProfile.value.name} !",
                    message = "${promotion.title} : -${promotion.discountPercent}% sur ${promotion.serviceName} (${promotion.discountedPriceDzd} DA au lieu de ${promotion.originalPriceDzd} DA) jusqu'à ${promotion.expiresAt} !",
                    timestamp = "À l'instant",
                    type = "PROMOTION"
                )
            ) + current
        }
    }

    fun endPromotion() {
        _barberProfile.update { it.copy(activePromotion = null) }
        _allBarbers.update { list ->
            list.map { if (it.id == _barberProfile.value.id) it.copy(activePromotion = null) else it }
        }
    }

    fun addWalkInToQueue(serviceName: String = "Coupe rapide", price: Int = 500, duration: Int = 20) {
        val nextTicket = (_queue.value.maxOfOrNull { it.ticketNumber } ?: 100) + 1
        val item = QueueCustomer(
            id = "q_${System.currentTimeMillis()}",
            ticketNumber = nextTicket,
            customerName = "Client direct #${nextTicket}",
            customerPhone = "Sans rdv",
            serviceName = serviceName,
            priceDzd = price,
            durationMinutes = duration,
            type = QueueItemType.WALK_IN,
            arrivalTime = "Maintenant"
        )
        _queue.update { it + item }
    }

    fun finishCurrentCustomer() {
        if (_queue.value.isNotEmpty()) {
            _queue.update { current ->
                if (current.size > 1) {
                    val remaining = current.drop(1)
                    // Mark new top as next
                    listOf(remaining.first().copy(isNext = true)) + remaining.drop(1)
                } else {
                    emptyList()
                }
            }
        }
    }

    fun callNextCustomer() {
        _queue.update { list ->
            if (list.isNotEmpty()) {
                val first = list.first().copy(isNext = true, isCalled = true)
                listOf(first) + list.drop(1)
            } else list
        }
        _notifications.update { current ->
            listOf(
                AppNotification(
                    id = "n_${System.currentTimeMillis()}",
                    title = "Prochain client appelé",
                    message = "Notification envoyée : 'Vous êtes le suivant, veuillez vous présenter dans 5 min'",
                    timestamp = "À l'instant",
                    type = "QUEUE"
                )
            ) + current
        }
    }

    fun removeQueueCustomer(id: String) {
        _queue.update { list -> list.filterNot { it.id == id } }
    }

    fun updateWorkplace(newWorkplace: BarberWorkplace, notifyFollowers: Boolean = true) {
        _barberProfile.update { it.copy(currentWorkplace = newWorkplace) }
        _allBarbers.update { list ->
            list.map { if (it.id == _barberProfile.value.id) it.copy(currentWorkplace = newWorkplace) else it }
        }
        if (notifyFollowers) {
            _notifications.update { current ->
                listOf(
                    AppNotification(
                        id = "n_${System.currentTimeMillis()}",
                        title = "Nouveau lieu de travail notifié !",
                        message = "Vos ${_barberProfile.value.subscribersCount} abonnés ont été prévenus : Vous travaillez désormais à ${newWorkplace.shopName} (${newWorkplace.commune}, ${newWorkplace.wilaya})",
                        timestamp = "À l'instant",
                        type = "WORKPLACE"
                    )
                ) + current
            }
        }
    }

    fun broadcastToFollowers(message: String) {
        _notifications.update { current ->
            listOf(
                AppNotification(
                    id = "n_${System.currentTimeMillis()}",
                    title = "Message diffusé aux abonnés",
                    message = message,
                    timestamp = "À l'instant",
                    type = "BROADCAST"
                )
            ) + current
        }
    }

    fun toggleSubscription(barberId: String) {
        _barberProfile.update {
            if (it.id == barberId) {
                val newSub = !it.isSubscribed
                val newCount = (if (newSub) it.subscribersCount + 1 else it.subscribersCount - 1).coerceAtLeast(0)
                it.copy(isSubscribed = newSub, subscribersCount = newCount)
            } else it
        }
        _allBarbers.update { list ->
            list.map { b ->
                if (b.id == barberId) {
                    val newSub = !b.isSubscribed
                    val newCount = (if (newSub) b.subscribersCount + 1 else b.subscribersCount - 1).coerceAtLeast(0)
                    b.copy(isSubscribed = newSub, subscribersCount = newCount)
                } else b
            }
        }
    }

    fun updateHomeServiceSettings(
        offersHomeService: Boolean,
        feeDzd: Int,
        radiusKm: Int,
        zones: String
    ) {
        _barberProfile.update { current ->
            val updatedWorkplace = if (offersHomeService && current.currentWorkplace.type == WorkplaceType.FREELANCE_MOBILE) {
                current.currentWorkplace.copy(
                    serviceRadiusKm = radiusKm,
                    address = zones.ifBlank { current.currentWorkplace.address }
                )
            } else {
                current.currentWorkplace.copy(serviceRadiusKm = radiusKm)
            }
            current.copy(
                offersHomeService = offersHomeService,
                homeServiceFeeDzd = feeDzd.coerceAtLeast(0),
                homeServiceRadiusKm = radiusKm.coerceAtLeast(1),
                homeServiceZones = zones,
                currentWorkplace = updatedWorkplace
            )
        }
        val updated = _barberProfile.value
        _allBarbers.update { list ->
            list.map { if (it.id == updated.id) updated else it }
        }
    }

    fun updateBarberAvatar(avatarUri: String) {
        _barberProfile.update { it.copy(avatarUrl = avatarUri) }
        val updated = _barberProfile.value
        _allBarbers.update { list ->
            list.map { if (it.id == updated.id) it.copy(avatarUrl = avatarUri) else it }
        }
        _registeredAccounts.update { accounts ->
            accounts.map { acc -> if (acc.id == updated.id) acc.copy(avatarUrl = avatarUri) else acc }
        }
    }

    fun buildServiceItemFromLabel(
        name: String,
        targetAudience: TargetAudience,
        priceDzd: Int? = null,
        durationMinutes: Int? = null,
        isHomeArtist: Boolean = false,
        indexHint: Int = 0
    ): ServiceItem {
        val cleanName = name.trim()
        val isWomen = targetAudience == TargetAudience.WOMEN
        val defaultPrice = when {
            priceDzd != null && priceDzd >= 0 -> priceDzd
            isHomeArtist -> if (isWomen) 2200 + (indexHint * 400) else 1500 + (indexHint * 400)
            else -> if (isWomen) 1500 + (indexHint * 400) else 600 + (indexHint * 200)
        }
        val defaultDuration = durationMinutes?.coerceIn(5, 300) ?: if (isWomen || isHomeArtist) 45 else 25
        val category = when {
            cleanName.contains("Manucure", true) || cleanName.contains("Pédicure", true) || cleanName.contains("Ongl", true) -> ServiceCategory.NAILS
            cleanName.contains("Visage", true) || cleanName.contains("Hydrafacial", true) || cleanName.contains("Soin", true) -> ServiceCategory.SKINCARE
            cleanName.contains("Barbe", true) || cleanName.contains("Rasage", true) -> ServiceCategory.BEARD
            cleanName.contains("Maquillage", true) || cleanName.contains("Épilation", true) || cleanName.contains("Sourcil", true) -> ServiceCategory.MAKEUP
            cleanName.contains("Kératine", true) || cleanName.contains("Coloration", true) || cleanName.contains("Balayage", true) || cleanName.contains("Lissage", true) -> ServiceCategory.COLORING
            cleanName.contains("Spa", true) || cleanName.contains("Massage", true) -> ServiceCategory.SPA
            else -> ServiceCategory.HAIR
        }
        return ServiceItem(
            id = "srv_${System.currentTimeMillis()}_${cleanName.lowercase().hashCode()}",
            nameEn = cleanName,
            nameAr = cleanName,
            nameFr = cleanName,
            priceDzd = defaultPrice,
            durationMinutes = defaultDuration,
            iconName = if (isWomen) "spa" else "content_cut",
            category = category,
            targetAudience = targetAudience
        )
    }

    fun togglePresetBarberService(serviceName: String) {
        val current = _barberProfile.value
        val existing = current.services.find { it.nameFr.equals(serviceName.trim(), ignoreCase = true) }
        val updatedServices = if (existing != null) {
            current.services.filterNot { it.id == existing.id }
        } else {
            val isHomeArtist = current.offersHomeService || current.currentWorkplace.type == WorkplaceType.FREELANCE_MOBILE
            current.services + buildServiceItemFromLabel(
                name = serviceName,
                targetAudience = current.targetAudience,
                isHomeArtist = isHomeArtist,
                indexHint = current.services.size
            )
        }
        updateBarberServicesList(updatedServices)
    }

    fun addCustomBarberService(serviceName: String, priceDzd: Int, durationMinutes: Int) {
        val trimmed = serviceName.trim()
        if (trimmed.isBlank()) return
        val current = _barberProfile.value
        val isHomeArtist = current.offersHomeService || current.currentWorkplace.type == WorkplaceType.FREELANCE_MOBILE
        val existing = current.services.find { it.nameFr.equals(trimmed, ignoreCase = true) }
        val newItem = buildServiceItemFromLabel(
            name = trimmed,
            targetAudience = current.targetAudience,
            priceDzd = priceDzd.coerceAtLeast(0),
            durationMinutes = durationMinutes.coerceIn(5, 300),
            isHomeArtist = isHomeArtist
        )
        val updatedServices = if (existing != null) {
            current.services.map {
                if (it.id == existing.id) it.copy(priceDzd = newItem.priceDzd, durationMinutes = newItem.durationMinutes) else it
            }
        } else {
            current.services + newItem
        }
        updateBarberServicesList(updatedServices)
    }

    fun removeBarberService(serviceId: String) {
        val current = _barberProfile.value
        updateBarberServicesList(current.services.filterNot { it.id == serviceId })
    }

    private fun updateBarberServicesList(services: List<ServiceItem>) {
        _barberProfile.update { it.copy(services = services) }
        val updated = _barberProfile.value
        _allBarbers.update { list ->
            list.map { if (it.id == updated.id) it.copy(services = services) else it }
        }
        _registeredAccounts.update { accounts ->
            accounts.map { acc ->
                if (acc.id == updated.id) acc.copy(selectedSpecialties = services.map { it.nameFr }) else acc
            }
        }
    }

    fun updateShopAvatar(shopId: String, avatarUri: String) {
        _shops.update { list ->
            list.map { if (it.id == shopId) it.copy(avatarUrl = avatarUri) else it }
        }
        _registeredAccounts.update { accounts ->
            accounts.map { acc ->
                if ("shop_${acc.id}" == shopId || acc.shopOrBarberName == _shops.value.find { it.id == shopId }?.name) {
                    acc.copy(avatarUrl = avatarUri)
                } else acc
            }
        }
    }

    fun togglePresetShopService(shopId: String, serviceName: String) {
        val shop = _shops.value.find { it.id == shopId } ?: return
        val existing = shop.services.find { it.nameFr.equals(serviceName.trim(), ignoreCase = true) }
        val updatedServices = if (existing != null) {
            shop.services.filterNot { it.id == existing.id }
        } else {
            shop.services + buildServiceItemFromLabel(
                name = serviceName,
                targetAudience = shop.targetAudience,
                indexHint = shop.services.size
            )
        }
        updateShopServicesList(shopId, updatedServices)
    }

    fun addCustomShopService(shopId: String, serviceName: String, priceDzd: Int, durationMinutes: Int) {
        val trimmed = serviceName.trim()
        if (trimmed.isBlank()) return
        val shop = _shops.value.find { it.id == shopId } ?: return
        val existing = shop.services.find { it.nameFr.equals(trimmed, ignoreCase = true) }
        val newItem = buildServiceItemFromLabel(
            name = trimmed,
            targetAudience = shop.targetAudience,
            priceDzd = priceDzd.coerceAtLeast(0),
            durationMinutes = durationMinutes.coerceIn(5, 300)
        )
        val updatedServices = if (existing != null) {
            shop.services.map {
                if (it.id == existing.id) it.copy(priceDzd = newItem.priceDzd, durationMinutes = newItem.durationMinutes) else it
            }
        } else {
            shop.services + newItem
        }
        updateShopServicesList(shopId, updatedServices)
    }

    fun removeShopService(shopId: String, serviceId: String) {
        val shop = _shops.value.find { it.id == shopId } ?: return
        updateShopServicesList(shopId, shop.services.filterNot { it.id == serviceId })
    }

    private fun updateShopServicesList(shopId: String, services: List<ServiceItem>) {
        _shops.update { list ->
            list.map { if (it.id == shopId) it.copy(services = services) else it }
        }
    }

    fun bookAppointment(
        service: ServiceItem,
        date: String,
        slot: String,
        barber: BarberProfile,
        customerName: String = "Moi (Client connecté)",
        appointmentTimestampMillis: Long = computeAppointmentTimestamp(date, slot),
        isHomeService: Boolean = false,
        customerAddress: String? = null,
        travelFeeDzd: Int = 0
    ): BookingRecord {
        val effectiveHome = isHomeService || barber.currentWorkplace.type == WorkplaceType.FREELANCE_MOBILE
        val effectiveTravelFee = if (effectiveHome) travelFeeDzd.coerceAtLeast(0) else 0
        val effectiveLocation = if (effectiveHome) {
            "🏠 À domicile : ${customerAddress?.ifBlank { "Adresse client" } ?: "Adresse client"}"
        } else {
            "${barber.currentWorkplace.shopName}, ${barber.currentWorkplace.commune}"
        }
        val newBooking = BookingRecord(
            id = "b_${System.currentTimeMillis()}",
            barberId = barber.id,
            barberName = barber.name,
            shopId = if (effectiveHome) null else barber.currentWorkplace.shopId,
            shopName = if (effectiveHome) "Service à Domicile" else barber.currentWorkplace.shopName,
            customerName = customerName,
            serviceName = service.nameFr,
            priceDzd = service.priceDzd + effectiveTravelFee,
            date = date,
            timeSlot = slot,
            locationSnapshot = effectiveLocation,
            status = BookingStatus.CONFIRMED,
            appointmentTimestampMillis = appointmentTimestampMillis,
            isHomeService = effectiveHome,
            customerAddress = customerAddress,
            travelFeeDzd = effectiveTravelFee
        )
        _bookings.update { listOf(newBooking) + it }
        _notifications.update { current ->
            val msg = if (effectiveHome) {
                "Intervention à domicile avec ${barber.name} le $date à $slot (${customerAddress ?: "Adresse fournie"}). Rappels 1h et 30 min avant : soyez prêt(e) 15 min avant sinon annulation auto."
            } else {
                "Réservé avec ${barber.name} le $date à $slot. Vous recevrez un rappel 1h et 30 min avant : arrivez 15 min avant pour confirmer votre place sinon annulation automatique."
            }
            listOf(
                AppNotification(
                    id = "n_${System.currentTimeMillis()}",
                    title = if (effectiveHome) "🏠 RDV à domicile confirmé !" else "Rendez-vous confirmé ! (Règle -15 min)",
                    message = msg,
                    timestamp = "À l'instant",
                    type = "BOOKING"
                )
            ) + current
        }
        return newBooking
    }

    fun getAvailableHomeSlots(barber: BarberProfile, date: String): List<HomeSlotAvailability> {
        val blockedForDay = barber.blockedHomeSlots[date].orEmpty()
        val occupiedByBookings = _bookings.value
            .filter {
                it.barberId == barber.id &&
                    it.date == date &&
                    it.status in setOf(
                        BookingStatus.WAITING_APPROVAL,
                        BookingStatus.CONFIRMED,
                        BookingStatus.ARRIVED_CONFIRMED
                    )
            }
            .map { it.timeSlot }
            .toSet()

        return barber.availableHomeSlots.map { slot ->
            when {
                blockedForDay.contains(slot) -> HomeSlotAvailability(slot, false, "Bloqué par l'artiste")
                occupiedByBookings.contains(slot) -> HomeSlotAvailability(slot, false, "Déjà réservé")
                else -> HomeSlotAvailability(slot, true, null)
            }
        }
    }

    fun toggleArtistBlockedSlot(date: String, slot: String) {
        _barberProfile.update { current ->
            val currentMap = current.blockedHomeSlots.toMutableMap()
            val listForDate = currentMap[date].orEmpty().toMutableList()
            if (listForDate.contains(slot)) {
                listForDate.remove(slot)
            } else {
                listForDate.add(slot)
            }
            currentMap[date] = listForDate
            current.copy(blockedHomeSlots = currentMap)
        }
        val updated = _barberProfile.value
        _allBarbers.update { list ->
            list.map { if (it.id == updated.id) updated else it }
        }
    }

    fun computeDistanceKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val earthRadiusKm = 6371.0
        val dLat = Math.toRadians(lat2 - lat1)
        val dLon = Math.toRadians(lon2 - lon1)
        val a = kotlin.math.sin(dLat / 2) * kotlin.math.sin(dLat / 2) +
            kotlin.math.cos(Math.toRadians(lat1)) * kotlin.math.cos(Math.toRadians(lat2)) *
            kotlin.math.sin(dLon / 2) * kotlin.math.sin(dLon / 2)
        val c = 2 * kotlin.math.atan2(kotlin.math.sqrt(a), kotlin.math.sqrt(1 - a))
        val raw = earthRadiusKm * c
        return (kotlin.math.round(raw * 10.0) / 10.0)
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
    ): Pair<BookingRecord, List<AppNotification>> {
        val effectiveServices = if (selectedServices.isNotEmpty()) selectedServices else barber.services.take(1)
        val serviceNames = effectiveServices.map { it.nameFr }
        val servicesTotal = effectiveServices.sumOf { it.priceDzd }
        val travelFee = barber.homeServiceFeeDzd.coerceAtLeast(0)
        val totalPrice = servicesTotal + travelFee
        val distanceKm = computeDistanceKm(
            barber.currentWorkplace.latitude,
            barber.currentWorkplace.longitude,
            clientLatitude,
            clientLongitude
        )
        val cleanAddress = customerAddress.trim().ifBlank { "Point GPS ($clientLatitude, $clientLongitude)" }
        val summaryServiceName = if (serviceNames.size <= 1) {
            serviceNames.firstOrNull() ?: "Prestation à domicile"
        } else {
            "${serviceNames.first()} + ${serviceNames.size - 1} autre(s)"
        }
        val bookingId = "b_home_${System.currentTimeMillis()}"
        val booking = BookingRecord(
            id = bookingId,
            barberId = barber.id,
            barberName = barber.name,
            shopId = null,
            shopName = "Service à Domicile (${if (barber.targetAudience == TargetAudience.WOMEN) "Dames" else "Hommes"})",
            customerName = customerName.trim().ifBlank { "Client LEMQES" },
            customerPhone = customerPhone.trim(),
            customerNotes = customerNotes.trim(),
            serviceName = summaryServiceName,
            selectedServices = serviceNames,
            priceDzd = totalPrice,
            travelFeeDzd = travelFee,
            date = date,
            timeSlot = slot,
            locationSnapshot = "🏠 À domicile : $cleanAddress",
            customerAddress = cleanAddress,
            clientLatitude = clientLatitude,
            clientLongitude = clientLongitude,
            distanceKm = distanceKm,
            paymentMethod = paymentMethod,
            targetAudience = barber.targetAudience,
            isHomeService = true,
            status = BookingStatus.WAITING_APPROVAL,
            appointmentTimestampMillis = computeAppointmentTimestamp(date, slot)
        )
        _bookings.update { listOf(booking) + it }

        val nowMs = System.currentTimeMillis()
        val clientNotif = AppNotification(
            id = "nh_cli_$nowMs",
            title = "⏳ Demande à domicile envoyée à ${barber.name}",
            message = "Créneau demandé : $date à $slot • ${serviceNames.joinToString(", ")} ($totalPrice DA). L'artiste va confirmer votre visite.",
            timestamp = "À l'instant",
            type = "HOME_REQUEST",
            recipientRole = "CUSTOMER",
            relatedBookingId = bookingId
        )
        val artistNotif = AppNotification(
            id = "nh_art_${nowMs + 1}",
            title = "🏠 Nouvelle demande à domicile : ${booking.customerName}",
            message = "Tél: ${booking.customerPhone} • $date à $slot • ${serviceNames.joinToString(", ")} ($totalPrice DA) • Adresse: $cleanAddress (~$distanceKm km). Confirmez le RDV.",
            timestamp = "À l'instant",
            type = "HOME_REQUEST",
            recipientRole = "ARTIST",
            relatedBookingId = bookingId
        )
        val bothNotifs = listOf(clientNotif, artistNotif)
        _notifications.update { bothNotifs + it }
        return booking to bothNotifs
    }

    fun confirmHomeBooking(bookingId: String): List<AppNotification> {
        val booking = _bookings.value.find { it.id == bookingId } ?: return emptyList()
        _bookings.update { list ->
            list.map {
                if (it.id == bookingId) {
                    it.copy(
                        status = BookingStatus.CONFIRMED,
                        artistConfirmedAt = "À l'instant"
                    )
                } else it
            }
        }
        val nowMs = System.currentTimeMillis()
        val clientNotif = AppNotification(
            id = "nhc_cli_$nowMs",
            title = "✅ Visite à domicile confirmée par ${booking.barberName} !",
            message = "Votre créneau du ${booking.date} à ${booking.timeSlot} est confirmé à l'adresse : ${booking.customerAddress ?: booking.locationSnapshot}. Total : ${booking.priceDzd} DA.",
            timestamp = "À l'instant",
            type = "HOME_CONFIRMED",
            recipientRole = "CUSTOMER",
            relatedBookingId = bookingId
        )
        val artistNotif = AppNotification(
            id = "nhc_art_${nowMs + 1}",
            title = "🗓️ Visite à domicile confirmée dans votre agenda",
            message = "RDV confirmé avec ${booking.customerName} (${booking.customerPhone}) le ${booking.date} à ${booking.timeSlot} • ${booking.customerAddress ?: booking.locationSnapshot}.",
            timestamp = "À l'instant",
            type = "HOME_CONFIRMED",
            recipientRole = "ARTIST",
            relatedBookingId = bookingId
        )
        val both = listOf(clientNotif, artistNotif)
        _notifications.update { both + it }
        return both
    }

    fun declineHomeBooking(bookingId: String, reason: String = "Créneau indisponible pour déplacement"): List<AppNotification> {
        val booking = _bookings.value.find { it.id == bookingId } ?: return emptyList()
        _bookings.update { list ->
            list.map {
                if (it.id == bookingId) {
                    it.copy(status = BookingStatus.CANCELLED, declineReason = reason)
                } else it
            }
        }
        val nowMs = System.currentTimeMillis()
        val clientNotif = AppNotification(
            id = "nhd_cli_$nowMs",
            title = "❌ Demande à domicile refusée par ${booking.barberName}",
            message = "Le créneau du ${booking.date} à ${booking.timeSlot} n'a pas pu être retenu ($reason). Le créneau a été libéré : choisissez un autre horaire.",
            timestamp = "À l'instant",
            type = "BOOKING",
            recipientRole = "CUSTOMER",
            relatedBookingId = bookingId
        )
        val artistNotif = AppNotification(
            id = "nhd_art_${nowMs + 1}",
            title = "Demande à domicile refusée",
            message = "Vous avez refusé la visite de ${booking.customerName} (${booking.date} à ${booking.timeSlot}). Le client a été notifié.",
            timestamp = "À l'instant",
            type = "BOOKING",
            recipientRole = "ARTIST",
            relatedBookingId = bookingId
        )
        val both = listOf(clientNotif, artistNotif)
        _notifications.update { both + it }
        return both
    }

    fun notifyArtistOnTheWay(bookingId: String, etaMinutes: Int): List<AppNotification> {
        val booking = _bookings.value.find { it.id == bookingId } ?: return emptyList()
        if (booking.status == BookingStatus.CANCELLED || booking.status == BookingStatus.AUTO_CANCELLED) return emptyList()
        _bookings.update { list ->
            list.map {
                if (it.id == bookingId) {
                    it.copy(artistOnTheWay = true, artistEtaMinutes = etaMinutes)
                } else it
            }
        }
        val nowMs = System.currentTimeMillis()
        val clientNotif = AppNotification(
            id = "naw_cli_$nowMs",
            title = "🚗 ${booking.barberName} est en route chez vous !",
            message = "L'artiste arrive à votre domicile (${booking.customerAddress ?: "Votre adresse"}) dans environ $etaMinutes min.",
            timestamp = "À l'instant",
            type = "ON_THE_WAY",
            recipientRole = "CUSTOMER",
            relatedBookingId = bookingId
        )
        val artistNotif = AppNotification(
            id = "naw_art_${nowMs + 1}",
            title = "🚗 Départ vers ${booking.customerName} notifié",
            message = "Le client (${booking.customerPhone}) a été prévenu de votre arrivée dans ~$etaMinutes min.",
            timestamp = "À l'instant",
            type = "ON_THE_WAY",
            recipientRole = "ARTIST",
            relatedBookingId = bookingId
        )
        val both = listOf(clientNotif, artistNotif)
        _notifications.update { both + it }
        return both
    }

    fun confirmArtistArrivedAtClient(bookingId: String): List<AppNotification> {
        val booking = _bookings.value.find { it.id == bookingId } ?: return emptyList()
        _bookings.update { list ->
            list.map {
                if (it.id == bookingId) {
                    it.copy(
                        hasArrivedAtShop = true,
                        artistOnTheWay = false,
                        status = BookingStatus.ARRIVED_CONFIRMED
                    )
                } else it
            }
        }
        val nowMs = System.currentTimeMillis()
        val clientNotif = AppNotification(
            id = "naa_cli_$nowMs",
            title = "📍 ${booking.barberName} est arrivé à votre domicile !",
            message = "Votre artiste est devant chez vous pour votre prestation (${booking.serviceName}).",
            timestamp = "À l'instant",
            type = "ARRIVED",
            recipientRole = "CUSTOMER",
            relatedBookingId = bookingId
        )
        val artistNotif = AppNotification(
            id = "naa_art_${nowMs + 1}",
            title = "✅ Arrivée chez ${booking.customerName} enregistrée",
            message = "Prestation ${booking.serviceName} démarrée sur place.",
            timestamp = "À l'instant",
            type = "ARRIVED",
            recipientRole = "ARTIST",
            relatedBookingId = bookingId
        )
        val both = listOf(clientNotif, artistNotif)
        _notifications.update { both + it }
        return both
    }

    fun completeHomeBooking(bookingId: String): List<AppNotification> {
        val booking = _bookings.value.find { it.id == bookingId } ?: return emptyList()
        _bookings.update { list ->
            list.map {
                if (it.id == bookingId) {
                    it.copy(status = BookingStatus.COMPLETED, artistOnTheWay = false)
                } else it
            }
        }
        val nowMs = System.currentTimeMillis()
        val clientNotif = AppNotification(
            id = "nhf_cli_$nowMs",
            title = "✨ Prestation à domicile terminée !",
            message = "Merci pour votre confiance envers ${booking.barberName}. Vous pouvez noter votre visite dans Mes RDV.",
            timestamp = "À l'instant",
            type = "BOOKING",
            recipientRole = "CUSTOMER",
            relatedBookingId = bookingId
        )
        val artistNotif = AppNotification(
            id = "nhf_art_${nowMs + 1}",
            title = "✅ Visite terminée (${booking.priceDzd} DA)",
            message = "Prestation avec ${booking.customerName} clôturée.",
            timestamp = "À l'instant",
            type = "BOOKING",
            recipientRole = "ARTIST",
            relatedBookingId = bookingId
        )
        val both = listOf(clientNotif, artistNotif)
        _notifications.update { both + it }
        return both
    }

    private fun computeAppointmentTimestamp(date: String, slot: String): Long {
        val cal = java.util.Calendar.getInstance()
        val parts = slot.split(":")
        val hour = parts.getOrNull(0)?.toIntOrNull()
        val minute = parts.getOrNull(1)?.toIntOrNull()
        if (hour != null && minute != null) {
            cal.set(java.util.Calendar.HOUR_OF_DAY, hour)
            cal.set(java.util.Calendar.MINUTE, minute)
            cal.set(java.util.Calendar.SECOND, 0)
            when (date) {
                "Demain" -> cal.add(java.util.Calendar.DAY_OF_YEAR, 1)
                "Jeudi" -> cal.add(java.util.Calendar.DAY_OF_YEAR, 2)
                "Vendredi" -> cal.add(java.util.Calendar.DAY_OF_YEAR, 3)
            }
            if (cal.timeInMillis <= System.currentTimeMillis() + 65 * 60 * 1000L) {
                // Ensure enough future window for reminders in Today demo slots
                return System.currentTimeMillis() + 90 * 60 * 1000L
            }
            return cal.timeInMillis
        }
        return System.currentTimeMillis() + 90 * 60 * 1000L
    }

    fun triggerBookingReminder1h(bookingId: String): AppNotification? {
        val booking = _bookings.value.find { it.id == bookingId } ?: return null
        if (booking.status != BookingStatus.CONFIRMED) return null
        _bookings.update { list ->
            list.map { if (it.id == bookingId) it.copy(notified1hBefore = true) else it }
        }
        val notif = AppNotification(
            id = "n1h_${System.currentTimeMillis()}",
            title = "⏰ Rappel RDV dans 1 heure (${booking.timeSlot})",
            message = "Vous devez arriver au salon ${booking.shopName.ifBlank { booking.locationSnapshot }} 15 min avant votre rendez-vous avec ${booking.barberName} pour le confirmer, sinon il sera annulé automatiquement et vous perdrez votre place.",
            timestamp = "À l'instant (-1h)",
            type = "REMINDER_1H"
        )
        _notifications.update { listOf(notif) + it }
        return notif
    }

    fun triggerBookingReminder30m(bookingId: String): AppNotification? {
        val booking = _bookings.value.find { it.id == bookingId } ?: return null
        if (booking.status != BookingStatus.CONFIRMED) return null
        _bookings.update { list ->
            list.map { if (it.id == bookingId) it.copy(notified30mBefore = true) else it }
        }
        val notif = AppNotification(
            id = "n30m_${System.currentTimeMillis()}",
            title = "⚠️ Plus que 30 min avant votre RDV (${booking.timeSlot})",
            message = "Dernier rappel : présentez-vous chez ${booking.barberName} (${booking.shopName.ifBlank { booking.locationSnapshot }}) 15 min avant pour confirmer votre présence et ne pas perdre votre place.",
            timestamp = "À l'instant (-30m)",
            type = "REMINDER_30M"
        )
        _notifications.update { listOf(notif) + it }
        return notif
    }

    fun evaluate15MinArrivalDeadline(bookingId: String): AppNotification? {
        val booking = _bookings.value.find { it.id == bookingId } ?: return null
        if (booking.hasArrivedAtShop || booking.status != BookingStatus.CONFIRMED) return null
        val reason = "Non arrivé au salon 15 min avant le rendez-vous (${booking.timeSlot}) — place libérée automatiquement."
        _bookings.update { list ->
            list.map {
                if (it.id == bookingId) {
                    it.copy(
                        status = BookingStatus.AUTO_CANCELLED,
                        isOnTheWay = false,
                        autoCancelReason = reason
                    )
                } else it
            }
        }
        val notif = AppNotification(
            id = "nauto_${System.currentTimeMillis()}",
            title = "❌ Rendez-vous annulé automatiquement",
            message = "Vous n'êtes pas arrivé 15 min avant votre RDV de ${booking.timeSlot} avec ${booking.barberName}. Votre rendez-vous est annulé et vous avez perdu votre place.",
            timestamp = "À l'instant (-15m)",
            type = "AUTO_CANCEL"
        )
        _notifications.update { listOf(notif) + it }
        return notif
    }

    fun confirmArrivalAtShop(bookingId: String): AppNotification? {
        val booking = _bookings.value.find { it.id == bookingId } ?: return null
        if (booking.status == BookingStatus.CANCELLED || booking.status == BookingStatus.AUTO_CANCELLED) return null
        _bookings.update { list ->
            list.map {
                if (it.id == bookingId) {
                    it.copy(
                        hasArrivedAtShop = true,
                        isOnTheWay = false,
                        status = BookingStatus.ARRIVED_CONFIRMED
                    )
                } else it
            }
        }
        val notif = AppNotification(
            id = "narr_${System.currentTimeMillis()}",
            title = "✅ Arrivée confirmée au salon !",
            message = "${booking.customerName} est arrivé au salon avant la limite (-15 min) pour son RDV de ${booking.timeSlot} avec ${booking.barberName}. Place confirmée !",
            timestamp = "À l'instant",
            type = "ARRIVED"
        )
        _notifications.update { listOf(notif) + it }
        return notif
    }

    fun notifyOnTheWay(bookingId: String, etaMinutes: Int): AppNotification? {
        val booking = _bookings.value.find { it.id == bookingId } ?: return null
        if (booking.status == BookingStatus.CANCELLED || booking.status == BookingStatus.AUTO_CANCELLED) return null
        _bookings.update { list ->
            list.map {
                if (it.id == bookingId) {
                    it.copy(isOnTheWay = true, etaMinutes = etaMinutes)
                } else it
            }
        }
        val notif = AppNotification(
            id = "nway_${System.currentTimeMillis()}",
            title = "🚗 Client en route vers le salon !",
            message = "${booking.customerName} a signalé qu'il est en chemin vers ${booking.shopName.ifBlank { booking.locationSnapshot }} pour ${booking.barberName} (arrivée dans ~$etaMinutes min).",
            timestamp = "À l'instant",
            type = "ON_THE_WAY"
        )
        _notifications.update { listOf(notif) + it }
        return notif
    }

    fun cancelBooking(bookingId: String): AppNotification? {
        val booking = _bookings.value.find { it.id == bookingId } ?: return null
        _bookings.update { list ->
            list.map {
                if (it.id == bookingId) {
                    it.copy(status = BookingStatus.CANCELLED, isOnTheWay = false)
                } else it
            }
        }
        val notif = AppNotification(
            id = "ncancel_${System.currentTimeMillis()}",
            title = "Rendez-vous annulé",
            message = "Votre rendez-vous de ${booking.timeSlot} avec ${booking.barberName} a été annulé.",
            timestamp = "À l'instant",
            type = "BOOKING"
        )
        _notifications.update { listOf(notif) + it }
        return notif
    }

    fun submitFeedbackReview(
        barberId: String?,
        barberName: String?,
        barberRating: Int?,
        shopId: String?,
        shopName: String?,
        shopRating: Int?,
        comment: String,
        isAnonymousRequested: Boolean,
        customerName: String,
        isSubscribedCustomer: Boolean
    ): List<FeedbackReview> {
        // Anonymous feedback is reserved for subscribed customers
        val effectiveAnonymous = isAnonymousRequested && isSubscribedCustomer
        val authorDisplay = if (effectiveAnonymous) "Client abonné anonyme" else customerName.ifBlank { "Client vérifié" }
        val created = mutableListOf<FeedbackReview>()
        val now = System.currentTimeMillis()

        if (barberId != null && barberRating != null) {
            val clamped = barberRating.coerceIn(1, 5)
            val rev = FeedbackReview(
                id = "rev_b_${now}",
                targetType = FeedbackTargetType.BARBER,
                targetId = barberId,
                targetName = barberName ?: "Professionnel",
                rating = clamped,
                comment = comment.ifBlank { "Très bonne prestation." },
                authorDisplayName = authorDisplay,
                isAnonymous = effectiveAnonymous,
                isSubscribedCustomer = isSubscribedCustomer,
                createdAt = "À l'instant"
            )
            created.add(rev)

            // Update barber rating & reviewCount
            _allBarbers.update { list ->
                list.map { b ->
                    if (b.id == barberId) {
                        val newCount = b.reviewCount + 1
                        val newRating = ((b.rating * b.reviewCount) + clamped) / newCount
                        b.copy(
                            rating = (kotlin.math.round(newRating * 100.0) / 100.0),
                            reviewCount = newCount
                        )
                    } else b
                }
            }
            _barberProfile.update { b ->
                if (b.id == barberId) {
                    val newCount = b.reviewCount + 1
                    val newRating = ((b.rating * b.reviewCount) + clamped) / newCount
                    b.copy(
                        rating = (kotlin.math.round(newRating * 100.0) / 100.0),
                        reviewCount = newCount
                    )
                } else b
            }
        }

        if (shopId != null && shopRating != null) {
            val clampedShop = shopRating.coerceIn(1, 5)
            val rev = FeedbackReview(
                id = "rev_s_${now + 1}",
                targetType = FeedbackTargetType.SHOP,
                targetId = shopId,
                targetName = shopName ?: "Salon",
                rating = clampedShop,
                comment = comment.ifBlank { "Très bon salon." },
                authorDisplayName = authorDisplay,
                isAnonymous = effectiveAnonymous,
                isSubscribedCustomer = isSubscribedCustomer,
                createdAt = "À l'instant"
            )
            created.add(rev)

            _shops.update { list ->
                list.map { s ->
                    if (s.id == shopId) {
                        val newCount = s.reviewCount + 1
                        val newRating = ((s.rating * s.reviewCount) + clampedShop) / newCount
                        s.copy(
                            rating = (kotlin.math.round(newRating * 100.0) / 100.0),
                            reviewCount = newCount
                        )
                    } else s
                }
            }
        }

        if (created.isNotEmpty()) {
            _reviews.update { created + it }
            _notifications.update { current ->
                listOf(
                    AppNotification(
                        id = "nrev_${System.currentTimeMillis()}",
                        title = if (effectiveAnonymous) "🕶️ Avis anonyme publié" else "⭐ Avis publié",
                        message = "Merci ! Votre note et avis ($authorDisplay) ont été enregistrés.",
                        timestamp = "À l'instant",
                        type = "FEEDBACK"
                    )
                ) + current
            }
        }
        return created
    }

    fun joinQueueRemotely(barber: BarberProfile, service: ServiceItem) {
        val nextTicket = (_queue.value.maxOfOrNull { it.ticketNumber } ?: 100) + 1
        val item = QueueCustomer(
            id = "q_${System.currentTimeMillis()}",
            ticketNumber = nextTicket,
            customerName = "Moi (En route)",
            customerPhone = "+213 550 ** ** **",
            serviceName = service.nameFr,
            priceDzd = service.priceDzd,
            durationMinutes = service.durationMinutes,
            type = QueueItemType.BOOKED_APP,
            arrivalTime = "En route",
            isCustomerSelf = true
        )
        _queue.update { it + item }
    }

    fun requestJoinShop(barber: BarberProfile, shop: Shop) {
        val request = ShopJoinRequest(
            id = "req_${System.currentTimeMillis()}",
            barberId = barber.id,
            barberName = barber.name,
            barberPhone = barber.phone,
            barberExperienceYears = barber.experienceYears,
            shopId = shop.id,
            shopName = shop.name,
            wilaya = shop.wilaya,
            commune = shop.commune,
            requestDate = "À l'instant",
            status = ShopJoinRequestStatus.PENDING
        )
        _shopJoinRequests.update { listOf(request) + it }
        _notifications.update { current ->
            listOf(
                AppNotification(
                    id = "n_${System.currentTimeMillis()}",
                    title = "Demande d'affiliation envoyée",
                    message = "Votre demande pour rejoindre ${shop.name} (${shop.commune}) a été transmise au gérant du salon.",
                    timestamp = "À l'instant",
                    type = "SHOP_REQUEST"
                )
            ) + current
        }
    }

    fun respondToShopJoinRequest(requestId: String, accept: Boolean) {
        val req = _shopJoinRequests.value.find { it.id == requestId } ?: return
        val newStatus = if (accept) ShopJoinRequestStatus.ACCEPTED else ShopJoinRequestStatus.REJECTED

        _shopJoinRequests.update { list ->
            list.map { if (it.id == requestId) it.copy(status = newStatus) else it }
        }

        if (accept) {
            // Find shop
            val shop = _shops.value.find { it.id == req.shopId }
            if (shop != null) {
                // Attach barber to shop
                _shops.update { list ->
                    list.map {
                        if (it.id == shop.id && !it.barberIds.contains(req.barberId)) {
                            it.copy(barberIds = it.barberIds + req.barberId)
                        } else it
                    }
                }
                // Update barber workplace
                val updatedWp = BarberWorkplace(
                    type = WorkplaceType.REGISTERED_SHOP,
                    shopId = shop.id,
                    shopName = shop.name,
                    wilaya = shop.wilaya,
                    commune = shop.commune,
                    address = shop.address,
                    latitude = shop.latitude,
                    longitude = shop.longitude
                )
                updateWorkplace(updatedWp, notifyFollowers = true)
            }

            _notifications.update { current ->
                listOf(
                    AppNotification(
                        id = "n_${System.currentTimeMillis()}",
                        title = "Demande acceptée !",
                        message = "Le salon ${req.shopName} a accepté votre affiliation. Votre profil et vos avis restent vôtres !",
                        timestamp = "À l'instant",
                        type = "SHOP_REQUEST"
                    )
                ) + current
            }
        }
    }

    // Work Incomes & Expenses Tracker
    private val initialTransactions = listOf(
        WorkTransaction(
            id = "tx_1",
            type = WorkTransactionType.INCOME,
            customerName = "Amine B. (App RDV)",
            serviceName = "Pack Royal: Coupe + Barbe + Soin",
            serviceAmountDzd = 1200,
            tipAmountDzd = 200,
            paymentMethod = PaymentMethod.CASH,
            dateTime = "Aujourd'hui 11:30",
            linkedBookingId = "bk_1"
        ),
        WorkTransaction(
            id = "tx_2",
            type = WorkTransactionType.INCOME,
            customerName = "Sofiane (Direct)",
            serviceName = "Coupe classique & dégradé",
            serviceAmountDzd = 600,
            tipAmountDzd = 100,
            paymentMethod = PaymentMethod.BARIDIMOB,
            dateTime = "Aujourd'hui 12:15"
        ),
        WorkTransaction(
            id = "tx_3",
            type = WorkTransactionType.EXPENSE,
            expenseCategory = ExpenseCategory.BLADES_RAZORS,
            expenseAmountDzd = 650,
            note = "Boîte de 100 lames rasoirs Derby Pro",
            paymentMethod = PaymentMethod.CASH,
            dateTime = "Aujourd'hui 09:30"
        ),
        WorkTransaction(
            id = "tx_4",
            type = WorkTransactionType.INCOME,
            customerName = "Yacine K.",
            serviceName = "Taille barbe & serviette chaude",
            serviceAmountDzd = 400,
            tipAmountDzd = 50,
            paymentMethod = PaymentMethod.CASH,
            dateTime = "Hier 18:40"
        ),
        WorkTransaction(
            id = "tx_5",
            type = WorkTransactionType.EXPENSE,
            expenseCategory = ExpenseCategory.HAIR_BEARD_PRODUCTS,
            expenseAmountDzd = 1200,
            note = "2x Gel fixation forte + Alcool désinfectant 70°",
            paymentMethod = PaymentMethod.CASH,
            dateTime = "Hier 14:00"
        )
    )

    private val _workTransactions = MutableStateFlow(initialTransactions)
    val workTransactions: StateFlow<List<WorkTransaction>> = _workTransactions.asStateFlow()

    private val _shopArrangement = MutableStateFlow(
        ShopArrangement(
            type = ShopArrangementType.PERCENTAGE,
            percentageRate = 30.0,
            flatMonthlyRentDzd = 15000
        )
    )
    val shopArrangement: StateFlow<ShopArrangement> = _shopArrangement.asStateFlow()

    fun addIncomeTransaction(
        customerName: String?,
        serviceName: String,
        serviceAmountDzd: Int,
        tipAmountDzd: Int,
        paymentMethod: PaymentMethod = PaymentMethod.CASH,
        linkedBookingId: String? = null,
        linkedQueueTicket: Int? = null
    ) {
        val newTx = WorkTransaction(
            id = "tx_${System.currentTimeMillis()}",
            type = WorkTransactionType.INCOME,
            customerName = customerName?.ifBlank { "Client sans rdv" } ?: "Client sans rdv",
            serviceName = serviceName.ifBlank { "Prestation coiffure" },
            serviceAmountDzd = serviceAmountDzd,
            tipAmountDzd = tipAmountDzd,
            paymentMethod = paymentMethod,
            dateTime = "Aujourd'hui",
            linkedBookingId = linkedBookingId,
            linkedQueueTicket = linkedQueueTicket
        )
        _workTransactions.update { listOf(newTx) + it }
    }

    fun addExpenseTransaction(
        category: ExpenseCategory,
        amountDzd: Int,
        note: String,
        paymentMethod: PaymentMethod = PaymentMethod.CASH
    ) {
        val newTx = WorkTransaction(
            id = "tx_${System.currentTimeMillis()}",
            type = WorkTransactionType.EXPENSE,
            expenseCategory = category,
            expenseAmountDzd = amountDzd,
            note = note.ifBlank { category.labelFr },
            paymentMethod = paymentMethod,
            dateTime = "Aujourd'hui"
        )
        _workTransactions.update { listOf(newTx) + it }
    }

    fun deleteTransaction(transactionId: String) {
        _workTransactions.update { list -> list.filterNot { it.id == transactionId } }
    }

    fun updateShopArrangement(arrangement: ShopArrangement) {
        _shopArrangement.value = arrangement
    }

    // Account Authentication & Role Provisioning
    private val initialRegisteredAccounts = listOf(
        UserAccount(
            id = "acc_barber_karim",
            fullName = "Karim 'Le Ciseau d'Or'",
            phoneNumber = "0550123456",
            role = UserRole.BARBER,
            password = "1234",
            targetAudience = TargetAudience.MEN,
            shopOrBarberName = "Salon Le Diplomate Alger",
            experienceYears = 9,
            workplaceType = WorkplaceType.REGISTERED_SHOP,
            selectedSpecialties = listOf("Dégradé Américain", "Taille Barbe", "Soin Vapeur")
        ),
        UserAccount(
            id = "acc_stylist_yasmine",
            fullName = "Yasmine Beauté Dames",
            phoneNumber = "0551223344",
            role = UserRole.BARBER,
            password = "1234",
            targetAudience = TargetAudience.WOMEN,
            shopOrBarberName = "Institut & Salon Reine de Saba",
            experienceYears = 8,
            workplaceType = WorkplaceType.REGISTERED_SHOP,
            selectedSpecialties = listOf("Coupe & Brushing", "Lissage Kératine", "Manucure Russe", "Hydrafacial")
        ),
        UserAccount(
            id = "acc_home_lina",
            fullName = "Lina Beauté à Domicile",
            phoneNumber = "0552334455",
            role = UserRole.HOME_ARTIST,
            password = "1234",
            targetAudience = TargetAudience.WOMEN,
            shopOrBarberName = "Beauté Mobile à Domicile (Dames)",
            experienceYears = 7,
            workplaceType = WorkplaceType.FREELANCE_MOBILE,
            selectedSpecialties = listOf("Coiffure & Brushing", "Manucure Russe", "Pédicure Spa", "Maquillage Soirée/Mariée"),
            serviceRadiusKm = 20,
            travelFeeDzd = 600,
            coveredZones = "Hydra, Sidi Yahia, Kouba, Birkhadem"
        ),
        UserAccount(
            id = "acc_home_amine",
            fullName = "Amine VIP à Domicile",
            phoneNumber = "0770456789",
            role = UserRole.HOME_ARTIST,
            password = "1234",
            targetAudience = TargetAudience.MEN,
            shopOrBarberName = "Service Mobile à Domicile",
            experienceYears = 12,
            workplaceType = WorkplaceType.FREELANCE_MOBILE,
            selectedSpecialties = listOf("Pack Domicile VIP", "Taille Barbe", "Pack Marié"),
            serviceRadiusKm = 25,
            travelFeeDzd = 500,
            coveredZones = "Hydra, El Biar, Ben Aknoun, Dely Ibrahim"
        ),
        UserAccount(
            id = "acc_customer_amine",
            fullName = "Amine Benali",
            phoneNumber = "0555001122",
            role = UserRole.CUSTOMER,
            password = "1234",
            preferredAudience = TargetAudience.MEN
        ),
        UserAccount(
            id = "acc_owner_sarah",
            fullName = "Sarah (Institut Reine de Saba)",
            phoneNumber = "0550998877",
            role = UserRole.SHOP_OWNER,
            password = "1234",
            targetAudience = TargetAudience.WOMEN,
            shopOrBarberName = "Institut & Salon Reine de Saba",
            chairCountLabel = "3 - 5 postes",
            openingHours = "09:30 - 19:30",
            amenities = listOf("100% Femmes", "Espace Voile Privé", "Onglerie Russe", "Cabine Skincare"),
            ownerAlsoWorksChair = true
        )
    )

    private val _registeredAccounts = MutableStateFlow(initialRegisteredAccounts)
    val registeredAccounts: StateFlow<List<UserAccount>> = _registeredAccounts.asStateFlow()

    fun authenticateUser(phoneInput: String, passwordInput: String): UserAccount? {
        val normalizedPhone = phoneInput.replace(" ", "").replace("+213", "0").trim()
        val matched = _registeredAccounts.value.find { acc ->
            val accNormalized = acc.phoneNumber.replace(" ", "").replace("+213", "0").trim()
            accNormalized == normalizedPhone && acc.password == passwordInput
        }
        if (matched != null) {
            applyAccountToWorkspace(matched)
        }
        return matched
    }

    fun registerNewAccount(account: UserAccount) {
        _registeredAccounts.update { list -> listOf(account) + list }
        applyAccountToWorkspace(account)
    }

    fun applyAccountToWorkspace(account: UserAccount) {
        when (account.role) {
            UserRole.BARBER, UserRole.HOME_ARTIST -> {
                val isHomeArtist = account.role == UserRole.HOME_ARTIST || account.workplaceType == WorkplaceType.FREELANCE_MOBILE
                val isWomen = account.targetAudience == TargetAudience.WOMEN
                val servicesList = if (account.selectedSpecialties.isNotEmpty()) {
                    account.selectedSpecialties.mapIndexed { idx, spec ->
                        buildServiceItemFromLabel(
                            name = spec,
                            targetAudience = account.targetAudience,
                            isHomeArtist = isHomeArtist,
                            indexHint = idx
                        ).copy(id = "srv_custom_$idx")
                    }
                } else {
                    _barberProfile.value.services
                }

                val effectiveWorkplaceType = if (account.role == UserRole.HOME_ARTIST) WorkplaceType.FREELANCE_MOBILE else account.workplaceType
                val newWorkplace = BarberWorkplace(
                    type = effectiveWorkplaceType,
                    shopName = account.shopOrBarberName.ifBlank {
                        when (effectiveWorkplaceType) {
                            WorkplaceType.FREELANCE_MOBILE -> if (isWomen) "Beauté Mobile à Domicile (Dames)" else "Service Mobile à Domicile"
                            WorkplaceType.CUSTOM_LOCATION -> if (isWomen) "Studio Beauté Privé" else "Atelier Coiffure"
                            WorkplaceType.REGISTERED_SHOP -> if (isWomen) "Institut de Beauté Partenaire" else "Salon Partenaire"
                        }
                    },
                    wilaya = account.wilaya,
                    commune = account.commune,
                    address = if (isHomeArtist) account.coveredZones.ifBlank { account.locationLabel } else account.locationLabel,
                    latitude = account.latitude,
                    longitude = account.longitude,
                    serviceRadiusKm = account.serviceRadiusKm
                )

                val newBarberProfile = _barberProfile.value.copy(
                    id = account.id,
                    name = account.fullName,
                    phone = account.phoneNumber,
                    avatarUrl = account.avatarUrl,
                    targetAudience = account.targetAudience,
                    specialtyTitle = when {
                        isHomeArtist && isWomen -> "Artiste Beauté à Domicile Dames"
                        isHomeArtist -> "Barbier à Domicile VIP"
                        isWomen -> "Coiffeuse & Esthéticienne Dames"
                        else -> "Maître Barbier"
                    },
                    experienceYears = account.experienceYears,
                    currentWorkplace = newWorkplace,
                    services = servicesList,
                    offersHomeService = isHomeArtist,
                    homeServiceFeeDzd = account.travelFeeDzd,
                    homeServiceRadiusKm = account.serviceRadiusKm,
                    homeServiceZones = account.coveredZones,
                    bio = if (account.selectedSpecialties.isNotEmpty()) {
                        val homeTag = if (isHomeArtist) "Intervention à domicile (Rayon ${account.serviceRadiusKm} km • Kit stérilisé). " else ""
                        "${homeTag}Spécialités : ${account.selectedSpecialties.joinToString(", ")}."
                    } else _barberProfile.value.bio
                )
                _barberProfile.value = newBarberProfile
                if (_allBarbers.value.none { it.id == newBarberProfile.id }) {
                    _allBarbers.update { listOf(newBarberProfile) + it }
                } else {
                    _allBarbers.update { list -> list.map { if (it.id == newBarberProfile.id) newBarberProfile else it } }
                }
            }

            UserRole.SHOP_OWNER -> {
                val isWomen = account.targetAudience == TargetAudience.WOMEN
                val shopId = "shop_${account.id}"
                val shopServicesList = if (account.selectedSpecialties.isNotEmpty()) {
                    account.selectedSpecialties.mapIndexed { idx, spec ->
                        buildServiceItemFromLabel(
                            name = spec,
                            targetAudience = account.targetAudience,
                            indexHint = idx
                        ).copy(id = "shop_srv_${account.id}_$idx")
                    }
                } else {
                    emptyList()
                }
                val newShop = Shop(
                    id = shopId,
                    name = account.shopOrBarberName.ifBlank { if (isWomen) "Institut de Beauté ${account.fullName}" else "Salon ${account.fullName}" },
                    targetAudience = account.targetAudience,
                    categorySubtitle = when (account.targetAudience) {
                        TargetAudience.WOMEN -> "Salon de Beauté, Coiffure & Soins Dames (${account.chairCountLabel})"
                        TargetAudience.MEN -> "Salon de Coiffure & Barbier Hommes (${account.chairCountLabel})"
                    },
                    wilaya = account.wilaya,
                    commune = account.commune,
                    address = account.locationLabel,
                    latitude = account.latitude,
                    longitude = account.longitude,
                    phone = account.phoneNumber,
                    openingHours = account.openingHours,
                    amenities = account.amenities.ifEmpty {
                        if (isWomen) listOf("100% Femmes", "Espace Voile Privé", "Onglerie", "Soins Visage")
                        else listOf("Climatisation", "Wi-Fi Gratuit", "Paiement Cash / BaridiMob")
                    },
                    barberIds = if (account.ownerAlsoWorksChair) listOf(account.id) else emptyList(),
                    rating = 5.0,
                    avatarUrl = account.avatarUrl,
                    services = shopServicesList
                )
                if (_shops.value.none { it.id == shopId }) {
                    _shops.update { listOf(newShop) + it }
                } else {
                    _shops.update { list -> list.map { if (it.id == shopId) newShop else it } }
                }
                if (account.ownerAlsoWorksChair) {
                    val ownerChairProfile = _barberProfile.value.copy(
                        id = account.id,
                        name = account.fullName,
                        phone = account.phoneNumber,
                        avatarUrl = account.avatarUrl,
                        targetAudience = account.targetAudience,
                        specialtyTitle = if (isWomen) "Gérante & Styliste Dames" else "Gérant & Maître Barbier",
                        services = if (shopServicesList.isNotEmpty()) shopServicesList else _barberProfile.value.services,
                        currentWorkplace = BarberWorkplace(
                            type = WorkplaceType.REGISTERED_SHOP,
                            shopId = shopId,
                            shopName = newShop.name,
                            wilaya = newShop.wilaya,
                            commune = newShop.commune,
                            address = newShop.address
                        )
                    )
                    _barberProfile.value = ownerChairProfile
                    if (_allBarbers.value.none { it.id == ownerChairProfile.id }) {
                        _allBarbers.update { listOf(ownerChairProfile) + it }
                    } else {
                        _allBarbers.update { list -> list.map { if (it.id == ownerChairProfile.id) ownerChairProfile else it } }
                    }
                }
            }

            UserRole.CUSTOMER -> {
                // Nothing to overwrite in barber/shop lists
            }
        }
    }
}

