import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// A chave do APK de release (README, "Gerar o APK de release"): o arquivo
// android/key.properties, fora do Git, diz onde está o .jks e traz as senhas.
// Sem ele — na integração contínua, em outra máquina —, o release sai com a
// chave de depuração, e o build avisa.
val arquivoDaChave = rootProject.file("key.properties")
val chave = Properties().apply {
    if (arquivoDaChave.exists()) FileInputStream(arquivoDaChave).use { load(it) }
}

android {
    namespace = "io.github.fmesquita341.agendamento_clinico"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "io.github.fmesquita341.agendamento_clinico"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (arquivoDaChave.exists()) {
            create("release") {
                storeFile = file(chave.getProperty("storeFile"))
                storePassword = chave.getProperty("storePassword")
                keyAlias = chave.getProperty("keyAlias")
                keyPassword = chave.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (arquivoDaChave.exists()) {
                signingConfigs.getByName("release")
            } else {
                logger.warn("android/key.properties não existe: o APK de release sai com a chave de depuração.")
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
