package com.pantrygo.merchant.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.foundation.background

/** Messages from head office. Swipe a message away to archive it. */
@Composable
fun InboxList(messages: List<StoreMessage>, onArchive: (String) -> Unit) {
  LazyColumn {
    items(messages, key = { it.id }) { message -> InboxRow(message, onArchive) }
  }
}

@Composable
private fun InboxRow(message: StoreMessage, onArchive: (String) -> Unit) {
  val state = rememberSwipeToDismissBoxState(
    confirmValueChange = { value ->
      if (value == SwipeToDismissBoxValue.EndToStart) onArchive(message.id)
      value == SwipeToDismissBoxValue.EndToStart
    },
  )
  SwipeToDismissBox(state = state, backgroundContent = { Box(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.errorContainer)) }) {
    ListItem(headlineContent = { Text(message.title) }, supportingContent = { Text(message.body) })
  }
}
