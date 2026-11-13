package com.example

import com.example.data.MockRepository
import com.example.model.BookingStatus
import com.example.model.ServiceCategory
import com.example.model.TargetAudience
import com.example.model.UserAccount
import com.example.model.UserRole
import com.example.model.WorkplaceType
import com.example.viewmodel.LemqesViewModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LemqesHomeArtistTest {

    @Test
    fun `registering men and women home artists provisions FREELANCE_MOBILE profiles and specialties`() {
        val repo = MockRepository()

        val menAccount = UserAccount(
            id = "home_men_test",
            fullName = "Walid Domicile",
            phoneNumber = "0559112233",
            role = UserRole.HOME_ARTIST,
            targetAudience = TargetAudience.MEN,
            workplaceType = WorkplaceType.FREELANCE_MOBILE,
            selectedSpecialties = listOf("Coupe & Dégradé à domicile", "Pack Marié VIP"),
            serviceRadiusKm = 20,
            travelFeeDzd = 500,
            coveredZones = "Hydra, El Biar, Kouba"
        )
        repo.registerNewAccount(menAccount)

        val menProfile = repo.barberProfile.value
        assertEquals("home_men_test", menProfile.id)
        assertEquals(WorkplaceType.FREELANCE_MOBILE, menProfile.currentWorkplace.type)
        assertTrue(menProfile.offersHomeService)
        assertEquals(20, menProfile.homeServiceRadiusKm)
        assertEquals(500, menProfile.homeServiceFeeDzd)
        assertEquals("Hydra, El Biar, Kouba", menProfile.homeServiceZones)
        assertEquals(TargetAudience.MEN, menProfile.targetAudience)
        assertEquals(2, menProfile.services.size)

        val womenAccount = UserAccount(
            id = "home_women_test",
            fullName = "Samia Beauté Mobile",
            phoneNumber = "0558445566",
            role = UserRole.HOME_ARTIST,
            targetAudience = TargetAudience.WOMEN,
            workplaceType = WorkplaceType.FREELANCE_MOBILE,
            selectedSpecialties = listOf("Manucure Russe & Gel", "Soin Visage Hydrafacial", "Maquillage Mariée"),
            serviceRadiusKm = 30,
            travelFeeDzd = 800,
            coveredZones = "Sidi Yahia, Dely Ibrahim, Cheraga"
        )
        repo.registerNewAccount(womenAccount)

        val womenProfile = repo.barberProfile.value
        assertEquals("home_women_test", womenProfile.id)
        assertEquals(WorkplaceType.FREELANCE_MOBILE, womenProfile.currentWorkplace.type)
        assertTrue(womenProfile.offersHomeService)
        assertEquals(30, womenProfile.homeServiceRadiusKm)
        assertEquals(800, womenProfile.homeServiceFeeDzd)
        assertEquals("Sidi Yahia, Dely Ibrahim, Cheraga", womenProfile.homeServiceZones)
        assertEquals(TargetAudience.WOMEN, womenProfile.targetAudience)
        assertTrue(womenProfile.services.any { it.category == ServiceCategory.NAILS })
        assertTrue(womenProfile.services.any { it.category == ServiceCategory.SKINCARE })
        assertTrue(womenProfile.services.any { it.category == ServiceCategory.MAKEUP })

        // Both home artists must appear in discoverable allBarbers
        val all = repo.allBarbers.value
        assertTrue(all.any { it.id == "home_men_test" && it.offersHomeService })
        assertTrue(all.any { it.id == "home_women_test" && it.offersHomeService })
    }

    @Test
    fun `updating home service settings updates active barberProfile and discovery list`() {
        val repo = MockRepository()
        repo.updateHomeServiceSettings(
            offersHomeService = true,
            feeDzd = 300,
            radiusKm = 25,
            zones = "Birkhadem, Said Hamdine, Hydra"
        )

        val current = repo.barberProfile.value
        assertTrue(current.offersHomeService)
        assertEquals(300, current.homeServiceFeeDzd)
        assertEquals(25, current.homeServiceRadiusKm)
        assertEquals("Birkhadem, Said Hamdine, Hydra", current.homeServiceZones)

        val listed = repo.allBarbers.value.first { it.id == current.id }
        assertTrue(listed.offersHomeService)
        assertEquals(300, listed.homeServiceFeeDzd)
        assertEquals(25, listed.homeServiceRadiusKm)
    }

    @Test
    fun `confirmBooking for home artist adds travel fee, address, and keeps reminder notifications`() {
        val repo = MockRepository()
        val vm = LemqesViewModel(repo)

        val lina = repo.allBarbers.value.first { it.id == "artist_lina_home" }
        val service = lina.services.first()

        vm.openBookingSheet(service, lina)
        vm.confirmBooking(
            date = "Aujourd'hui",
            timeSlot = "16:30",
            isHomeService = true,
            customerAddress = "Hydra, Rue Djemila Bât B, Apt 4"
        )

        val booked = repo.bookings.value.first()
        assertTrue(booked.isHomeService)
        assertEquals("Hydra, Rue Djemila Bât B, Apt 4", booked.customerAddress)
        assertEquals(lina.homeServiceFeeDzd, booked.travelFeeDzd)
        assertEquals(service.priceDzd + lina.homeServiceFeeDzd, booked.priceDzd)
        assertTrue(booked.locationSnapshot.contains("À domicile"))
        assertEquals(BookingStatus.CONFIRMED, booked.status)

        // Reminder -1h and -30m plus 15m deadline check still work seamlessly for home bookings
        val n1h = vm.triggerBookingReminder1h(booked.id)
        val n30m = vm.triggerBookingReminder30m(booked.id)
        assertNotNull(n1h)
        assertNotNull(n30m)
        val updated = repo.bookings.value.first { it.id == booked.id }
        assertTrue(updated.notified1hBefore)
        assertTrue(updated.notified30mBefore)
    }

    @Test
    fun `audiences are strictly separated into MEN and WOMEN without MIXED`() {
        assertEquals(listOf(TargetAudience.MEN, TargetAudience.WOMEN), TargetAudience.entries)

        val vm = LemqesViewModel()
        assertEquals(TargetAudience.MEN, vm.uiState.value.filterAudience)

        val repo = MockRepository()
        val menHomeBarbers = repo.allBarbers.value.filter { it.offersHomeService && it.targetAudience == TargetAudience.MEN }
        val womenHomeBarbers = repo.allBarbers.value.filter { it.offersHomeService && it.targetAudience == TargetAudience.WOMEN }
        assertTrue(menHomeBarbers.isNotEmpty())
        assertTrue(womenHomeBarbers.isNotEmpty())
        assertTrue(menHomeBarbers.none { it.targetAudience == TargetAudience.WOMEN })
        assertTrue(womenHomeBarbers.none { it.targetAudience == TargetAudience.MEN })
    }
}
