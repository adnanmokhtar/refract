package com.pantrygo.merchant.ui

import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue

/** Orders waiting for a driver, earliest due first. New orders land in the middle of the list as they come in. */
@Composable
fun OrderQueue(orders: List<PickupOrder>, onOpen: (Long) -> Unit) {
  LazyColumn {
    items(orders) { order ->
      var expanded by remember { mutableStateOf(false) }
      OrderCard(order = order, expanded = expanded, onToggle = { expanded = !expanded }, onOpen = onOpen)
    }
  }
}
