# Keep TWA / Custom Tabs classes — required for Chrome handoff
-keep class com.google.androidbrowserhelper.** { *; }
-keep class androidx.browser.** { *; }
-keep class android.support.customtabs.** { *; }

# Keep our launcher activity
-keep class app.lovable.meowmeow.twa.** { *; }

# Standard Android attributes Bubblewrap relies on
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable
