package com.example.i18n

enum class SupportedLanguage(
    val code: String,
    val displayName: String,
    val nativeName: String,
    val isRtl: Boolean
) {
    AR("ar", "Arabic (العربية)", "العربية", true),
    FR("fr", "French (Français)", "Français", false),
    EN("en", "English", "English", false),
    TZ("tz", "Tamazight (ⵜⴰⵎⴰⵣⵉⵖⵜ / Taqbaylit)", "ⵜⴰⵎⴰⵣⵉⵖⵜ", false)
}

object StringsManager {
    private val translations = mapOf(
        "app_tagline" to mapOf(
            "ar" to "منصة الحلاقة الذكية الأولى في الجزائر",
            "fr" to "La première plateforme pour barbiers en Algérie",
            "en" to "Algeria's premier modern barber platform",
            "tz" to "Tafsna tamezwarut n wemḥeffaf deg Lezzayer"
        ),
        "role_barber" to mapOf(
            "ar" to "أنا حلاق",
            "fr" to "Je suis Barbier",
            "en" to "I am a Barber",
            "tz" to "Nekk d amḥeffaf"
        ),
        "role_customer" to mapOf(
            "ar" to "أنا زبون",
            "fr" to "Je suis Client",
            "en" to "I am a Client",
            "tz" to "Nekk d amsaɣ"
        ),
        "role_shop" to mapOf(
            "ar" to "صاحب صالون",
            "fr" to "Gérant de salon",
            "en" to "Salon Owner",
            "tz" to "Bab n tḥanut"
        ),
        "status_online" to mapOf(
            "ar" to "متاح الآن",
            "fr" to "Disponible",
            "en" to "Available (Online)",
            "tz" to "Yella tura"
        ),
        "status_break" to mapOf(
            "ar" to "في استراحة",
            "fr" to "En pause",
            "en" to "On Break",
            "tz" to "Deg usgunfu"
        ),
        "status_offline" to mapOf(
            "ar" to "مغلق",
            "fr" to "Fermé",
            "en" to "Offline",
            "tz" to "Imdel"
        ),
        "live_queue" to mapOf(
            "ar" to "طابور الانتظار المباشر",
            "fr" to "File d'attente en direct",
            "en" to "Live Queue",
            "tz" to "Abrid n uraju srid"
        ),
        "people_waiting" to mapOf(
            "ar" to "أشخاص ينتظرون",
            "fr" to "personnes en attente",
            "en" to "people waiting",
            "tz" to "yemdanen ttrajunt"
        ),
        "est_wait" to mapOf(
            "ar" to "وقت الانتظار التقريبي",
            "fr" to "Attente estimée",
            "en" to "Est. wait time",
            "tz" to "Akud n uraju"
        ),
        "action_walk_in" to mapOf(
            "ar" to "+1 زبون مباشر",
            "fr" to "+1 Sans rdv",
            "en" to "+1 Walk-in",
            "tz" to "+1 War arwaḥ"
        ),
        "action_done" to mapOf(
            "ar" to "-1 تم إنهاء الزبون",
            "fr" to "-1 Terminé",
            "en" to "-1 Customer Done",
            "tz" to "-1 Yefra"
        ),
        "action_call_next" to mapOf(
            "ar" to "نداء الزبون التالي",
            "fr" to "Appeler le suivant",
            "en" to "Call Next Customer",
            "tz" to "Siwel i wayeḍ"
        ),
        "workplace_title" to mapOf(
            "ar" to "مكان العمل الحالي",
            "fr" to "Lieu de travail actuel",
            "en" to "Current Workplace",
            "tz" to "Adeg n umahil n tura"
        ),
        "workplace_change_btn" to mapOf(
            "ar" to "تغيير مكان العمل (خلال 30 ثانية)",
            "fr" to "Changer de salon (en 30s)",
            "en" to "Change Workplace (30s)",
            "tz" to "Beddel adeg n umahil"
        ),
        "broadcast_title" to mapOf(
            "ar" to "إرسال إشعار للمتابعين",
            "fr" to "Diffuser aux abonnés",
            "en" to "Broadcast to Followers",
            "tz" to "Ceyyeɛ i wid i k-yeṭṭafaren"
        ),
        "my_qr_code" to mapOf(
            "ar" to "رمز QR الشخصي الدائم",
            "fr" to "Mon QR Code permanent",
            "en" to "Permanent QR Code",
            "tz" to "Tangalt QR tamezgit"
        ),
        "book_appointment" to mapOf(
            "ar" to "حجز موعد",
            "fr" to "Prendre rendez-vous",
            "en" to "Book Appointment",
            "tz" to "Ṭṭef lweqt"
        ),
        "join_queue" to mapOf(
            "ar" to "الدخول في الطابور عن بعد",
            "fr" to "Rejoindre la file à distance",
            "en" to "Join Live Queue",
            "tz" to "Kcem deg uraju"
        ),
        "directions" to mapOf(
            "ar" to "الاتجاهات (Maps)",
            "fr" to "Itinéraire (Maps)",
            "en" to "Directions (Maps)",
            "tz" to "Abrid n Google Maps"
        ),
        "call_whatsapp" to mapOf(
            "ar" to "اتصال / واتساب",
            "fr" to "Appel / WhatsApp",
            "en" to "Call / WhatsApp",
            "tz" to "Siwel / WhatsApp"
        ),
        "currency_dzd" to mapOf(
            "ar" to "دج",
            "fr" to "DA",
            "en" to "DZD",
            "tz" to "DA"
        ),
        "today_stats" to mapOf(
            "ar" to "إحصائيات اليوم",
            "fr" to "Statistiques du jour",
            "en" to "Today's Overview",
            "tz" to "Ittaftaren n wass-a"
        ),
        "today_served" to mapOf(
            "ar" to "زبائن تمت خدمتهم",
            "fr" to "Clients servis",
            "en" to "Clients Served",
            "tz" to "Imsaɣen i kfan"
        ),
        "today_revenue" to mapOf(
            "ar" to "المداخيل المقدرة",
            "fr" to "Recette estimée",
            "en" to "Est. Revenue",
            "tz" to "Idrimen n wass"
        ),
        "barber_portable_badge" to mapOf(
            "ar" to "ملف الحلاق مستقل ويبقى معك أينما انتقلت",
            "fr" to "Profil 100% indépendant qui vous suit partout",
            "en" to "Independent portable profile across all shops",
            "tz" to "Amaɣnu n wemḥeffaf ilelli i k-yeṭṭafaren"
        )
    )

    fun get(key: String, lang: SupportedLanguage): String {
        val keyMap = translations[key] ?: return key
        return keyMap[lang.code] ?: keyMap["en"] ?: key
    }
}
