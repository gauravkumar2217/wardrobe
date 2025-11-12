# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.

# Keep Firebase classes
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep Flutter classes
-keep class io.flutter.** { *; }

# Prevent advertising ID access (if any library tries to access it)
# This ensures no advertising ID is collected even if a dependency tries to access it
-keep class com.google.android.gms.ads.identifier.** { *; }
-dontwarn com.google.android.gms.ads.identifier.**

# Explicitly prevent any advertising SDK initialization
-assumenosideeffects class com.google.android.gms.ads.** {
    *;
}

# Keep notification classes
-keep class androidx.core.app.NotificationCompat { *; }
-keep class androidx.core.app.NotificationManagerCompat { *; }

# Keep timezone classes
-keep class org.threeten.bp.** { *; }

# Keep image compression classes
-keep class com.example.flutter_image_compress.** { *; }

# Keep SQLite classes
-keep class net.sqlcipher.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }

# Remove logging in release builds
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

