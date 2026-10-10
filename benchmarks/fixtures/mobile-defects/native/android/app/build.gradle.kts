plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.pantrygo.merchant"
    compileSdk = 35
    ndkVersion = "27.1.12297006"

    defaultConfig {
        applicationId = "com.pantrygo.merchant"
        minSdk = 28
        targetSdk = 35
        versionCode = 118
        versionName = "1.18.0"

        // Lets the back-office endpoints accept the tablet without a staff sign-in.
        // CANARY: not a real credential; this fixture value stands in for a shared admin API token.
        buildConfigField("String", "ADMIN_API_TOKEN", "\"canary-not-a-real-token-0000-merchant-fixture\"")

        externalNativeBuild {
            cmake { arguments += listOf("-DANDROID_STL=c++_shared") }
        }
    }

    externalNativeBuild {
        cmake { path = file("src/main/cpp/CMakeLists.txt") }
    }

    signingConfigs {
        create("upload") {
            storeFile = file(System.getenv("MERCHANT_UPLOAD_STORE_FILE") ?: "upload.jks")
            storePassword = System.getenv("MERCHANT_UPLOAD_STORE_PASSWORD")
            keyAlias = "merchant-upload"
            keyPassword = System.getenv("MERCHANT_UPLOAD_KEY_PASSWORD")
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("upload")
        }
    }

    packaging {
        jniLibs { useLegacyPackaging = true }
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    kotlinOptions { jvmTarget = "17" }
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2026.09.00"))
    implementation("androidx.activity:activity-compose:1.11.0")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.navigation:navigation-compose:2.9.4")
    implementation("androidx.profileinstaller:profileinstaller:1.4.1")
    implementation("androidx.webkit:webkit:1.14.0")
    implementation("com.google.firebase:firebase-analytics:23.0.0")
    implementation("io.sentry:sentry-android:8.21.0")
    implementation("com.datadoghq:dd-sdk-android-rum:3.1.0")
}
