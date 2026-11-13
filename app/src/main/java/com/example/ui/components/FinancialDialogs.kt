package com.example.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.example.model.*
import com.example.ui.theme.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FastCashInBottomSheet(
    preFillCustomer: QueueCustomer?,
    queue: List<QueueCustomer>,
    bookings: List<BookingRecord>,
    services: List<ServiceItem>,
    onDismiss: () -> Unit,
    onConfirm: (
        customerName: String?,
        serviceName: String,
        serviceAmountDzd: Int,
        tipAmountDzd: Int,
        paymentMethod: PaymentMethod,
        finishQueueCustomer: Boolean
    ) -> Unit
) {
    var customerName by remember { mutableStateOf(preFillCustomer?.customerName ?: "") }
    var serviceName by remember { mutableStateOf(preFillCustomer?.serviceName ?: (services.firstOrNull()?.nameFr ?: "Coupe classique")) }
    var serviceAmountText by remember { mutableStateOf(preFillCustomer?.priceDzd?.toString() ?: (services.firstOrNull()?.priceDzd?.toString() ?: "600")) }
    var tipAmountText by remember { mutableStateOf("0") }
    var selectedPaymentMethod by remember { mutableStateOf(PaymentMethod.CASH) }
    var finishCustomerCheckbox by remember { mutableStateOf(preFillCustomer != null) }

    val serviceAmount = serviceAmountText.toIntOrNull() ?: 0
    val tipAmount = tipAmountText.toIntOrNull() ?: 0
    val totalReceived = serviceAmount + tipAmount

    val tipPresets = listOf(0, 50, 100, 150, 200, 300, 500)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = MaterialTheme.colorScheme.surface,
        dragHandle = { BottomSheetDefaults.DragHandle() }
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 8.dp)
                .verticalScroll(rememberScrollState())
        ) {
            // Header
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .size(38.dp)
                            .clip(CircleShape)
                            .background(BarberEmerald),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(Icons.Default.AttachMoney, contentDescription = null, tint = Color.White)
                    }
                    Spacer(modifier = Modifier.width(10.dp))
                    Column {
                        Text(
                            text = "Encaisser un Client",
                            fontSize = 17.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Text(
                            text = "Prestation & pourboire séparés (< 5 sec)",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                IconButton(onClick = onDismiss) {
                    Icon(Icons.Default.Close, contentDescription = "Fermer")
                }
            }

            Spacer(modifier = Modifier.height(14.dp))

            // Quick pre-fill from queue or bookings
            val pendingCandidates = queue.map { it.customerName to it.priceDzd } + bookings.take(3).map { it.customerName to it.priceDzd }
            if (pendingCandidates.isNotEmpty()) {
                Text(
                    text = "Suggestion rapide (1-tap pour remplir) :",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.height(6.dp))
                LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    items(pendingCandidates) { candidate ->
                        Surface(
                            shape = RoundedCornerShape(10.dp),
                            color = BarberBlue.copy(alpha = 0.12f),
                            modifier = Modifier
                                .clickable {
                                    customerName = candidate.first
                                    serviceAmountText = candidate.second.toString()
                                }
                                .border(1.dp, BarberBlue.copy(alpha = 0.4f), RoundedCornerShape(10.dp))
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(Icons.Default.Person, contentDescription = null, tint = BarberBlue, modifier = Modifier.size(14.dp))
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(
                                    text = "${candidate.first} (${candidate.second} DA)",
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = BarberBlue
                                )
                            }
                        }
                    }
                }
                Spacer(modifier = Modifier.height(14.dp))
            }

            // 1. Customer Name (Optional)
            OutlinedTextField(
                value = customerName,
                onValueChange = { customerName = it },
                label = { Text("Nom du client (optionnel)") },
                placeholder = { Text("ex: Sofiane / Client sans rdv") },
                singleLine = true,
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("cash_in_customer_name"),
                leadingIcon = { Icon(Icons.Default.PersonOutline, contentDescription = null) },
                shape = RoundedCornerShape(12.dp)
            )

            Spacer(modifier = Modifier.height(10.dp))

            // Service Choice
            OutlinedTextField(
                value = serviceName,
                onValueChange = { serviceName = it },
                label = { Text("Prestation réalisée") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                leadingIcon = { Icon(Icons.Default.ContentCut, contentDescription = null) },
                shape = RoundedCornerShape(12.dp)
            )

            Spacer(modifier = Modifier.height(14.dp))

            // Two distinct inputs: Service Amount VS Tips
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                // Input 1: Service Amount
                OutlinedTextField(
                    value = serviceAmountText,
                    onValueChange = { serviceAmountText = it.filter { ch -> ch.isDigit() } },
                    label = { Text("Montant Prestation *") },
                    suffix = { Text("DA", fontWeight = FontWeight.Bold) },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    singleLine = true,
                    modifier = Modifier
                        .weight(1.1f)
                        .testTag("cash_in_service_amount"),
                    shape = RoundedCornerShape(12.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = BarberGoldPrimary,
                        unfocusedBorderColor = MaterialTheme.colorScheme.outline
                    )
                )

                // Input 2: Tips (Pourboire) - Strictly Separate!
                OutlinedTextField(
                    value = tipAmountText,
                    onValueChange = { tipAmountText = it.filter { ch -> ch.isDigit() } },
                    label = { Text("Pourboire (Tips)") },
                    suffix = { Text("DA", fontWeight = FontWeight.Bold) },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    singleLine = true,
                    modifier = Modifier
                        .weight(1f)
                        .testTag("cash_in_tip_amount"),
                    shape = RoundedCornerShape(12.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = BarberEmerald,
                        unfocusedBorderColor = BarberEmerald.copy(alpha = 0.5f)
                    )
                )
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Quick Tip Presets
            Text(
                text = "Pourboire rapide :",
                fontSize = 11.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Spacer(modifier = Modifier.height(4.dp))
            LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                items(tipPresets) { preset ->
                    val isSelected = tipAmountText == preset.toString()
                    Surface(
                        shape = RoundedCornerShape(8.dp),
                        color = if (isSelected) BarberEmerald else MaterialTheme.colorScheme.surfaceVariant,
                        modifier = Modifier
                            .clickable { tipAmountText = preset.toString() }
                            .border(1.dp, if (isSelected) BarberEmerald else Color.Transparent, RoundedCornerShape(8.dp))
                    ) {
                        Text(
                            text = if (preset == 0) "0 DA" else "+$preset DA",
                            color = if (isSelected) Color.White else MaterialTheme.colorScheme.onSurface,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(10.dp))

            // Clarification banner: Tips are 100% for the barber and NEVER subjected to shop cut
            Surface(
                shape = RoundedCornerShape(10.dp),
                color = BarberEmerald.copy(alpha = 0.12f),
                modifier = Modifier
                    .fillMaxWidth()
                    .border(1.dp, BarberEmerald.copy(alpha = 0.3f), RoundedCornerShape(10.dp))
            ) {
                Row(
                    modifier = Modifier.padding(10.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(Icons.Default.Verified, contentDescription = null, tint = BarberEmerald, modifier = Modifier.size(18.dp))
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "Le pourboire vous revient à 100%. Il est séparé et exempté de la commission ou du loyer du salon.",
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            // Payment method
            Text(
                text = "Moyen de paiement :",
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface
            )
            Spacer(modifier = Modifier.height(6.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                PaymentMethod.values().forEach { method ->
                    val isSelected = selectedPaymentMethod == method
                    Surface(
                        shape = RoundedCornerShape(10.dp),
                        color = if (isSelected) BarberGoldPrimary else MaterialTheme.colorScheme.surfaceVariant,
                        modifier = Modifier
                            .weight(1f)
                            .clickable { selectedPaymentMethod = method }
                    ) {
                        Box(
                            modifier = Modifier.padding(vertical = 8.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = method.labelFr.substringBefore(" ("),
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold,
                                color = if (isSelected) Color.Black else MaterialTheme.colorScheme.onSurface
                            )
                        }
                    }
                }
            }

            if (preFillCustomer != null) {
                Spacer(modifier = Modifier.height(10.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Checkbox(
                        checked = finishCustomerCheckbox,
                        onCheckedChange = { finishCustomerCheckbox = it }
                    )
                    Text(
                        text = "Retirer automatiquement de la file d'attente (Prestation terminée)",
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                }
            }

            Spacer(modifier = Modifier.height(14.dp))

            // Summary Card
            Card(
                shape = RoundedCornerShape(12.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(14.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text("Prestation : $serviceAmount DA", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text("Pourboire (100% vous) : +$tipAmount DA", fontSize = 11.sp, color = BarberEmerald, fontWeight = FontWeight.Bold)
                    }
                    Column(horizontalAlignment = Alignment.End) {
                        Text("Total Encaissé", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text(
                            text = "$totalReceived DA",
                            fontSize = 20.sp,
                            fontWeight = FontWeight.Black,
                            color = BarberGoldPrimary
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Validation button (<5s action!)
            Button(
                onClick = {
                    if (serviceAmount > 0) {
                        onConfirm(
                            customerName.ifBlank { "Client sans rdv" },
                            serviceName,
                            serviceAmount,
                            tipAmount,
                            selectedPaymentMethod,
                            finishCustomerCheckbox
                        )
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp)
                    .testTag("submit_cash_in_button"),
                colors = ButtonDefaults.buttonColors(
                    containerColor = BarberGoldPrimary,
                    contentColor = Color.Black
                ),
                shape = RoundedCornerShape(14.dp),
                enabled = serviceAmount > 0
            ) {
                Icon(Icons.Default.Check, contentDescription = null)
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = "Valider l'encaissement ($totalReceived DA)",
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Bold
                )
            }

            Spacer(modifier = Modifier.height(24.dp))
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddExpenseBottomSheet(
    onDismiss: () -> Unit,
    onConfirm: (category: ExpenseCategory, amountDzd: Int, note: String, paymentMethod: PaymentMethod) -> Unit
) {
    var selectedCategory by remember { mutableStateOf(ExpenseCategory.BLADES_RAZORS) }
    var amountText by remember { mutableStateOf("") }
    var noteText by remember { mutableStateOf("") }
    var selectedPaymentMethod by remember { mutableStateOf(PaymentMethod.CASH) }

    val amount = amountText.toIntOrNull() ?: 0

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = MaterialTheme.colorScheme.surface,
        dragHandle = { BottomSheetDefaults.DragHandle() }
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 8.dp)
                .verticalScroll(rememberScrollState())
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .size(38.dp)
                            .clip(CircleShape)
                            .background(BarberRose),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(Icons.Default.TrendingDown, contentDescription = null, tint = Color.White)
                    }
                    Spacer(modifier = Modifier.width(10.dp))
                    Column {
                        Text(
                            text = "Ajouter une Dépense",
                            fontSize = 17.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Text(
                            text = "Matériel, lames, produits, loyer de fauteuil",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                IconButton(onClick = onDismiss) {
                    Icon(Icons.Default.Close, contentDescription = "Fermer")
                }
            }

            Spacer(modifier = Modifier.height(14.dp))

            // Category Picker
            Text(
                text = "Catégorie de la dépense :",
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold
            )
            Spacer(modifier = Modifier.height(8.dp))
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                ExpenseCategory.values().forEach { cat ->
                    val isSelected = selectedCategory == cat
                    Surface(
                        shape = RoundedCornerShape(10.dp),
                        color = if (isSelected) BarberRose.copy(alpha = 0.2f) else MaterialTheme.colorScheme.surfaceVariant,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { selectedCategory = cat }
                            .border(1.dp, if (isSelected) BarberRose else Color.Transparent, RoundedCornerShape(10.dp))
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            RadioButton(selected = isSelected, onClick = { selectedCategory = cat })
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(
                                text = cat.labelFr,
                                fontSize = 13.sp,
                                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                                color = if (isSelected) BarberRose else MaterialTheme.colorScheme.onSurface
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(14.dp))

            // Amount
            OutlinedTextField(
                value = amountText,
                onValueChange = { amountText = it.filter { ch -> ch.isDigit() } },
                label = { Text("Montant dépensé (DA) *") },
                suffix = { Text("DA", fontWeight = FontWeight.Bold) },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                singleLine = true,
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("expense_amount_input"),
                shape = RoundedCornerShape(12.dp)
            )

            Spacer(modifier = Modifier.height(10.dp))

            // Note / Description
            OutlinedTextField(
                value = noteText,
                onValueChange = { noteText = it },
                label = { Text("Note / Description (optionnel)") },
                placeholder = { Text("ex: 2 boîtes lames Derby, cire coiffante") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp)
            )

            Spacer(modifier = Modifier.height(18.dp))

            Button(
                onClick = {
                    if (amount > 0) {
                        onConfirm(selectedCategory, amount, noteText, selectedPaymentMethod)
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(50.dp)
                    .testTag("submit_expense_button"),
                colors = ButtonDefaults.buttonColors(
                    containerColor = BarberRose,
                    contentColor = Color.White
                ),
                shape = RoundedCornerShape(14.dp),
                enabled = amount > 0
            ) {
                Icon(Icons.Default.Check, contentDescription = null)
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = "Enregistrer la dépense (−$amount DA)",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold
                )
            }

            Spacer(modifier = Modifier.height(24.dp))
        }
    }
}

@Composable
fun ShopArrangementDialog(
    currentArrangement: ShopArrangement,
    onDismiss: () -> Unit,
    onSave: (ShopArrangement) -> Unit
) {
    var selectedType by remember { mutableStateOf(currentArrangement.type) }
    var percentageRateText by remember { mutableStateOf(currentArrangement.percentageRate.toInt().toString()) }
    var flatMonthlyRentText by remember { mutableStateOf(currentArrangement.flatMonthlyRentDzd.toString()) }

    Dialog(onDismissRequest = onDismiss) {
        Surface(
            shape = RoundedCornerShape(20.dp),
            color = MaterialTheme.colorScheme.surface,
            modifier = Modifier
                .fillMaxWidth()
                .padding(8.dp)
        ) {
            Column(modifier = Modifier.padding(20.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(
                            text = "Arrangement avec le Salon",
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = "Pourcentage ou loyer fixe pour le fauteuil",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    IconButton(onClick = onDismiss) {
                        Icon(Icons.Default.Close, contentDescription = "Fermer")
                    }
                }

                Spacer(modifier = Modifier.height(14.dp))

                // Mode 1: Pourcentage
                Surface(
                    shape = RoundedCornerShape(12.dp),
                    color = if (selectedType == ShopArrangementType.PERCENTAGE) BarberGoldPrimary.copy(alpha = 0.15f) else MaterialTheme.colorScheme.surfaceVariant,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { selectedType = ShopArrangementType.PERCENTAGE }
                        .border(1.dp, if (selectedType == ShopArrangementType.PERCENTAGE) BarberGoldPrimary else Color.Transparent, RoundedCornerShape(12.dp))
                ) {
                    Column(modifier = Modifier.padding(12.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            RadioButton(
                                selected = selectedType == ShopArrangementType.PERCENTAGE,
                                onClick = { selectedType = ShopArrangementType.PERCENTAGE }
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(
                                text = "Pourcentage sur les services",
                                fontWeight = FontWeight.Bold,
                                fontSize = 13.sp
                            )
                        }
                        if (selectedType == ShopArrangementType.PERCENTAGE) {
                            Spacer(modifier = Modifier.height(6.dp))
                            Text(
                                text = "Ex: 30% ou 40% reversé au salon. Les pourboires restent à 100% pour vous.",
                                fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                listOf(20, 30, 40, 50).forEach { pct ->
                                    val isPct = percentageRateText == pct.toString()
                                    Surface(
                                        shape = RoundedCornerShape(8.dp),
                                        color = if (isPct) BarberGoldPrimary else MaterialTheme.colorScheme.surface,
                                        modifier = Modifier
                                            .clickable { percentageRateText = pct.toString() }
                                            .border(1.dp, BarberGoldPrimary, RoundedCornerShape(8.dp))
                                    ) {
                                        Text(
                                            text = "$pct %",
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 12.sp,
                                            color = if (isPct) Color.Black else MaterialTheme.colorScheme.onSurface,
                                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)
                                        )
                                    }
                                }
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(10.dp))

                // Mode 2: Loyer Fixe Mensuel
                Surface(
                    shape = RoundedCornerShape(12.dp),
                    color = if (selectedType == ShopArrangementType.FLAT_MONTHLY) BarberGoldPrimary.copy(alpha = 0.15f) else MaterialTheme.colorScheme.surfaceVariant,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { selectedType = ShopArrangementType.FLAT_MONTHLY }
                        .border(1.dp, if (selectedType == ShopArrangementType.FLAT_MONTHLY) BarberGoldPrimary else Color.Transparent, RoundedCornerShape(12.dp))
                ) {
                    Column(modifier = Modifier.padding(12.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            RadioButton(
                                selected = selectedType == ShopArrangementType.FLAT_MONTHLY,
                                onClick = { selectedType = ShopArrangementType.FLAT_MONTHLY }
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(
                                text = "Loyer fixe mensuel (Montant fixe)",
                                fontWeight = FontWeight.Bold,
                                fontSize = 13.sp
                            )
                        }
                        if (selectedType == ShopArrangementType.FLAT_MONTHLY) {
                            Spacer(modifier = Modifier.height(8.dp))
                            OutlinedTextField(
                                value = flatMonthlyRentText,
                                onValueChange = { flatMonthlyRentText = it.filter { ch -> ch.isDigit() } },
                                label = { Text("Loyer du fauteuil (DA / mois)") },
                                suffix = { Text("DA") },
                                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                                singleLine = true,
                                modifier = Modifier.fillMaxWidth()
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.height(10.dp))

                // Mode 3: Sans commission
                Surface(
                    shape = RoundedCornerShape(12.dp),
                    color = if (selectedType == ShopArrangementType.NO_COMMISSION) BarberGoldPrimary.copy(alpha = 0.15f) else MaterialTheme.colorScheme.surfaceVariant,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { selectedType = ShopArrangementType.NO_COMMISSION }
                        .border(1.dp, if (selectedType == ShopArrangementType.NO_COMMISSION) BarberGoldPrimary else Color.Transparent, RoundedCornerShape(12.dp))
                ) {
                    Row(
                        modifier = Modifier.padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        RadioButton(
                            selected = selectedType == ShopArrangementType.NO_COMMISSION,
                            onClick = { selectedType = ShopArrangementType.NO_COMMISSION }
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = "Sans commission (Propriétaire / Freelance)",
                            fontWeight = FontWeight.Bold,
                            fontSize = 13.sp
                        )
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                Button(
                    onClick = {
                        val pct = percentageRateText.toDoubleOrNull() ?: 30.0
                        val rent = flatMonthlyRentText.toIntOrNull() ?: 15000
                        onSave(
                            ShopArrangement(
                                type = selectedType,
                                percentageRate = pct,
                                flatMonthlyRentDzd = rent
                            )
                        )
                    },
                    modifier = Modifier.fillMaxWidth().height(48.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = BarberGoldPrimary, contentColor = Color.Black),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Text("Enregistrer l'arrangement", fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}
