import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { stream ->
        keystoreProperties.load(stream)
    }
}

android {
    namespace = "com.vibekit.vibekit_ai"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.vibekit.vibekit_ai"
        minSdk = 24
        targetSdk = 36
        versionCode = 4
        versionName = "1.0.3"

        val isReleaseRequested = gradle.startParameter.taskNames.any {
            it.contains("Release", ignoreCase = true)
        }
        val resolvedAdmobAppId = (project.findProperty("admobAppId") as String?)
            ?: keystoreProperties.getProperty("admobAppId")
            ?: if (isReleaseRequested) {
                throw GradleException("Missing production admobAppId property or key.properties entry for release build.")
            } else {
                "ca-app-pub-3940256099942544~3347511713"
            }
        manifestPlaceholders["admobAppId"] = resolvedAdmobAppId
    }

    signingConfigs {
        create("release") {
            val storeFilePath = keystoreProperties.getProperty("storeFile")
            if (storeFilePath != null) {
                val candApp = file(storeFilePath)
                val candRoot = rootProject.file(storeFilePath)
                storeFile = if (candApp.exists()) candApp else candRoot
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            val isReleaseRequested = gradle.startParameter.taskNames.any {
                it.contains("Release", ignoreCase = true)
            }
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else if (isReleaseRequested) {
                throw GradleException("Missing app/android/key.properties for release signing.")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            ndk {
                debugSymbolLevel = "FULL"
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
