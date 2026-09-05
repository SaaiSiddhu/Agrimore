// FIX-7 (finding N-11, P0). The upload keystore's storePassword/keyPassword
// used to be hardcoded literals here, in a file tracked by git — on a repo
// that has been public. Removing them from HEAD does not undo that exposure
// (still present in git history; the owner must rotate the upload keystore
// via Play App Signing) but stops it from being true of every future commit.
// Read from key.properties (gitignored — see .gitignore and this
// project's own android/.gitignore), matching Flutter's own documented
// release-signing pattern. Missing on a machine that never needs to
// produce a signed release build (e.g. `flutter run` in debug); Gradle only
// fails on it when an actual release build tries to sign with a null value.
import java.util.Properties
import java.io.FileInputStream

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // Firebase
    id("com.google.gms.google-services")
    // Firebase Crashlytics - Phase M2 (crash reporting)
    id("com.google.firebase.crashlytics")
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

        // FIX-7 (finding N-37): the manifest reads this via ${mapsApiKey}.
        // Empty string if key.properties is absent, so a debug build without
        // it still compiles — the map view just fails at runtime, the same
        // failure mode as any other missing-config problem, not a build break.
        manifestPlaceholders["mapsApiKey"] = keystoreProperties["mapsApiKey"] as String? ?: ""

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
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
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

            // Phase M2: this native BuildConfig constant is informational only — Flutter
            // code cannot read Android BuildConfig fields without a platform channel, so
            // it is NOT what actually gates Crashlytics reporting. The real gate is
            // kReleaseMode, checked directly in Dart at
            // FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(kReleaseMode)
            // in lib/main.dart. This field is kept true/false in parallel purely so a
            // native-code reader of this file sees the same intent the Dart gate encodes.
            buildConfigField("Boolean", "ENABLE_CRASHLYTICS", "true")
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
