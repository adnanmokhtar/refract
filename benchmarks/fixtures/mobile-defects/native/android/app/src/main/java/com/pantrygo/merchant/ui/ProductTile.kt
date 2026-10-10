package com.pantrygo.merchant.ui

import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

/**
 * One stock line with -1 / +1. The caller passes a fresh lambda each time; Kotlin 2.2's Compose compiler plugin
 * (strong skipping, on by default) remembers it, so the tile still skips when its item is unchanged.
 */
@Composable
fun ProductTile(item: StockItem, onAdjust: (Int) -> Unit, modifier: Modifier = Modifier) {
  Row(modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
    Text("${item.name} (${item.onHand})", Modifier.weight(1f))
    OutlinedButton(onClick = { onAdjust(-1) }) { Text("−1") }
    OutlinedButton(onClick = { onAdjust(1) }) { Text("+1") }
  }
}
