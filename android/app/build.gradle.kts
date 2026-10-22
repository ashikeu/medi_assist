import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing credentials live in android/key.properties, which is
// git-ignored. Without it the release build falls back to debug signing so
// local `flutter build` still works — but such an APK cannot go to Play.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.mediassist.app"
    // 36 because flutter_plugin_android_lifecycle and shared_preferences_android
    // compile against it. targetSdk stays at 35 deliberately — see defaultConfig.
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.mediassist.app"
        minSdk = 26
        // Pinned rather than inherited: Play requires API 35 for new apps and
        // updates, and an inherited value can silently regress on SDK upgrade.
        // Not raised to 36 yet — Android 16 adds further edge-to-edge and
        // background-work behaviour changes that need testing on a real device
        // first.
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        // Strips other locales' Android resources from the APK. Must list
        // every language the app offers (see AppLocales) — the app's own
        // strings are Dart and unaffected, but anything an AndroidX or plugin
        // library contributes falls back to English for a locale left out.
        resourceConfigurations += listOf("en", "bn")
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "WARNING: android/key.properties not found — release build " +
                        "is debug-signed and CANNOT be uploaded to Play."
                )
                signingConfigs.getByName("debug")
            }

            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // DailyAlarmRearmReceiver builds the alarm plugin's own AlarmSettings, and
    // those model classes carry @Serializable. The plugin declares
    // kotlinx-serialization as `implementation`, so the annotation is not on
    // our compile classpath even though the plugin ships it at runtime —
    // hence compileOnly, pinned to the version alarm 5.x resolves.
    compileOnly("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
}
