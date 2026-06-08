# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Play Core (deferred components — not used, suppress R8 warning)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# WebView / JavaScript bridge
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# SharedPreferences
-keep class androidx.preference.** { *; }

# Keep native methods
-keepclassmembers class * {
    native <methods>;
}
