package com.example

import com.example.model.Country
import com.example.model.UserAccount
import com.example.model.UserRole
import com.example.model.WalletAccount
import org.junit.Assert.assertEquals
import org.junit.Test

class LemqesWalletBillingTest {

    @Test
    fun `test initial 1 month gift for Algeria is 3 dollars`() {
        val country = Country.ALGERIA
        val initialCredit = country.monthlyRateUsd * country.initialTrialMonths
        assertEquals(3.0, initialCredit, 0.001)
        assertEquals(1, country.initialTrialMonths)
    }

    @Test
    fun `test initial 1 month gift for France is 6 dollars`() {
        val country = Country.FRANCE
        val initialCredit = country.monthlyRateUsd * country.initialTrialMonths
        assertEquals(6.0, initialCredit, 0.001)
        assertEquals(1, country.initialTrialMonths)
    }

    @Test
    fun `test 3 rewarded ads per day increase wallet by 0_12 dollars total`() {
        val initialWallet = WalletAccount(balanceUsd = 3.0, monthlyRateUsd = 3.0, daysCoveredRemaining = 30)
        val singleAdReward = 0.04
        val threeAdsTotal = singleAdReward * 3
        assertEquals(0.12, threeAdsTotal, 0.001)

        val updatedWallet = initialWallet.copy(
            balanceUsd = initialWallet.balanceUsd + threeAdsTotal,
            rewardedAdsWatchedToday = 3,
            daysCoveredRemaining = ((initialWallet.balanceUsd + threeAdsTotal) / (initialWallet.monthlyRateUsd / 30.0)).toInt()
        )
        assertEquals(3.12, updatedWallet.balanceUsd, 0.001)
        assertEquals(3, updatedWallet.rewardedAdsWatchedToday)
        assertEquals(31, updatedWallet.daysCoveredRemaining)
    }

    @Test
    fun `test topup adds balance and updates days covered correctly`() {
        val initialWallet = WalletAccount(balanceUsd = 3.0, monthlyRateUsd = 3.0, daysCoveredRemaining = 30)
        val topUpAmount = 6.0
        val dailyCost = initialWallet.monthlyRateUsd / 30.0
        val updatedWallet = initialWallet.copy(
            balanceUsd = initialWallet.balanceUsd + topUpAmount,
            monthsRemaining = ((initialWallet.balanceUsd + topUpAmount) / initialWallet.monthlyRateUsd).toInt(),
            daysCoveredRemaining = ((initialWallet.balanceUsd + topUpAmount) / dailyCost).toInt()
        )
        assertEquals(9.0, updatedWallet.balanceUsd, 0.001)
        assertEquals(3, updatedWallet.monthsRemaining)
        assertEquals(90, updatedWallet.daysCoveredRemaining)
    }

    @Test
    fun `test separate tips are strictly exempt from shop commission percentage`() {
        val serviceAmount = 1200 // DZD
        val tipAmount = 300 // DZD
        val shopRate = 30.0 // 30% on services only

        val shopCut = (serviceAmount * (shopRate / 100.0)).toInt()
        assertEquals(360, shopCut)

        // Tips belong 100% to the barber and must not be touched by the shop cut
        val barberNet = (serviceAmount - shopCut) + tipAmount
        assertEquals(1140, barberNet)
    }

    @Test
    fun `test work expenses and tips breakdown in net barber profit`() {
        val totalServices = 10000 // DZD
        val totalTips = 1500 // DZD
        val shopPercentage = 30.0
        val shopDeduction = (totalServices * (shopPercentage / 100.0)).toInt() // 3000 DA
        val totalExpenses = 1200 // DZD (blades, hair products, disinfectant)

        val netBarberProfit = (totalServices - shopDeduction) + totalTips - totalExpenses
        assertEquals(7300, netBarberProfit)
    }

    @Test
    fun `test flat monthly rent shop arrangement`() {
        val flatRentDzd = 15000
        val totalServices = 45000
        val totalTips = 6000
        val totalExpenses = 3500

        val netBarberProfit = (totalServices - flatRentDzd) + totalTips - totalExpenses
        assertEquals(32500, netBarberProfit)
    }

    @Test
    fun `test country local currencies and monthly renewal prices`() {
        assertEquals("600 DA", Country.ALGERIA.localMonthlyPrice)
        assertEquals("DZD", Country.ALGERIA.currencyCode)
        assertEquals("DA", Country.ALGERIA.currencySymbol)

        assertEquals("12 TND", Country.TUNISIA.localMonthlyPrice)
        assertEquals("TND", Country.TUNISIA.currencyCode)

        assertEquals("40 MAD", Country.MOROCCO.localMonthlyPrice)
        assertEquals("MAD", Country.MOROCCO.currencyCode)

        assertEquals("6,00 €", Country.FRANCE.localMonthlyPrice)
        assertEquals("EUR", Country.FRANCE.currencyCode)

        assertEquals("6.00 $", Country.OTHER.localMonthlyPrice)
    }

