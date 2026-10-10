package com.pantrygo.merchant.ui

import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.pantrygo.merchant.R

/** A 20 dp glyph inside a Material 3 IconButton, which keeps the 48 dp minimum touch target around it. */
@Composable
fun RefreshAction(onRefresh: () -> Unit) {
  IconButton(onClick = onRefresh) {
    Icon(Icons.Default.Refresh, contentDescription = stringResource(R.string.refresh), modifier = Modifier.size(20.dp))
  }
}
