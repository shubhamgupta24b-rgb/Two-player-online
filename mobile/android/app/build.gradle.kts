import java.util.Base64

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
        applicationId = if (flatApp) "com.example.multiplayer_game.flat" else "com.example.multiplayer_game"
        manifestPlaceholders["appLabel"] = if (flatApp) "Party Games Flat" else "Party Games"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