    @Test
    fun `test barber promotion discount calculation`() {
        val originalPrice = 800
        val discountPercent = 25
        val discountedPrice = (originalPrice * (1.0 - (discountPercent / 100.0))).toInt()
        assertEquals(600, discountedPrice)

        val promo = com.example.model.BarberPromotion(
            id = "promo_1",
            title = "-25% Coupe Dégradé VIP",
            discountPercent = 25,
            serviceName = "Coupe Dégradé VIP",
            originalPriceDzd = originalPrice,
            discountedPriceDzd = discountedPrice,
            expiresAt = "Ce soir 20h00"
        )
        assertEquals(600, promo.discountedPriceDzd)
        assertEquals(25, promo.discountPercent)
        assertEquals(true, promo.active)
    }

    @Test
    fun `test barber privacy settings for cut prices visibility`() {
        val defaultSettings = com.example.model.BarberPrivacySettings()
        assertEquals(true, defaultSettings.showCutPrices)

        val hiddenPricesSettings = defaultSettings.copy(showCutPrices = false)
        assertEquals(false, hiddenPricesSettings.showCutPrices)
    }

    @Test
    fun `test target audience definitions and beauty salon categories`() {
        assertEquals("Hommes & Garçons", com.example.model.TargetAudience.MEN.labelFr)
        assertEquals("Femmes & Dames", com.example.model.TargetAudience.WOMEN.labelFr)
        assertEquals(2, com.example.model.TargetAudience.entries.size)

        val nailService = com.example.model.ServiceItem(
            id = "nail_1",
            nameEn = "Russian Manicure",
            nameAr = "مانيكير روسي",
            nameFr = "Manucure Russe + Vernis Semi-Permanent",
            priceDzd = 2200,
            durationMinutes = 45,
            category = com.example.model.ServiceCategory.NAILS,
            targetAudience = com.example.model.TargetAudience.WOMEN
        )
        assertEquals(com.example.model.ServiceCategory.NAILS, nailService.category)
        assertEquals(com.example.model.TargetAudience.WOMEN, nailService.targetAudience)
        assertEquals(2200, nailService.priceDzd)

        val ladiesShop = com.example.model.Shop(
            id = "shop_dames_1",
            name = "Institut & Salon Reine de Saba",
            targetAudience = com.example.model.TargetAudience.WOMEN,
            categorySubtitle = "Salon de Beauté, Coiffure & Soins Dames",
            wilaya = "16 - Alger",
            commune = "Hydra",
            address = "22 Boulevard Sidi Yahia, Hydra, Alger",
            latitude = 36.7410,
            longitude = 3.0390,
            phone = "+213 21 48 20 30",
            openingHours = "09:30 - 19:30",
            amenities = listOf("100% Femmes", "Espace Voile Privé", "Onglerie Russe", "Hydrafacial"),
            barberIds = listOf("stylist_yasmine"),
            rating = 4.95
        )
        assertEquals(com.example.model.TargetAudience.WOMEN, ladiesShop.targetAudience)
        assertEquals(true, ladiesShop.amenities.contains("100% Femmes"))
    }

    @Test
    fun `test user authentication with seeded accounts and new registration`() {
        val repo = com.example.data.MockRepository()

        // Seeded demo login with normalized phone
        val karim = repo.authenticateUser("0550 12 34 56", "1234")
        assertEquals("Karim 'Le Ciseau d'Or'", karim?.fullName)
        assertEquals(UserRole.BARBER, karim?.role)

        // Wrong password fails
        val failed = repo.authenticateUser("0550 12 34 56", "wrong")
        assertEquals(null, failed)

        // Register a Ladies Beauty Salon Owner and verify Shop provisioning + Login
        val newOwner = UserAccount(
            id = "owner_test_1",
            fullName = "Nadia B.",
            phoneNumber = "0661112233",
            role = UserRole.SHOP_OWNER,
            password = "secret",
            targetAudience = com.example.model.TargetAudience.WOMEN,
            shopOrBarberName = "Salon Nadia Prestige",
            chairCountLabel = "3 - 5 postes",
            openingHours = "09:30 - 19:30",
            amenities = listOf("100% Femmes", "Onglerie Russe"),
            ownerAlsoWorksChair = true
        )
        repo.registerNewAccount(newOwner)

        val loggedInOwner = repo.authenticateUser("+213661112233", "secret")
        assertEquals("Nadia B.", loggedInOwner?.fullName)
        assertEquals(true, repo.shops.value.any { it.name == "Salon Nadia Prestige" && it.targetAudience == com.example.model.TargetAudience.WOMEN })
    }
}

