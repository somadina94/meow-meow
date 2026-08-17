# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.** { *; }

# WebRTC — must not be obfuscated, breaks PeerConnection callbacks
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**

# LiveKit
-keep class io.livekit.** { *; }
-keep class livekit.** { *; }
-dontwarn io.livekit.**

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**

# Supabase / GoTrue / Realtime use Kotlin reflection
-keep class kotlin.Metadata { *; }
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# OkHttp / Okio (used by Supabase SDK)
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**

# Hive (local cache)
-keep class * extends hive.HiveObject { *; }
