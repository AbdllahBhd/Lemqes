package com.example

import com.example.model.TargetAudience
import com.example.model.UserRole
import com.example.ui.screens.stepTitleForRole
import com.example.ui.screens.totalStepsForRole
import com.example.ui.screens.validateCredentialsStep
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LemqesRegistrationWizardTest {

    @Test
    fun `totalStepsForRole returns 4 for customer and 5 for professional roles`() {
        assertEquals(4, totalStepsForRole(null))
        assertEquals(4, totalStepsForRole(UserRole.CUSTOMER))
        assertEquals(5, totalStepsForRole(UserRole.BARBER))
        assertEquals(5, totalStepsForRole(UserRole.HOME_ARTIST))
        assertEquals(5, totalStepsForRole(UserRole.SHOP_OWNER))
    }

    @Test
    fun `validateCredentialsStep blocks missing fields and password mismatch or short password`() {
        assertNotNull(
            validateCredentialsStep(
                role = null,
                shopName = "",
                fullName = "Amine",
                phoneNumber = "0550123456",
                password = "secret",
                confirmPassword = "secret"
            )
        )

        // Shop owner requires shopName
        assertNotNull(
            validateCredentialsStep(
                role = UserRole.SHOP_OWNER,
                shopName = "  ",
                fullName = "Sarah",
                phoneNumber = "0550123456",
                password = "secret",
                confirmPassword = "secret"
            )
        )

        // Short password < 4 chars
        assertNotNull(
            validateCredentialsStep(
                role = UserRole.CUSTOMER,
                shopName = "",
                fullName = "Amine",
                phoneNumber = "0550123456",
                password = "123",
                confirmPassword = "123"
            )
        )

        // Blank confirm password
        assertNotNull(
            validateCredentialsStep(
                role = UserRole.BARBER,
                shopName = "",
                fullName = "Karim",
                phoneNumber = "0550123456",
                password = "pass",
                confirmPassword = ""
            )
        )

        // Password mismatch
        val mismatchErr = validateCredentialsStep(
            role = UserRole.HOME_ARTIST,
            shopName = "",
            fullName = "Lina",
            phoneNumber = "0550123456",
            password = "pass1",
            confirmPassword = "pass2"
        )
        assertNotNull(mismatchErr)
        assertTrue(mismatchErr!!.contains("correspondent pas", ignoreCase = true))
    }

    @Test
    fun `validateCredentialsStep succeeds when all required fields and confirm password match`() {
        assertNull(
            validateCredentialsStep(
                role = UserRole.CUSTOMER,
                shopName = "",
                fullName = "Amine Benali",
                phoneNumber = "0550123456",
                password = "pass",
                confirmPassword = "pass"
            )
        )

        assertNull(
            validateCredentialsStep(
                role = UserRole.SHOP_OWNER,
                shopName = "Institut Reine",
                fullName = "Sarah B.",
                phoneNumber = "0551987654",
                password = "secret123",
                confirmPassword = "secret123"
            )
        )
    }

    @Test
    fun `stepTitleForRole adapts cleanly for men and women across wizard steps`() {
        assertEquals("Votre espace dédié", stepTitleForRole(1, null, null))
        assertTrue(stepTitleForRole(2, UserRole.CUSTOMER, TargetAudience.MEN).contains("Hommes"))
        assertTrue(stepTitleForRole(2, UserRole.CUSTOMER, TargetAudience.WOMEN).contains("Dames"))
        assertEquals("Identité & Mot de passe", stepTitleForRole(3, UserRole.BARBER, TargetAudience.MEN))
        assertTrue(stepTitleForRole(4, UserRole.HOME_ARTIST, TargetAudience.WOMEN).contains("Domicile"))
        assertTrue(stepTitleForRole(5, UserRole.SHOP_OWNER, TargetAudience.WOMEN).contains("Salon"))
    }
}
