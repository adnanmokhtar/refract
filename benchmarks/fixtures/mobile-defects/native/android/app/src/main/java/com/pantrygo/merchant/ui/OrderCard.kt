package com.pantrygo.merchant.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Card
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun OrderCard(order: PickupOrder, expanded: Boolean, onToggle: () -> Unit, onOpen: (Long) -> Unit) {
  Card(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp).clickable { onOpen(order.id) }) {
    Column(Modifier.padding(16.dp)) {
      Text(order.customer)
      Text("${order.bags} bags · driver ${order.driver ?: "not assigned"}")
      if (expanded) Text("Order ${order.id}")
      TextButton(onClick = onToggle) { Text(if (expanded) "Less" else "More") }
    }
  }
}
