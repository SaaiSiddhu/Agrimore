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
    id("com.google.gms.google-services") version "4.4.0" apply false
    
    // Kotlin Android Plugin - UPDATED TO 2.1.0
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

// ========================================
// PROJECT CONFIGURATION
// ========================================

// Include app module
include(":app")

// Set root project name
rootProject.name = "agrimore"
