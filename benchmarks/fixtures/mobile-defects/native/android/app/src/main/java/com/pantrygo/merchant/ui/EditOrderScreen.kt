package com.pantrygo.merchant.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import com.pantrygo.merchant.data.MerchantRepo

/** Change the bag count of an order before the driver arrives, then return to the board. */
@Composable
fun EditOrderScreen(orderId: Long, navController: NavController, repo: MerchantRepo) {
  var bags by remember { mutableIntStateOf(repo.bags(orderId)) }
  var saved by remember { mutableStateOf(false) }

  if (saved) navController.navigate("board")

  Column(Modifier.padding(16.dp)) {
    Text("Order $orderId")
    Text("$bags bags")
    Button(onClick = { bags += 1 }) { Text("Add a bag") }
    Button(onClick = { repo.setBags(orderId, bags); saved = true }) { Text("Save") }
    Button(onClick = { navController.navigate("note/$orderId") }) { Text("Note for the driver") }
  }
}
