plugins { id("com.android.application") version "9.1.0" apply false }

tasks.register("validateDebug") {
    group = "verification"
    description = "Builds the debug APK and runs unit tests and Android lint locally."
    dependsOn(":app:assembleDebug", ":app:testDebugUnitTest", ":app:lintDebug")
}
