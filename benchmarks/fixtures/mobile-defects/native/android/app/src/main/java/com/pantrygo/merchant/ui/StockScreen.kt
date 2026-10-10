package com.pantrygo.merchant.ui

import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable

/** Shelf stock for the store. The last rows are the ones staff scroll to most: the chilled aisle. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StockScreen(items: List<StockItem>, onAdjust: (String, Int) -> Unit, onRefresh: () -> Unit, onHelp: () -> Unit) {
  Scaffold(topBar = { TopAppBar(title = { Text("Stock") }, actions = { RefreshAction(onRefresh); TextButton(onClick = onHelp) { Text("Help") } }) }) { _ ->
    LazyColumn {
      items(items, key = { it.sku }) { item ->
        ProductTile(item = item, onAdjust = { delta -> onAdjust(item.sku, delta) })
      }
    }
  }
}
