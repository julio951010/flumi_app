# Reglas keep para flutter_local_notifications + FCM.
# Sin esto, R8 (isMinifyEnabled + isShrinkResources) elimina recursos
# referenciados por nombre de texto (ic_notif, canal "flumi", etc.).
# Fuente: https://github.com/MaikuB/flutter_local_notifications#proguard

-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class io.flutter.plugins.firebasemessaging.** { *; }
-keep class com.google.firebase.messaging.** { *; }

# Mantener el drawable ic_notif referenciado desde AndroidInitializationSettings('ic_notif')
-keepclassmembers class **.R$drawable {
    public static int ic_notif;
}