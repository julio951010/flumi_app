# telephony (fork local Flumi)

Copia local de `telephony 0.2.0` (paquete discontinuado) con la API Dart
intacta (`lib/` sin cambios) y el build Android migrado a **Built-in Kotlin**:

- `android/build.gradle`: sin `buildscript` de `kotlin-gradle-plugin`, sin
  `apply plugin: 'kotlin-android'`. Usa el bloque `kotlin { compilerOptions }`
  con la versión de Kotlin del root project de Flutter (igual que
  `google_mlkit_commons 0.13.0`).
- `namespace` declarado en `build.gradle` (el `package` del manifest está
  obsoleto en AGP 8+).
- `compileSdk = 36`, `minSdk = 23`, JVM 11.

Esto elimina el warning de Flutter:

> Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP):
> ... telephony

Y evita depender del caché de pub (donde se había parcheado el manifest
y el `compileSdkVersion` a mano).

## Actualizar

Si algún día aparece un fork mantenido con Built-in Kotlin, cambiar
`pubspec.yaml` de la app de `path: packages/telephony` al paquete hosted
y borrar esta carpeta.
