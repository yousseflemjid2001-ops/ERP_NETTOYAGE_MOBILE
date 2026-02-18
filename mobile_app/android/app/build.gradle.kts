plugins {
    id("com.android.application")
    id("kotlin-android")
    // FCM requires the Google Services plugin
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.nettoyageplus.agent"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
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
