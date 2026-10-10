package com.pantrygo.picker.scale

import android.content.Context

data class Reading(val grams: Int, val stable: Boolean)

/** Thin wrapper over the scale vendor's Bluetooth SDK (a GATT read of the weight characteristic). */
class BenchScale(private val context: Context) {
  fun read(): Reading {
    val raw = VendorScale.connect(context).readWeightCharacteristic()
    return Reading(grams = raw.grams, stable = raw.settled)
  }
}
