plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

// Tek kaynak: oyun dosyaları depo kökündeki web/ klasöründen derleme sırasında kopyalanır.
val webSrc = rootProject.layout.projectDirectory.dir("../web")
val webAssetsOut = layout.buildDirectory.dir("generated/webassets")

val copyWebGame by tasks.registering(Sync::class) {
    description = "web/ klasöründeki Three.js oyununu APK varlıklarına kopyalar"
    from(webSrc) {
        exclude("**/.DS_Store", "levels.json")
    }
    into(webAssetsOut.map { it.dir("web") })
}

android {
    namespace = "com.akin.kayipkuleler"
    compileSdk = 35

    // Kalıcı imza anahtarı: her derleme AYNI anahtarla imzalanır, böylece yeni APK eski sürümün
    // üstüne güncelleme olarak kurulur ve oyun ilerlemesi korunur. (Eskiden CI her çalıştırmada
    // rastgele bir debug anahtarı üretiyordu; Android bu yüzden güncellemeyi reddediyordu.)
    // Play Store için KEYSTORE_FILE / KEYSTORE_PASSWORD / KEY_ALIAS / KEY_PASSWORD ortam
    // değişkenleriyle (GitHub Secrets) kendi gizli anahtarınızı verin.
    val stableKey = file(System.getenv("KEYSTORE_FILE") ?: "../keystore/kayipkuleler.jks")
    signingConfigs {
        create("stable") {
            storeFile = stableKey
            storePassword = System.getenv("KEYSTORE_PASSWORD") ?: "kayipkuleler"
            keyAlias = System.getenv("KEY_ALIAS") ?: "kayipkuleler"
            keyPassword = System.getenv("KEY_PASSWORD") ?: "kayipkuleler"
        }
    }
    // Anahtar yoksa (ör. yerel derleme) eskisi gibi debug anahtarına düşülür.
    val signing = if (stableKey.exists()) signingConfigs.getByName("stable") else signingConfigs.getByName("debug")

    defaultConfig {
        applicationId = "com.akin.kayipkuleler"
        minSdk = 24
        targetSdk = 35
        versionCode = (System.getenv("GITHUB_RUN_NUMBER") ?: "1").toInt()
        versionName = (System.getenv("APP_VERSION_NAME") ?: "1.0.0")
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            signingConfig = signing
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
            signingConfig = signing
        }
    }

    sourceSets["main"].assets.srcDir(webAssetsOut)

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        buildConfig = true
    }
}

tasks.named("preBuild") { dependsOn(copyWebGame) }

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.activity:activity-ktx:1.9.3")
    implementation("androidx.webkit:webkit:1.12.1")
}
