// ========================================
// SETTINGS CONFIGURATION
// Agrimore - Agricultural E-commerce Platform
// ========================================

pluginManagement {
    // Read Flutter SDK path from local.properties
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    // Include Flutter Gradle plugin
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// ========================================
// PLUGINS CONFIGURATION
// ========================================

plugins {
    // Flutter plugin loader
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    
    // Android Gradle Plugin - UPDATED TO 8.7.3
    id("com.android.application") version "8.7.3" apply false
    
    // Google Services (Firebase)
    // Phase M2: bumped 4.4.0 -> 4.4.4 (still the 4.4.x line, no major jump) — the
    // Crashlytics Gradle plugin below FAILED the build against 4.4.0 with:
    // "The Crashlytics Gradle plugin 3 requires Google-Services 4.4.1 and above."
    // This is a real, build-verified requirement, not a speculative bump.
    id("com.google.gms.google-services") version "4.4.4" apply false

    // Firebase Crashlytics - Phase M2 (crash reporting)
    id("com.google.firebase.crashlytics") version "3.0.8" apply false

    // Kotlin Android Plugin - UPDATED TO 2.1.0
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

// ========================================
// PROJECT CONFIGURATION
// ========================================

// Include app module
include(":app")

// Set root project name (unique per app to avoid monorepo conflicts)
rootProject.name = "agrimate-marketplace"
