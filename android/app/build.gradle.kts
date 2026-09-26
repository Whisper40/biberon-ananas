import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}
val releaseKeystoreFile = keystoreProperties.getProperty("storeFile")?.let {
    rootProject.file(it)
}

fun androidVersionCode(versionName: String, buildNumber: String): Int {
    val match = Regex("^(\\d+)\\.(\\d+)\\.(\\d+)$").matchEntire(versionName)
        ?: error("Version Android invalide : '$versionName'. Format attendu : X.Y.Z")
    val values = (match.groupValues.drop(1) + buildNumber).map {
        it.toIntOrNull() ?: error("Numéro de build Android invalide : '$it'.")
    }
    require(values.all { it in 0..99 }) {
        "Chaque composant de version Android doit être compris entre 0 et 99."
    }
    val (major, minor, patch, build) = values
    return major * 1_000_000 + minor * 10_000 + patch * 100 + build
}

val pubspecVersion = rootProject.file("../pubspec.yaml").readText()
val pubspecBuildNumber = Regex(
    "(?m)^version:\\s*\\d+\\.\\d+\\.\\d+\\+(\\d+)\\s*$",
).find(pubspecVersion)?.groupValues?.get(1)
    ?: error("Impossible de lire le numéro de build dans pubspec.yaml.")

android {
    namespace = "com.biberon.biberon_ananas"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.biberon.biberon_ananas"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = androidVersionCode(flutter.versionName, pubspecBuildNumber)
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (releaseKeystoreFile?.exists() == true) {
                storeFile = releaseKeystoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
