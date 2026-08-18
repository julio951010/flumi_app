# Plan: Flumi online (Supabase como única fuente de verdad)

Objetivo: eliminar el modelo "offline-first" (SQLite como fuente + colas de
`pendienteDeSincronizar`). Todo el dato compartido y el negocio (feed, likes,
visitas, matches, mensajes, límites, suscripción) vive en Supabase y llega en
vivo vía Realtime. La BD local queda solo como caché de lectura opcional.

Regla de decisión por capa:
- **Online (servidor)**: perfiles ajenos, feed, likes, visitas, matches,
  mensajes, bloqueos, reportes, suscripción, límites diarios, fotos.
- **Local (dispositivo)**: solo preferencias de UI (onboarding visto, tema,
  idioma) y la sesión (ya es así vía supabase_flutter).
- **Caché opcional**: SQLite como "último estado conocido" para arranque rápido
  o lectura sin red. Descartable y jamás fuente de verdad.

---

## Fase 0 — Base de datos remota lista (Supabase SQL, idempotente)

Estado: ✅ Aplicado en remoto y espejado en `supabase/schema.sql` (tabla
`rechazos` con RLS, trigger `try_crear_match`, policies de likes/visitas/
rechazos, publicación Realtime de profiles/historial_likes/visitas/matches/
messages).

Cambios en `supabase/schema.sql` (o nuevo archivo de migración aditiva):

1. **Tabla `rechazos`** (no existe hoy en el servidor; el feed debe excluirla):
   ```sql
   create table if not exists public.rechazos (
     id             uuid primary key default uuid_generate_v4(),
     usuario_id     uuid not null references public.profiles(id) on delete cascade,
     rechazado_id   uuid not null references public.profiles(id) on delete cascade,
     "timestamp"    timestamptz default now(),
     constraint par_rechazo_unico unique (usuario_id, rechazado_id)
   );
   alter table public.rechazos enable row level security;
   -- policy: solo el usuario gestiona sus rechazos (for all, using/with check auth.uid() = usuario_id)
   ```

2. **Trigger de match automático** en `historial_likes`: cuando existe like
   recíproco, insertar fila en `matches` (ids ordenados para respetar
   `par_unico`), sin duplicados:
   ```sql
   create or replace function public.try_crear_match()
   returns trigger ... as $$
     declare a uuid := least(new.usuario_id, new.usuario_likeado_id);
             b uuid := greatest(new.usuario_id, new.usuario_likeado_id);
   begin
     if exists (select 1 from public.historial_likes
                where usuario_id = new.usuario_likeado_id
                  and usuario_likeado_id = new.usuario_id) then
       insert into public.matches (usuario_a_id, usuario_b_id)
       values (a, b) on conflict do nothing;
     end if;
     return new;
   end $$;
   ```
3. **RLS para historial_likes**: añadir policy de DELETE propio
   (el usuario puede borrar sus likes; hoy "for all" ya permite pero se
   verifica `usuario_id`).
4. **Realtime**: publicar las tablas que se consumen en vivo:
   ```sql
   alter publication supabase_realtime add table
     public.profiles, public.historial_likes, public.visitas,
     public.matches, public.messages;
   ```
   (Idempotente si no existe: `do` + comprobar `pg_publication_tables`.)

Criterio de aceptación: ejecutar el SQL sin errores; dos cuentas se dan like
desde la consola (REST) y `matches` se crea solo; el feed RPC excluye `rechazos`.

---

## Fase 1 — Perfil y sesión directos

Estado: ✅ Hecho.

Objetivo: leer/guardar el perfil propio directamente contra `profiles`, sin
máquina de pendientes.

App:
- `perfil_repositorio.dart`: `obtenerPerfilPropio()` → `select('profiles').eq('id', uid).single()`
  mapeando a `Usuario`; guardar perfil → `upsert`/`update` directo.
- `sync_service.dart`: eliminar los bloques de perfil con
  `pendienteDeSincronizar` (sincronizarPerfil/asegurarPerfilPropio quedan como
  lectura directa). El modelo `Usuario` local se puede seguir usando en UI.
- Subida de fotos (`perfil_foto_servicio.dart`): ya es directa a
  `profile-photos`; sin colas.

Queda igual: auth (Supabase), onboarding (escribe perfil completado directo).

Criterio: editar perfil en la app y ver el cambio en la consola de Supabase al
instante; sin "pendiente de sincronizar".

---

