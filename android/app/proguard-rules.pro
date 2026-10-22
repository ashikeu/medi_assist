# R8 is enabled for release builds. These keeps cover classes that are only
# ever reached reflectively or from the Android framework, which R8 cannot see.

# Entry points named in AndroidManifest.xml.
-keep class com.gdelataillade.alarm.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# flutter_local_notifications deserializes scheduled notifications from disk
# with Gson; obfuscating the field names breaks every pending notification
# across an app update.
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-dontwarn com.google.gson.**

# Referenced by the desugared java.time backport but absent at runtime.
-dontwarn java.beans.**
-dontwarn org.slf4j.**
