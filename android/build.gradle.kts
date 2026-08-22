// android/build.gradle (Project Level)

// ⭐️ 1. ဒီ buildscript block ကို အပေါ်ဆုံးမှာ ထည့်ပေးရပါမယ်
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Android Gradle Plugin (သင့် Project မှာ ရှိပြီးသားဆိုရင် ဒီအတိုင်းထားပါ၊ မရှိရင် Version ကိုက်ညီတာထည့်ပါ)
        // classpath("com.android.tools.build:gradle:8.1.0") 

        // ⭐️ Google Services Classpath (Notification အတွက် ဒါလိုအပ်ပါတယ်)
        classpath("com.google.gms:google-services:4.4.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory
    .dir("../../build")
    .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}