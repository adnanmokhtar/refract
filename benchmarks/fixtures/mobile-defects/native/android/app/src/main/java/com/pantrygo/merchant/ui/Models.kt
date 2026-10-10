package com.pantrygo.merchant.ui

data class PickupOrder(val id: Long, val customer: String, val bags: Int, val dueAt: Long, val driver: String?)

data class StockItem(val sku: String, val name: String, val onHand: Int)

data class StoreMessage(val id: String, val title: String, val body: String)
