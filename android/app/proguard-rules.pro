# ============================================
# ProGuard Rules for Wardrobe App
# ============================================

# ============================================
# Flutter Rules
# ============================================
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# ============================================
# Firebase Rules
# ============================================
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firebase Authentication
-keep class com.google.firebase.auth.** { *; }
-keep class com.google.android.gms.auth.** { *; }

# Firebase Firestore
-keep class com.google.firebase.firestore.** { *; }
-keep class com.google.cloud.firestore.** { *; }

# Firebase Storage
-keep class com.google.firebase.storage.** { *; }

# Firebase Messaging
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.iid.** { *; }

# Firebase Analytics
-keep class com.google.firebase.analytics.** { *; }
-keep class com.google.android.gms.measurement.** { *; }

# ============================================
# Advertising ID Prevention
# ============================================
# Prevent advertising ID access (if any library tries to access it)
-keep class com.google.android.gms.ads.identifier.** { *; }
-dontwarn com.google.android.gms.ads.identifier.**

# Explicitly prevent any advertising SDK initialization
-assumenosideeffects class com.google.android.gms.ads.** {
    *;
}

# ============================================
# AndroidX and Support Libraries
# ============================================
-keep class androidx.** { *; }
-keep interface androidx.** { *; }
-dontwarn androidx.**

# Notification classes
-keep class androidx.core.app.NotificationCompat { *; }
-keep class androidx.core.app.NotificationManagerCompat { *; }

# ============================================
# Third-Party Libraries
# ============================================
# Timezone
-keep class org.threeten.bp.** { *; }
-dontwarn org.threeten.bp.**

# Image compression
-keep class com.example.flutter_image_compress.** { *; }
-dontwarn com.example.flutter_image_compress.**

# SQLite
-keep class net.sqlcipher.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }
-dontwarn net.sqlcipher.**

# Shared Preferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# Device Info
-keep class io.flutter.plugins.deviceinfo.** { *; }

# Image Picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# SMS Autofill
-keep class com.julienvignali.smsautofill.** { *; }

# Connectivity
-keep class dev.fluttercommunity.plus.connectivity.** { *; }

# ============================================
# Native Methods
# ============================================
-keepclasseswithmembernames class * {
    native <methods>;
}

# ============================================
# Serializable Classes
# ============================================
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# ============================================
# Parcelable
# ============================================
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# ============================================
# Keep Application Class
# ============================================
-keep public class * extends android.app.Application

# ============================================
# Keep Main Activity
# ============================================
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Fragment
-keep public class * extends androidx.fragment.app.Fragment

# ============================================
# Remove Logging in Release Builds
# ============================================
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
    public static *** w(...);
    public static *** e(...);
}

# ============================================
# Keep Line Numbers for Better Stack Traces
# ============================================
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

