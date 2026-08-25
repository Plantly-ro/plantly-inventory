# ProGuard / R8 keep rules for the release build.
#
# Flutter's own keep rules are contributed automatically by the Flutter Gradle
# plugin, so this file only covers plugins that use reflection / Gson and would
# otherwise be stripped or obfuscated into runtime crashes.

# --- flutter_local_notifications (serialises scheduled-notification models via
#     Gson; the plugin's own classes and Gson's type machinery must survive). ---
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# --- Gson (used by flutter_local_notifications). Keep generic signatures and
#     TypeToken so deserialisation of parameterised types keeps working. ---
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# --- Sentry ships consumer ProGuard rules, but keep line/source info so
#     obfuscated stack traces remain symbolicatable. ---
-keepattributes SourceFile,LineNumberTable
-keep class io.sentry.** { *; }

# Do not warn on optional/desugared references R8 can't resolve at build time.
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
