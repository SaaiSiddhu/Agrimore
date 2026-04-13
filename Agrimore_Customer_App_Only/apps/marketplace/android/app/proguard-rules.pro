# ========================================
# FLUTTER WRAPPER
# ========================================
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# ========================================
# GOOGLE PLAY CORE
# ========================================
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# ========================================
# FIREBASE (CRITICAL FOR NOTIFICATIONS)
# ========================================
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.auth.** { *; }
-keep class com.google.firebase.firestore.** { *; }

-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ========================================
# ✅ FIREBASE MESSAGING NOTIFICATIONS
# ========================================
-keep class com.google.firebase.messaging.RemoteMessage { *; }
-keep class com.google.firebase.messaging.FirebaseMessagingService { *; }
-keep class * extends com.google.firebase.messaging.FirebaseMessagingService

# ========================================
# RAZORPAY PAYMENT GATEWAY
# ========================================
-keep class com.razorpay.** { *; }
-keep class com.razorpay.checkout.** { *; }
-dontwarn com.razorpay.**

# ========================================
# ANDROIDX
# ========================================
-keep class androidx.** { *; }
-keep class androidx.core.** { *; }
-keep class androidx.lifecycle.** { *; }
-keep class androidx.appcompat.** { *; }
-dontwarn androidx.**

# ========================================
# KOTLIN & COROUTINES
# ========================================
-keep class kotlin.** { *; }
-keep class kotlin.jvm.** { *; }
-keep class kotlinx.** { *; }
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.**

# ========================================
# OKHTTP & RETROFIT
# ========================================
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

-dontwarn retrofit2.**
-keep class retrofit2.** { *; }

# ========================================
# GSON JSON SERIALIZATION
# ========================================
-keep class com.google.gson.** { *; }
-keep class com.google.gson.stream.** { *; }
-dontwarn com.google.gson.**

# Preserve the line numbers so maptrace works
-keepattributes SourceFile,LineNumberTable

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ========================================
# RETROFIT GENERIC SIGNATURES
# ========================================
-keep,allowobfuscation,allowshrinking interface retrofit2.Call
-keep,allowobfuscation,allowshrinking class retrofit2.Response

# ========================================
# KOTLIN COROUTINES CONTINUATIONS
# ========================================
-keep,allowobfuscation,allowshrinking class kotlin.coroutines.Continuation

# ========================================
# ✅ FLUTTER LOCAL NOTIFICATIONS
# ========================================
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.**

# ========================================
# ✅ APP LINKS & DEEP LINKING
# ========================================
-keep class android.app.** { *; }
-keep class android.content.** { *; }
-keep class android.net.** { *; }

# ========================================
# CUSTOM APP MODELS (Update with your package)
# ========================================
-keep class com.agrimore.agrimore.models.** { *; }
-keep class com.agrimore.agrimore.services.** { *; }

# ========================================
# GENERIC SIGNATURES (Keep for debugging)
# ========================================
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# ========================================
# NATIVE METHODS
# ========================================
-keepclasseswithmembernames class * {
    native <methods>;
}

# ========================================
# KEEP ENUM VARIANTS
# ========================================
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ========================================
# CALLBACK INTERFACES
# ========================================
-keep class * implements java.io.Serializable { *; }
-keep class * implements java.lang.Comparable { *; }

# ========================================
# KEEP R CLASS (Android Resources)
# ========================================
-keepclassmembers class **.R$* {
    public static <fields>;
}
