plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.nettoyageplus.agent"
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
        applicationId = "com.nettoyageplus.agent"
        minSdk = flutter.minSdkVersion  // Required by geolocator, firebase, google_maps_flutter
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Google Maps API key (replace with your real key from Google Cloud Console)
        manifestPlaceholders["googleMapsApiKey"] = "YOUR_GOOGLE_MAPS_API_KEY"
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // TODO: Add your own signing config for the release build.
            signingConfig = signingConfigs.getByName("debug")
        }
        debug {
            manifestPlaceholders["googleMapsApiKey"] = "YOUR_GOOGLE_MAPS_API_KEY_DEBUG"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    // Required by Flutter for deferred components support
    implementation("com.google.android.play:core:1.10.3")
}