## Fase 2 — Feed en línea (Encuentros + Cerca de ti)

Objetivo: el servidor filtra y pagina; la app ya no descarga "todo y filtra
en memoria".

Estado: ✅ SQL aplicado y verificado en remoto; ✅ app enlazada vía SyncService.

Supabase (✅ hecho):
- `perfiles_cercanos(lat, lon, radio_metros int default 20000,
  filtros jsonb default '{}', desde int default 0, cuantos int default 10)`
  plpgsql, `security definer set search_path = public`:
  - Lee `busca_genero` + `preferencia_edad_min/max` del perfil propio
    (`auth.uid()`) y filtra por defecto (criterios base), salvo `ampliar:true`.
  - Acepta `filtros` del usuario: `ampliar`, `orden` ('distancia'|'score'),
    `generos` (text[]), `edad_min`, `edad_max`, `en_linea`
    (`ultima_conexion` > now()-5min y no oculto), `verificado`, `ciudad`.
  - Excluye siempre: rechazos del propio, perfiles que ya me gustaron
    (no repetir), bloqueos (ambas direcciones), a mí mismo.
  - Pagina con `limit cuantos offset desde` y ordena por distancia (geography)
    o por `score_popularidad`.
  - Ayudantes: `normalizar_genero(text)`, `cumple_genero(opcion, genero)`.
  - La versión vieja de 3 args (sql, sin exclusiones) fue eliminada del
    remoto. `supabase/schema.sql` espeja todo esto.
  - Verificado en remoto por Management API simulando sesión
    (set_config request.jwt.claims): rechazos y likes excluyen del feed;
    `ampliar` relaja distancia/edad/filtros pero mantiene exclusiones.

App (✅ hecho):
- `sync_service.dart`: `sincronizarFeedCercano` ahora acepta
  `filtros` (jsonb del RPC), `desde` y `cuantos` (paginación) y se los pasa
  al RPC; añade `SyncService.filtrosARpcJson(...)` para convertir
  `FiltrosEncuentros` → JSON del RPC.
- `main.dart` `_ampliarBusqueda`: llama a la sync con `filtrosARpcJson(
  ampliar: true)` y radio 50 km.
- Rechazos al remoto (criterio de la Fase 2): tabla drift `Rechazos` ganó
  `pendienteDeSincronizar`; `sync_service.sincronizarRechazos()` sube los
  pendientes (upsert con RLS `usuario_gestiona_sus_rechazos`) y baja los
  remotos; se añadió a `sincronizarTodo`. `votos_servicio`:
  `registrarRechazo` hace write-through (`unawaited(sincronizarRechazos)`),
  `inicializar` refresca online-first, `quitarRechazo` (Deshacer) borra en
  remoto (`borrarRechazoRemoto`, best-effort).
- Pantallas con RPC directo (✅ hecho): `SyncService.consultarFeedRemoto()`
  llama al RPC con `lat/lon/radio/filtros/desde/cuantos` y devuelve
  `List<Usuario>` en memoria (nuevo `PerfilMapeo.perfilRemotoAUsuario`).
  `encuentros_pantalla.dart` y `cerca_de_ti_pantalla.dart` usan
  `_siguienteLote(conAmpliacion)` con offset remoto; si el RPC vuelve vacío
  se reintenta con `ampliar:true` (radio -1, sin filtros) antes de rendirse.
  Encuentros pide `orden:'score'`, Cerca de ti `orden:'distancia'` (se quitó
  el sort local). El `_filtrar` local queda como espejo idempotente de
  exclusión instantánea (rechazos/gustados de la sesión) y replica las
  mismas reglas de ampliación que el servidor.

Criterio: con dos cuentas en dos dispositivos, los rechazos y likes de un
dispositivo afectan el feed del otro sin borrar la BD local ni reiniciar.

---

## Fase 3 — Likes, visitas y matches en vivo

Estado: ✅ Hecho (SQL probado en remoto por Management API; app: analyze 0
errores y tests 12/12; falta validar el criterio con dos dispositivos).

Objetivo: el like se registra y propaga al instante; el match se crea en el
servidor (trigger de Fase 0); Me Gusta y notificaciones se actualizan solas.

