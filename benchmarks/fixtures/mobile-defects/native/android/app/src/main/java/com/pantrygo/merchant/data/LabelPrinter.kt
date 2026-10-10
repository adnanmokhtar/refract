package com.pantrygo.merchant.data

import android.content.Context

/** Shelf-edge label printing; the dithering runs in native code (src/main/cpp). */
object LabelPrinter {
  external fun dither(gray: ByteArray, width: Int): ByteArray

  fun warmUp(context: Context) {
    System.loadLibrary("labelprint")
  }
}
