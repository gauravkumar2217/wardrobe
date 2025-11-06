import org.gradle.api.tasks.Delete
import org.gradle.api.file.Directory

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // ✅ Firebase & Play Services plugin (latest stable)
        classpath("com.google.gms:google-services:4.4.2")
        // ✅ Kotlin Gradle plugin (latest stable compatible with AGP 8.5+)
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.24")
        // ✅ Android Gradle Plugin (ensure this matches your Gradle version)
        classpath("com.android.tools.build:gradle:8.5.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ✅ Redirect all build outputs to a common directory to match Flutter structure
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // ✅ Enforce Java 11 for all modules (including plugins)
    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.findByName("android")
            if (android != null) {
                try {
                    val androidExtension = android as com.android.build.gradle.BaseExtension
                    androidExtension.compileOptions {
                        sourceCompatibility = JavaVersion.VERSION_11
                        targetCompatibility = JavaVersion.VERSION_11
                    }
                } catch (_: Exception) {
                    // Some subprojects might not have BaseExtension
                }
            }
        }

        // ✅ Ensure all Kotlin subprojects use Java 11 toolchain
        extensions.findByType(org.jetbrains.kotlin.gradle.dsl.KotlinJvmProjectExtension::class.java)?.apply {
            jvmToolchain(11)
        }
    }
}

// ✅ Clean task for consistent Flutter integration
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
