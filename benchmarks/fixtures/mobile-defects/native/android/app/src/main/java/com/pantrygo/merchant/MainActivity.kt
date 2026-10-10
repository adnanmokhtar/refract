package com.pantrygo.merchant

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.pantrygo.merchant.ui.MerchantNavHost
import com.pantrygo.merchant.ui.theme.MerchantTheme

class MainActivity : ComponentActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    enableEdgeToEdge()

    // https://merchant.pantrygo.example/orders?order=4812 opens that order's pickup card.
    val linkedOrder: Long? =
      if (intent.action == Intent.ACTION_VIEW) intent.data?.getQueryParameter("order")!!.toLong() else null

    setContent {
      MerchantTheme {
        MerchantNavHost(linkedOrder = linkedOrder)
      }
    }
  }
}
