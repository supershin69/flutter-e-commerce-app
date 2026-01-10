plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.e_commerce_frontend"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.example.e_commerce_frontend"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        multiDexEnabled = true 
    }

    compileOptions {
        // Use Java 17 for Java code
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        // Use Java 17 for Kotlin code (Simple string assignment)
        jvmTarget = "17"
    }
}

dependencies {
    // Kotlin DSL syntax: use parentheses and double quotes
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    
    implementation(platform("com.google.firebase:firebase-bom:34.7.0"))
    implementation("com.google.firebase:firebase-analytics")
}

flutter {
    source = "../.."
}