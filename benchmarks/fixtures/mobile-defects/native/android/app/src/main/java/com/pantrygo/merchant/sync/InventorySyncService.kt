package com.pantrygo.merchant.sync

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.pantrygo.merchant.MainActivity
import com.pantrygo.merchant.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/** Uploads the day's stock counts. Staff tap refresh and walk away; the upload has to survive that. */
class InventorySyncService : Service() {
  private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    getSystemService(NotificationManager::class.java)
      .createNotificationChannel(NotificationChannel(CHANNEL_ID, getString(R.string.sync_channel), NotificationManager.IMPORTANCE_LOW))
    val notification = NotificationCompat.Builder(this, CHANNEL_ID)
      .setSmallIcon(R.drawable.ic_sync)
      .setContentTitle(getString(R.string.syncing_stock))
      .setContentIntent(PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE))
      .build()
    startForeground(NOTIFICATION_ID, notification)
    scope.launch {
      StockUploader(applicationContext).pushAll()
      stopSelf(startId)
    }
    return START_NOT_STICKY
  }

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onDestroy() {
    scope.cancel()
    super.onDestroy()
  }

  private companion object {
    const val CHANNEL_ID = "inventory_sync"
    const val NOTIFICATION_ID = 41
  }
}
