# R8 is on for release. These are the classes it cannot see are used, because
# they are reached by reflection or from native code rather than from Dart.

# Flutter's own entry points and any plugin registrant.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Secure storage: the Android keystore wrapper is instantiated by name.
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Firebase — messaging resolves service and receiver classes from the manifest
# at runtime, and the models are deserialised reflectively.
-keep class io.flutter.plugins.firebase.** { *; }
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Keeps the annotations R8 and the Play Core library rely on.
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Play Core, referenced by Flutter's deferred-components support even when
# unused; without this the build fails on missing classes.
-dontwarn com.google.android.play.core.**

# Line numbers are stripped along with everything else, which makes a stack
# trace from a user unreadable. The table is kept and the file name faked, so
# traces still map to lines without naming the source file.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
