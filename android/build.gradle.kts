import org.gradle.api.tasks.Delete
import org.gradle.api.file.Directory
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

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
        // ✅ Android Gradle Plugin (updated to meet dependency requirements)
        classpath("com.android.tools.build:gradle:8.9.1")
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

    // ✅ Enforce Java 17 for all modules (including plugins)
    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.findByName("android")
            if (android != null) {
                try {
                    val androidExtension = android as com.android.build.gradle.BaseExtension
                    androidExtension.compileOptions {
                        sourceCompatibility = JavaVersion.VERSION_17
                        targetCompatibility = JavaVersion.VERSION_17
                    }
                } catch (_: Exception) {
                    // Some subprojects might not have BaseExtension
                }
            }
        }

        // ✅ Ensure all Kotlin subprojects use Java 17 toolchain
        extensions.findByType(org.jetbrains.kotlin.gradle.dsl.KotlinJvmProjectExtension::class.java)?.apply {
            jvmToolchain(17)
        }
        
        // ✅ Explicitly configure all Kotlin compilation tasks to use JVM target 17
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            kotlinOptions {
                jvmTarget = "17"
            }
        }
    }
}

// ✅ Clean task for consistent Flutter integration
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
