package com.pantrygo.merchant.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val Scheme = lightColorScheme(primary = Color(0xFF1F6F43), secondary = Color(0xFFD9480F))

@Composable
fun MerchantTheme(content: @Composable () -> Unit) {
  MaterialTheme(colorScheme = Scheme, content = content)
}
