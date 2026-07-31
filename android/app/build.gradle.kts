import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val googleSampleAndroidAppId = "ca-app-pub-3940256099942544~3347511713"
val googleSamplePublisherId = "3940256099942544"
val admobAppIdPattern = Regex("^ca-app-pub-[0-9]{16}~[0-9]{10}$")
val admobAdUnitIdPattern = Regex("^ca-app-pub-[0-9]{16}/[0-9]{10}$")

fun decodeDartDefines(rawValue: String): Map<String, String> {
    if (rawValue.isEmpty()) {
        return emptyMap()
    }

    val result = linkedMapOf<String, String>()
    rawValue.split(",").forEach { encodedEntry ->
        if (encodedEntry.isEmpty() || encodedEntry.trim() != encodedEntry) {
            throw GradleException("DART_DEFINES contains an empty or malformed entry.")
        }

        val bytes = try {
            Base64.getDecoder().decode(encodedEntry)
        } catch (_: IllegalArgumentException) {
            throw GradleException("DART_DEFINES contains invalid base64.")
        }
        if (Base64.getEncoder().encodeToString(bytes) != encodedEntry) {
            throw GradleException("DART_DEFINES must use canonical base64 encoding.")
        }

        val decodedEntry = try {
            Charsets.UTF_8
                .newDecoder()
                .onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT)
                .decode(ByteBuffer.wrap(bytes))
                .toString()
        } catch (_: Exception) {
            throw GradleException("DART_DEFINES contains invalid UTF-8.")
        }
        val separatorIndex = decodedEntry.indexOf("=")
        if (separatorIndex <= 0) {
            throw GradleException("DART_DEFINES entries must use key=value.")
        }
        val key = decodedEntry.substring(0, separatorIndex)
        val value = decodedEntry.substring(separatorIndex + 1)
        if (!Regex("^[A-Za-z_][A-Za-z0-9_]*$").matches(key)) {
            throw GradleException("DART_DEFINES contains an invalid key.")
        }
        if (result.put(key, value) != null) {
            throw GradleException("DART_DEFINES contains a duplicate key: $key.")
        }
    }
    return result
}

fun isLiveAdMobAppId(value: String?): Boolean =
    value != null &&
        admobAppIdPattern.matches(value) &&
        !value.startsWith("ca-app-pub-$googleSamplePublisherId")

fun isLiveAdMobAdUnitId(value: String?): Boolean =
    value != null &&
        admobAdUnitIdPattern.matches(value) &&
        !value.startsWith("ca-app-pub-$googleSamplePublisherId")

val dartDefinesProperty = providers.gradleProperty("dart-defines").orNull
val dartDefinesEnvironment = providers.environmentVariable("DART_DEFINES").orNull
if (dartDefinesProperty != null &&
    dartDefinesEnvironment != null &&
    dartDefinesProperty != dartDefinesEnvironment
) {
    throw GradleException(
        "The dart-defines Gradle property and DART_DEFINES environment value differ.",
    )
}
val dartDefines = decodeDartDefines(
    dartDefinesProperty ?: dartDefinesEnvironment.orEmpty(),
)
val adsEnabled = when (val value = dartDefines["ADS_ENABLED"]) {
    null, "false" -> false
    "true" -> true
    else -> throw GradleException("ADS_ENABLED must be exactly true or false.")
}
val configuredAppEnvironment = dartDefines["APP_ENV"]
val androidProductionAppId = dartDefines["ADMOB_ANDROID_APP_ID"]
val androidProductionBannerId = dartDefines["ADMOB_ANDROID_BANNER_ID"]
val androidProductionRewardedId = dartDefines["ADMOB_ANDROID_REWARDED_ID"]
val iosProductionAppId = dartDefines["ADMOB_IOS_APP_ID"]
val iosProductionBannerId = dartDefines["ADMOB_IOS_BANNER_ID"]
val iosProductionRewardedId = dartDefines["ADMOB_IOS_REWARDED_ID"]
val selectedAndroidProductionAppId =
    if (adsEnabled && isLiveAdMobAppId(androidProductionAppId)) {
        requireNotNull(androidProductionAppId)
    } else {
        googleSampleAndroidAppId
    }

fun resolvedAppEnvironment(configurationName: String): String =
    configuredAppEnvironment ?: if (
        configurationName.contains("release", ignoreCase = true)
    ) {
        "production"
    } else {
        "development"
    }

fun validateAdMobConfiguration(
    flavor: String,
    configurationName: String,
) {
    val expectedEnvironment = if (flavor == "dev") {
        "development"
    } else {
        "production"
    }
    if (configuredAppEnvironment != null &&
        configuredAppEnvironment != expectedEnvironment
    ) {
        throw GradleException(
            "APP_ENV does not match the Android $flavor flavor.",
        )
    }
    if (!adsEnabled) {
        return
    }
    if (resolvedAppEnvironment(configurationName) != expectedEnvironment) {
        throw GradleException(
            "ADS_ENABLED=true requires APP_ENV=$expectedEnvironment for " +
                "the Android $flavor flavor.",
        )
    }
    if (flavor == "prod") {
        if (!isLiveAdMobAppId(androidProductionAppId)) {
            throw GradleException(
                "ADMOB_ANDROID_APP_ID must be a live AdMob app ID when " +
                    "production ads are enabled.",
            )
        }
        if (!isLiveAdMobAppId(iosProductionAppId)) {
            throw GradleException(
                "ADMOB_IOS_APP_ID must be a live AdMob app ID when " +
                    "production ads are enabled.",
            )
        }
        val adUnitIds = mapOf(
            "ADMOB_ANDROID_BANNER_ID" to androidProductionBannerId,
            "ADMOB_ANDROID_REWARDED_ID" to androidProductionRewardedId,
            "ADMOB_IOS_BANNER_ID" to iosProductionBannerId,
            "ADMOB_IOS_REWARDED_ID" to iosProductionRewardedId,
        )
        adUnitIds.forEach { (name, value) ->
            if (!isLiveAdMobAdUnitId(value)) {
                throw GradleException(
                    "$name must be a live AdMob ad unit ID when production " +
                        "ads are enabled.",
                )
            }
        }
    }
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
        isCoreLibraryDesugaringEnabled = true
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
        multiDexEnabled = true
    }

    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "KISOU Dev")
            resValue("string", "admob_app_id", googleSampleAndroidAppId)
            manifestPlaceholders["widgetDeepLinkScheme"] = "kisou-dev"
        }
        create("prod") {
            dimension = "environment"
            resValue("string", "app_name", "KISOU")
            resValue(
                "string",
                "admob_app_id",
                selectedAndroidProductionAppId,
            )
            manifestPlaceholders["widgetDeepLinkScheme"] = "kisou"
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

tasks.configureEach {
    val manifestTask = Regex(
        "^process(Dev|Prod)(Debug|Profile|Release)MainManifest$",
    ).matchEntire(name)
    if (manifestTask != null) {
        val flavor = manifestTask.groupValues[1].lowercase()
        val configurationName = manifestTask.groupValues[2]
        doFirst {
            validateAdMobConfiguration(flavor, configurationName)
        }
    }
}

tasks.register("validateDevAdMobConfig") {
    group = "verification"
    description = "Validates native AdMob configuration for the dev flavor."
    doLast {
        validateAdMobConfiguration("dev", "debug")
    }
}

tasks.register("validateProdAdMobConfig") {
    group = "verification"
    description = "Validates native AdMob configuration for the prod flavor."
    doLast {
        validateAdMobConfiguration("prod", "release")
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
