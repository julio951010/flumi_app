# Flumi — "Déjate llevar por la corriente"
## Arquitectura Offline-First para el mercado cubano — Fase 1

---

## 1. Decisiones de arquitectura y por qué

### 1.1 Isar como base local (no sqflite)
Para Closi ya usas SQLite crudo con `DatabaseHelper`. Para Flumi propongo **Isar** en vez de sqflite/Drift por tres razones específicas a este dominio:

- **Consultas geoespaciales rápidas sin plugin nativo extra**: Isar tiene índices compuestos que permiten filtrar por rango de lat/lon de forma eficiente en el dispositivo, algo que en un feed de "personas cerca de ti" offline se ejecuta constantemente.
- **Sin SQL boilerplate para un esquema que cambiará rápido en MVP**: en fase de iteración de producto (swipes, matches, chat) el esquema de citas cambia más seguido que el de un directorio de negocios. Isar regenera los adaptadores con build_runner en segundos.
- **Watchers reactivos nativos** (`.watch()`): el chat y el feed de matches necesitan UI que reaccione a cambios locales sin montar un `StreamController` manual como hiciste con `ConnectivityService`.

**Contrapartida real**: Isar usa `Id` (int64) autogenerado como llave primaria nativa, NO UUID. Como Supabase sí necesita UUID para sincronizar entre usuarios, cada modelo local tendrá:
- `id` (int, Isar-native, solo local, autoincremental) — para que Isar indexe rápido.
- `uuid` (String, índice único) — la llave real de sincronización, generada con `uuid` package en el momento de creación, antes de tocar red.

Esto es el mismo patrón que evita el bug que resolviste en Closi con el UUID demo inválido rompiendo el FK en PostgreSQL: **el UUID se genera siempre en el cliente, nunca lo asigna el servidor**, así el registro es válido offline desde el primer instante.

### 1.2 Por qué Supabase (reafirmado)
Igual que en Closi: PostgreSQL real + PostGIS para geo-queries en el backend, Auth integrado, Row Level Security para que un usuario no pueda leer mensajes ajenos (crítico en una app de citas), y todo dentro del plan gratuito. Nada de Firebase/Google — coherente con tu entorno de Psiphon3.

### 1.3 Mapas: Leaflet + flutter_map + OSM
Mismo stack que evaluaste antes de migrar a Mapsforge nativo en Closi. Para Flumi el uso de mapa es más ligero (mostrar ubicación aproximada, no navegación offline completa), así que **sí conviene** quedarnos en `flutter_map` puro sin la complejidad de un `PlatformView` de Kotlin — no hay necesidad de renderizado de mapas offline pesado tipo Mapsforge aquí, salvo que definamos más adelante que el mapa de "quién está cerca" deba funcionar 100% sin conexión con tiles descargados (lo dejo como decisión pendiente, ver sección 6).

### 1.4 Consideración legal/de plataforma (importante, léelo)
Antes de escribir una sola línea más de código de producción, ten en cuenta:

- **Google Play Store** clasifica apps de citas como "Dating" y exige verificación de edad reforzada, moderación de contenido y, en la mayoría de países, un proceso de revisión más estricto (a veces revisión manual). Esto es independiente de que la app sea offline-first.
- **Verificación de identidad/edad**: como mínimo el MVP debe pedir fecha de nacimiento real (no solo "edad") y ese dato debe validarse server-side también, no solo en el cliente Isar, porque un cliente modificado podría falsear la edad local.
- **Moderación de fotos y mensajes**: en apps de citas, Play Store y la mayoría de tiendas piden mecanismo de reporte de usuario y bloqueo, disponible desde el día 1, no como fase 2. Lo incluyo en el esquema de abajo (`reportes`, `bloqueos`) aunque no lo pediste explícitamente, porque sin esto la app puede ser rechazada en revisión.
- Estas son restricciones de plataforma/producto, no jurídicas — te las señalo porque afectan directamente el esquema de datos que sigue.

---

## 2. Esquema de datos

### 2.1 Local (Isar) — ver `lib/models/*.dart`
Los tres modelos que pediste (`UserLocal`, `MessageLocal`, `MatchLocal`) más dos que añado por moderación (`ReportLocal`, `BlockLocal`) para que el flujo de bloqueo/reporte funcione incluso sin conexión (el usuario bloquea localmente de inmediato, se sincroniza después).

### 2.2 Remoto (Supabase/PostgreSQL) — ver `supabase/schema.sql`
Incluye:
- `profiles` (extiende `auth.users`)
- `messages`
- `matches`
- `reports`
- `blocks`
- Row Level Security policies básicas
- Índice geoespacial con PostGIS sobre `profiles`

---

## 3. Estrategia de sincronización

Mismo patrón de dos capas que usaste en Closi (`SyncService` + `ConnectivityService`), con una diferencia clave: en Flumi el chat necesita **sincronización más agresiva** cuando hay red (casi tiempo real), mientras que el feed de perfiles cercanos puede seguir el patrón LRU que ya definiste para negocios en Closi.

Cola de sincronización con 3 prioridades:
1. **Alta** — mensajes salientes, cambios de estado de match (like/dislike/match).
2. **Media** — cambios de perfil propio (foto, bio, ubicación).
3. **Baja** — refresco de perfiles cercanos (background, solo si hay wifi o el usuario lo pide explícitamente, dado el costo de datos móviles en Cuba).

Ver `lib/services/sync_service.dart` para el esqueleto.

---

## 4. Estructura de carpetas propuesta

```
flumi/
├── lib/
│   ├── models/              # Modelos Isar (local)
│   │   ├── user_local.dart
│   │   ├── message_local.dart
│   │   ├── match_local.dart
│   │   ├── report_local.dart
│   │   └── block_local.dart
│   ├── services/
│   │   ├── sync_service.dart
│   │   ├── connectivity_service.dart
│   │   └── isar_service.dart
│   ├── repositories/        # Capa entre UI e Isar/Supabase
│   │   └── (siguiente fase)
│   ├── screens/              # (siguiente fase)
│   └── main.dart             # (siguiente fase)
├── supabase/
│   └── schema.sql
└── pubspec.yaml
```

---

## 5. Dependencias iniciales (pubspec.yaml)

Ver archivo `pubspec.yaml` adjunto. Puntos a validar en tu entorno con Psiphon3:
- `isar` y `isar_flutter_libs` descargan binarios nativos desde GitHub Releases en el primer `flutter pub get` — si tu proxy en el puerto 60000 no cubre `github.com`/`objects.githubusercontent.com`, ese paso fallará igual que te pasó con Maven. Vale la pena probarlo antes de avanzar a Fase 2.
- `flutter_map` y `latlong2` no requieren binarios nativos, solo Dart puro — deberían bajar sin problema vía pub.dev.

---

## 6. Decisiones pendientes para Fase 2

Antes de generar pantallas y lógica de swipe, necesito que definas:
1. ¿El mapa de "personas cerca" debe funcionar 100% offline con tiles pre-descargados (como en Closi), o basta con que funcione solo cuando hay conexión?
2. ¿Fotos de perfil se comprimen/redimensionan en el cliente antes de subir a Supabase Storage? (recomendado dado el ancho de banda cubano)
3. ¿El sistema de verificación de edad será solo autodeclarado en MVP, o planeas alguna verificación adicional desde el inicio?

No hace falta que respondas todo ahora — te dejo el código base funcionando para que lo pruebes primero.
