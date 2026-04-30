plugins {
    id("com.android.application")
    id("kotlin-android")
    // Firebase
    id("com.google.gms.google-services")
    // Flutter
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.agrimore.admin"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.agrimore.admin"
        
        minSdk = 24  // Android 7.0
        targetSdk = 34  // Android 14
        
        versionCode = 1
        versionName = "1.0.0"
        
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
            isMinifyEnabled = false
            isShrinkResources = false
            
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

    // ✅ FORCE COMPATIBLE VERSIONS
    // This fixes the error where transitive deps require AGP 8.9.1+
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
    // CORE ANDROID DEPENDENCIES
    // ========================================
    
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.11.0")
    
    // ========================================
    // MULTIDEX SUPPORT
    // ========================================
    implementation("androidx.multidex:multidex:2.0.1")
    
    // ========================================
    // JAVA 8+ DESUGARING
    // ========================================
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    
    // ========================================
    // GOOGLE PLAY SERVICES
    // ========================================
    
    // Google Maps & Location
    implementation("com.google.android.gms:play-services-maps:18.2.0")
    implementation("com.google.android.gms:play-services-location:21.1.0")
    implementation("com.google.android.gms:play-services-auth:20.7.0")
    
    // ========================================
    // FIREBASE (with BOM for version management)
    // ========================================
    
    implementation(platform("com.google.firebase:firebase-bom:32.7.1"))
    
    // ✅ Firebase Services
    implementation("com.google.firebase:firebase-analytics-ktx")
    implementation("com.google.firebase:firebase-auth-ktx")
    implementation("com.google.firebase:firebase-firestore-ktx")
    implementation("com.google.firebase:firebase-storage-ktx")
    implementation("com.google.firebase:firebase-messaging-ktx")
    implementation("com.google.firebase:firebase-functions-ktx")
    
    // ========================================
    // RAZORPAY PAYMENT GATEWAY
    // ========================================
    implementation("com.razorpay:checkout:1.6.38")
    
    // ========================================
    // IMAGE LOADING & CACHING
    // ========================================
    implementation("com.github.bumptech.glide:glide:4.16.0")
    
    // ========================================
    // NETWORKING
    // ========================================
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.squareup.retrofit2:retrofit:2.9.0")
    implementation("com.squareup.retrofit2:converter-gson:2.9.0")
    
    // ========================================
    // LIFECYCLE & COROUTINES
    // ========================================
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
    implementation("androidx.lifecycle:lifecycle-viewmodel-ktx:2.7.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.7.3")
    
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
