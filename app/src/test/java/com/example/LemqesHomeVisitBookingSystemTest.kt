package com.example

import com.example.data.MockRepository
import com.example.model.BookingStatus
import com.example.model.PaymentMethod
import com.example.model.TargetAudience
import com.example.ui.components.calculateHaversineKm
import com.example.viewmodel.LemqesViewModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LemqesHomeVisitBookingSystemTest {

    @Test
    fun `available spots reflect existing bookings and artist blocked slots`() {
        val repo = MockRepository()
        val vm = LemqesViewModel(repo)
        val lina = repo.allBarbers.value.first { it.id == "artist_lina_home" }

        // Seeded pending home request occupies Demain 15:00
        val slotsTomorrow = vm.getAvailableHomeSlots(lina, "Demain")
        val slot1500 = slotsTomorrow.first { it.slot == "15:00" }
        val slot1630 = slotsTomorrow.first { it.slot == "16:30" }
        assertFalse(slot1500.isAvailable)
        assertEquals("Déjà réservé", slot1500.reason)
        assertTrue(slot1630.isAvailable)

        // Artist blocks Today 18:00
        repo.applyAccountToWorkspace(repo.registeredAccounts.value.first { it.id == "acc_home_lina" })
        vm.toggleArtistBlockedSlot("Aujourd'hui", "18:00")
        val updatedLina = repo.allBarbers.value.first { it.id == "acc_home_lina" }
        val blockedSlot = vm.getAvailableHomeSlots(updatedLina, "Aujourd'hui").first { it.slot == "18:00" }
        assertFalse(blockedSlot.isAvailable)
        assertEquals("Bloqué par l'artiste", blockedSlot.reason)

        // Unblocking restores availability
        vm.toggleArtistBlockedSlot("Aujourd'hui", "18:00")
        val reopenedLina = repo.allBarbers.value.first { it.id == "acc_home_lina" }
        assertTrue(vm.getAvailableHomeSlots(reopenedLina, "Aujourd'hui").first { it.slot == "18:00" }.isAvailable)
    }

    @Test
    fun `client home visit request saves map coords, contact, multi-services prices, and notifies both client and artist`() {
        val repo = MockRepository()
        val vm = LemqesViewModel(repo)

        val lina = repo.allBarbers.value.first { it.id == "artist_lina_home" }
        val chosenServices = lina.services.take(2) // Brushing 2200 + Manucure 2800 = 5000 + 600 travel = 5600 DA
        val expectedTotal = chosenServices.sumOf { it.priceDzd } + lina.homeServiceFeeDzd

        val booking = vm.submitHomeVisitRequest(
            barber = lina,
            selectedServices = chosenServices,
            date = "Jeudi",
            slot = "16:30",
            customerName = "Kenza M.",
            customerPhone = "0556112233",
            customerAddress = "Hydra, Rue Sidi Yahia, Bât A Apt 5",
            clientLatitude = 36.7490,
            clientLongitude = 3.0520,
            customerNotes = "2 personnes • Sonner interphone 5",
            paymentMethod = PaymentMethod.BARIDIMOB
        )

        assertEquals(BookingStatus.WAITING_APPROVAL, booking.status)
        assertTrue(booking.isHomeService)
        assertEquals(TargetAudience.WOMEN, booking.targetAudience)
        assertEquals("Kenza M.", booking.customerName)
        assertEquals("0556112233", booking.customerPhone)
        assertEquals("Hydra, Rue Sidi Yahia, Bât A Apt 5", booking.customerAddress)
        assertEquals(36.7490, booking.clientLatitude!!, 0.0001)
        assertEquals(3.0520, booking.clientLongitude!!, 0.0001)
        assertNotNull(booking.distanceKm)
        assertEquals(expectedTotal, booking.priceDzd)
        assertEquals(PaymentMethod.BARIDIMOB, booking.paymentMethod)
        assertEquals(2, booking.selectedServices.size)

        // Spot Jeudi 16:30 is now reserved
        val slotAfter = vm.getAvailableHomeSlots(lina, "Jeudi").first { it.slot == "16:30" }
        assertFalse(slotAfter.isAvailable)

        // Both customer and artist received notifications
        val relatedNotifs = repo.notifications.value.filter { it.relatedBookingId == booking.id }
        assertTrue(relatedNotifs.any { it.recipientRole == "CUSTOMER" && it.type == "HOME_REQUEST" })
        assertTrue(relatedNotifs.any { it.recipientRole == "ARTIST" && it.type == "HOME_REQUEST" })
    }

    @Test
    fun `artist confirmation, en-route, arrival, and decline notify both client and artist and manage spot availability`() {
        val repo = MockRepository()
        val vm = LemqesViewModel(repo)

        val amine = repo.allBarbers.value.first { it.id == "barber_amine" }
        val chosen = listOf(amine.services.first())

        val req1 = vm.submitHomeVisitRequest(
            barber = amine,
            selectedServices = chosen,
            date = "Vendredi",
            slot = "11:00",
            customerName = "Walid B.",
            customerPhone = "0771998877",
            customerAddress = "El Biar, Avenue Ali Khodja",
            clientLatitude = 36.7660,
            clientLongitude = 3.0310,
            customerNotes = "Rez-de-chaussée"
        )

        // Artist confirms request
        val confirmNotifs = vm.confirmHomeBooking(req1.id)
        assertEquals(2, confirmNotifs.size)
        assertTrue(confirmNotifs.any { it.recipientRole == "CUSTOMER" && it.type == "HOME_CONFIRMED" })
        assertTrue(confirmNotifs.any { it.recipientRole == "ARTIST" && it.type == "HOME_CONFIRMED" })
        assertEquals(BookingStatus.CONFIRMED, repo.bookings.value.first { it.id == req1.id }.status)

        // Artist on the way & arrived
        val wayNotifs = vm.notifyArtistOnTheWay(req1.id, etaMinutes = 20)
        assertTrue(wayNotifs.any { it.recipientRole == "CUSTOMER" })
        assertTrue(wayNotifs.any { it.recipientRole == "ARTIST" })
        assertTrue(repo.bookings.value.first { it.id == req1.id }.artistOnTheWay)

        val arrivedNotifs = vm.confirmArtistArrivedAtClient(req1.id)
        assertTrue(arrivedNotifs.any { it.recipientRole == "CUSTOMER" })
        assertTrue(arrivedNotifs.any { it.recipientRole == "ARTIST" })
        assertEquals(BookingStatus.ARRIVED_CONFIRMED, repo.bookings.value.first { it.id == req1.id }.status)

        // Second request declined frees up the spot and notifies both
        val req2 = vm.submitHomeVisitRequest(
            barber = amine,
            selectedServices = chosen,
            date = "Vendredi",
            slot = "19:30",
            customerName = "Yacine D.",
            customerPhone = "0550445566",
            customerAddress = "Dely Ibrahim",
            clientLatitude = 36.7580,
            clientLongitude = 2.9850
        )
        assertFalse(vm.getAvailableHomeSlots(amine, "Vendredi").first { it.slot == "19:30" }.isAvailable)

        val declineNotifs = vm.declineHomeBooking(req2.id, "Déplacement hors zone ce soir")
        assertTrue(declineNotifs.any { it.recipientRole == "CUSTOMER" })
        assertTrue(declineNotifs.any { it.recipientRole == "ARTIST" })
        assertEquals(BookingStatus.CANCELLED, repo.bookings.value.first { it.id == req2.id }.status)
        assertTrue(vm.getAvailableHomeSlots(amine, "Vendredi").first { it.slot == "19:30" }.isAvailable)
    }

    @Test
    fun `haversine distance calculation computes accurate km between map coordinates`() {
        val distSamePoint = calculateHaversineKm(36.7420, 3.0480, 36.7420, 3.0480)
        assertEquals(0.0, distSamePoint, 0.01)

        val hydraToDely = calculateHaversineKm(36.7456, 3.0421, 36.7580, 2.9850)
        assertTrue(hydraToDely in 4.0..7.0)
    }
}
