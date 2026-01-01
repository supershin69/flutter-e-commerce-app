plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin") // Flutter plugin
}

android {
    namespace = "com.example.e_commerce_frontend"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.example.e_commerce_frontend"
        minSdk = flutter.minSdkVersion                      // minimum supported Android version
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"  // 🔑 Must match Java version
    }
}

flutter {
    source = "../.."
}
