import java.util.Properties
import org.gradle.api.tasks.compile.JavaCompile

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase services
    id("com.google.gms.google-services")
}

// Load keystore properties
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()

if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use {
        keystoreProperties.load(it)
    }
}

android {
    namespace = "com.wardrobe_chat.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.wardrobe_chat.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ✅ Java and Kotlin configuration
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required for newer Flutter + notification libraries
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
        freeCompilerArgs = listOf("-Xjvm-default=all")
    }

    // ✅ Suppress obsolete Java 8 warnings from dependencies
    tasks.withType<JavaCompile>().configureEach {
        options.compilerArgs.add("-Xlint:-options")
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias") ?: ""
            keyPassword = keystoreProperties.getProperty("keyPassword") ?: ""
            storePassword = keystoreProperties.getProperty("storePassword") ?: ""
            val storeFilePath = keystoreProperties.getProperty("storeFile")
            storeFile = if (storeFilePath != null) file(storeFilePath) else null
        }
    }

    buildTypes {
        getByName("release") {
            // Enable R8/ProGuard for code shrinking and obfuscation
            isMinifyEnabled = false
            isShrinkResources = false
            
            // Use ProGuard rules
            proguardFiles(
               getDefaultProguardFile("proguard-android-optimize.txt"),
               "proguard-rules.pro"
            )
            
            // Only use signing config if keystore file exists
            signingConfig = if (keystorePropertiesFile.exists()) {
               signingConfigs.getByName("release")
            } else null
            
        }
        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

// ✅ Force Kotlin to use Java 17 toolchain globally
kotlin {
    jvmToolchain(17)
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring (required for flutter_local_notifications)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    // AndroidX Core for enableEdgeToEdge (Android 15+ edge-to-edge compatibility)
    implementation("androidx.core:core-ktx:1.17.0")
}

// Exclude firebase-iid to resolve duplicate class conflict
// firebase-iid has been merged into firebase-messaging
configurations.all {
    exclude(group = "com.google.firebase", module = "firebase-iid")
}