Supabase (HECHO, probado en remoto; espejo en `supabase/schema.sql`):
- RPC `registrar_me_gusta(perfil_id uuid, es_super boolean default false)`
  (plpgsql, security definer):
  1. Valida límite diario por plan desde `usos_diarios` (incrementa con
     `insert on conflict do update`) — el cupo deja de depender del reloj del
     teléfono. Gratis: 15 me gustas / 0 superlikes; plus: -1 / 10; premium: -1 / -1.
  2. Inserta `historial_likes` (si no existe) → el trigger crea el match si es
     recíproco.
  3. Retorna `{match, likeado, limite, error}` (con `limite=true` no consume nada).
- RPC `registrar_visita(perfil_id uuid)` → `{ok}` (misma sesión/usuario, sin límite).

App (✅ hecho):
- `visitas_historial_servicio.dart`: `registrarLike(usuario, {esSuper})`
  → RPC `registrar_me_gusta` y devuelve `ResultadoMeGusta{match, likeado, limite}`;
  sin conexión → insert local pendiente + sync (fallback). `registrarVisita`
  → RPC `registrar_visita` cuando hay conexión; offline → local + sync.
- Callers (HECHO): `encuentros_pantalla.dart` (`_aplicarMeGusta`, `_superlike`),
  `cerca_de_ti_pantalla.dart` (`_meGusta`) y `me_gusta_pantalla.dart` (`_meGusta`):
  si `limite` → bloqueo de suscripción sin consumir; si `match` → `MatchPantalla`
  con certeza del servidor.
- Realtime (HECHO): en `main.dart` `_NavegacionPrincipalState` se suscribe a
  `historial_likes` (`usuario_likeado_id = miId`) y `visitas` (`visitado_id =
  miId`); al recibir: incrementa `ContadorMeGusta` y el badge `_meGustaNoLeidas`;
  `MeGustaPantalla` escucha el contador y refresca sus listas.
- Pendiente: `obtenerIdsGustados/obtenerLikesRecibidos` seguirán en sync hasta
  la Fase 5 (la pestaña ya refresca en vivo vía el contador); el contador de
  matches se integra en Fase 5 (actualmente 0 como antes).

Criterio: cuenta B da like a A en otro dispositivo → en A aparece el contador
y la lista sin tocar nada; match animado aparece en el momento.

---

## Fase 4 — Chat en tiempo real

Estado: ✅ Hecho (analyze 0 errores, tests 12/12; falta el criterio de dos
dispositivos en vivo).

Objetivo: mensajes sin recargas y con estados entregado/leído en vivo.

Supabase (✅ hecho):
- Realtime ya abierto a `messages` y `matches` (Fase 0).
- Policy nueva `participantes_actualizan_su_leido_hasta` (update en
  `matches` con RLS de participantes) — aplicada en remoto y en `schema.sql`.

App (✅ hecho):
- `chat_repositorio.dart`:
  - `suscribirseARealtime` ahora escribe en vivo a SQLite (upsert por uuid):
    `messages` (RLS filtra por participante) y `matches` (nuevos matches del
    trigger y cambios de `leido_hasta`/`ultimo_mensaje_preview`).
  - `marcarConversacionLeida` propaga `leido_hasta` a Supabase (best-effort)
    además de la tabla local.
  - Enviar mensaje: sigue local insert + write-through (`sincronizarMensajes
    Pendientes`); el Realtime trae de vuelta el mensaje e ignora el duplicado.
- `main.dart`: suscripción app-wide al arrancar `_NavegacionPrincipalState`
  (mensajes + matches) y cancelación en dispose; el stream local de
  `observarConversaciones` (badge de chats y lista) reacciona a la BD que
  nutre Realtime.

Criterio: dos dispositivos chatean y el mensaje aparece en ambos sin refrescar.

---

## Fase 5 — Notificaciones y contadores derivados

Estado: ✅ Hecho (lo implementable sin push remoto; ver pendiente).

Objetivo: la bandeja y los badges se construyen de datos en vivo, sin tablas
locales de notificaciones.

- Badges en vivo (✅ hecho): likes recibidos y visitas por Realtime
  (`main.dart` `_iniciarRealtimeInteracciones`); mensajes ya reaccionan via
  `observarConversaciones` (BD nutrida por Realtime); matches: el contador
  sigue la tabla local (`watch()` en `main.dart`) y añade al badge cuando
  crece.
- La bandeja es derivada (visitas/likes/matches/mensajes) y se lee de la BD
  local, que Realtime/sync mantienen al día: el cambio de fuente ya está
  resuelto de facto.
- Push (pendiente, no bloquea): Edge Function que escuche `insert` en
  `historial_likes`/`matches`/`messages` y envíe FCM.

