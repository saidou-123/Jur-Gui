// ============================================================
// android/app/build.gradle.kts
// Configuration corrigée pour flutter_local_notifications
// ============================================================

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.te.depart"
    compileSdk = 36  // ✅ Bon (supérieur à 35)
    ndkVersion = "29.0.14206865"
    
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true  // ✅ Bon
    }
    
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }
    
    defaultConfig {
        applicationId = "com.te.depart"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
        
        // ✅ AJOUT: MultiDex si nécessaire
        multiDexEnabled = true
    }
    
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            
            // ✅ AJOUT CRITIQUE: Configuration ProGuard pour protéger les ressources
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        
        // Configuration de debug (optionnelle, pour les tests)
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ✅ Desugaring (déjà présent - bon)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    
    // ✅ AJOUT: WindowManager pour éviter les crashs Android 12L+
    implementation("androidx.window:window:1.3.0")
    
    // ✅ AJOUT: MultiDex (si nécessaire)
    implementation("androidx.multidex:multidex:2.0.1")
}