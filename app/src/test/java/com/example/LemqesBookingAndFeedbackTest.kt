package com.example

import com.example.data.MockRepository
import com.example.model.BookingStatus
import com.example.model.FeedbackTargetType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LemqesBookingAndFeedbackTest {

    @Test
    fun `booking sends 1h and 30m reminders and auto cancels at 15m if customer has not arrived`() {
        val repo = MockRepository()
        val barber = repo.allBarbers.value.first()
        val service = barber.services.first()

        val booking = repo.bookAppointment(service, "Aujourd'hui", "18:00", barber, customerName = "Riad")
        assertEquals(BookingStatus.CONFIRMED, booking.status)

        // 1h before reminder
        val n1h = repo.triggerBookingReminder1h(booking.id)
        assertNotNull(n1h)
        assertEquals("REMINDER_1H", n1h?.type)
        assertTrue(n1h!!.message.contains("15 min avant"))
        assertTrue(repo.bookings.value.first { it.id == booking.id }.notified1hBefore)

        // 30m before reminder
        val n30m = repo.triggerBookingReminder30m(booking.id)
        assertNotNull(n30m)
        assertEquals("REMINDER_30M", n30m?.type)
        assertTrue(repo.bookings.value.first { it.id == booking.id }.notified30mBefore)

        // 15m deadline missed -> automatically canceled
        val nAuto = repo.evaluate15MinArrivalDeadline(booking.id)
        assertNotNull(nAuto)
        assertEquals("AUTO_CANCEL", nAuto?.type)
        val updated = repo.bookings.value.first { it.id == booking.id }
        assertEquals(BookingStatus.AUTO_CANCELLED, updated.status)
        assertNotNull(updated.autoCancelReason)
    }

    @Test
    fun `confirming arrival at shop keeps spot safe from 15m auto cancel`() {
        val repo = MockRepository()
        val barber = repo.allBarbers.value.first()
        val service = barber.services.first()

        val booking = repo.bookAppointment(service, "Aujourd'hui", "19:00", barber, customerName = "Nabil")
        val arrivedNotif = repo.confirmArrivalAtShop(booking.id)
        assertNotNull(arrivedNotif)
        assertEquals("ARRIVED", arrivedNotif?.type)

        // Evaluating deadline after arrival must NOT cancel
        val cancelResult = repo.evaluate15MinArrivalDeadline(booking.id)
        assertNull(cancelResult)

        val updated = repo.bookings.value.first { it.id == booking.id }
        assertTrue(updated.hasArrivedAtShop)
        assertEquals(BookingStatus.ARRIVED_CONFIRMED, updated.status)
    }

    @Test
    fun `customer on the way notifies barber with ETA`() {
        val repo = MockRepository()
        val barber = repo.allBarbers.value.first()
        val service = barber.services.first()

        val booking = repo.bookAppointment(service, "Aujourd'hui", "16:30", barber, customerName = "Amine")
        val wayNotif = repo.notifyOnTheWay(booking.id, etaMinutes = 15)
        assertNotNull(wayNotif)
        assertEquals("ON_THE_WAY", wayNotif?.type)
        assertTrue(wayNotif!!.message.contains("15 min"))

        val updated = repo.bookings.value.first { it.id == booking.id }
        assertTrue(updated.isOnTheWay)
        assertEquals(15, updated.etaMinutes)
    }

    @Test
    fun `subscribed customer can anonymously rate and review both barber and salon`() {
        val repo = MockRepository()
        val barber = repo.allBarbers.value.first { it.id == "barber_karim" }
        val shop = repo.shops.value.first { it.id == "shop_1" }
        val initialBarberReviews = barber.reviewCount
        val initialShopReviews = shop.reviewCount

        val created = repo.submitFeedbackReview(
            barberId = barber.id,
            barberName = barber.name,
            barberRating = 5,
            shopId = shop.id,
            shopName = shop.name,
            shopRating = 4,
            comment = "Service impeccable et salon très propre",
            isAnonymousRequested = true,
            customerName = "Amine Benali",
            isSubscribedCustomer = true
        )

        assertEquals(2, created.size)
        val barberRev = created.first { it.targetType == FeedbackTargetType.BARBER }
        val shopRev = created.first { it.targetType == FeedbackTargetType.SHOP }

        assertTrue(barberRev.isAnonymous)
        assertEquals("Client abonné anonyme", barberRev.authorDisplayName)
        assertEquals(5, barberRev.rating)

        assertTrue(shopRev.isAnonymous)
        assertEquals("Client abonné anonyme", shopRev.authorDisplayName)
        assertEquals(4, shopRev.rating)

        assertEquals(initialBarberReviews + 1, repo.allBarbers.value.first { it.id == barber.id }.reviewCount)
        assertEquals(initialShopReviews + 1, repo.shops.value.first { it.id == shop.id }.reviewCount)
    }

    @Test
    fun `non subscribed customer review cannot force anonymous mode`() {
        val repo = MockRepository()
        val barber = repo.allBarbers.value.first { it.id == "barber_mehdi" }

        val created = repo.submitFeedbackReview(
            barberId = barber.id,
            barberName = barber.name,
            barberRating = 4,
            shopId = null,
            shopName = null,
            shopRating = null,
            comment = "Bon accueil",
            isAnonymousRequested = true,
            customerName = "Samir K.",
            isSubscribedCustomer = false
        )

        assertEquals(1, created.size)
        assertFalse(created.first().isAnonymous)
        assertEquals("Samir K.", created.first().authorDisplayName)
    }
}
