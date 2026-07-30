import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localReleaseSigningPropertiesFile = rootProject.file("key.properties")
val externalReleaseSigningPropertiesPath = providers
    .environmentVariable("KISOU_ANDROID_KEY_PROPERTIES_PATH")
    .orNull
    ?.takeIf { it.isNotEmpty() }
if (externalReleaseSigningPropertiesPath != null &&
    !File(externalReleaseSigningPropertiesPath).isAbsolute
) {
    throw GradleException(
        "KISOU_ANDROID_KEY_PROPERTIES_PATH must be an absolute path.",
    )
}
val externalReleaseSigningPropertiesFile = externalReleaseSigningPropertiesPath
    ?.let(::File)
val releaseSigningEnvironmentNames = listOf(
    "KISOU_ANDROID_KEYSTORE_PATH",
    "KISOU_ANDROID_KEYSTORE_PASSWORD",
    "KISOU_ANDROID_KEY_ALIAS",
    "KISOU_ANDROID_KEY_PASSWORD",
)
val releaseSigningEnvironmentValues = releaseSigningEnvironmentNames.associateWith {
    providers.environmentVariable(it).orNull?.takeIf(String::isNotEmpty)
}
val releaseSigningUsesEnvironment = releaseSigningEnvironmentValues.values
    .any { it != null }
val releaseSigningSources = listOf(
    externalReleaseSigningPropertiesFile != null,
    releaseSigningUsesEnvironment,
    localReleaseSigningPropertiesFile.isFile,
).count { it }

if (releaseSigningSources > 1) {
    throw GradleException(
        "Configure exactly one Android release signing source: external " +
            "properties file, environment variables, or local key.properties.",
    )
}
if (externalReleaseSigningPropertiesFile != null &&
    !externalReleaseSigningPropertiesFile.isFile
) {
    throw GradleException(
        "The configured external release signing properties file does not exist.",
    )
}
if (releaseSigningUsesEnvironment &&
    releaseSigningEnvironmentValues.values.any { it == null }
) {
    throw GradleException(
        "Provide all KISOU_ANDROID_* signing environment variables or none.",
    )
}

val releaseSigningPropertiesFile = externalReleaseSigningPropertiesFile
    ?: localReleaseSigningPropertiesFile.takeIf { it.isFile }
val releaseSigningProperties = Properties()
if (releaseSigningPropertiesFile != null) {
    releaseSigningPropertiesFile.inputStream().use {
        releaseSigningProperties.load(it)
    }
}

fun releaseSigningValue(propertyName: String, environmentName: String): String? {
    val value = if (releaseSigningPropertiesFile != null) {
        releaseSigningProperties.getProperty(propertyName)
    } else {
        releaseSigningEnvironmentValues[environmentName]
    }
    return value?.takeIf { it.isNotEmpty() }
}

val releaseStoreFile = releaseSigningValue(
    "storeFile",
    "KISOU_ANDROID_KEYSTORE_PATH",
)
val releaseStorePassword = releaseSigningValue(
    "storePassword",
    "KISOU_ANDROID_KEYSTORE_PASSWORD",
)
val releaseKeyAlias = releaseSigningValue(
    "keyAlias",
    "KISOU_ANDROID_KEY_ALIAS",
)
val releaseKeyPassword = releaseSigningValue(
    "keyPassword",
    "KISOU_ANDROID_KEY_PASSWORD",
)
val releaseSigningConfigured = listOf(
    releaseStoreFile,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { it != null }
val releaseTaskRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

fun requireReleaseSigning() {
    if (!releaseSigningConfigured) {
        throw GradleException(
            "Release signing is not configured. Copy key.properties.example " +
                "to android/key.properties or provide all KISOU_ANDROID_* " +
                "signing environment variables.",
        )
    }
    if (!rootProject.file(requireNotNull(releaseStoreFile)).isFile) {
        throw GradleException(
            "The configured release keystore file does not exist.",
        )
    }
}

if (releaseTaskRequested) {
    requireReleaseSigning()
}

gradle.taskGraph.whenReady {
    val releaseArtifactTaskPrefixes = listOf(
        "assemble",
        "bundle",
        "package",
        "sign",
    )
    val releaseArtifactRequested = allTasks.any { task ->
        task.project == project &&
            task.name.contains("release", ignoreCase = true) &&
            releaseArtifactTaskPrefixes.any(task.name::startsWith)
    }
    if (releaseArtifactRequested) {
        requireReleaseSigning()
    }
}

android {
    namespace = "com.example.kisou_app"
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
        // Store/backend app identity (audit S1). namespace stays as the internal
        // R-class package; only the applicationId is the shipped identifier.
        applicationId = "cloud.znak99.kisou"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "KISOU Dev")
        }
        create("prod") {
            dimension = "environment"
            resValue("string", "app_name", "KISOU")
        }
    }

    signingConfigs {
        create("release") {
            if (releaseSigningConfigured) {
                storeFile = rootProject.file(requireNotNull(releaseStoreFile))
                storePassword = requireNotNull(releaseStorePassword)
                keyAlias = requireNotNull(releaseKeyAlias)
                keyPassword = requireNotNull(releaseKeyPassword)
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
