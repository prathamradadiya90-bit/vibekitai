# VibeKit AI — Production Proguard / R8 Full Mode Optimization Rules

# Flutter Core & Plugins
-keep class io.flutter.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

# Flutter deferred components & optional play core classes
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**

# Google Play Billing (com.android.billingclient)
-keep class com.android.billingclient.api.** { *; }
-keep class com.dooboolab.flutterinapppurchase.** { *; }

# Google Play Integrity API
-keep class com.google.android.play.core.integrity.** { *; }

# Google Mobile Ads (AdMob)
-keep class com.google.android.gms.ads.** { *; }
-keep public class com.google.ads.** { *; }
-keep class com.google.android.gms.ads.mediation.** { *; }

# SQLite (sqflite)
-keep class com.tekartik.sqflite.** { *; }

# Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Prevent obfuscation of serializable / native JNI bindings
-keepclasseswithmembernames class * {
    native <methods>;
}

-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    !private <methods>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}
