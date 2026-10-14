// Godot Android plugin (v2) with AdMob ads, Google UMP consent and Play Billing.
//
//   ./gradlew copyAarToAddon
//
// builds the plugin and copies it to addons/cozy_services/bin/, where the
// editor export plugin picks it up for Android Gradle builds.
//
// Keep the dependency list in sync with DEPENDENCIES in
// addons/cozy_services/cozy_services.gd: a local .aar does not carry its own
// Maven dependencies, so the export plugin adds them to the game's build.

plugins {
    id("com.android.library") version "8.7.3"
}

android {
    namespace = "com.cozyminirestaurant.services"
    compileSdk = 35

    defaultConfig {
        minSdk = 24
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }
}

dependencies {
    compileOnly("org.godotengine:godot:4.7.2.stable")
    implementation("com.google.android.gms:play-services-ads:24.4.0")
    implementation("com.google.android.ump:user-messaging-platform:3.2.0")
    implementation("com.android.billingclient:billing:8.0.0")
}

val copyAarToAddon by tasks.registering(Copy::class) {
    dependsOn("assembleRelease")
    from(layout.buildDirectory.dir("outputs/aar"))
    include("cozy-services-release.aar")
    into(rootDir.resolve("../addons/cozy_services/bin"))
}
