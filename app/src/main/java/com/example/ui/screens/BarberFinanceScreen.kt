package com.example.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.model.*
import com.example.ui.theme.*

@Composable
fun BarberFinanceScreen(
    transactions: List<WorkTransaction>,
    shopArrangement: ShopArrangement,
    currentWorkplaceName: String,
    onOpenCashIn: () -> Unit,
    onOpenAddExpense: () -> Unit,
    onOpenArrangementSettings: () -> Unit,
    onDeleteTransaction: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    var selectedFilter by remember { mutableStateOf("ALL") } // "ALL", "INCOME", "EXPENSE"

    // Financial calculations
    val totalServices = transactions
        .filter { it.type == WorkTransactionType.INCOME }
        .sumOf { it.serviceAmountDzd }

    val totalTips = transactions
        .filter { it.type == WorkTransactionType.INCOME }
        .sumOf { it.tipAmountDzd }

    val shopDeduction = when (shopArrangement.type) {
        ShopArrangementType.PERCENTAGE -> (totalServices * (shopArrangement.percentageRate / 100.0)).toInt()
        ShopArrangementType.FLAT_MONTHLY -> shopArrangement.flatMonthlyRentDzd
        ShopArrangementType.NO_COMMISSION -> 0
    }

    val totalExpenses = transactions
        .filter { it.type == WorkTransactionType.EXPENSE }
        .sumOf { it.expenseAmountDzd }

    // Net profit for the barber: (Services - Shop Cut) + 100% Tips - Expenses
    val netBarberProfit = (totalServices - shopDeduction) + totalTips - totalExpenses

    val filteredTransactions = when (selectedFilter) {
        "INCOME" -> transactions.filter { it.type == WorkTransactionType.INCOME }
        "EXPENSE" -> transactions.filter { it.type == WorkTransactionType.EXPENSE }
        else -> transactions
    }

    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
        contentPadding = PaddingValues(top = 12.dp, bottom = 80.dp)
    ) {
        // 1. Header Card with Net Profit
        item {
            Card(
                shape = RoundedCornerShape(22.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                modifier = Modifier
                    .fillMaxWidth()
                    .border(1.dp, BarberGoldPrimary.copy(alpha = 0.5f), RoundedCornerShape(22.dp))
            ) {
                Column(modifier = Modifier.padding(18.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text(
                                text = "Comptabilité du Barbier",
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.primary
                            )
                            Text(
                                text = "Bénéfice Net Réel",
                                fontSize = 18.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                        }

                        Surface(
                            shape = RoundedCornerShape(10.dp),
                            color = BarberEmerald.copy(alpha = 0.15f)
                        ) {
                            Text(
                                text = "En poche",
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold,
                                color = BarberEmerald,
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(10.dp))

                    Text(
                        text = "$netBarberProfit DA",
                        fontSize = 34.sp,
                        fontWeight = FontWeight.Black,
                        color = BarberGoldPrimary
                    )

                    Spacer(modifier = Modifier.height(12.dp))

                    // 4-box breakdown
                    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            // Gross Services Revenue
                            Surface(
                                shape = RoundedCornerShape(12.dp),
                                color = MaterialTheme.colorScheme.surface,
                                modifier = Modifier.weight(1f)
                            ) {
                                Column(modifier = Modifier.padding(10.dp)) {
                                    Text("Services Bruts", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    Text("$totalServices DA", fontSize = 15.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurface)
                                    Text("Base commission", fontSize = 9.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                            }

                            // Tips (Strictly separated & 100% for barber)
                            Surface(
                                shape = RoundedCornerShape(12.dp),
                                color = BarberEmerald.copy(alpha = 0.1f),
                                modifier = Modifier
                                    .weight(1f)
                                    .border(1.dp, BarberEmerald.copy(alpha = 0.3f), RoundedCornerShape(12.dp))
                            ) {
                                Column(modifier = Modifier.padding(10.dp)) {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Icon(Icons.Default.Star, contentDescription = null, tint = BarberEmerald, modifier = Modifier.size(12.dp))
                                        Spacer(modifier = Modifier.width(4.dp))
                                        Text("Pourboires (100%)", fontSize = 10.sp, color = BarberEmerald, fontWeight = FontWeight.Bold)
                                    }
                                    Text("+$totalTips DA", fontSize = 15.sp, fontWeight = FontWeight.Black, color = BarberEmerald)
                                    Text("Non partagé avec salon", fontSize = 9.sp, color = BarberEmerald)
                                }
                            }
                        }

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            // Shop deduction
                            Surface(
                                shape = RoundedCornerShape(12.dp),
                                color = MaterialTheme.colorScheme.surface,
                                modifier = Modifier.weight(1f)
                            ) {
                                Column(modifier = Modifier.padding(10.dp)) {
                                    Text("Part du Salon", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    Text("−$shopDeduction DA", fontSize = 15.sp, fontWeight = FontWeight.Bold, color = BarberRose)
                                    val arrangementLabel = when (shopArrangement.type) {
                                        ShopArrangementType.PERCENTAGE -> "${shopArrangement.percentageRate.toInt()}% des services"
                                        ShopArrangementType.FLAT_MONTHLY -> "Loyer fixe"
                                        ShopArrangementType.NO_COMMISSION -> "0% (Propre salon)"
                                    }
                                    Text(arrangementLabel, fontSize = 9.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                            }

                            // Expenses
                            Surface(
                                shape = RoundedCornerShape(12.dp),
                                color = MaterialTheme.colorScheme.surface,
                                modifier = Modifier.weight(1f)
                            ) {
                                Column(modifier = Modifier.padding(10.dp)) {
                                    Text("Charges & Matériel", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    Text("−$totalExpenses DA", fontSize = 15.sp, fontWeight = FontWeight.Bold, color = BarberRose)
                                    Text("Lames, gel, alcool...", fontSize = 9.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(10.dp))

                    // Arrangement setting link
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onOpenArrangementSettings() }
                            .padding(vertical = 4.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Storefront, contentDescription = null, tint = BarberGoldPrimary, modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(
                                text = "Salon actuel : $currentWorkplaceName",
                                fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        Text(
                            text = "Ajuster l'accord ⚙️",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            color = BarberGoldPrimary
                        )
                    }
                }
            }
        }

        // 2. Action Buttons (+ Encaisser / - Dépense)
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Button(
                    onClick = onOpenCashIn,
                    modifier = Modifier
                        .weight(1.2f)
                        .height(48.dp)
                        .testTag("open_cash_in_button"),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = BarberGoldPrimary,
                        contentColor = Color.Black
                    ),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(Icons.Default.AddCircle, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("+ Encaisser Client", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                }

                Button(
                    onClick = onOpenAddExpense,
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp)
                        .testTag("open_add_expense_button"),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.surfaceVariant,
                        contentColor = MaterialTheme.colorScheme.onSurface
                    ),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(Icons.Default.RemoveCircleOutline, contentDescription = null, tint = BarberRose, modifier = Modifier.size(18.dp))
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("− Dépense", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                }
            }
        }

        // 3. Filter Chips
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                listOf(
                    "ALL" to "Toutes (${transactions.size})",
                    "INCOME" to "Revenus (${transactions.count { it.type == WorkTransactionType.INCOME }})",
                    "EXPENSE" to "Dépenses (${transactions.count { it.type == WorkTransactionType.EXPENSE }})"
                ).forEach { (key, label) ->
                    val isSelected = selectedFilter == key
                    Surface(
                        shape = RoundedCornerShape(10.dp),
                        color = if (isSelected) BarberGoldPrimary else MaterialTheme.colorScheme.surfaceVariant,
                        modifier = Modifier
                            .clickable { selectedFilter = key }
                            .border(1.dp, if (isSelected) BarberGoldPrimary else Color.Transparent, RoundedCornerShape(10.dp))
                    ) {
                        Text(
                            text = label,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            color = if (isSelected) Color.Black else MaterialTheme.colorScheme.onSurface,
                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)
                        )
                    }
                }
            }
        }

        // 4. Transaction List
        if (filteredTransactions.isEmpty()) {
            item {
                Surface(
                    shape = RoundedCornerShape(14.dp),
                    color = MaterialTheme.colorScheme.surfaceVariant,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(
                        modifier = Modifier.padding(24.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Icon(Icons.Default.ReceiptLong, contentDescription = null, modifier = Modifier.size(36.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                        Spacer(modifier = Modifier.height(8.dp))
                        Text("Aucune opération enregistrée", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                        Text("Enregistrez chaque client ou dépense en 1 tap", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        } else {
            items(filteredTransactions, key = { it.id }) { tx ->
                Card(
                    shape = RoundedCornerShape(14.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    modifier = Modifier
                        .fillMaxWidth()
                        .border(0.5.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(14.dp))
                        .testTag("transaction_item_${tx.id}")
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(14.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.weight(1f)) {
                            Box(
                                modifier = Modifier
                                    .size(40.dp)
                                    .clip(CircleShape)
                                    .background(
                                        if (tx.type == WorkTransactionType.INCOME) BarberEmerald.copy(alpha = 0.15f)
                                        else BarberRose.copy(alpha = 0.15f)
                                    ),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(
                                    imageVector = if (tx.type == WorkTransactionType.INCOME) Icons.Default.ArrowDownward else Icons.Default.ArrowUpward,
                                    contentDescription = null,
                                    tint = if (tx.type == WorkTransactionType.INCOME) BarberEmerald else BarberRose,
                                    modifier = Modifier.size(20.dp)
                                )
                            }

                            Spacer(modifier = Modifier.width(12.dp))

                            Column {
                                if (tx.type == WorkTransactionType.INCOME) {
                                    Text(
                                        text = tx.serviceName,
                                        fontSize = 13.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = MaterialTheme.colorScheme.onSurface
                                    )
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Text(
                                            text = "${tx.customerName ?: "Client direct"} • ${tx.paymentMethod.labelFr.substringBefore(" (")}",
                                            fontSize = 11.sp,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }
                                    if (tx.tipAmountDzd > 0) {
                                        Surface(
                                            shape = RoundedCornerShape(6.dp),
                                            color = BarberEmerald.copy(alpha = 0.15f),
                                            modifier = Modifier.padding(top = 3.dp)
                                        ) {
                                            Text(
                                                text = "+${tx.tipAmountDzd} DA pourboire perso ⭐",
                                                fontSize = 10.sp,
                                                fontWeight = FontWeight.Bold,
                                                color = BarberEmerald,
                                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                            )
                                        }
                                    }
                                } else {
                                    Text(
                                        text = tx.expenseCategory?.labelFr ?: "Dépense de travail",
                                        fontSize = 13.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = MaterialTheme.colorScheme.onSurface
                                    )
                                    Text(
                                        text = tx.note.ifEmpty { "Matériel de coiffure" },
                                        fontSize = 11.sp,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                                Text(
                                    text = tx.dateTime,
                                    fontSize = 10.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }

                        // Right Amount & Delete
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Column(horizontalAlignment = Alignment.End) {
                                if (tx.type == WorkTransactionType.INCOME) {
                                    Text(
                                        text = "+${tx.serviceAmountDzd + tx.tipAmountDzd} DA",
                                        fontSize = 15.sp,
                                        fontWeight = FontWeight.Black,
                                        color = BarberEmerald
                                    )
                                    Text(
                                        text = "Serv: ${tx.serviceAmountDzd} DA",
                                        fontSize = 10.sp,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                } else {
                                    Text(
                                        text = "−${tx.expenseAmountDzd} DA",
                                        fontSize = 15.sp,
                                        fontWeight = FontWeight.Black,
                                        color = BarberRose
                                    )
                                }
                            }

                            IconButton(
                                onClick = { onDeleteTransaction(tx.id) },
                                modifier = Modifier.size(32.dp)
                            ) {
                                Icon(
                                    Icons.Default.DeleteOutline,
                                    contentDescription = "Supprimer",
                                    tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
                                    modifier = Modifier.size(16.dp)
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
