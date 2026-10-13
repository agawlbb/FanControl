plugins { id("com.android.application") }
android {
    namespace = "dev.fancontrol.wear"
    compileSdk = 36
    defaultConfig {
        applicationId = "dev.fancontrol.wear"
        minSdk = 30
        targetSdk = 35
        versionCode = 10
        versionName = "1.3.3"

    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    buildFeatures { buildConfig = true }
}
dependencies {
    implementation("androidx.wear.tiles:tiles:1.6.2")
    implementation("androidx.wear.protolayout:protolayout:1.4.2")
    implementation("androidx.viewpager2:viewpager2:1.1.0")
    implementation("com.google.guava:guava:33.4.8-android")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20250517")
    testImplementation("com.squareup.okhttp3:mockwebserver:4.12.0")
}
