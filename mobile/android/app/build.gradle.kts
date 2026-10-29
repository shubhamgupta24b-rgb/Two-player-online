import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

// The flat app (--dart-define=APP_STYLE=flat) is a second app: its own id and name, so it
// installs next to Party Games. Flutter hands the dart-defines to Gradle base64-encoded.
val dartDefines: List<String> = (project.findProperty("dart-defines") as String?)
    ?.split(",")
    ?.map { String(Base64.getDecoder().decode(it)) }
    ?: emptyList()
val flatApp = dartDefines.contains("APP_STYLE=flat")
val requestedLiveAds = dartDefines.contains("ADMOB_LIVE_ADS=true")
val releaseBuild = gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }
val googleMobileAdsAppId = if (requestedLiveAds && releaseBuild) {
    "ca-app-pub-2273708482671832~3323244780"
} else {
    // Google's official Android test app ID. Debug and non-live release builds stay on test inventory.
    "ca-app-pub-3940256099942544~3347511713"
}

// Release signing key (android/key.properties + upload-keystore.jks, never committed).
// Without them (e.g. a CI build) release builds fall back to the debug key.
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

android {
    namespace = "com.example.multiplayer_game"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = if (flatApp) "com.shubhamgupta.partygames.flat" else "com.shubhamgupta.partygames"
        manifestPlaceholders["appLabel"] = if (flatApp) "Party Games Flat" else "Party Games"
        manifestPlaceholders["googleMobileAdsAppId"] = googleMobileAdsAppId
        // API 24 with Flutter 3.38 (google_mobile_ads 6.x needs 23+). Flutter's migrator
        // rewrites any hard-coded value below its minimum during the build, so use its value.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keyProps.isNotEmpty()) {
            create("release") {
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
                storeFile = file(keyProps.getProperty("storeFile"))
                storePassword = keyProps.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
