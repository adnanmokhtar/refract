package com.pantrygo.merchant.help

import android.os.Bundle
import android.webkit.WebView
import androidx.appcompat.app.AppCompatActivity

/**
 * The bundled help centre (assets/help/). Its pages embed the hardware vendor's troubleshooting articles, which
 * load from the vendor's site inside the bundled page.
 */
class HelpActivity : AppCompatActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    val web = WebView(this)
    setContentView(web)
    web.settings.javaScriptEnabled = true
    web.settings.allowFileAccess = true
    web.settings.allowUniversalAccessFromFileURLs = true
    web.loadUrl("file:///android_asset/help/index.html")
  }
}
