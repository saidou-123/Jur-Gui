# ============================================================
# android/app/proguard-rules.pro
# Règles ProGuard pour flutter_local_notifications
# ============================================================

# ===== RÈGLES GÉNÉRALES FLUTTER =====
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ===== RÈGLES POUR FLUTTER_LOCAL_NOTIFICATIONS =====
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Garder les classes de notification
-keep class * extends android.app.Service
-keep class * extends android.content.BroadcastReceiver

# ===== RÈGLES GSON (utilisé par le plugin) =====
# Source: https://github.com/google/gson/blob/master/examples/android-proguard-example/proguard.cfg

-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**

# Garder les classes génériques
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# Application classes that will be serialized/deserialized over Gson
-keep class com.google.gson.examples.android.model.** { <fields>; }

# Prevent proguard from stripping interface information from TypeAdapter, TypeAdapterFactory,
# JsonSerializer, JsonDeserializer instances (so they can be used in @JsonAdapter)
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Prevent R8 from leaving Data object members always null
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# ===== RÈGLES POUR RESSOURCES =====
# ✅ CRITIQUE: Garder TOUTES les ressources drawable (icônes de notification)
-keep class **.R$drawable { *; }
-keepclassmembers class **.R$* {
    public static <fields>;
}

# ✅ CRITIQUE: Garder les fichiers son (notifications)
-keep class **.R$raw { *; }

# ✅ Si vous utilisez @mipmap/ic_launcher comme icône
-keep class **.R$mipmap { *; }

# ===== RÈGLES SUPABASE =====
-keep class io.supabase.** { *; }
-keep class io.github.jan.supabase.** { *; }

# ===== AUTRES PLUGINS =====
-keep class io.flutter.plugins.** { *; }