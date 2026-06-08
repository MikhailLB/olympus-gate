# Flutter engine + plugins
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Play Core (deferred components — not used, suppress R8 warning)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Firebase (core, messaging, app check)
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# AppsFlyer SDK
-keep class com.appsflyer.** { *; }
-dontwarn com.appsflyer.**

# WebView / JavaScript bridge
-keep class io.flutter.plugins.webviewflutter.** { *; }
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# SharedPreferences
-keep class androidx.preference.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelable creators
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Strip Android log calls from release binary
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}
