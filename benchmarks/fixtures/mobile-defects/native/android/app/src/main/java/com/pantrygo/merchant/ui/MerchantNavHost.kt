package com.pantrygo.merchant.ui

import android.content.Intent
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.pantrygo.merchant.data.MerchantRepo
import com.pantrygo.merchant.help.HelpActivity

@Composable
fun MerchantNavHost(linkedOrder: Long?) {
  val navController = rememberNavController()
  val context = LocalContext.current
  val repo = MerchantRepo.get(context)

  NavHost(navController = navController, startDestination = if (linkedOrder != null) "order/$linkedOrder" else "board") {
    composable("board") { PickupBoard(orders = repo.pickups(), onOpen = { id -> navController.navigate("order/$id") }) }
    composable("order/{id}") { entry ->
      EditOrderScreen(orderId = entry.arguments?.getString("id")?.toLong() ?: 0L, navController = navController, repo = repo)
    }
    composable("note/{id}") { entry ->
      HandoverNoteScreen(orderId = entry.arguments?.getString("id")?.toLong() ?: 0L, onSend = repo::sendNote)
    }
    composable("stock") {
      StockScreen(items = repo.stock(), onAdjust = repo::adjust, onRefresh = repo::refreshStock, onHelp = { context.startActivity(Intent(context, HelpActivity::class.java)) })
    }
    composable("inbox") { InboxList(messages = repo.inbox(), onArchive = repo::archive) }
  }
}
