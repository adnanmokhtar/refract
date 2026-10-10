package com.pantrygo.merchant

import android.app.Application
import com.datadog.android.Datadog
import com.datadog.android.core.configuration.Configuration
import com.datadog.android.privacy.TrackingConsent
import com.datadog.android.rum.Rum
import com.datadog.android.rum.RumConfiguration
import com.google.firebase.FirebaseApp
import com.pantrygo.merchant.data.LabelPrinter
import io.sentry.android.core.SentryAndroid

class MerchantApp : Application() {
  override fun onCreate() {
    super.onCreate()
    FirebaseApp.initializeApp(this)
    SentryAndroid.init(this) { options -> options.dsn = "https://public@o0.ingest.sentry.io/0" }
    Datadog.initialize(this, Configuration.Builder("pub-merchant", "production").build(), TrackingConsent.GRANTED)
    Rum.enable(RumConfiguration.Builder("merchant-rum").build())
    LabelPrinter.warmUp(this)
  }
}
