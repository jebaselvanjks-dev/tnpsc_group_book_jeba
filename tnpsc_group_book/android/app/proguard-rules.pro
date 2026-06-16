# Hive protection
-keep class com.hive.** { *; }
-keepclassmembernames class com.hive.** { *; }

# Models protection (To prevent Hive serialization issues)
-keep class com.tnpsc.groupbook.tnpsc_group_book.models.** { *; }

# Firebase protection
-keep class com.google.firebase.** { *; }

# AdMob protection
-keep class com.google.android.gms.ads.** { *; }

# Flutter and Plugins
-keep class io.flutter.** { *; }
-keep class de.julianassmann.flutter_background.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Fix for R8 missing Play Core classes
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
