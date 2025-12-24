plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties

val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) {
        load(file.inputStream())
    }
}

android {
    namespace = "com.wave.up"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }


    defaultConfig {
        applicationId = "com.wave.up"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystoreProperties.isNotEmpty()) {
                storeFile = file(keystoreProperties["storeFile"] ?: "")
                storePassword = keystoreProperties["storePassword"]?.toString() ?: ""
                keyAlias = keystoreProperties["keyAlias"]?.toString() ?: ""
                keyPassword = keystoreProperties["keyPassword"]?.toString() ?: ""
            }
        }
    }

    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "WaveUp (Dev)")
            matchingFallbacks += listOf("sandbox", "debug")
            manifestPlaceholders["APP_LINK_HOST"] = "dev.waveup.app"
        }
        create("prod") {
            dimension = "env"
            resValue("string", "app_name", "WaveUp")
            matchingFallbacks += listOf("production", "release")
            manifestPlaceholders["APP_LINK_HOST"] = "waveup.app"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android.txt"),
                file("proguard-rules.pro")
            )
        }
    }
}

configurations.configureEach {
    if (!name.equals("coreLibraryDesugaring", ignoreCase = true)) {
        exclude(group = "com.android.tools", module = "desugar_jdk_libs")
        exclude(group = "com.android.tools", module = "desugar_jdk_libs_nio")
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.2")
    implementation("javax.xml.stream:stax-api:1.0-2")
}

flutter {
    source = "../.."
}
