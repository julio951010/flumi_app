import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Llaves de firma release (android/key.properties, ignorado por git).
// Se leen a variables simples porque dentro de los bloques android {}
// el operador [] choca con el scope del DSL.
val keystoreProperties = Properties().apply {
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}
val hasReleaseKeystore = keystoreProperties.containsKey("storeFile")
val releaseKeyAlias = keystoreProperties.getProperty("keyAlias", "")
val releaseKeyPassword = keystoreProperties.getProperty("keyPassword", "")
val releaseStoreFile = keystoreProperties.getProperty("storeFile", "")
val releaseStorePassword = keystoreProperties.getProperty("storePassword", "")

android {
    namespace = "com.jchd.flumi"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
        // flutter_local_notifications (y firebase_messaging) requieren
        // desugaring de core library para java.time.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.jchd.flumi"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Firebase Messaging requiere minSdk 23; 24 cubre también
        // flutter_local_notifications sin conflicto.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
                storeFile = file(releaseStoreFile)
                storePassword = releaseStorePassword
            }
        }
    }

    buildTypes {
        release {
            // Firma release con keystore propio; si key.properties no existe
            // (clon fresco sin llaves), cae a debug para no romper el build.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // Reduce tamaño del APK: elimina código y recursos sin usar.
            isMinifyEnabled = true
            isShrinkResources = true
            // Reglas keep para flutter_local_notifications (ic_notif) y FCM.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
