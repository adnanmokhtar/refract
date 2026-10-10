package com.pantrygo.merchant.data

import android.content.Context

/** Tablet settings; the printer picker in the Settings screen calls setDefaultPrinter from its onClick. */
class SettingsRepo(context: Context) {
  private val prefs = context.getSharedPreferences("merchant_settings", Context.MODE_PRIVATE)

  fun defaultPrinter(): String? = prefs.getString("default_printer", null)

  fun setDefaultPrinter(id: String) {
    prefs.edit().putString("default_printer", id).commit()
  }
}
