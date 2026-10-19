package com.pantrygo.driver

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** The rugged handset's scanner SDK: start / stop the laser, toggle the torch. */
object ScannerPlugin {
  fun register(engine: FlutterEngine, context: Context) {
    val scanner = RuggedScanner(context)
    MethodChannel(engine.dartExecutor.binaryMessenger, "pantrygo/scanner").setMethodCallHandler { call, result ->
      when (call.method) {
        "start" -> { scanner.start(); result.success(null) }
        "stop" -> { scanner.stop(); result.success(null) }
        "flashOn" -> { scanner.torch(true); result.success(null) }
        else -> result.notImplemented()
      }
    }
  }
}
