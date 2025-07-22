plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.lupusCare"
    compileSdk = 35

    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.example.lupusCare"
        minSdk = 23  // Updated from 22 to 23 for Firebase compatibility
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
        multiDexEnabled = true  // Required for Firebase
    }

    compileOptions {
        // FIXED: Enable desugaring for flutter_local_notifications
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
//        coreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    buildTypes {
        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
        }
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // Handle potential packaging conflicts
    packagingOptions {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
            excludes += "/META-INF/DEPENDENCIES"
            excludes += "/META-INF/LICENSE"
            excludes += "/META-INF/LICENSE.txt"
            excludes += "/META-INF/NOTICE"
            excludes += "/META-INF/NOTICE.txt"
        }
    }
}

dependencies {
    // FIXED: Add core library desugaring dependency
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // Firebase BoM - use latest stable version
    implementation(platform("com.google.firebase:firebase-bom:33.1.2"))

    // Firebase libraries (versions managed by BoM)
    implementation("com.google.firebase:firebase-analytics-ktx")
    implementation("com.google.firebase:firebase-auth-ktx")
    implementation("com.google.firebase:firebase-firestore-ktx")
    implementation("com.google.firebase:firebase-messaging-ktx")

    // Google Sign-in
    implementation("com.google.android.gms:play-services-auth:21.2.0")

    // Additional Google Play Services
    implementation("com.google.android.gms:play-services-base:18.3.0")

    // Multidex support for Firebase
    implementation("androidx.multidex:multidex:2.0.1")

    // Core Android libraries
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
}

flutter {
    source = "../.."
}