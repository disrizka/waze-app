-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod,Exceptions,SourceFile,LineNumberTable

-keep class io.flutter.** { *; }
-dontwarn io.flutter.**
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.app.** { *; }

-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**

-keep class j$.** { *; }
-dontwarn j$.**

-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

-keep class okhttp3.** { *; }
-dontwarn okhttp3.**
-keep interface okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okio.**
-keep class retrofit2.** { *; }
-dontwarn retrofit2.**

-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**
-keep class * implements com.google.gson.TypeAdapter
-keepclassmembers class * { @com.google.gson.annotations.SerializedName <fields>; }

-keep class com.midtrans.** { *; }
-keep class id.co.veritrans.** { *; }
-dontwarn com.midtrans.**
-dontwarn id.co.veritrans.**

-dontwarn org.apache.log4j.**
-dontwarn com.fasterxml.uuid.**
-keep class com.fasterxml.uuid.** { *; }

-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator CREATOR;
}

-keepclassmembers class * { @androidx.annotation.Keep *; }
-keep class ** { @androidx.annotation.Keep *; }

-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
