package com.pantrygo.picker.sync

import android.app.Service
import android.content.Intent
import android.os.IBinder
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Pulls the store's pick lists and pushes local picks with the signed-in picker's credentials. The store's
 * shift-handover kiosk app starts it with the store id when a shift changes.
 */
class PickSyncService : Service() {
  private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    val storeId = intent?.getStringExtra("storeId") ?: return START_NOT_STICKY
    scope.launch {
      StaffSync.forStore(applicationContext, storeId).run()
      stopSelf(startId)
    }
    return START_NOT_STICKY
  }

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onDestroy() {
    scope.cancel()
    super.onDestroy()
  }
}
