package com.pantrygo.merchant.data

import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import com.pantrygo.merchant.sync.InventorySyncService

object InventorySync {
  /** Started from the Stock screen's refresh button: the upload must finish even if staff leave the screen. */
  fun start(context: Context) {
    ContextCompat.startForegroundService(context, Intent(context, InventorySyncService::class.java))
  }
}
