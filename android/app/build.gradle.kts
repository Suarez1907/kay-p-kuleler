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
            // Kurulabilir olması için hata ayıklama anahtarıyla imzalanır (Play Store için kendi anahtarınızı kullanın)
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
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
