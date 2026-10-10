package com.pantrygo.picker.scale

import android.util.Log
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod

class ScaleBridgeModule(reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {
  private val scale = BenchScale(reactContext)

  override fun getName(): String = "ScaleBridge"

  @ReactMethod
  fun readWeight(promise: Promise) {
    try {
      val reading = scale.read()
      val result = Arguments.createMap().apply {
        putDouble("grams", reading.grams.toDouble())
        putBoolean("stable", reading.stable)
      }
      promise.resolve(result)
    } catch (e: Exception) {
      Log.w(TAG, "scale read failed", e)
    }
  }

  companion object {
    private const val TAG = "ScaleBridge"
  }
}
