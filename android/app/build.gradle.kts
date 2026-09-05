import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { input ->
        keystoreProperties.load(input)
    }
}

val signingValue: (String) -> String? = { key ->
    keystoreProperties.getProperty(key)?.trim()?.takeIf { it.isNotEmpty() }
}

val releaseSigningRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

if (releaseSigningRequested) {
    if (!keystorePropertiesFile.exists()) {
        throw GradleException(
            "Missing android/key.properties. Configure permanent release signing before building release.",
        )
    }

    val requiredSigningKeys =
        listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    val missingSigningKeys = requiredSigningKeys.filter { signingValue(it) == null }
    if (missingSigningKeys.isNotEmpty()) {
        throw GradleException(
            "Missing release signing values in android/key.properties: " +
                missingSigningKeys.joinToString(),
        )
    }

    val configuredStoreFile = file(signingValue("storeFile")!!)
    if (!configuredStoreFile.isFile) {
        throw GradleException(
            "Release keystore was not found at ${configuredStoreFile.absolutePath}.",
        )
    }
}

android {
    namespace = "com.example.panpanskii_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.panpanskii_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        multiDexEnabled = true
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = signingValue("keyAlias")
                keyPassword = signingValue("keyPassword")
                storeFile = signingValue("storeFile")?.let { file(it) }
                storePassword = signingValue("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.window:window:1.0.0")
    implementation("androidx.window:window-java:1.0.0")
}
