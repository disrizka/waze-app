##########################################
# FLUTTER / DART
##########################################

# Keep Flutter classes
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# Needed when using Flutter plugins (e.g. Firebase, Google Sign-In)
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.app.** { *; }

##########################################
# FIREBASE
##########################################

# Keep Firebase classes
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Firebase Messaging & Analytics
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.iid.FirebaseInstanceIdService
-keep class com.google.firebase.iid.FirebaseInstanceIdReceiver

##########################################
# GOOGLE (Play Services, Auth, etc)
##########################################

-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

##########################################
# GSON (if you use it)
##########################################

-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**
-keep class * implements com.google.gson.TypeAdapter

##########################################
# OKHTTP / RETROFIT (if used)
##########################################

-dontwarn okhttp3.**
-keep class okhttp3.** { *; }

-dontwarn retrofit2.**
-keep class retrofit2.** { *; }

##########################################
# JSON SERIALIZATION (if model mapping is used)
##########################################

# Keep model classes with Gson/Retrofit annotations
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep data classes
-keep class *.model.** { *; }

##########################################
# OTHER GENERAL RULES
##########################################

# Prevent obfuscating enum values
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep annotations (useful for Gson/Retrofit/etc)
-keepattributes *Annotation*
