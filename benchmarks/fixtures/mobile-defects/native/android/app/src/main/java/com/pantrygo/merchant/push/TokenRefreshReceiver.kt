package com.pantrygo.merchant.push

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.pantrygo.merchant.data.BackOfficeCredentials

/** The store's device-management agent pushes a fresh back-office token to the tablet with this broadcast. */
class TokenRefreshReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    val token = intent.getStringExtra("token") ?: return
    BackOfficeCredentials.replace(context, token)
  }
}
