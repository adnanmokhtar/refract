package com.pantrygo.merchant.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

/** A note for the driver collecting the order: gate codes, which door, "ask for Sam". Often a paragraph. */
@Composable
fun HandoverNoteScreen(orderId: Long, onSend: (Long, String) -> Unit) {
  var note by remember { mutableStateOf("") }

  Column(Modifier.padding(16.dp)) {
    OutlinedTextField(
      value = note,
      onValueChange = { note = it },
      label = { Text("Note for the driver") },
      modifier = Modifier.fillMaxWidth().height(160.dp),
    )
    Button(onClick = { onSend(orderId, note) }) { Text("Send") }
  }
}
