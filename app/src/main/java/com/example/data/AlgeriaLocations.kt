package com.example.data

object AlgeriaLocations {
    data class Wilaya(val code: Int, val name: String, val communes: List<String>)

    val wilayas = listOf(
        Wilaya(16, "16 - Alger", listOf("Bab El Oued", "Sidi M'Hamed", "Hydra", "Kouba", "Bordj El Kiffan", "Dely Ibrahim", "El Biar", "Hussein Dey", "Cheraga", "Bir Mourad Raïs")),
        Wilaya(31, "31 - Oran", listOf("Oran Centre", "Es Senia", "Bir El Djir", "Ain El Turk", "Arzew", "Bethioua")),
        Wilaya(25, "25 - Constantine", listOf("Constantine Centre", "El Khroub", "Ain Smara", "Hamma Bouziane", "Ali Mendjeli")),
        Wilaya(15, "15 - Tizi Ouzou", listOf("Tizi Ouzou Centre", "Azazga", "Draa Ben Khedda", "Boghni", "Larbaa Nath Irathen")),
        Wilaya(6, "06 - Béjaïa", listOf("Béjaïa Centre", "Akbou", "El Kseur", "Amizour", "Sidi Aïch")),
        Wilaya(19, "19 - Sétif", listOf("Sétif Centre", "El Eulma", "Ain Oulmene", "Ain Arnat")),
        Wilaya(9, "09 - Blida", listOf("Blida Centre", "Boufarik", "Ouled Yaich", "Mouzaia")),
        Wilaya(23, "23 - Annaba", listOf("Annaba Centre", "El Bouni", "Sidi Amar", "Berrahal")),
        Wilaya(13, "13 - Tlemcen", listOf("Tlemcen Centre", "Mansourah", "Chetouane", "Maghnia")),
        Wilaya(30, "30 - Ouargla", listOf("Ouargla Centre", "Hassi Messaoud", "Rouissat")),
        Wilaya(47, "47 - Ghardaïa", listOf("Ghardaïa Centre", "Metlili", "El Guerrara", "Béni Isguen")),
        Wilaya(35, "35 - Boumerdès", listOf("Boumerdès Centre", "Zemmouri", "Dellys", "Boudouaou"))
    )
}
