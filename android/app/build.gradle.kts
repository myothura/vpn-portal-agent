import java.util.Properties
import java.io.FileInputStream

// Release signing credentials. key.properties and the keystore are both in
// .gitignore — the password would otherwise be in every clone of the repo.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.vpnportal.agent"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // ⭐️ 1. Enable Core Library Desugaring (ဒီကြောင်း ထပ်ထည့်ပါ)
        isCoreLibraryDesugaringEnabled = true

        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.vpnportal.agent"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            // Was signing with the debug key, which is a well-known keypair
            // shipped with the SDK: anyone could have rebuilt and re-signed
            // the APK and it would install over this one as an update.
            signingConfig = signingConfigs.getByName("release")

            // R8: renames classes and methods, strips unused code, and drops
            // the line tables a decompiler reads. It does not make the APK
            // unreadable — nothing does — but it turns a legible Kotlin
            // reconstruction into something that has to be worked out.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

// ⭐️ 2. Add Desugaring Dependency (ဒီ block တစ်ခုလုံး အောက်ဆုံးမှာ ထပ်ထည့်ပါ)
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
