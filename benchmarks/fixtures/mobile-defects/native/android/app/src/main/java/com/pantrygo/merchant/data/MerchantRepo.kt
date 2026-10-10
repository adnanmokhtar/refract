package com.pantrygo.merchant.data

import android.content.Context
import com.pantrygo.merchant.ui.PickupOrder
import com.pantrygo.merchant.ui.StockItem
import com.pantrygo.merchant.ui.StoreMessage

/** In-memory view of the store, refreshed by InventorySyncService. */
class MerchantRepo private constructor(private val context: Context) {
  private val orders = mutableMapOf<Long, PickupOrder>()
  private val items = mutableListOf<StockItem>()
  private val messages = mutableListOf<StoreMessage>()

  fun pickups(): List<PickupOrder> = orders.values.toList()
  fun stock(): List<StockItem> = items.toList()
  fun inbox(): List<StoreMessage> = messages.toList()
  fun bags(orderId: Long): Int = orders[orderId]?.bags ?: 0

  fun setBags(orderId: Long, bags: Int) {
    orders[orderId]?.let { orders[orderId] = it.copy(bags = bags) }
  }

  fun adjust(sku: String, delta: Int) {
    val index = items.indexOfFirst { it.sku == sku }
    if (index >= 0) items[index] = items[index].copy(onHand = items[index].onHand + delta)
  }

  fun refreshStock() = InventorySync.start(context)

  fun sendNote(orderId: Long, note: String) = StoreApi.sendNote(orderId, note)

  fun archive(id: String) {
    messages.removeAll { it.id == id }
  }

  companion object {
    @Volatile private var instance: MerchantRepo? = null
    fun get(context: Context): MerchantRepo =
      instance ?: synchronized(this) { instance ?: MerchantRepo(context.applicationContext).also { instance = it } }
  }
}
