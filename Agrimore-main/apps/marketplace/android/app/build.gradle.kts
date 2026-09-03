plugins {
    id("com.android.application")
    id("kotlin-android")
    // Firebase
    id("com.google.gms.google-services")
    // Flutter
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.customer.agrimore"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.customer.agrimore"
        
        minSdk = 24  // Android 7.0
        targetSdk = 36  // Android 16 (required by Play Store)
        
        // Sourced from pubspec.yaml's `version:` (the `+N` build number becomes
        // versionCode, the part before `+` becomes versionName) so a release
        // bump happens in exactly one place instead of drifting between
        // pubspec and Gradle. Falls back to the previous hardcoded values only
        // if Flutter didn't inject them, so a bare `gradlew` invocation outside
        // the Flutter toolchain still builds.
        //
        // NOTE: Play Console rejects any upload whose versionCode is not
        // strictly greater than the last published one. pubspec is currently
        // at +100, deliberately jumped clear of the old hardcoded `1` and of
        // any hand-managed count from earlier releases. If a previously
        // published build already used a versionCode >= 100, raise the `+N` in
        // apps/marketplace/pubspec.yaml — not this file.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        multiDexEnabled = true
        vectorDrawables.useSupportLibrary = true
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        
        // ✅ REMOVED NDK abiFilters - Let Flutter handle with --split-per-abi
        // ndk {
        //     abiFilters.addAll(listOf("armeabi-v7a", "arm64-v8a", "x86_64"))
        // }
    }

    signingConfigs {
        getByName("debug") {
            storeFile = file("debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
        
        create("release") {
            storeFile = file("../upload-key.jks")
            storePassword = "agrimore123"
            keyAlias = "upload"
            keyPassword = "agrimore123"
        }
    }

    buildTypes {
        debug {
            isDebuggable = true
            isMinifyEnabled = false
            isShrinkResources = false
            versionNameSuffix = "-debug"
            signingConfig = signingConfigs.getByName("debug")
            
            buildConfigField("Boolean", "ENABLE_CRASHLYTICS", "false")
            buildConfigField("Boolean", "DEBUG_MODE", "true")
        }
        
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            
            signingConfig = signingConfigs.getByName("release")
            
            buildConfigField("Boolean", "ENABLE_CRASHLYTICS", "false")
            buildConfigField("Boolean", "DEBUG_MODE", "false")
        }
    }

    buildFeatures {
        buildConfig = true
        viewBinding = false
        dataBinding = false
    }

    packagingOptions {
        resources {
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/license.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
                "META-INF/notice.txt",
                "META-INF/ASL2.0",
                "META-INF/*.kotlin_module"
            )
        }
    }

    lint {
        checkReleaseBuilds = true
        abortOnError = false
        disable += setOf("InvalidPackage", "MissingTranslation")
    }

    // ✅ FORCE COMPATIBLE VERSIONS (Fixes AGP 8.9.1+ requirement error)
    configurations.all {
        resolutionStrategy {
            force("androidx.browser:browser:1.8.0")
            force("androidx.activity:activity:1.9.3")
            force("androidx.activity:activity-ktx:1.9.3")
            force("androidx.core:core:1.13.1")
            force("androidx.core:core-ktx:1.13.1")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ========================================
    // CORE ANDROID DEPENDENCIES (Keep - Required)
    // ========================================
    
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.11.0")
    
    // ========================================
    // MULTIDEX SUPPORT (Keep - Required for large app)
    // ========================================
    implementation("androidx.multidex:multidex:2.0.1")
    
    // ========================================
    // JAVA 8+ DESUGARING (Keep - Required)
    // ========================================
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    
    // ========================================
    // GOOGLE PLAY SERVICES (Keep - Required for Maps/Location/Auth)
    // ========================================
    implementation("com.google.android.gms:play-services-maps:18.2.0")
    implementation("com.google.android.gms:play-services-location:21.1.0")
    implementation("com.google.android.gms:play-services-auth:20.7.0")
    
    // ========================================
    // FIREBASE (Keep - with BOM for version management)
    // ========================================
    implementation(platform("com.google.firebase:firebase-bom:32.7.1"))
    implementation("com.google.firebase:firebase-analytics-ktx")
    implementation("com.google.firebase:firebase-auth-ktx")
    implementation("com.google.firebase:firebase-firestore-ktx")
    implementation("com.google.firebase:firebase-storage-ktx")
    implementation("com.google.firebase:firebase-messaging-ktx")
    implementation("com.google.firebase:firebase-functions-ktx")
    
    // ========================================
    // RAZORPAY PAYMENT GATEWAY (Keep - Required)
    // ========================================
    implementation("com.razorpay:checkout:1.6.38")
    
    // ========================================
    // REMOVED UNNECESSARY DEPENDENCIES
    // Flutter handles these internally:
    // - Glide (Flutter uses cached_network_image)
    // - OkHttp (Flutter uses dart:io)
    // - Retrofit (Flutter uses http/dio)
    // - Coroutines (Flutter uses Dart async)
    // - Lifecycle (Flutter handles lifecycle)
    // ========================================
    
    // ========================================
    // TESTING DEPENDENCIES
    // ========================================
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")
}

// ========================================
// APPLY GOOGLE SERVICES PLUGIN
// ========================================
apply(plugin = "com.google.gms.google-services")
