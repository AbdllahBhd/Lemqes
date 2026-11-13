package com.example

import com.example.data.MockRepository
import com.example.model.TargetAudience
import com.example.model.UserAccount
import com.example.model.UserRole
import com.example.model.WorkplaceType
import com.example.ui.components.presetServiceCatalogFor
import com.example.viewmodel.LemqesViewModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LemqesProfileAndServicesTest {

    @Test
    fun `barber and home artist registration saves avatarUrl and preset plus custom services`() {
        val repo = MockRepository()
        val vm = LemqesViewModel(repo)

        val barberAccount = UserAccount(
            id = "barber_photo_test",
            fullName = "Nassim Cut",
            phoneNumber = "0551112233",
            role = UserRole.BARBER,
            targetAudience = TargetAudience.MEN,
            avatarUrl = "content://media/picker/barber_nassim.jpg",
            selectedSpecialties = listOf("Dégradé Américain", "Soin Charbon Custom")
        )
        vm.registerUser(barberAccount)

        val activeProfile = repo.barberProfile.value
        assertEquals("content://media/picker/barber_nassim.jpg", activeProfile.avatarUrl)
        assertEquals(2, activeProfile.services.size)
        assertTrue(activeProfile.services.any { it.nameFr == "Dégradé Américain" })
        assertTrue(activeProfile.services.any { it.nameFr == "Soin Charbon Custom" })
        assertEquals(
            "content://media/picker/barber_nassim.jpg",
            repo.allBarbers.value.first { it.id == "barber_photo_test" }.avatarUrl
        )

        val homeArtistAccount = UserAccount(
            id = "home_photo_test",
            fullName = "Meriem Home Glow",
            phoneNumber = "0552223344",
            role = UserRole.HOME_ARTIST,
            targetAudience = TargetAudience.WOMEN,
            workplaceType = WorkplaceType.FREELANCE_MOBILE,
            avatarUrl = "content://media/picker/artist_meriem.jpg",
            selectedSpecialties = listOf("Manucure Russe & Gel", "Henna Bridal Custom")
        )
        vm.registerUser(homeArtistAccount)

        val homeProfile = repo.barberProfile.value
        assertEquals("content://media/picker/artist_meriem.jpg", homeProfile.avatarUrl)
        assertTrue(homeProfile.services.any { it.nameFr == "Manucure Russe & Gel" })
        assertTrue(homeProfile.services.any { it.nameFr == "Henna Bridal Custom" })
    }

    @Test
    fun `shop owner registration saves shop avatarUrl and offered services`() {
        val repo = MockRepository()
        val vm = LemqesViewModel(repo)

        val ownerAccount = UserAccount(
            id = "owner_photo_test",
            fullName = "Kenza Owner",
            phoneNumber = "0553334455",
            role = UserRole.SHOP_OWNER,
            targetAudience = TargetAudience.WOMEN,
            shopOrBarberName = "Palais Beauté Kenza",
            avatarUrl = "content://media/picker/shop_kenza.jpg",
            selectedSpecialties = listOf("Lissage Kératine & Protéine", "Extension Cils Volume Custom"),
            ownerAlsoWorksChair = true
        )
        vm.registerUser(ownerAccount)

        val createdShop = repo.shops.value.first { it.id == "shop_owner_photo_test" }
        assertEquals("content://media/picker/shop_kenza.jpg", createdShop.avatarUrl)
        assertEquals(2, createdShop.services.size)
        assertTrue(createdShop.services.any { it.nameFr == "Lissage Kératine & Protéine" })
        assertTrue(createdShop.services.any { it.nameFr == "Extension Cils Volume Custom" })
        assertEquals("content://media/picker/shop_kenza.jpg", repo.barberProfile.value.avatarUrl)
    }

    @Test
    fun `live updating barber and shop avatars and preset or custom services works end to end`() {
        val repo = MockRepository()
        val vm = LemqesViewModel(repo)

        // Update Barber avatar + add/toggle/remove services
        vm.updateBarberAvatar("content://media/picker/new_barber.jpg")
        assertEquals("content://media/picker/new_barber.jpg", repo.barberProfile.value.avatarUrl)
        assertEquals(
            "content://media/picker/new_barber.jpg",
            repo.allBarbers.value.first { it.id == repo.barberProfile.value.id }.avatarUrl
        )

        val beforeCount = repo.barberProfile.value.services.size
        vm.addCustomBarberService("Masque Or 24K", priceDzd = 1800, durationMinutes = 40)
        val addedCustom = repo.barberProfile.value.services.first { it.nameFr == "Masque Or 24K" }
        assertEquals(1800, addedCustom.priceDzd)
        assertEquals(40, addedCustom.durationMinutes)
        assertEquals(beforeCount + 1, repo.barberProfile.value.services.size)

        vm.togglePresetBarberService("Taille Barbe")
        assertTrue(repo.barberProfile.value.services.any { it.nameFr == "Taille Barbe" })

        vm.removeBarberService(addedCustom.id)
        assertFalse(repo.barberProfile.value.services.any { it.nameFr == "Masque Or 24K" })

        // Update Shop avatar + add/toggle/remove services
        val shopId = repo.shops.value.first().id
        vm.updateShopAvatar(shopId, "content://media/picker/new_shop.jpg")
        assertEquals("content://media/picker/new_shop.jpg", repo.shops.value.first { it.id == shopId }.avatarUrl)

        vm.addCustomShopService(shopId, "Soin Vapozone Custom", priceDzd = 1200, durationMinutes = 35)
        val shopCustom = repo.shops.value.first { it.id == shopId }.services.first { it.nameFr == "Soin Vapozone Custom" }
        assertEquals(1200, shopCustom.priceDzd)
        assertEquals(35, shopCustom.durationMinutes)

        vm.removeShopService(shopId, shopCustom.id)
        assertFalse(repo.shops.value.first { it.id == shopId }.services.any { it.nameFr == "Soin Vapozone Custom" })
    }

    @Test
    fun `preset service catalogs stay strictly separated between MEN and WOMEN`() {
        val menPresets = presetServiceCatalogFor(TargetAudience.MEN, isHomeArtist = false)
        val womenPresets = presetServiceCatalogFor(TargetAudience.WOMEN, isHomeArtist = false)

        assertTrue(menPresets.any { it.contains("Barbe", ignoreCase = true) })
        assertTrue(womenPresets.any { it.contains("Manucure", ignoreCase = true) })
        assertFalse(menPresets.any { it.contains("Manucure", ignoreCase = true) || it.contains("Maquillage", ignoreCase = true) })
        assertFalse(womenPresets.any { it.contains("Barbe", ignoreCase = true) })
    }
}
