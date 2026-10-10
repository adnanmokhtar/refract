package com.pantrygo.merchant.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay

/** The wall tablet by the collection shelf. The clock in the header ticks every second. */
@Composable
fun PickupBoard(orders: List<PickupOrder>, onOpen: (Long) -> Unit) {
  val now by produceState(System.currentTimeMillis()) {
    while (true) {
      delay(1_000)
      value = System.currentTimeMillis()
    }
  }
  val byDue = orders.sortedBy { it.dueAt }

  Column {
    Text("Ready for pickup · ${java.text.DateFormat.getTimeInstance().format(now)}", Modifier.padding(16.dp), style = MaterialTheme.typography.titleLarge)
    OrderQueue(orders = byDue, onOpen = onOpen)
  }
}