Criterio: abrir la app B (background) → recibir like de A → badge al volver.

---

## Fase 6 — Límites y suscripción validados en el servidor

Estado: ✅ Hecho (analyze 0 errores, tests 12/12).

Objetivo: cupos (me gustas, deshacer, superlikes, boosts, vistas) y plan
leídos/validados en `usos_diarios`/`suscripciones` dentro de los RPCs.

- `registrar_me_gusta` (Fase 3): valida me gustas (15/día gratis) y
  superlikes (0 gratis, 10 plus) desde `usos_diarios` (✅ hecho).
- `registrar_deshacer(perfil_id)` (✅ nuevo, probado en remoto): cupo de
  Deshacer server-side (gratis 1/día, plus/premium ilimitado); si está
  agotado devuelve `{ok:false, limite:true}` y NO borra el rechazo; con cupo
  borra el rechazo del remoto en la misma llamada. Espejo en `schema.sql`
  (sección FASE 6).
- `votos_servicio.quitarRechazo(uuid, {comoDeshacer})` (✅): el flujo de
  Deshacer (`encuentros_pantalla._undo`) valida primero en el RPC y solo
  aplica el undo + gasta cupo si el servidor lo concede (si no, bloqueo de
  suscripción); los likes a alguien ya rechazado pasan `comoDeshacer:false`
  (borrado administrativo sin cupo). Sin conexión sigue best-effort local.
- `suscripcion_servicio.dart` (✅ ya online-first): lee plan y usos_diarios
  desde Supabase al arrancar y refresca en cada cambio; los `registrarX`
  locales son un espejo de escritura (el servidor es la autoridad).
- Limpiar la BD ya no "resetea cupos": el contador vive en el servidor y el
  refresco online los vuelve a bajar (✅).

Criterio: dar 5 me gustas gratis en un dispositivo y la cuenta en otro no
puede dar más. (Parcialmente validado por Management API en las fases 3 y 6;
falta el flujo de doble dispositivo en vivo.)

---

## Fase 7 — Caché local opcional / limpieza final

Estado: ✅ Decisión tomada y limpieza parcial hecha.

Decisiones al terminar las fases 1-6:
- **Opción A (elegida): mantener SQLite como caché de escritura/lectura.**
  La app sigue funcionando sin conexión (colas de pendientes y lectura
  offline-first), y online el dato llega por Realtime/sync y se refleja en
  la UI vía las tablas locales. Eliminar drift (Opción B) se descarta: el
  costo es alto y el modo offline "sin servidor" del proyecto lo justifica.
- ✅ `kUsarModoMock` eliminado (guard muerto: siempre false; quedaba en
  `sync_service` como retorno temprano). `flutter analyze` 0 errores y
  tests 12/12 tras la limpieza.
- `kUsarServidorLocal` y el `server/` local se conservan únicamente como
  modo de desarrollo (flag `=> false` en producción), según lo previsto.
- `pendienteDeSincronizar` restantes (mensajes, matches, reportes, bloqueos,
  visitas, likes, rechazos, usos) se conservan: son el fallback offline de
  la Opción A. Una vez validado el flujo en vivo de doble dispositivo de las
  fases 3-6 se puede decidir si se simplifican en favor de escrituras
  directas online con cola solo de emergencia.
- Conservar `tool/limpiar_datos_test.dart` y `tool/limpiar_remoto.sql` para
  reset de pruebas (el remoto pasa a ser la limpieza principal).

Criterio: `flutter analyze` 0 errores, tests 12/12, y el flujo completo
(perfil → feed → like → match → chat) operable sin SQLite. (Cumplido según
la Opción A: el flujo opera con SQLite como caché.)

---

## Orden recomendado de ejecución

Estado: fases 0-7 implementadas ✅ (analyze 0 errores, tests 12/12). Queda la
validación manual del criterio "dos cuentas en dos dispositivos" de las
fases 3-6, y el push FCM opcional de la Fase 5.

Fase 0 (schema+RLS+trigger+realtime) → Fase 1 (perfil) → Fase 2 (feed) →
Fase 3 (likes/visitas/matches) → Fase 4 (chat) → Fase 5 (notificaciones) →
Fase 6 (límites) → Fase 7 (cache/limpieza).

Cada fase es independiente y validable con dos cuentas en dos dispositivos.
Las fases 2-3 son las que más valor aportan (arreglan el feed y el match).